// Networking/YouTubeService.swift
import Foundation
import GoogleSignIn

@MainActor
final class YouTubeService {

    static let shared = YouTubeService()
    private init() {}
    
    /// The last channel loaded successfully. The paywall uses this so it
    /// doesn't have to load the channel again.
    private(set) var lastChannel: Channel?

    /// Retention curves and video lengths, saved for this session so each loads once
    private var curveCache: [String: [RetentionDataPoint]] = [:]
    private var durationCache: [String: Int] = [:]
    /// Curves being loaded right now, so two screens asking at once share one request
    private var curveTasks: [String: Task<[RetentionDataPoint], Never>] = [:]
    /// The reach job lookup in progress, so screens loading at once don't all create one
    private var reachJobTask: Task<String?, Never>?
    /// Short / long / live per video, saved for this session
    private var formatCache: [String: VideoFormat] = [:]
    /// CTR results, shared by every screen for 10 minutes (it was being fetched 6 times at launch)
    private var thumbStatsTask: Task<[String: ThumbnailStats], Never>?
    private var thumbStatsAt: Date?
    
    /// Call this when the user signs out, so the next account never sees the old channel.
    func clearCache() {
        lastChannel = nil
        curveCache = [:]
        durationCache = [:]
        formatCache = [:]
        thumbStatsTask = nil
        thumbStatsAt = nil
    }
    
