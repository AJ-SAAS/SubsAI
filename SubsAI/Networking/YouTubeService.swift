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
    
    /// Call this when the user signs out, so the next account never sees the old channel.
    func clearCache() {
        lastChannel = nil
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
    /// Safe to call many times. Only talks to YouTube the first time.
    @discardableResult
    func ensureReachJob() async -> String? {
        if AuthManager.shared.isDemoMode { return nil }
        if let saved = UserDefaults.standard.string(forKey: reachJobKey) { return saved }

        struct Job: Codable { let id: String?; let reportTypeId: String? }
        struct JobList: Codable { let jobs: [Job]? }

        do {
            let token = try await AuthManager.shared.getValidToken()
            let jobsURL = URL(string: "https://youtubereporting.googleapis.com/v1/jobs")!

            // Already have one? (for example, made on another phone)
            let (listData, _) = try await URLSession.shared.data(for: URLRequest(url: jobsURL, bearerToken: token))
            let list = try JSONDecoder().decode(JobList.self, from: listData)
            if let existing = list.jobs?.first(where: { $0.reportTypeId == Self.reachReportType })?.id {
                UserDefaults.standard.set(existing, forKey: reachJobKey)
                return existing
            }

            // Make a new one
            var request = URLRequest(url: jobsURL, bearerToken: token)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "reportTypeId": Self.reachReportType,
                "name": "SubsAI thumbnail CTR"
            ])
            let (createdData, _) = try await URLSession.shared.data(for: request)
            let job = try JSONDecoder().decode(Job.self, from: createdData)
            if let id = job.id {
                UserDefaults.standard.set(id, forKey: reachJobKey)
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
                let (data, _) = try await URLSession.shared.data(for: URLRequest(url: components.url!, bearerToken: token))
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

            // 2. Download only the files we haven't seen yet
            var cache = loadReachCache()
            for report in newestPerDay.values where cache[report.id] == nil {
                guard let urlString = report.downloadUrl, let url = URL(string: urlString) else { continue }
                let (csv, _) = try await URLSession.shared.data(for: URLRequest(url: url, bearerToken: token))
                cache[report.id] = Self.parseReach(csv)
            }
            let keep = Set(newestPerDay.values.map(\.id))
            cache = cache.filter { keep.contains($0.key) }
            saveReachCache(cache)

            // 3. Add up every day
            // Docs call CTR a "percentage". If any value is above 1 it's 0-100, else 0-1.
            let maxCTR = cache.values.map(\.maxCTR).max() ?? 0
            let scale = maxCTR > 1 ? 100.0 : 1.0

            var totals: [String: (impressions: Double, weighted: Double)] = [:]
            for day in cache.values {
                for (videoId, value) in day.rows {
                    let current = totals[videoId] ?? (0, 0)
                    totals[videoId] = (current.impressions + value[0], current.weighted + value[1])
                }
            }
            return totals.compactMapValues { total in
                guard total.impressions > 0 else { return nil }
                return ThumbnailStats(impressions: total.impressions, ctr: total.weighted / total.impressions / scale)
            }
        } catch {
            print("⚠️ Thumbnail CTR fetch failed:", error)
            return [:]
        }
    }

    // MARK: Reach report parsing + cache

    struct ReachDay: Codable {
        var rows: [String: [Double]]   // videoId -> [impressions, impressions x raw CTR]
        var maxCTR: Double
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
            let impressions = Double(columns[impressionsIndex]) ?? 0
            let ctr = Double(columns[ctrIndex]) ?? 0
            let current = day.rows[columns[videoIndex]] ?? [0, 0]
            day.rows[columns[videoIndex]] = [current[0] + impressions, current[1] + impressions * ctr]
            day.maxCTR = max(day.maxCTR, ctr)
        }
        return day
    }

    private var reachCacheURL: URL {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("reach-\(lastChannel?.id ?? "me").json")
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
