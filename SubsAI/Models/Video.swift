// Models/Video.swift
import Foundation

/// Short, regular (long) video, or livestream. From YouTube's own label when possible.
enum VideoFormat: String, Codable {
    case short, long, live

    init(apiValue: String) {
        switch apiValue {
        case "SHORTS":      self = .short
        case "LIVE_STREAM": self = .live
        default:            self = .long
        }
    }
}

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
    /// nil until we know. Unknown counts as a long video.
    var format: VideoFormat?

    var isShort: Bool { format == .short }

    /// Shorts are only compared with Shorts, long videos (and lives) with long videos
    func isSameFormat(as other: Video) -> Bool { isShort == other.isShort }

    var thumbnailURL: URL? {
        URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
    }

    var verdict: CoachVerdict {
        CoachVerdict(video: self)
    }

    /// Days since the video went up
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: publishedAt, to: Date()).day ?? 0
    }

    /// Views compared to this channel's usual (median) video. 2.0 = twice as many.
    var viewsVsUsual: Double? {
        guard let usual = analytics?.expectedViews, usual > 0 else { return nil }
        return Double(views) / Double(usual)
    }

    var primaryFix: CoachFix {
        guard let stats = analytics else { return .none }

        // Only judge the thumbnail when YouTube gave us a real CTR (never for Shorts: people swipe, not click)
        if !isShort && stats.hasCTR && stats.ctr < 0.03 { return .thumbnail }
        // A short watch time is normal for a Short
        if !isShort && stats.averageViewDuration < 35   { return .hook }
        if stats.retention > 0 && stats.retention < 0.25 { return .retention }

        // Give new videos a week before saying they aren't being found
        if ageInDays >= 7, let ratio = viewsVsUsual, ratio < 0.5 { return .discovery }
        return .none
    }

    var healthScore: Int {
        guard let stats = analytics else { return 50 }
        var score = 100

        if stats.hasCTR {
            let ctr = stats.ctr
            if ctr < 0.02      { score -= 40 }
            else if ctr < 0.03 { score -= 28 }
            else if ctr < 0.04 { score -= 15 }
            else if ctr < 0.05 { score -= 6  }
        }

        let ret = stats.retention
        if ret < 0.15      { score -= 35 }
        else if ret < 0.25 { score -= 22 }
        else if ret < 0.35 { score -= 12 }
        else if ret < 0.45 { score -= 4  }

        if views == 0 { score -= 10 }
        else if ageInDays >= 7, let ratio = viewsVsUsual {
            if ratio < 0.5      { score -= 15 }
            else if ratio < 1.0 { score -= 5  }
        }
        return max(min(score, 100), 0)
    }

    // MARK: - Growth Per View (GPV)
    // Subs gained per 1,000 views, the YouTube version of a conversion rate
    var growthPerView: Double {
        guard let stats = analytics, views > 0, stats.subscribersGained > 0 else { return 0 }
        return Double(stats.subscribersGained) / Double(views) * 1000
    }

    /// Likes + comments + shares per 1,000 views (nil if we don't have them)
    var engagementPer1K: Double? {
        guard let stats = analytics, views >= 200,
              let likes = stats.likes, let comments = stats.comments, let shares = stats.shares
        else { return nil }
        return Double(likes + comments + shares) / Double(views) * 1000
    }

    var growthPerViewLabel: String {
        let gpv = growthPerView
        if gpv == 0 { return "-" }
        return String(format: "%.1f per 1K views", gpv)
    }

    var growthQuality: String {
        let gpv = growthPerView
        if gpv >= 3.0 { return "High" }
        if gpv >= 1.0 { return "Good" }
        if gpv > 0    { return "Low" }
        return "-"
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
        analytics: VideoAnalytics? = nil,
        format: VideoFormat? = nil
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
        self.format = format
    }
}

// MARK: - VideoAnalytics
struct VideoAnalytics: Codable {
    /// Thumbnail CTR, 0...1. 0 means "not known yet" (see hasCTR).
    let ctr: Double
    let averageViewDuration: Int
    /// Average % of the video people watched, 0...1
    let retention: Double
    /// This channel's usual views per video (median)
    let expectedViews: Int
    let subscribersGained: Int
    /// Thumbnail impressions behind the CTR (nil if unknown)
    let impressions: Double?
    /// All-time likes, comments and shares (nil if unknown)
    let likes: Int?
    let comments: Int?
    let shares: Int?

    /// True only when the CTR came from YouTube (not a guess)
    var hasCTR: Bool { ctr > 0 }

    init(
        ctr: Double,
        averageViewDuration: Int,
        retention: Double,
        expectedViews: Int,
        subscribersGained: Int = 0,
        impressions: Double? = nil,
        likes: Int? = nil,
        comments: Int? = nil,
        shares: Int? = nil
    ) {
        self.ctr = ctr
        self.averageViewDuration = averageViewDuration
        self.retention = retention
        self.expectedViews = expectedViews
        self.subscribersGained = subscribersGained
        self.impressions = impressions
        self.likes = likes
        self.comments = comments
        self.shares = shares
    }
}