    /// Loads the channel, or returns nil if it fails or takes longer than `seconds`.
    func fetchChannel(timeout seconds: Double) async -> Channel? {
        await withTaskGroup(of: Channel?.self) { group in
            group.addTask { @MainActor in
                try? await self.fetchChannel()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: - Mock Data for Demo Account (Apple Review + Testing)
    private func mockChannel() -> Channel {
        Channel(
            id: "UCdemoTechGrowth2026",
            name: "TechGrowth Daily",
            subscribers: 124800,
            totalViews: 4520000,
            watchTime: 18420,
            videoCount: 87,
            thumbnailCTR: 0.062,
            profilePicURL: "https://picsum.photos/id/1015/300/300",
            bannerURL: nil,
            subscribersHidden: false
        )
    }

    private func mockVideos() -> [Video] {
        let now = Date()
        return [
            Video(
                videoId: "demo1",
                title: "I Tried the New YouTube Algorithm for 30 Days – Here’s What Happened",
                publishedAt: now.addingTimeInterval(-86400 * 4),
                views: 42800,
                watchTime: 12400,
                thumbnailCTR: 0.078,
                averageViewDuration: 142,
                dropOffSecond: 18,
                analytics: VideoAnalytics(ctr: 0.078, averageViewDuration: 142, retention: 0.48, expectedViews: 52000, subscribersGained: 1240)
            ),
            Video(
                videoId: "demo2",
                title: "How to Get 10x More Views with Better Thumbnails (2026 Update)",
                publishedAt: now.addingTimeInterval(-86400 * 11),
                views: 67300,
                watchTime: 18900,
                thumbnailCTR: 0.091,
                averageViewDuration: 98,
                dropOffSecond: 12,
                analytics: VideoAnalytics(ctr: 0.091, averageViewDuration: 98, retention: 0.55, expectedViews: 58000, subscribersGained: 890)
            ),
            Video(
                videoId: "demo3",
                title: "Why Your Retention Drops at 47 Seconds (and How to Fix It)",
                publishedAt: now.addingTimeInterval(-86400 * 19),
                views: 21900,
                watchTime: 6700,
                thumbnailCTR: 0.044,
                averageViewDuration: 67,
                dropOffSecond: 47,
                analytics: VideoAnalytics(ctr: 0.044, averageViewDuration: 67, retention: 0.31, expectedViews: 35000, subscribersGained: 320)
            ),
            Video(
                videoId: "demo4",
                title: "7 Thumbnail Mistakes Killing Your CTR Right Now",
                publishedAt: now.addingTimeInterval(-86400 * 26),
                views: 35100,
                watchTime: 9800,
                thumbnailCTR: 0.067,
                averageViewDuration: 115,
                dropOffSecond: 22,
                analytics: VideoAnalytics(ctr: 0.067, averageViewDuration: 115, retention: 0.42, expectedViews: 41000, subscribersGained: 610)
            )
        ]
    }

    private func mockPeriodAnalytics(_ period: TimePeriod) -> (views: Int, watchHours: Double, netSubs: Int) {
        switch period {
        case .week:    return (12400, 620, 340)
        case .month:   return (48700, 2480, 920)
        case .quarter: return (142000, 7100, 2150)
        }
    }

    // Public helper for demo
    func demoVideos() -> [Video] {
        mockVideos()
    }

    // MARK: - Channel Info
    func fetchChannel() async throws -> Channel {
        if AuthManager.shared.isDemoMode {
            let channel = mockChannel()
            lastChannel = channel
            return channel
        }
        
        let token = try await AuthManager.shared.getValidToken()

        var components = URLComponents(
            string: "https://www.googleapis.com/youtube/v3/channels"
        )!
        components.queryItems = [
            .init(name: "part", value: "snippet,statistics,brandingSettings"),
            .init(name: "mine", value: "true")
        ]

        let request = URLRequest(url: components.url!, bearerToken: token)
        let (data, _) = try await URLSession.shared.data(for: request)

        struct Response: Codable {
            let items: [Item]
            struct Item: Codable {
                let id: String?
                let snippet: Snippet?
                let statistics: Statistics?
                let brandingSettings: BrandingSettings?

                struct Snippet: Codable {
                    let title: String?
                    let thumbnails: Thumbnails?
                    struct Thumbnails: Codable {
                        let high: Thumb?
                        let medium: Thumb?
                        let `default`: Thumb?
                        struct Thumb: Codable { let url: String? }
                    }
                }
                struct Statistics: Codable {
                    let subscriberCount: String?
                    let viewCount: String?
                    let videoCount: String?
                    let hiddenSubscriberCount: Bool?   // NEW: true if the creator hides their subs
                }
                struct BrandingSettings: Codable {
                    let image: Image?
                    struct Image: Codable {
                        let bannerExternalUrl: String?
                    }
                }
            }
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let item = decoded.items.first else {
            throw NSError(domain: "ChannelError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No channel found"])
        }

        let thumbs = item.snippet?.thumbnails
        let stats = item.statistics
        
        // NEW: the sub count is only real if it was sent AND isn't hidden
        let subsHidden = (stats?.hiddenSubscriberCount ?? false) || stats?.subscriberCount == nil
        
        let channel = Channel(
            id: item.id ?? "",
            name: item.snippet?.title ?? "Unknown Channel",
            subscribers: Int(stats?.subscriberCount ?? "0") ?? 0,
            totalViews: Int(stats?.viewCount ?? "0") ?? 0,
            watchTime: 0,
            videoCount: Int(stats?.videoCount ?? "0") ?? 0,
            thumbnailCTR: 0,
            profilePicURL: thumbs?.high?.url
                ?? thumbs?.medium?.url
                ?? thumbs?.default?.url
                ?? "",
            bannerURL: item.brandingSettings?.image?.bannerExternalUrl,
            subscribersHidden: subsHidden
        )
        lastChannel = channel
        return channel
    }

    // MARK: - Period Analytics
    func fetchPeriodAnalytics(_ period: TimePeriod) async throws -> (views: Int, watchHours: Double, netSubs: Int) {
        if AuthManager.shared.isDemoMode {
            return mockPeriodAnalytics(period)
        }
        
        let token = try await AuthManager.shared.getValidToken()

        let end = Date()
        guard let start = Calendar.current.date(
            byAdding: .day, value: -period.days, to: end
        ) else {
            throw NSError(domain: "DateError", code: -1)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var components = URLComponents(
            string: "https://youtubeanalytics.googleapis.com/v2/reports"
        )!
        components.queryItems = [
            .init(name: "ids",        value: "channel==MINE"),
            .init(name: "startDate",  value: formatter.string(from: start)),
            .init(name: "endDate",    value: formatter.string(from: end)),
            .init(name: "metrics",    value: "views,estimatedMinutesWatched,subscribersGained,subscribersLost"),
            .init(name: "dimensions", value: "day")
        ]

        let request = URLRequest(url: components.url!, bearerToken: token)
        let (data, _) = try await URLSession.shared.data(for: request)

        struct Response: Codable {
            let columnHeaders: [Header]?
            let rows: [[AnalyticsValue]]?
            struct Header: Codable { let name: String? }
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)

        var viewsIndex = -1, minutesIndex = -1, gainedIndex = -1, lostIndex = -1
        decoded.columnHeaders?.enumerated().forEach { index, header in
            switch header.name {
            case "views":                   viewsIndex   = index
            case "estimatedMinutesWatched": minutesIndex = index
            case "subscribersGained":       gainedIndex  = index
            case "subscribersLost":         lostIndex    = index
            default: break
            }
        }

        var views = 0.0, minutes = 0.0, gained = 0.0, lost = 0.0
        for row in decoded.rows ?? [] {
            func num(_ i: Int) -> Double {
                guard i >= 0, i < row.count else { return 0 }
                return row[i].doubleValue
            }
            views   += num(viewsIndex)
            minutes += num(minutesIndex)
            gained  += num(gainedIndex)
            lost    += num(lostIndex)
        }

        let watchHours = minutes / 60.0
        print("🔍 Analytics — views: \(Int(views)), watchHours: \(watchHours), gained: \(Int(gained)), lost: \(Int(lost))")

        return (Int(views), watchHours, Int(gained - lost))
    }


    // MARK: - Daily Trend (Home chart)

    /// Real daily views, watch hours and net subs for the period.
    func fetchDailyTrend(_ period: TimePeriod) async throws -> DailyTrend {
        if AuthManager.shared.isDemoMode {
            return Self.demoTrend(days: period.days)
        }

        let rows = try await analyticsRows(
            days: period.days,
            metrics: ["views", "estimatedMinutesWatched", "subscribersGained", "subscribersLost"],
            dimension: "day"
        )

        return DailyTrend(
            views:      rows.map { $0["views"] ?? 0 },
            watchHours: rows.map { ($0["estimatedMinutesWatched"] ?? 0) / 60 },
            netSubs:    rows.map { ($0["subscribersGained"] ?? 0) - ($0["subscribersLost"] ?? 0) }
        )
    }

    /// Total watch hours over the last `lastDays` days (365 = YouTube's 12-month window).
    func fetchWatchHours(lastDays: Int) async throws -> Double {
        if AuthManager.shared.isDemoMode {
            return 1_840
        }

        let rows = try await analyticsRows(
            days: lastDays,
            metrics: ["estimatedMinutesWatched"],
            dimension: nil
        )
        return (rows.first?["estimatedMinutesWatched"] ?? 0) / 60
    }

    // MARK: - Shared request

    private func analyticsRows(days: Int, metrics: [String], dimension: String?) async throws -> [[String: Double]] {
        let token = try await AuthManager.shared.getValidToken()

        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else { return [] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var components = URLComponents(string: "https://youtubeanalytics.googleapis.com/v2/reports")!
        var items: [URLQueryItem] = [
            .init(name: "ids",       value: "channel==MINE"),
            .init(name: "startDate", value: formatter.string(from: start)),
            .init(name: "endDate",   value: formatter.string(from: end)),
            .init(name: "metrics",   value: metrics.joined(separator: ","))
        ]
        if let dimension {
            items.append(.init(name: "dimensions", value: dimension))
            items.append(.init(name: "sort",       value: dimension))
        }
        components.queryItems = items

        let request = URLRequest(url: components.url!, bearerToken: token)
        let (data, _) = try await URLSession.shared.data(for: request)

        struct Response: Decodable {
            let columnHeaders: [Header]?
            let rows: [[AnalyticsValue]]?
            struct Header: Decodable { let name: String? }
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let names = decoded.columnHeaders?.map { $0.name ?? "" } ?? []

        return (decoded.rows ?? []).map { row in
            var values: [String: Double] = [:]
            for (index, name) in names.enumerated() where index < row.count && metrics.contains(name) {
                values[name] = row[index].doubleValue
            }
            return values
        }
    }

    // MARK: - Demo account

    static func demoTrend(days: Int) -> DailyTrend {
        // Gentle upward trend with a little day-to-day wobble
        let views = (0..<days).map { i -> Double in
            let d = Double(i)
            return 1_500 + d * 22 + sin(d * 0.9) * 120 + sin(d * 2.3) * 60
        }
        return DailyTrend(
            views:      views,
            watchHours: views.map { $0 * 0.05 },
            netSubs:    (0..<days).map { i in Double(20 + (i * 13) % 17) }
        )
    }

    // MARK: - Early views (for ranking the latest video)

    /// Views each video got in its first `days` days after it was posted.
    /// Every video gets the same number of days, so a new video isn't unfairly
    /// compared to old ones that had months to collect views.
    func fetchEarlyViews(for videos: [(id: String, published: Date)], days: Int) async -> [String: Int] {
        guard !videos.isEmpty, days > 0 else { return [:] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let token = try? await AuthManager.shared.getValidToken() else { return [:] }

        // Work out each video's date window up front (same number of days for every video)
        let calendar = Calendar.current
        let windows: [(id: String, start: String, end: String)] = videos.compactMap { video in
            let start = calendar.startOfDay(for: video.published)
            guard let rawEnd = calendar.date(byAdding: .day, value: days - 1, to: start) else { return nil }
            return (video.id, formatter.string(from: start), formatter.string(from: min(rawEnd, Date())))
        }

        return await withTaskGroup(of: (String, Int)?.self) { group in
            for window in windows {
                group.addTask {
                    var components = URLComponents(string: "https://youtubeanalytics.googleapis.com/v2/reports")!
                    components.queryItems = [
                        .init(name: "ids",       value: "channel==MINE"),
                        .init(name: "metrics",   value: "views"),
                        .init(name: "filters",   value: "video==\(window.id)"),
                        .init(name: "startDate", value: window.start),
                        .init(name: "endDate",   value: window.end)
                    ]

                    struct Response: Decodable { let rows: [[AnalyticsValue]]? }
                    let response = try? await URLSession.shared.data(for: URLRequest(url: components.url!, bearerToken: token))
                    guard
                        let data = response?.0,
                        let decoded = try? JSONDecoder().decode(Response.self, from: data)
                    else { return nil }

                    let views = decoded.rows?.first?.first?.intValue ?? 0
                    return (window.id, views)
                }
            }

            var result: [String: Int] = [:]
            for await item in group {
                if let item { result[item.0] = item.1 }
            }
            return result
        }
    }

    // MARK: - One video's daily views (for the trend line on Video Review)

    /// Daily views for one video, oldest day first.
    /// Covers the last `days` days, or since the video was posted if it's newer.
    func fetchVideoDailyViews(videoId: String, publishedAt: Date, days: Int = 90) async -> [Double] {
        if AuthManager.shared.isDemoMode {
            return (0..<days).map { i -> Double in
                let d = Double(i)
                return 20 + d * 0.12 + sin(d * 0.45) * 6 + sin(d * 1.7) * 3
            }
        }

        let calendar = Calendar.current
        guard let windowStart = calendar.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let start = max(calendar.startOfDay(for: publishedAt), windowStart)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var components = URLComponents(string: "https://youtubeanalytics.googleapis.com/v2/reports")!
        components.queryItems = [
            .init(name: "ids",        value: "channel==MINE"),
            .init(name: "metrics",    value: "views"),
            .init(name: "dimensions", value: "day"),
            .init(name: "sort",       value: "day"),
            .init(name: "filters",    value: "video==\(videoId)"),
            .init(name: "startDate",  value: formatter.string(from: start)),
            .init(name: "endDate",    value: formatter.string(from: Date()))
        ]

        struct Response: Decodable { let rows: [[AnalyticsValue]]? }
        do {
            let token = try await AuthManager.shared.getValidToken()
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: components.url!, bearerToken: token))
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            // Each row is [day, views]
            return (decoded.rows ?? []).compactMap { $0.count >= 2 ? $0[1].doubleValue : nil }
        } catch {
            print("⚠️ Daily views failed:", error)
            return []
        }
    }

    /// Day by day numbers for one video (oldest day first). Days with no data are left out by YouTube.
    struct VideoDaily {
        var views: [Double] = []
        var minutes: [Double] = []   // watch time, in minutes
        var subs: [Double] = []      // subscribers gained that day
    }

    /// Views, watch time and new subscribers per day, in one request.
    func fetchVideoDaily(videoId: String, publishedAt: Date, days: Int = 90) async -> VideoDaily {
        if AuthManager.shared.isDemoMode {
            let views = await fetchVideoDailyViews(videoId: videoId, publishedAt: publishedAt, days: days)
            var minutes: [Double] = []
            var subs: [Double] = []
            for (i, v) in views.enumerated() {
                minutes.append(v * 3.4)
                let bonus: Double = (i % 3 == 0) ? 1 : 0
                subs.append((v / 60).rounded() + bonus)
            }
            return VideoDaily(views: views, minutes: minutes, subs: subs)
        }

        let calendar = Calendar.current
        guard let windowStart = calendar.date(byAdding: .day, value: -days, to: Date()) else { return VideoDaily() }
        let start = max(calendar.startOfDay(for: publishedAt), windowStart)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var components = URLComponents(string: "https://youtubeanalytics.googleapis.com/v2/reports")!
        components.queryItems = [
            .init(name: "ids",        value: "channel==MINE"),
            .init(name: "metrics",    value: "views,estimatedMinutesWatched,subscribersGained"),
            .init(name: "dimensions", value: "day"),
            .init(name: "sort",       value: "day"),
            .init(name: "filters",    value: "video==\(videoId)"),
            .init(name: "startDate",  value: formatter.string(from: start)),
            .init(name: "endDate",    value: formatter.string(from: Date()))
        ]

        struct Response: Decodable { let rows: [[AnalyticsValue]]? }
        do {
            let token = try await AuthManager.shared.getValidToken()
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: components.url!, bearerToken: token))
            let rows = try JSONDecoder().decode(Response.self, from: data).rows ?? []
            // Each row is [day, views, minutes, subs]
            var result = VideoDaily()
            for row in rows where row.count >= 4 {
                result.views.append(row[1].doubleValue)
                result.minutes.append(row[2].doubleValue)
                result.subs.append(row[3].doubleValue)
            }
            return result
        } catch {
            print("⚠️ Daily video numbers failed:", error)
            return VideoDaily()
        }
    }

    // MARK: - Best video ever (for the first look after connecting)

    struct BestVideo {
        let id: String
        let title: String
        let views: Int
    }

    /// The channel's most viewed video, all time. Proof that people want what they make.
    func fetchBestVideo() async -> BestVideo? {
        if AuthManager.shared.isDemoMode {
            guard let top = demoVideos().max(by: { $0.views < $1.views }) else { return nil }
            return BestVideo(id: top.videoId, title: top.title, views: top.views)
        }

        let rows = await analyticsQuery([
            .init(name: "metrics",    value: "views"),
            .init(name: "dimensions", value: "video"),
            .init(name: "sort",       value: "-views"),
            .init(name: "maxResults", value: "1")
        ], timeout: 10)
        guard let row = rows.first, row.count >= 2, case .string(let id) = row[0] else { return nil }
        let views = row[1].intValue

        struct Response: Decodable {
            struct Item: Decodable {
                struct Snippet: Decodable { let title: String }
                let snippet: Snippet
            }
            let items: [Item]
        }
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
        components.queryItems = [.init(name: "part", value: "snippet"), .init(name: "id", value: id)]
        do {
            let token = try await AuthManager.shared.getValidToken()
            var request = URLRequest(url: components.url!, bearerToken: token)
            request.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: request)
            let title = try JSONDecoder().decode(Response.self, from: data).items.first?.snippet.title ?? ""
            return BestVideo(id: id, title: title, views: views)
        } catch {
            return BestVideo(id: id, title: "", views: views)
        }
    }

    // MARK: - Shorts vs long videos
    //
    // 1. Ask YouTube Analytics for its own label (creatorContentType: SHORTS, VIDEO_ON_DEMAND, LIVE_STREAM).
    //    YouTube has this label for views from 2019 on.
    // 2. Anything still unknown: use the length. Up to 60s = Short, over 3 min = long.
    //    In between (Shorts can be up to 3 min), check if youtube.com/shorts/ID stays a Shorts page.

    func fetchFormats(videoIds: [String]) async -> [String: VideoFormat] {
        if AuthManager.shared.isDemoMode {
            return Dictionary(uniqueKeysWithValues: videoIds.map { ($0, VideoFormat.long) })
        }

        let missing = videoIds.filter { formatCache[$0] == nil }
        if !missing.isEmpty {
            var found: [String: (format: VideoFormat, views: Double)] = [:]

            // 1. YouTube's own label, 50 videos per request
            var index = 0
            while index < missing.count {
                let chunk = missing[index..<min(index + 50, missing.count)]
                let rows = await analyticsQuery([
                    .init(name: "dimensions", value: "video,creatorContentType"),
                    .init(name: "metrics",    value: "views"),
                    .init(name: "filters",    value: "video==" + chunk.joined(separator: ","))
                ], startDate: "2019-01-01")
                for row in rows where row.count >= 3 {
                    guard case .string(let id) = row[0], case .string(let type) = row[1] else { continue }
                    let views = row[2].doubleValue
                    // A video can show up twice (a live that became a normal video): keep the bigger one
                    if views >= (found[id]?.views ?? -1) {
                        found[id] = (VideoFormat(apiValue: type), views)
                    }
                }
                index += 50
            }

            var formats = found.mapValues { $0.format }

            // 2. Fallback for the rest: length, then the Shorts page check
            let unknown = missing.filter { formats[$0] == nil }
            if !unknown.isEmpty {
                let durations = await cachedDurations(unknown)
                for id in unknown {
                    guard let seconds = durations[id] else { continue }
                    if seconds <= 60 {
                        formats[id] = .short
                    } else if seconds > 180 {
                        formats[id] = .long
                    } else {
                        formats[id] = await isShortsPage(id) ? .short : .long
                    }
                }
            }

            formatCache.merge(formats) { _, new in new }
            let shorts = formats.values.filter { $0 == .short }.count
            print("🎬 Formats: \(shorts) Shorts, \(formats.count - shorts) long/live (YouTube labeled \(found.count) of \(missing.count))")
        }
        return formatCache.filter { videoIds.contains($0.key) }
    }

    /// youtube.com/shorts/ID stays on /shorts/ for a Short, and redirects to /watch for a normal video
    private func isShortsPage(_ videoId: String) async -> Bool {
        guard let url = URL(string: "https://www.youtube.com/shorts/\(videoId)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        let result = try? await URLSession.shared.data(for: request)
        guard let finalURL = result?.1.url else { return false }
        return finalURL.path.hasPrefix("/shorts/")
    }

    // MARK: - Video insights (Video Review page)
    //
    // Everything the review needs beyond the basic numbers, all real, all from YouTube:
    //   - video length (Data API)
    //   - retention curve: % still watching at each point (Analytics API)
    //   - where views came from: search, suggested, home... (Analytics API)
    //   - the words people searched to find it (Analytics API)

    func fetchVideoInsights(videoId: String, publishedAt: Date? = nil) async -> VideoInsights {
        if AuthManager.shared.isDemoMode { return Self.demoInsights() }

        async let duration = cachedDurations([videoId])
        async let curve = cachedCurve(videoId, publishedAt: publishedAt)
        async let traffic = fetchTrafficSources(videoId: videoId, publishedAt: publishedAt)
        async let terms = fetchSearchTerms(videoId: videoId, publishedAt: publishedAt)

        return VideoInsights(
            durationSeconds: await duration[videoId],
            retentionCurve: await curve,
            trafficViews: await traffic,
            searchTerms: await terms
        )
    }

    /// How well recent videos hold people at the hook moment (their "usual").
    /// Looks at up to 8 recent videos.
    func fetchHookBaseline(recentVideos: [Video]) async -> HookBaseline? {
        if AuthManager.shared.isDemoMode {
            return HookBaseline(median: 0.71, sampleCount: 8,
                                bestTitle: "How to Get 10x More Views with Better Thumbnails (2026 Update)",
                                bestValue: 0.82)
        }
        let sample = await recentInsights(recentVideos)
        let results: [(title: String, value: Double)] = sample.compactMap { item in
            item.insights.hookRetention.map { (item.video.title, $0) }
        }
        guard !results.isEmpty else { return nil }
        let sorted = results.map(\.value).sorted()
        let best = results.max { $0.value < $1.value }
        return HookBaseline(median: sorted[sorted.count / 2],
                            sampleCount: results.count,
                            bestTitle: best?.title,
                            bestValue: best?.value)
    }

    /// Your "usual" way people watch, from up to 8 recent videos:
    ///  - averageCurve: the average retention line (by position in the video)
    ///  - atSecond: the middle value at set moments (0:05, 0:10, 0:30...)
    struct RetentionProfile {
        let averageCurve: [RetentionDataPoint]
        let atSecond: [Int: Double]
        let sampleCount: Int
        let videos: [(video: Video, insights: VideoInsights)]
    }

    func fetchRetentionProfile(recentVideos: [Video], checkpoints: [Int]) async -> RetentionProfile? {
        let sample = await recentInsights(recentVideos)
        guard sample.count >= 3 else { return nil }

        // Average line: group points by position (0%, 1%, ... 100%)
        var buckets: [Int: [Double]] = [:]
        for item in sample {
            for point in item.insights.retentionCurve {
                buckets[Int((point.elapsedTimeRatio * 100).rounded()), default: []]
                    .append(min(point.audienceWatchRatio, 1))
            }
        }
        let averageCurve = buckets.keys.sorted().compactMap { key -> RetentionDataPoint? in
            guard let values = buckets[key], values.count >= 3 else { return nil }
            return RetentionDataPoint(elapsedTimeRatio: Double(key) / 100,
                                      audienceWatchRatio: values.reduce(0, +) / Double(values.count))
        }

        // Middle value at each moment (only videos long enough for that moment)
        var atSecond: [Int: Double] = [:]
        for second in checkpoints {
            let values = sample.compactMap { item -> Double? in
                guard let d = item.insights.durationSeconds, Double(second) <= Double(d) * 0.5 else { return nil }
                return item.insights.retention(atSecond: second)
            }.sorted()
            if values.count >= 3 { atSecond[second] = values[values.count / 2] }
        }

        return RetentionProfile(averageCurve: averageCurve, atSecond: atSecond,
                                sampleCount: sample.count, videos: sample)
    }

    /// Length + retention curve for one video (cached)
    func retentionInsights(for videoId: String, publishedAt: Date? = nil) async -> VideoInsights {
        if AuthManager.shared.isDemoMode {
            var demo = Self.demoInsights()
            demo.trafficViews = [:]
            demo.searchTerms = []
            return demo
        }
        async let durations = cachedDurations([videoId])
        async let curve = cachedCurve(videoId, publishedAt: publishedAt)
        return VideoInsights(durationSeconds: await durations[videoId], retentionCurve: await curve)
    }

    /// Up to 8 recent videos that have a length and a retention curve
    private func recentInsights(_ recentVideos: [Video]) async -> [(video: Video, insights: VideoInsights)] {
        let sample = Array(recentVideos.prefix(8))
        guard !sample.isEmpty else { return [] }

        if AuthManager.shared.isDemoMode {
            // Slightly different demo lines, so "your usual" looks real
            return sample.enumerated().map { index, video in
                var demo = Self.demoInsights()
                let shift = 0.03 * Double(index % 4) + 0.04
                demo.retentionCurve = demo.retentionCurve.map {
                    RetentionDataPoint(elapsedTimeRatio: $0.elapsedTimeRatio,
                                       audienceWatchRatio: max($0.audienceWatchRatio - shift * $0.elapsedTimeRatio * 2, 0.05))
                }
                return (video, demo)
            }
        }

        let started = Date()
        let durations = await cachedDurations(sample.map(\.videoId))

        // Load curves 3 at a time: fast, without flooding YouTube with 8 heavy requests at once
        var curves: [String: [RetentionDataPoint]] = [:]
        var index = 0
        while index < sample.count {
            let batch = sample[index..<min(index + 3, sample.count)]
            let loaded = await withTaskGroup(of: (String, [RetentionDataPoint]).self) { group in
                for video in batch {
                    group.addTask { (video.videoId, await self.cachedCurve(video.videoId, publishedAt: video.publishedAt)) }
                }
                var result: [String: [RetentionDataPoint]] = [:]
                for await (id, curve) in group { result[id] = curve }
                return result
            }
            curves.merge(loaded) { _, new in new }
            index += 3
        }

        let result: [(video: Video, insights: VideoInsights)] = sample.compactMap { video in
            guard let duration = durations[video.videoId],
                  let curve = curves[video.videoId], curve.count >= 20 else { return nil }
            return (video, VideoInsights(durationSeconds: duration, retentionCurve: curve, isShort: video.isShort))
        }
        print("⏱ Usual retention from \(result.count)/\(sample.count) videos in \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
        return result
    }

    private func cachedCurve(_ videoId: String, publishedAt: Date?) async -> [RetentionDataPoint] {
        if let cached = curveCache[videoId] { return cached }
        if let running = curveTasks[videoId] { return await running.value }

        let task = Task { await self.fetchRetentionCurve(videoId: videoId, publishedAt: publishedAt) }
        curveTasks[videoId] = task
        let curve = await task.value
        curveTasks[videoId] = nil
        if !curve.isEmpty { curveCache[videoId] = curve }
        return curve
    }

    private func cachedDurations(_ videoIds: [String]) async -> [String: Int] {
        let missing = videoIds.filter { durationCache[$0] == nil }
        if !missing.isEmpty {
            let fetched = await fetchDurations(videoIds: missing)
            durationCache.merge(fetched) { _, new in new }
        }
        return durationCache.filter { videoIds.contains($0.key) }
    }

    /// Video length in seconds, for up to 50 videos in one request
    func fetchDurations(videoIds: [String]) async -> [String: Int] {
        guard !videoIds.isEmpty else { return [:] }
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
        components.queryItems = [
            .init(name: "part", value: "contentDetails"),
            .init(name: "id",   value: videoIds.prefix(50).joined(separator: ","))
        ]
        struct Response: Decodable {
            let items: [Item]?
            struct Item: Decodable {
                let id: String
                let contentDetails: Details?
                struct Details: Decodable { let duration: String? }
            }
        }
        do {
            let token = try await AuthManager.shared.getValidToken()
            var request = URLRequest(url: components.url!, bearerToken: token)
            request.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            var result: [String: Int] = [:]
            for item in decoded.items ?? [] {
                if let text = item.contentDetails?.duration, let seconds = Self.seconds(fromISODuration: text) {
                    result[item.id] = seconds
                }
            }
            return result
        } catch {
            print("⚠️ Durations failed:", error)
            return [:]
        }
    }

    /// "PT1H2M3S" -> 3723
    static func seconds(fromISODuration text: String) -> Int? {
        guard text.hasPrefix("P") else { return nil }
        var total = 0, number = ""
        var inTime = false
        for char in text.dropFirst() {
            if char == "T" { inTime = true; continue }
            if char.isNumber { number.append(char); continue }
            let value = Int(number) ?? 0
            number = ""
            switch char {
            case "D": total += value * 86_400
            case "H": total += value * 3_600
            case "M": total += inTime ? value * 60 : 0
            case "S": total += value
            default: break
            }
        }
        return total > 0 ? total : nil
    }

    /// % still watching at each point of the video (all time)
    func fetchRetentionCurve(videoId: String, publishedAt: Date? = nil) async -> [RetentionDataPoint] {
        // Ask only from the day the video was posted. It's all of the video's data,
        // but a much smaller request, so YouTube answers fast.
        // (Asking "since 2005" made YouTube take 15+ seconds and time out.)
        let start = publishedAt == nil ? "2020-01-01" : Self.startDate(for: publishedAt)

        let rows = await analyticsQuery([
            .init(name: "dimensions", value: "elapsedVideoTimeRatio"),
            .init(name: "metrics",    value: "audienceWatchRatio"),
            .init(name: "filters",    value: "video==\(videoId)")
        ], startDate: start, timeout: 30)
        return rows.compactMap { row -> RetentionDataPoint? in
            guard row.count >= 2 else { return nil }
            return RetentionDataPoint(elapsedTimeRatio: row[0].doubleValue, audienceWatchRatio: row[1].doubleValue)
        }
        .sorted { $0.elapsedTimeRatio < $1.elapsedTimeRatio }
    }

    /// Views by traffic source type, e.g. ["YT_SEARCH": 1200, "RELATED_VIDEO": 5400]
    func fetchTrafficSources(videoId: String, publishedAt: Date? = nil) async -> [String: Double] {
        let rows = await analyticsQuery(startDate: Self.startDate(for: publishedAt), [
            .init(name: "dimensions", value: "insightTrafficSourceType"),
            .init(name: "metrics",    value: "views"),
            .init(name: "filters",    value: "video==\(videoId)")
        ])
        var result: [String: Double] = [:]
        for row in rows where row.count >= 2 {
            if case .string(let type) = row[0] { result[type] = row[1].doubleValue }
        }
        return result
    }

    /// The top words people searched on YouTube to find this video
    func fetchSearchTerms(videoId: String, publishedAt: Date? = nil) async -> [SearchTerm] {
        let rows = await analyticsQuery(startDate: Self.startDate(for: publishedAt), [
            .init(name: "dimensions", value: "insightTrafficSourceDetail"),
            .init(name: "metrics",    value: "views"),
            .init(name: "filters",    value: "video==\(videoId);insightTrafficSourceType==YT_SEARCH"),
            .init(name: "sort",       value: "-views"),
            .init(name: "maxResults", value: "10")
        ])
        return rows.compactMap { row in
            guard row.count >= 2, case .string(let term) = row[0], !term.isEmpty else { return nil }
            return SearchTerm(term: term, views: row[1].intValue)
        }
    }

    /// All-time Analytics query for this channel. Returns [] on any error.
    /// Per-video queries: start the day before the video was posted (small and fast)
    static func startDate(for publishedAt: Date?) -> String {
        guard let publishedAt else { return "2005-04-23" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: publishedAt) ?? publishedAt)
    }

    private func analyticsQuery(startDate: String, _ items: [URLQueryItem]) async -> [[AnalyticsValue]] {
        await analyticsQuery(items, startDate: startDate)
    }

    private func analyticsQuery(_ items: [URLQueryItem], startDate: String = "2005-04-23", timeout: TimeInterval = 20) async -> [[AnalyticsValue]] {
        var components = URLComponents(string: "https://youtubeanalytics.googleapis.com/v2/reports")!
        components.queryItems = [
            .init(name: "ids",       value: "channel==MINE"),
            .init(name: "startDate", value: startDate),
            .init(name: "endDate",   value: Date().youtubeAnalyticsDateString())
        ] + items
        struct Response: Decodable { let rows: [[AnalyticsValue]]? }
        do {
            let token = try await AuthManager.shared.getValidToken()
            var request = URLRequest(url: components.url!, bearerToken: token)
            request.timeoutInterval = timeout   // never leave a screen spinning for a minute
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("⚠️ Analytics \(http.statusCode):", items.map { "\($0.name)=\($0.value ?? "")" },
                      String(data: data, encoding: .utf8)?.prefix(300) ?? "")
                return []
            }
            return try JSONDecoder().decode(Response.self, from: data).rows ?? []
        } catch {
            print("⚠️ Analytics query failed:", items.map { "\($0.name)=\($0.value ?? "")" }, error)
            return []
        }
    }

    static func demoInsights() -> VideoInsights {
        // 8:12 video: strong start, slow slide, one clear drop around 2:14
        let duration = 492
        let curve: [RetentionDataPoint] = (0...100).map { i in
            let x = Double(i) / 100
            var y = 1.0 - 0.22 * min(x / 0.06, 1)          // first seconds
            y -= 0.20 * x                                   // slow slide
            if x > 0.27 { y -= 0.12 * min((x - 0.27) / 0.04, 1) }   // drop at 2:14
            if x > 0.92 { y -= 0.15 * (x - 0.92) / 0.08 }   // end screen
            return RetentionDataPoint(elapsedTimeRatio: x, audienceWatchRatio: max(y, 0.05))
        }
        return VideoInsights(
            durationSeconds: duration,
            retentionCurve: curve,
            trafficViews: ["SUBSCRIBER": 5800, "RELATED_VIDEO": 2400, "YT_SEARCH": 400, "EXT_URL": 900, "PLAYLIST": 500],
            searchTerms: [
                SearchTerm(term: "youtube algorithm 2026", views: 1200),
                SearchTerm(term: "how to get more views", views: 640),
                SearchTerm(term: "youtube growth tips", views: 310)
            ]
        )
    }

    // MARK: - Thumbnail CTR (YouTube Reporting API, "reach" reports)
    //
    // CTR is NOT in the Analytics API. YouTube puts it in daily report files
    // (added January 2026). How it works:
    //   1. We ask YouTube once to start making "channel_reach_basic_a1" reports (a "job").
    //   2. YouTube makes one CSV file per day. The first ones show up 1 to 2 days later.
    //   3. We download each file once, add up the numbers, and cache them on the phone.
    // Needs the "YouTube Reporting API" turned on in Google Cloud. Same sign-in scope
    // as the Analytics API (yt-analytics.readonly).

    struct ThumbnailStats {
        let impressions: Double
        let ctr: Double          // 0...1  (0.062 = 6.2%)
    }

    private static let reachReportType = "channel_reach_basic_a1"

    private var reachJobKey: String { "yt.reachJobId.\(lastChannel?.id ?? "me")" }

    /// Makes sure YouTube is building daily reach reports for this channel.
    /// Safe to call many times, even at the same moment: they all share one request.
    @discardableResult
    func ensureReachJob() async -> String? {
        if AuthManager.shared.isDemoMode { return nil }
        if let saved = UserDefaults.standard.string(forKey: reachJobKey) { return saved }
        if let running = reachJobTask { return await running.value }

        let task = Task { await self.findOrCreateReachJob() }
        reachJobTask = task
        let id = await task.value
        reachJobTask = nil
        return id
    }

    private func findOrCreateReachJob() async -> String? {
        struct Job: Codable { let id: String?; let reportTypeId: String? }
        struct JobList: Codable { let jobs: [Job]? }

        func existingJob(token: String) async throws -> String? {
            let url = URL(string: "https://youtubereporting.googleapis.com/v1/jobs")!
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, bearerToken: token))
            let list = try JSONDecoder().decode(JobList.self, from: data)
            return list.jobs?.first(where: { $0.reportTypeId == Self.reachReportType })?.id
        }

        func save(_ id: String) {
            // Only save once we know which channel this is, so accounts never mix
            if lastChannel != nil { UserDefaults.standard.set(id, forKey: reachJobKey) }
        }

        do {
            let token = try await AuthManager.shared.getValidToken()

            // Already have one? (made earlier, or on another phone)
            if let existing = try await existingJob(token: token) {
                save(existing)
                return existing
            }

            // Make a new one
            var request = URLRequest(url: URL(string: "https://youtubereporting.googleapis.com/v1/jobs")!, bearerToken: token)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "reportTypeId": Self.reachReportType,
                "name": "SubsAI thumbnail CTR"
            ])
            let (createdData, response) = try await URLSession.shared.data(for: request)

