// Features/Coach/CoachViewModel.swift
import Foundation
import SwiftUI

// MARK: - API Models (unchanged)
struct ChannelListResponse: Codable {
    let items: [ChannelItem]

    struct ChannelItem: Codable {
        let contentDetails: ContentDetails
    }

    struct ContentDetails: Codable {
        let relatedPlaylists: RelatedPlaylists
    }

    struct RelatedPlaylists: Codable {
        let uploads: String
    }
}

struct PlaylistItemsResponse: Codable {
    let items: [PlaylistItem]
    let nextPageToken: String?

    struct PlaylistItem: Codable {
        let snippet: Snippet?
        let contentDetails: ContentDetails?

        struct Snippet: Codable {
            let title: String?
            let publishedAt: String?
        }

        struct ContentDetails: Codable {
            let videoId: String?
        }
    }
}

struct AnalyticsReportResponse: Codable {
    let rows: [[AnalyticsValue]]?
}

// MARK: - Posting Time Insight (unchanged)
struct PostingTimeInsight {
    let bestDay: String
    let bestDayAvgViews: Int
    let worstDay: String
    let worstDayAvgViews: Int
    let sampleSize: Int
    let isReliable: Bool

    func isSuboptimal(for video: Video) -> Bool {
        guard isReliable else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let day = formatter.string(from: video.publishedAt)
        return day == worstDay
    }

    var briefingLine: String {
        let reliability = isReliable ? "" : " (early sign, more uploads will make this clearer)"
        return "Your \(bestDay) uploads average \(formatViews(bestDayAvgViews)) views vs \(formatViews(worstDayAvgViews)) on \(worstDay). Post your next video on \(bestDay)\(reliability)."
    }

    func reviewLine(for video: Video) -> String? {
        guard isSuboptimal(for: video) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let day = formatter.string(from: video.publishedAt)
        return "Posted on \(day). Your best day is \(bestDay), so it may have started slower."
    }

