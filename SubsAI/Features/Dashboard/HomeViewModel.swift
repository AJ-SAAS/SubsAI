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

    init() {
        // No auto-load — triggered by authRestored / signIn notifications
    }

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

            self.watchTimeGrowth = GrowthData(
                absolute: Int(watchHours),
                percentage: info.watchTime > 0
                    ? (watchHours / info.watchTime) * 100 : 0,
                trend: watchHours > 0 ? .up : (watchHours < 0 ? .down : .neutral)
            )

            self.channelInfo = info
            self.lastUpdated = Date()

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

    // MARK: - Fetch latest video
    func fetchLatestVideo() async {
        guard AuthManager.shared.isYouTubeConnected else { return }
        isLoadingLatestVideo = true

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

            // Step 2 — most recent video
            var components = URLComponents(
                string: "https://www.googleapis.com/youtube/v3/playlistItems"
            )!
            components.queryItems = [
                .init(name: "part",       value: "snippet,contentDetails"),
                .init(name: "maxResults", value: "1"),
                .init(name: "playlistId", value: uploadsId)
            ]

            let playlistRequest = URLRequest(url: components.url!, bearerToken: token)
            let (playlistData, _) = try await URLSession.shared.data(for: playlistRequest)
            let playlistResponse = try JSONDecoder().decode(PlaylistItemsResponse.self, from: playlistData)

            guard
                let item    = playlistResponse.items.first,
                let snippet = item.snippet,
                let videoId = item.contentDetails?.videoId,
                let title   = snippet.title
            else {
                isLoadingLatestVideo = false
                return
            }

            let formatter = ISO8601DateFormatter()
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
                video.thumbnailCTR        = retention > 0 ? 0.07 : 0.03
                video.analytics           = VideoAnalytics(
                    ctr:                 video.thumbnailCTR,
                    averageViewDuration: avgDuration,
                    retention:           retention,
                    expectedViews:       max(views, 1000)
                )
            }

            self.latestVideo = video

        } catch {
            print("⚠️ Latest video fetch failed:", error)
        }

        isLoadingLatestVideo = false
    }
}
