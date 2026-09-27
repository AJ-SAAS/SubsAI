// Features/Dashboard/HomeViewModel.swift
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var channelInfo: Channel?
    @Published var isLoading = false
    @Published var isLoadingLatestVideo = false
    @Published var errorMessage: String?
    @Published var selectedPeriod: TimePeriod = .week
    @Published var lastUpdated: Date?
    @Published var latestVideo: Video?

    @Published var subscriberGrowth: GrowthData?
    @Published var viewGrowth: GrowthData?
    @Published var watchTimeGrowth: GrowthData?

    // NEW: real day-by-day numbers for the chart
    @Published var trend: DailyTrend?
    // NEW: one entry per week (oldest first), true = at least one upload that week
    @Published var uploadWeeks: [Bool] = []
    // NEW: watch hours over the last 12 months (what YouTube counts for the 4,000h goal)
    @Published var yearWatchHours: Double?

    // NEW: latest video vs your other recent videos (views in the first few days)
    @Published var latestRank: VideoRank?
    /// True when the latest video is too new to rank fairly yet
    @Published var rankPending = false
    // NEW: real thumbnail CTR from YouTube's reach reports (nil = not ready yet)
    @Published var latestCTR: Double?
    @Published var latestImpressions: Double?

    struct VideoRank: Equatable {
        let rank: Int     // 1 = best
        let total: Int    // how many videos we compared
        let days: Int     // each video's first N days
    }

    init() {
        // No auto-load — triggered by authRestored / signIn notifications
    }

    // MARK: - Upload streak

    /// Weeks in a row with an upload. This week only counts once they post,
    /// but it doesn't break the streak yet (the week isn't over).
    var uploadStreak: Int {
        var weeks = uploadWeeks
        if weeks.last == false { weeks.removeLast() }
        var count = 0
        for posted in weeks.reversed() {
            if posted { count += 1 } else { break }
        }
        return count
    }

    var postedThisWeek: Bool { uploadWeeks.last == true }

    // MARK: - Load

    func loadChannelStats() async {
        guard AuthManager.shared.isYouTubeConnected else {
            print("⏭ loadChannelStats skipped — YouTube not connected")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            var info = try await YouTubeService.shared.fetchChannel()
            let (views, watchHours, netSubs) = try await YouTubeService.shared.fetchPeriodAnalytics(selectedPeriod)

            print("🔍 Analytics — views: \(views), watchHours: \(watchHours), netSubs: \(netSubs)")

            info.watchTime = watchHours

            self.subscriberGrowth = GrowthData(
                absolute: netSubs,
                percentage: info.subscribers > 0
                    ? (Double(netSubs) / Double(info.subscribers)) * 100 : 0,
                trend: netSubs > 0 ? .up : (netSubs < 0 ? .down : .neutral)
            )

            self.viewGrowth = GrowthData(
                absolute: views,
                percentage: info.totalViews > 0
                    ? (Double(views) / Double(info.totalViews)) * 100 : 0,
                trend: views > 0 ? .up : (views < 0 ? .down : .neutral)
            )

            // FIX: this used to divide watch hours by itself, so it always showed +100%.
            // We don't have the previous period to compare to, so no percentage here.
            self.watchTimeGrowth = GrowthData(
                absolute: Int(watchHours),
                percentage: 0,
                trend: watchHours > 0 ? .up : .neutral
            )

            self.channelInfo = info
            self.lastUpdated = Date()

            // NEW: ask YouTube to start making CTR reports (only does work the first time)
            Task { await YouTubeService.shared.ensureReachJob() }

            // NEW: real daily numbers for the chart (replaces the made-up line)
            self.trend = try? await YouTubeService.shared.fetchDailyTrend(selectedPeriod)

            // NEW: 12-month watch hours for the 4,000h goal (only needs loading once)
            if yearWatchHours == nil {
                self.yearWatchHours = try? await YouTubeService.shared.fetchWatchHours(lastDays: 365)
            }

        } catch {
            errorMessage = error.localizedDescription
            print("Dashboard load error:", error)
        }

        isLoading = false
        await fetchLatestVideo()
    }

    func changePeriod(to period: TimePeriod) {
        selectedPeriod = period
        Task { await loadChannelStats() }
    }

    // MARK: - Fetch latest video (+ upload dates for the streak)
    func fetchLatestVideo() async {
        guard AuthManager.shared.isYouTubeConnected else { return }
        isLoadingLatestVideo = true

        // Demo account: use the demo videos
        if AuthManager.shared.isDemoMode {
            let videos = YouTubeService.shared.demoVideos()
            latestVideo = videos.max { $0.publishedAt < $1.publishedAt }
            uploadWeeks = Self.weeks(from: videos.map { $0.publishedAt })
            latestRank = VideoRank(rank: 2, total: 10, days: 3)
            rankPending = false
            if let latest = latestVideo {
                let stats = await YouTubeService.shared.fetchThumbnailStats()
                latestCTR = stats[latest.videoId]?.ctr
                latestImpressions = stats[latest.videoId]?.impressions
            }
            isLoadingLatestVideo = false
            return
        }

        do {
            let token = try await AuthManager.shared.getValidToken()

            // Step 1 — uploads playlist
            let channelURL = URL(string:
                "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&mine=true"
            )!
            let channelRequest = URLRequest(url: channelURL, bearerToken: token)
            let (channelData, _) = try await URLSession.shared.data(for: channelRequest)
            let channelResponse = try JSONDecoder().decode(ChannelListResponse.self, from: channelData)

            guard let uploadsId = channelResponse.items.first?
                .contentDetails.relatedPlaylists.uploads else {
                isLoadingLatestVideo = false
                return
            }

            // Step 2 — recent uploads (newest first). 25 is enough to cover 12 weeks.
            var components = URLComponents(
                string: "https://www.googleapis.com/youtube/v3/playlistItems"
            )!
            components.queryItems = [
                .init(name: "part",       value: "snippet,contentDetails"),
                .init(name: "maxResults", value: "25"),
                .init(name: "playlistId", value: uploadsId)
            ]

            let playlistRequest = URLRequest(url: components.url!, bearerToken: token)
            let (playlistData, _) = try await URLSession.shared.data(for: playlistRequest)
            let playlistResponse = try JSONDecoder().decode(PlaylistItemsResponse.self, from: playlistData)

            let formatter = ISO8601DateFormatter()

            // NEW: upload dates for the streak
            let uploadDates = playlistResponse.items.compactMap { item in
                item.snippet?.publishedAt.flatMap { formatter.date(from: $0) }
            }
            self.uploadWeeks = Self.weeks(from: uploadDates)

            guard
                let item    = playlistResponse.items.first,
                let snippet = item.snippet,
                let videoId = item.contentDetails?.videoId,
                let title   = snippet.title
            else {
                isLoadingLatestVideo = false
                return
            }

            let published = snippet.publishedAt.flatMap {
                formatter.date(from: $0)
            } ?? Date()

            var video = Video(videoId: videoId, title: title, publishedAt: published)

            // Step 3 — analytics
            var analyticsComponents = URLComponents(
                string: "https://youtubeanalytics.googleapis.com/v2/reports"
            )!
            analyticsComponents.queryItems = [
                .init(name: "ids",       value: "channel==MINE"),
                .init(name: "metrics",   value: "views,estimatedMinutesWatched,averageViewDuration,averageViewPercentage"),
                .init(name: "filters",   value: "video==\(videoId)"),
                .init(name: "startDate", value: "2020-01-01"),
                .init(name: "endDate",   value: Date().youtubeAnalyticsDateString())
            ]

            let analyticsRequest = URLRequest(url: analyticsComponents.url!, bearerToken: token)
            let (analyticsData, _) = try await URLSession.shared.data(for: analyticsRequest)
            let report = try JSONDecoder().decode(AnalyticsReportResponse.self, from: analyticsData)

            if let row = report.rows?.first, row.count >= 4 {
                let views       = row[0].intValue
                let avgDuration = row[2].intValue
                let retention   = row[3].doubleValue / 100.0

                video.views               = views
                video.averageViewDuration = avgDuration
                // NOTE: this CTR is not real (the API doesn't give it here).
                // Home no longer shows it. Other screens still read it, so it's left as is for now.
                video.thumbnailCTR        = retention > 0 ? 0.07 : 0.03
                video.analytics           = VideoAnalytics(
                    ctr:                 video.thumbnailCTR,
                    averageViewDuration: avgDuration,
                    retention:           retention,
                    expectedViews:       max(views, 1000)
                )
            }

            self.latestVideo = video

            // NEW: ranking + real CTR
            let recent: [(id: String, published: Date)] = playlistResponse.items.compactMap { item in
                guard
                    let id = item.contentDetails?.videoId,
                    let date = item.snippet?.publishedAt.flatMap({ formatter.date(from: $0) })
                else { return nil }
                return (id, date)
            }
            await loadRankAndCTR(latest: video, recent: recent)

        } catch {
            print("⚠️ Latest video fetch failed:", error)
        }

        isLoadingLatestVideo = false
    }

    // MARK: - Ranking + CTR

    private func loadRankAndCTR(latest: Video, recent: [(id: String, published: Date)]) async {
        async let statsTask = YouTubeService.shared.fetchThumbnailStats()

        let age = Calendar.current.dateComponents([.day], from: latest.publishedAt, to: Date()).day ?? 0
        if age < 2 {
            // YouTube's numbers run about a day behind, so wait before ranking
            latestRank = nil
            rankPending = true
        } else {
            rankPending = false
            let days = min(age - 1, 28)
            let early = await YouTubeService.shared.fetchEarlyViews(for: Array(recent.prefix(10)), days: days)
            if let mine = early[latest.videoId], early.count >= 3 {
                let rank = early.values.filter { $0 > mine }.count + 1
                latestRank = VideoRank(rank: rank, total: early.count, days: days)
            } else {
                latestRank = nil
            }
        }

        let stats = await statsTask
        latestCTR = stats[latest.videoId]?.ctr
        latestImpressions = stats[latest.videoId]?.impressions
    }

    // MARK: - Helpers

    /// For each of the last `count` weeks (oldest first): was there an upload?
    static func weeks(from dates: [Date], count: Int = 12) -> [Bool] {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }

        return (0..<count).reversed().map { weeksBack in
            guard
                let start = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: thisWeek),
                let end   = calendar.date(byAdding: .weekOfYear, value: 1, to: start)
            else { return false }
            return dates.contains { $0 >= start && $0 < end }
        }
    }
}
