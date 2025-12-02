// Features/VideoAnalytics/VideoAnalyticsViewModel.swift
import SwiftUI

struct VideoStat: Identifiable, Codable {
    // Local UUID that stays in the app — we don’t want JSON to overwrite it
    let id = UUID()
    
    let title: String
    let views: Int
    let watchTime: Double
    let dropOffSeconds: Double
    let thumbnailCTR: Double
    let benchmarkViews: Int
    let benchmarkWatchTime: Double
    let benchmarkDropOff: Double
    let benchmarkThumbnailCTR: Double
    
    // This tells Codable: "Don't touch the id — it's generated locally"
    private enum CodingKeys: String, CodingKey {
        case title, views, watchTime, dropOffSeconds, thumbnailCTR
        case benchmarkViews, benchmarkWatchTime, benchmarkDropOff, benchmarkThumbnailCTR
        // id is intentionally excluded → no more warning!
    }
}

@MainActor
final class VideoAnalyticsViewModel: ObservableObject {
    @Published var videos: [VideoStat] = []

    func loadVideos() async {
        // Mock data for now — later you’ll replace this with real YouTube Analytics API
        videos = [
            VideoStat(
                title: "My Best Video Ever",
                views: 1200,
                watchTime: 8.2,
                dropOffSeconds: 85,
                thumbnailCTR: 12.5,
                benchmarkViews: 800,
                benchmarkWatchTime: 6.0,
                benchmarkDropOff: 70,
                benchmarkThumbnailCTR: 8.0
            ),
            VideoStat(
                title: "This One Flopped",
                views: 150,
                watchTime: 1.1,
                dropOffSeconds: 12,
                thumbnailCTR: 2.3,
                benchmarkViews: 800,
                benchmarkWatchTime: 6.0,
                benchmarkDropOff: 70,
                benchmarkThumbnailCTR: 8.0
            )
        ]
    }
    
    func needsImprovement(_ video: VideoStat) -> [String] {
        var issues: [String] = []
        if video.views < video.benchmarkViews { issues.append("Views") }
        if video.watchTime < video.benchmarkWatchTime { issues.append("Watch Time") }
        if video.dropOffSeconds < video.benchmarkDropOff { issues.append("Drop-off") }
        if video.thumbnailCTR < video.benchmarkThumbnailCTR { issues.append("Thumbnail CTR") }
        return issues
    }
    
    func statusColor(_ video: VideoStat, metric: String) -> Color {
        switch metric {
        case "Views":           return video.views >= video.benchmarkViews ? .green : .red
        case "Watch Time":      return video.watchTime >= video.benchmarkWatchTime ? .green : .red
        case "Drop-off":        return video.dropOffSeconds >= video.benchmarkDropOff ? .green : .red
        case "Thumbnail CTR":   return video.thumbnailCTR >= video.benchmarkThumbnailCTR ? .green : .red
        default:                return .primary
        }
    }
}
