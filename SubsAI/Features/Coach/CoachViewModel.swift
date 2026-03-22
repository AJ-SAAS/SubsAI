// Features/Coach/CoachViewModel.swift
import Foundation
import SwiftUI

// MARK: - API Models

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

// MARK: - Posting Time Insight
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
        let reliability = isReliable ? "" : " (early signal — more uploads will sharpen this)"
        return "Your \(bestDay) uploads average \(formatViews(bestDayAvgViews)) views vs \(formatViews(worstDayAvgViews)) on \(worstDay). Post your next video on \(bestDay)\(reliability)."
    }

    func reviewLine(for video: Video) -> String? {
        guard isSuboptimal(for: video) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let day = formatter.string(from: video.publishedAt)
        return "Posted on \(day) — outside your best window (\(bestDay)). Early distribution may have been affected."
    }

    private func formatViews(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Channel Diagnosis
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
                body: "Your last \(enriched.count) videos averaged \(String(format: "%.1f", avgCTR * 100))% CTR — well below the 7% benchmark. Your content quality is solid (retention is \(String(format: "%.0f", avgRetention * 100))%), but viewers aren't clicking. The problem is the packaging, not the video.",
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
                headline: "Viewers are dropping off mid-video — before your best content.",
                body: "Your average retention of \(String(format: "%.0f", avgRetention * 100))% suggests a pacing issue in the middle of your videos. Add a re-hook every 3–4 minutes to pull viewers back in.",
                videosNeedingAttention: needsAttention
            )
        case .discovery:
            return ChannelDiagnosis(
                headline: "Your videos are underperforming on discovery.",
                body: "Views are below expectations for your subscriber count. This usually means metadata — titles, descriptions, and tags — aren't optimised for search and suggested video placement.",
                videosNeedingAttention: needsAttention
            )
        default:
            return ChannelDiagnosis(
                headline: "Your channel is in good health.",
                body: "CTR and retention are both above benchmark across your recent videos. Focus on upload consistency to maintain momentum — your biggest risk right now is slowing down.",
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

    // autoLoad: false prevents concurrent token refreshes on cold launch
    init(autoLoad: Bool = true) {
        if autoLoad {
            Task {
                // Let AppDelegate finish restoring previous sign-in first
                try? await Task.sleep(nanoseconds: 500_000_000)
                await loadVideos()
            }
        }
    }

    func loadVideos() async {
        // Don't attempt a network call if YouTube isn't connected yet
        guard AuthManager.shared.isYouTubeConnected else {
            print("⏭ loadVideos skipped — YouTube not connected")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
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

            self.diagnosis          = ChannelDiagnosis.generate(from: self.videos)
            self.intelligenceReport = ChannelIntelligenceReport.generate(from: self.videos)
            self.postingTimeInsight = analyzePostingTimes()

            print("✅ Loaded \(videos.count) videos")

        } catch {
            print("❌ Video load failed:", error)
        }
    }

    var videosByPriority: [Video] {
        videos.sorted { a, b in
            a.verdict.severity > b.verdict.severity
        }
    }

    // MARK: - Posting Time Analysis
    func analyzePostingTimes() -> PostingTimeInsight? {
        let videosWithViews = videos.filter { $0.views > 0 }
        guard videosWithViews.count >= 4 else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"

        var dayGroups: [String: [Int]] = [:]
        for video in videosWithViews {
            let day = formatter.string(from: video.publishedAt)
            dayGroups[day, default: []].append(video.views)
        }

        guard dayGroups.count >= 2 else { return nil }

        let dayAverages = dayGroups.mapValues { views -> Int in
            views.reduce(0, +) / views.count
        }

        guard
            let best  = dayAverages.max(by: { $0.value < $1.value }),
            let worst = dayAverages.min(by: { $0.value < $1.value }),
            best.key != worst.key
        else { return nil }

        let gap = Double(best.value - worst.value) / Double(max(best.value, 1))
        guard gap >= 0.20 else { return nil }

        return PostingTimeInsight(
            bestDay: best.key,
            bestDayAvgViews: best.value,
            worstDay: worst.key,
            worstDayAvgViews: worst.value,
            sampleSize: videosWithViews.count,
            isReliable: videosWithViews.count >= 8
        )
    }

    // MARK: - Uploads Playlist ID
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

    // MARK: - Playlist Videos (Paginated)
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

    // MARK: - Analytics Enrichment
    private func enrichWithAnalytics(accessToken: String) async {
        let endDate   = Date().youtubeAnalyticsDateString()
        let startDate = Calendar.current
            .date(byAdding: .day, value: -28, to: Date())!
            .youtubeAnalyticsDateString()

        for index in videos.indices {
            let videoId = videos[index].videoId

            var components = URLComponents(
                string: "https://youtubeanalytics.googleapis.com/v2/reports"
            )!
            components.queryItems = [
                .init(name: "ids",     value: "channel==MINE"),
                .init(name: "metrics", value: "views,estimatedMinutesWatched,averageViewDuration,averageViewPercentage,subscribersGained"),
                .init(name: "filters", value: "video==\(videoId)"),
                .init(name: "startDate", value: startDate),
                .init(name: "endDate",   value: endDate)
            ]

            do {
                let request = URLRequest(url: components.url!, bearerToken: accessToken)
                let (data, _) = try await URLSession.shared.data(for: request)
                let report = try JSONDecoder().decode(AnalyticsReportResponse.self, from: data)

                guard let row = report.rows?.first, row.count >= 4 else { continue }

                let views       = row[0].intValue
                let avgDuration = row[2].intValue
                let retention   = row[3].doubleValue / 100.0
                let subsGained  = row.count >= 5 ? row[4].intValue : 0

                videos[index].views               = views
                videos[index].averageViewDuration = avgDuration
                videos[index].thumbnailCTR        = retention > 0 ? 0.07 : 0.03
                videos[index].analytics           = VideoAnalytics(
                    ctr:                 videos[index].thumbnailCTR,
                    averageViewDuration: avgDuration,
                    retention:           retention,
                    expectedViews:       max(views, 1000),
                    subscribersGained:   subsGained
                )

            } catch {
                print("⚠️ Analytics skipped for video:", videoId, error)
            }
        }
    }
}