            // 409 = it already exists (made a moment ago). Just look it up.
            if (response as? HTTPURLResponse)?.statusCode == 409,
               let existing = try await existingJob(token: token) {
                save(existing)
                return existing
            }

            let job = try JSONDecoder().decode(Job.self, from: createdData)
            if let id = job.id {
                save(id)
                print("✅ Reach report job created:", id)
            } else {
                print("⚠️ Reach job not created:", String(data: createdData, encoding: .utf8) ?? "")
            }
            return job.id
        } catch {
            print("⚠️ Reach job setup failed:", error)
            return nil
        }
    }

    /// Real thumbnail impressions + CTR for each video (all days we have added up).
    /// Returns an empty result until YouTube has made the first reports.
    func fetchThumbnailStats() async -> [String: ThumbnailStats] {
        // Reuse the last result (or the one in progress) for 10 minutes
        if let task = thumbStatsTask, let at = thumbStatsAt, Date().timeIntervalSince(at) < 600 {
            return await task.value
        }
        let task = Task { await self.loadThumbnailStats() }
        thumbStatsTask = task
        thumbStatsAt = Date()
        let result = await task.value
        if result.isEmpty { thumbStatsTask = nil }   // nothing yet: try again next time
        return result
    }

    private func loadThumbnailStats() async -> [String: ThumbnailStats] {
        if AuthManager.shared.isDemoMode {
            return Dictionary(uniqueKeysWithValues: mockVideos().map {
                ($0.videoId, ThumbnailStats(impressions: Double($0.views) * 11, ctr: $0.thumbnailCTR))
            })
        }
        guard let jobId = await ensureReachJob() else { return [:] }

        struct Report: Codable {
            let id: String
            let downloadUrl: String?
            let startTime: String?
            let endTime: String?
            let createTime: String?
        }
        struct ReportList: Codable { let reports: [Report]?; let nextPageToken: String? }

        do {
            let token = try await AuthManager.shared.getValidToken()

            // 1. List the report files
            var reports: [Report] = []
            var pageToken: String?
            repeat {
                var components = URLComponents(string: "https://youtubereporting.googleapis.com/v1/jobs/\(jobId)/reports")!
                if let pageToken { components.queryItems = [.init(name: "pageToken", value: pageToken)] }
                let (data, response) = try await URLSession.shared.data(for: URLRequest(url: components.url!, bearerToken: token))
                if let code = (response as? HTTPURLResponse)?.statusCode, code != 200 {
                    print("⚠️ Reach reports list failed (\(code)):", String(data: data, encoding: .utf8) ?? "")
                    return [:]
                }
                let page = try JSONDecoder().decode(ReportList.self, from: data)
                reports += page.reports ?? []
                pageToken = page.nextPageToken
            } while pageToken != nil && reports.count < 300

            // YouTube sometimes re-makes a day's file. Keep only the newest one per day.
            var newestPerDay: [String: Report] = [:]
            for report in reports {
                let day = report.startTime ?? report.id
                if let current = newestPerDay[day], (current.createTime ?? "") >= (report.createTime ?? "") { continue }
                newestPerDay[day] = report
            }

            // 2. Download only days we don't have yet (or that YouTube re-made).
            // The cache is saved by day and never trimmed. YouTube deletes its
            // files after about 60 days, so this is how the history keeps growing.
            var cache = loadReachCache()
            for (day, report) in newestPerDay where cache[day]?.reportId != report.id {
                guard let urlString = report.downloadUrl, let url = URL(string: urlString) else { continue }
                let (csv, _) = try await URLSession.shared.data(for: URLRequest(url: url, bearerToken: token))
                var parsed = Self.parseReach(csv)
                parsed.reportId = report.id
                parsed.endTime = report.endTime
                cache[day] = parsed
            }
            saveReachCache(cache)
            let videosWithCTR = Set(cache.values.flatMap { $0.rows.keys }).count
            print("📊 Reach: job \(jobId), \(reports.count) report files from YouTube, \(cache.count) days saved, CTR for \(videosWithCTR) videos")
            for report in reports.prefix(10) {
                let from: String = report.startTime ?? "?"
                let to: String = report.endTime ?? "?"
                print("📊 Reach file: \(from) to \(to)")
            }
            if reports.isEmpty {
                print("📊 Reach: YouTube hasn't made the first report yet. This can take up to 48 hours after the job was created.")
            }

            // 3. Add up the LAST 28 DAYS (same as YouTube Studio's default view)
            let scale = Self.reachScale(cache)
            var totals: [String: (impressions: Double, clicks: Double)] = [:]
            for (key, day) in cache where Self.isInLast28Days(key) {
                for (videoId, value) in day.rows {
                    let current = totals[videoId] ?? (0, 0)
                    totals[videoId] = (current.impressions + value[0], current.clicks + value[1] / scale)
                }
            }
            // Under 100 impressions, CTR swings too much to mean anything (1 click in 6 = 16.7%)
            return totals.compactMapValues { total in
                guard total.impressions >= Self.minCTRImpressions else { return nil }
                return ThumbnailStats(impressions: total.impressions, ctr: total.clicks / total.impressions)
            }
        } catch {
            print("⚠️ Thumbnail CTR fetch failed:", error)
            return [:]
        }
    }

    /// Thumbnail CTR for one video, from the saved reach reports.
    /// YouTube only gives these for the days since SubsAI was connected (plus a short backfill),
    /// so this is NOT the video's lifetime CTR. `firstDay`/`lastDay` say which days it covers.
    struct CTRHistory {
        var series: [Double] = []     // 7-day rolling CTR per day, oldest first
        var firstDay: Date?
        var lastDay: Date?
        var days = 0
        var impressions: Double = 0
        var ctr: Double = 0           // clicks / impressions over all those days
    }

    func thumbnailCTRHistory(videoId: String) -> CTRHistory {
        if AuthManager.shared.isDemoMode {
            var demo: [Double] = []
            for i in 0..<30 {
                let day = Double(i)
                let wave: Double = sin(day * 0.4) * 0.006
                let climb: Double = day * 0.0003
                demo.append(0.052 + wave + climb)
            }
            let first = Calendar.current.date(byAdding: .day, value: -30, to: Date())
            return CTRHistory(series: demo, firstDay: first, lastDay: Date(), days: 30, impressions: 48_000, ctr: 0.058)
        }

        let cache = loadReachCache()
        let scale = Self.reachScale(cache)
        let iso = ISO8601DateFormatter()

        // Keys are the report start times (ISO dates), so sorting them sorts by date.
        // Only the last 28 days, same as YouTube Studio's default view.
        var days: [(date: Date?, impressions: Double, clicks: Double)] = []
        var lastEnd: Date?
        for key in cache.keys.sorted() where Self.isInLast28Days(key) {
            guard let day = cache[key], let row = day.rows[videoId], row[0] > 0 else { continue }
            days.append((iso.date(from: key), row[0], row[1] / scale))
            if let end = day.endTime.flatMap({ iso.date(from: $0) }) { lastEnd = end }
        }

        var history = CTRHistory()
        history.days = days.count
        history.firstDay = days.first?.date
        history.lastDay = lastEnd ?? days.last?.date
        var totalImpressions: Double = 0
        var totalClicks: Double = 0
        for day in days {
            totalImpressions += day.impressions
            totalClicks += day.clicks
        }
        history.impressions = totalImpressions
        history.ctr = totalImpressions > 0 ? totalClicks / totalImpressions : 0
        let fromText: String = history.firstDay.map { iso.string(from: $0) } ?? "-"
        let toText: String = history.lastDay.map { iso.string(from: $0) } ?? "-"
        let pctText: String = String(format: "%.2f", history.ctr * 100)
        print("📊 CTR \(videoId): \(days.count) days, \(fromText) to \(toText), \(Int(totalImpressions)) impressions, \(pctText)%, scale \(Int(scale))")

        if days.count >= 3 {
            for i in days.indices {
                var impressions: Double = 0
                var clicks: Double = 0
                for day in days[max(0, i - 6)...i] {
                    impressions += day.impressions
                    clicks += day.clicks
                }
                history.series.append(impressions > 0 ? clicks / impressions : 0)
            }
        }
        return history
    }

    // MARK: Reach report parsing + cache

    struct ReachDay: Codable {
        var rows: [String: [Double]]   // videoId -> [impressions, impressions x raw CTR]
        var maxCTR: Double
        var reportId: String? = nil
        var endTime: String? = nil     // when this report's data ends
    }

    /// Below this many impressions we don't show a CTR (too few people to judge)
    static let minCTRImpressions: Double = 100

    /// YouTube's CTR column is 0-1 or 0-100. If any value is over 1, it's 0-100.
    private static func reachScale(_ cache: [String: ReachDay]) -> Double {
        (cache.values.map(\.maxCTR).max() ?? 0) > 1 ? 100.0 : 1.0
    }

    private static func isInLast28Days(_ key: String) -> Bool {
        guard let date = ISO8601DateFormatter().date(from: key) else { return true }
        return date >= Date().addingTimeInterval(-28 * 24 * 3600)
    }

    private static func parseReach(_ data: Data) -> ReachDay {
        guard let text = String(data: data, encoding: .utf8) else { return ReachDay(rows: [:], maxCTR: 0) }
        var lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return ReachDay(rows: [:], maxCTR: 0) }

        let header = lines.removeFirst()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard
            let videoIndex = header.firstIndex(of: "video_id"),
            let impressionsIndex = header.firstIndex(of: "video_thumbnail_impressions"),
            let ctrIndex = header.firstIndex(of: "video_thumbnail_impressions_ctr")
        else {
            print("⚠️ Unexpected reach report columns:", header)
            return ReachDay(rows: [:], maxCTR: 0)
        }

        var day = ReachDay(rows: [:], maxCTR: 0)
        for line in lines {
            let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard columns.count > max(videoIndex, impressionsIndex, ctrIndex) else { continue }
            // A blank CTR means YouTube held it back (too few people). Skip the row,
            // or its impressions would count as "0 clicks" and drag CTR down to 0%.
            guard
                let impressions = Double(columns[impressionsIndex]),
                let ctr = Double(columns[ctrIndex])
            else { continue }
            let current = day.rows[columns[videoIndex]] ?? [0, 0]
            day.rows[columns[videoIndex]] = [current[0] + impressions, current[1] + impressions * ctr]
            day.maxCTR = max(day.maxCTR, ctr)
        }
        return day
    }

    private var reachCacheURL: URL {
        // Application Support, not Caches: iOS can wipe Caches, and this history can't be downloaded again
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("reach-v3-\(lastChannel?.id ?? "me").json")
    }

    private func loadReachCache() -> [String: ReachDay] {
        guard let data = try? Data(contentsOf: reachCacheURL) else { return [:] }
        return (try? JSONDecoder().decode([String: ReachDay].self, from: data)) ?? [:]
    }

    private func saveReachCache(_ cache: [String: ReachDay]) {
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: reachCacheURL)
        }
    }
}

/// Day-by-day numbers for the selected period (oldest day first).
struct DailyTrend {
    let views: [Double]
    let watchHours: [Double]
    let netSubs: [Double]
}