    private func formatViews(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Channel Diagnosis (unchanged)
struct ChannelDiagnosis {
    let headline: String
    let body: String
    let videosNeedingAttention: Int

    static func generate(from videos: [Video]) -> ChannelDiagnosis {
        guard !videos.isEmpty else {
            return ChannelDiagnosis(
                headline: "Loading your channel diagnosis…",
                body: "We're analysing your recent videos.",
                videosNeedingAttention: 0
            )
        }

        let enriched = videos.filter { $0.analytics != nil }
        let needsAttention = enriched.filter { $0.primaryFix != .none }.count

        let fixCounts = Dictionary(
            grouping: enriched.compactMap { v -> CoachFix? in
                let f = v.primaryFix
                return f == .none ? nil : f
            },
            by: { $0 }
        ).mapValues { $0.count }

        let topFix = fixCounts.max(by: { $0.value < $1.value })?.key

        let avgCTR = enriched.compactMap { $0.analytics?.ctr }.reduce(0, +)
            / Double(max(enriched.count, 1))
        let avgRetention = enriched.compactMap { $0.analytics?.retention }.reduce(0, +)
            / Double(max(enriched.count, 1))

        switch topFix {
        case .thumbnail:
            return ChannelDiagnosis(
                headline: "Your titles and thumbnails are your biggest growth blocker.",
                body: "Your last \(enriched.count) videos averaged \(String(format: "%.1f", avgCTR * 100))% CTR. That's low. Your content quality is solid (retention is \(String(format: "%.0f", avgRetention * 100))%), but viewers aren't clicking. The problem is the packaging, not the video.",
                videosNeedingAttention: needsAttention
            )
        case .hook:
            return ChannelDiagnosis(
                headline: "Your hooks are costing you viewers before the video starts.",
                body: "Across your recent uploads, average watch duration is below benchmark. Viewers are deciding to leave in the first 30 seconds. One stronger opening line per video could meaningfully change your numbers.",
                videosNeedingAttention: needsAttention
            )
        case .retention:
            return ChannelDiagnosis(
                headline: "Viewers leave partway through, before your best part.",
                body: "Your average retention of \(String(format: "%.0f", avgRetention * 100))% suggests a pacing issue in the middle of your videos. Add a re-hook every 3–4 minutes to pull viewers back in.",
                videosNeedingAttention: needsAttention
            )
        case .discovery:
            return ChannelDiagnosis(
                headline: "Your videos are underperforming on discovery.",
                body: "Views are below expectations for your subscriber count. This usually means your titles and descriptions aren't using the words people search for.",
                videosNeedingAttention: needsAttention
            )
        default:
            return ChannelDiagnosis(
                headline: "Your channel is in good health.",
                body: "CTR and retention are both above benchmark across your recent videos. Keep posting on a steady schedule. The biggest risk now is slowing down.",
                videosNeedingAttention: 0
            )
        }
    }
}

// MARK: - Coach ViewModel
@MainActor
final class CoachViewModel: ObservableObject {

    @Published var videos: [Video] = []
    @Published var latestVideo: Video?
    @Published var isLoading = false
    @Published var diagnosis: ChannelDiagnosis?
    @Published var intelligenceReport: ChannelIntelligenceReport?
    @Published var postingTimeInsight: PostingTimeInsight?

    // MARK: Shorts vs long videos
    // Shorts and long videos play by different rules, so we never mix them in one report.
    // The switch only shows when a channel has both. The choice is shared by Coach and Intelligence.

    enum FormatFilter: String, CaseIterable {
        case long, shorts
        var label: String { self == .long ? "Long videos" : "Shorts" }
    }

    private static let formatFilterKey = "coachFormatFilter"

    @Published var formatFilter: FormatFilter =
        FormatFilter(rawValue: UserDefaults.standard.string(forKey: "coachFormatFilter") ?? "") ?? .long {
        didSet {
            UserDefaults.standard.set(formatFilter.rawValue, forKey: Self.formatFilterKey)
            rebuildReports()
        }
    }

    /// True when the channel has at least 1 Short AND at least 1 long video
    var hasBothFormats: Bool {
        videos.contains { $0.isShort } && videos.contains { !$0.isShort }
    }

    /// The videos to show right now: all of them if the channel only makes one kind,
    /// otherwise only the kind picked in the switch.
    var shownVideos: [Video] {
        guard hasBothFormats else { return videos }
        return videos.filter { formatFilter == .shorts ? $0.isShort : !$0.isShort }
    }

    /// Diagnosis, patterns and best posting day, built only from the videos shown
    func rebuildReports() {
        let list = shownVideos
        diagnosis          = ChannelDiagnosis.generate(from: list)
        intelligenceReport = ChannelIntelligenceReport.generate(from: list)
        postingTimeInsight = analyzePostingTimes(for: list)
    }

    init(autoLoad: Bool = true) {
        if autoLoad {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await loadVideos()
            }
        }
    }

    func loadVideos() async {
        guard AuthManager.shared.isYouTubeConnected else {
            print("⏭ loadVideos skipped — YouTube not connected")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if AuthManager.shared.isDemoMode {
                // DEMO PATH — rich mock data
                self.videos = YouTubeService.shared.demoVideos()
                self.latestVideo = self.videos.first
                
                try? await Task.sleep(nanoseconds: 600_000_000) // pleasant loading feel
                
                rebuildReports()
                
                print("✅ Demo mode: Loaded \(videos.count) mock videos")
                return
            }

            // REAL PATH — completely unchanged
            let token = try await AuthManager.shared.getValidToken()
            let uploadsPlaylistId = try await fetchUploadsPlaylist(accessToken: token)
            let baseVideos = try await fetchAllPlaylistVideos(
                playlistId: uploadsPlaylistId,
                accessToken: token
            )

            let sorted = baseVideos.sorted { $0.publishedAt > $1.publishedAt }
            self.videos = sorted
            self.latestVideo = sorted.first

            await enrichWithAnalytics(accessToken: token)

            rebuildReports()

            print("✅ Loaded \(videos.count) videos")

        } catch {
            print("❌ Video load failed:", error)
        }
    }

    var videosByPriority: [Video] {
        shownVideos.sorted { a, b in
            a.verdict.severity > b.verdict.severity
        }
    }

    // MARK: - Best day to post
    /// The ONE place that works out the best posting day. Coach and Intelligence both use it,
    /// so they can never disagree.
    /// - Only videos 7+ days old (newer ones haven't had time to get their views)
    /// - Only days with 2+ videos (one lucky video can't make a day "best")
    /// - Middle views per day, not the average (one viral video can't skew it)
    /// Pass a list to check only those videos (for example only Shorts, or only long videos)
    func analyzePostingTimes(for list: [Video]? = nil) -> PostingTimeInsight? {
        let settled = (list ?? videos).filter { $0.views > 0 && $0.ageInDays >= 7 }
        guard settled.count >= 4 else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"

        var dayGroups: [String: [Int]] = [:]
        for video in settled {
            dayGroups[formatter.string(from: video.publishedAt), default: []].append(video.views)
        }
        let usableDays = dayGroups.filter { $0.value.count >= 2 }
        guard usableDays.count >= 2 else { return nil }

        func middle(_ values: [Int]) -> Int {
            let sorted = values.sorted()
            return sorted[sorted.count / 2]
        }
        let dayMiddles = usableDays.mapValues(middle)

        guard
            let best  = dayMiddles.max(by: { $0.value < $1.value }),
            let worst = dayMiddles.min(by: { $0.value < $1.value }),
            best.key != worst.key
        else { return nil }

        let gap = Double(best.value - worst.value) / Double(max(best.value, 1))
        guard gap >= 0.20 else { return nil }

        let counted = usableDays.values.reduce(0) { $0 + $1.count }
        return PostingTimeInsight(
            bestDay: best.key,
            bestDayAvgViews: best.value,
            worstDay: worst.key,
            worstDayAvgViews: worst.value,
            sampleSize: counted,
            isReliable: counted >= 8 && (usableDays[best.key]?.count ?? 0) >= 3 && (usableDays[worst.key]?.count ?? 0) >= 3
        )
    }

    // MARK: - Uploads Playlist ID (unchanged)
    private func fetchUploadsPlaylist(accessToken: String) async throws -> String {
        let url = URL(string:
            "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&mine=true"
        )!
        let request = URLRequest(url: url, bearerToken: accessToken)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChannelListResponse.self, from: data)
        guard let uploads = response.items.first?.contentDetails.relatedPlaylists.uploads else {
            throw URLError(.badServerResponse)
        }
        return uploads
    }

