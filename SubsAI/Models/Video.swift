// Models/Video.swift
import Foundation

struct Video: Identifiable, Codable {
    let id: UUID
    let videoId: String
    let title: String
    let publishedAt: Date
    var views: Int
    var watchTime: Int
    var thumbnailCTR: Double
    var averageViewDuration: Int
    var dropOffSecond: Int
    var analytics: VideoAnalytics?

    var thumbnailURL: URL? {
        URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
    }

    var verdict: CoachVerdict {
        CoachVerdict(video: self)
    }

    var primaryFix: CoachFix {
        guard let stats = analytics else { return .none }
        if stats.ctr < 0.06               { return .thumbnail }
        if stats.averageViewDuration < 35  { return .hook }
        if views < stats.expectedViews     { return .discovery }
        return .none
    }

    var healthScore: Int {
        guard let stats = analytics else { return 50 }
        var score = 100
        let ctr = stats.ctr
        if ctr < 0.02      { score -= 40 }
        else if ctr < 0.04 { score -= 28 }
        else if ctr < 0.06 { score -= 18 }
        else if ctr < 0.07 { score -= 8  }
        let ret = stats.retention
        if ret < 0.15      { score -= 35 }
        else if ret < 0.25 { score -= 22 }
        else if ret < 0.35 { score -= 12 }
        else if ret < 0.45 { score -= 4  }
        if views == 0                           { score -= 10 }
        else if views < stats.expectedViews / 2 { score -= 15 }
        else if views < stats.expectedViews     { score -= 5  }
        return max(min(score, 100), 0)
    }

    // MARK: - Growth Per View (GPV)
    // Subs gained per 1,000 views — the YouTube equivalent of conversion rate
    var growthPerView: Double {
        guard let stats = analytics, views > 0, stats.subscribersGained > 0 else { return 0 }
        return Double(stats.subscribersGained) / Double(views) * 1000
    }

    var growthPerViewLabel: String {
        let gpv = growthPerView
        if gpv == 0 { return "—" }
        return String(format: "%.1f per 1K views", gpv)
    }

    var growthQuality: String {
        let gpv = growthPerView
        if gpv >= 3.0 { return "High" }
        if gpv >= 1.0 { return "Good" }
        if gpv > 0    { return "Low" }
        return "—"
    }

    init(
        id: UUID = UUID(),
        videoId: String,
        title: String,
        publishedAt: Date = Date(),
        views: Int = 0,
        watchTime: Int = 0,
        thumbnailCTR: Double = 0,
        averageViewDuration: Int = 0,
        dropOffSecond: Int = 0,
        analytics: VideoAnalytics? = nil
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.publishedAt = publishedAt
        self.views = views
        self.watchTime = watchTime
        self.thumbnailCTR = thumbnailCTR
        self.averageViewDuration = averageViewDuration
        self.dropOffSecond = dropOffSecond
        self.analytics = analytics
    }
}

// MARK: - VideoAnalytics
struct VideoAnalytics: Codable {
    let ctr: Double
    let averageViewDuration: Int
    let retention: Double
    let expectedViews: Int
    let subscribersGained: Int

    init(
        ctr: Double,
        averageViewDuration: Int,
        retention: Double,
        expectedViews: Int,
        subscribersGained: Int = 0
    ) {
        self.ctr = ctr
        self.averageViewDuration = averageViewDuration
        self.retention = retention
        self.expectedViews = expectedViews
        self.subscribersGained = subscribersGained
    }
}
