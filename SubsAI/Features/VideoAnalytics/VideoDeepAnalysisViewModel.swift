// Features/VideoAnalytics/VideoDeepAnalysisViewModel.swift
// Loads REAL data only. If YouTube has no retention data yet, the page says so
// (no more made-up curves).
import Foundation

@MainActor
final class VideoDeepAnalysisViewModel: ObservableObject {
    @Published var isLoading = true
    /// "Your usual" loads after this video's own data, so the page never waits on it
    @Published var isLoadingUsual = true
    /// This video: length + retention curve
    @Published var insights: VideoInsights?
    /// Your usual, from up to 8 recent videos
    @Published var profile: YouTubeService.RetentionProfile?

    let video: Video

    /// Moments we check in the Hook tab (only the ones that fit this video are shown)
    /// (1-3 seconds only fit Shorts: on long videos the curve isn't that detailed)
    static let checkpointCandidates = [1, 2, 3, 5, 10, 15, 30, 60, 120, 180]

    init(video: Video) {
        self.video = video
    }

    var hasCurve: Bool { (insights?.retentionCurve.count ?? 0) >= 20 && insights?.durationSeconds != nil }

    /// The moments that make sense for this video's length and data detail.
    /// YouTube's curve has about 100 points, so on long videos early seconds can't be read.
    var checkpoints: [Int] {
        guard let d = insights?.durationSeconds, d > 0 else { return [] }
        let step = Double(d) / 100
        return Self.checkpointCandidates
            .filter { Double($0) >= step * 1.5 && Double($0) <= Double(d) * 0.5 }
            .prefix(5)
            .map { $0 }
    }

    func load(allVideos: [Video]) async {
        guard insights == nil else { return }
        isLoading = true

        // Shorts compare to Shorts, long videos to long videos
        let recent = allVideos
            .filter { $0.videoId != video.videoId && $0.isSameFormat(as: video) }
            .sorted { $0.publishedAt > $1.publishedAt }

        // 1. This video first: the page shows as soon as it's here
        let started = Date()
        var loaded = await YouTubeService.shared.retentionInsights(for: video.videoId, publishedAt: video.publishedAt)
        loaded.isShort = video.isShort
        insights = loaded
        isLoading = false
        print("⏱ Deep analysis: this video's curve in \(String(format: "%.1f", Date().timeIntervalSince(started)))s, \(insights?.retentionCurve.count ?? 0) points")

        // 2. Then your usual (compare lines and ticks appear when ready)
        profile = await YouTubeService.shared.fetchRetentionProfile(
            recentVideos: recent,
            checkpoints: Self.checkpointCandidates
        )
        isLoadingUsual = false
    }
}