    // MARK: - Playlist Videos (Paginated) (unchanged)
    private func fetchAllPlaylistVideos(
        playlistId: String,
        accessToken: String
    ) async throws -> [Video] {

        var allVideos: [Video] = []
        var nextPageToken: String? = nil
        let formatter = ISO8601DateFormatter()

        repeat {
            var components = URLComponents(
                string: "https://www.googleapis.com/youtube/v3/playlistItems"
            )!
            components.queryItems = [
                .init(name: "part",       value: "snippet,contentDetails"),
                .init(name: "maxResults", value: "50"),
                .init(name: "playlistId", value: playlistId)
            ]
            if let token = nextPageToken {
                components.queryItems?.append(.init(name: "pageToken", value: token))
            }

            let request = URLRequest(url: components.url!, bearerToken: accessToken)
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)

            let pageVideos: [Video] = response.items.compactMap { item in
                guard
                    let snippet = item.snippet,
                    let videoId = item.contentDetails?.videoId,
                    let title   = snippet.title
                else { return nil }

                let published = snippet.publishedAt.flatMap {
                    formatter.date(from: $0)
                } ?? Date()

                return Video(videoId: videoId, title: title, publishedAt: published)
            }

            allVideos.append(contentsOf: pageVideos)
            nextPageToken = response.nextPageToken

        } while nextPageToken != nil

        return allVideos
    }

    // MARK: - Analytics Enrichment (ALL TIME)
    //
    // Before: one request per video, last 28 days only, and a made-up CTR.
    // Now: one "top videos" request (200 videos per page) covering the whole
    // life of the channel, real CTR from YouTube's reach reports, and
    // "usual views" = the middle (median) video on this channel.
    private func enrichWithAnalytics(accessToken: String) async {
        let endDate   = Date().youtubeAnalyticsDateString()
        let startDate = "2005-04-23"   // the day YouTube started, so this is all time

        var rowsById: [String: [AnalyticsValue]] = [:]
        var startIndex = 1

        while true {
            var components = URLComponents(string: "https://youtubeanalytics.googleapis.com/v2/reports")!
            components.queryItems = [
                .init(name: "ids",        value: "channel==MINE"),
                .init(name: "dimensions", value: "video"),
                .init(name: "metrics",    value: "views,estimatedMinutesWatched,averageViewDuration,averageViewPercentage,subscribersGained,likes,comments,shares"),
                .init(name: "sort",       value: "-views"),
                .init(name: "maxResults", value: "200"),
                .init(name: "startIndex", value: String(startIndex)),
                .init(name: "startDate",  value: startDate),
                .init(name: "endDate",    value: endDate)
            ]

            do {
                let request = URLRequest(url: components.url!, bearerToken: accessToken)
                let (data, _) = try await URLSession.shared.data(for: request)
                let report = try JSONDecoder().decode(AnalyticsReportResponse.self, from: data)
                let rows = report.rows ?? []

                for row in rows where row.count >= 6 {
                    guard case .string(let id) = row[0] else { continue }
                    rowsById[id] = Array(row.dropFirst())   // [views, minutes, avgDuration, avg%, subs, likes, comments, shares]
                }

                if rows.count < 200 { break }
                startIndex += 200
            } catch {
                print("⚠️ All-time analytics failed:", error)
                break
            }
        }

        // Real thumbnail CTR (only for days YouTube has reach reports for)
        let thumbnailStats = await YouTubeService.shared.fetchThumbnailStats()

        // Short or long for every video, so each is only compared with its own kind
        let formats = await YouTubeService.shared.fetchFormats(videoIds: videos.map(\.videoId))
        for index in videos.indices {
            videos[index].format = formats[videos[index].videoId]
        }

        // "Usual views" = the middle video of the SAME kind (Shorts vs long), not a made-up 1,000
        func usual(shorts: Bool) -> Int {
            let views = videos
                .filter { $0.isShort == shorts }
                .compactMap { rowsById[$0.videoId]?.first?.intValue }
                .sorted()
            return views.isEmpty ? 0 : views[views.count / 2]
        }
        let usualShortViews = usual(shorts: true)
        let usualLongViews = usual(shorts: false)

        for index in videos.indices {
            let videoId = videos[index].videoId
            guard let row = rowsById[videoId], row.count >= 5 else { continue }

            let views       = row[0].intValue
            let avgDuration = row[2].intValue
            let retention   = row[3].doubleValue / 100.0
            let subsGained  = row[4].intValue
            // Shorts are swiped to in the feed, not clicked, so thumbnail CTR doesn't apply
            let thumb       = videos[index].isShort ? nil : thumbnailStats[videoId]
            let likes: Int?    = row.count >= 8 ? row[5].intValue : nil
            let comments: Int? = row.count >= 8 ? row[6].intValue : nil
            let shares: Int?   = row.count >= 8 ? row[7].intValue : nil

            videos[index].views               = views
            videos[index].averageViewDuration = avgDuration
            videos[index].thumbnailCTR        = thumb?.ctr ?? 0      // 0 = not known yet
            videos[index].analytics           = VideoAnalytics(
                ctr:                 thumb?.ctr ?? 0,
                averageViewDuration: avgDuration,
                retention:           retention,
                expectedViews:       videos[index].isShort ? usualShortViews : usualLongViews,
                subscribersGained:   subsGained,
                impressions:         thumb?.impressions,
                likes:               likes,
                comments:            comments,
                shares:              shares
            )
        }

        print("✅ All-time analytics for \(rowsById.count) videos, CTR for \(thumbnailStats.count)")
    }
}
