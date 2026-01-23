import Foundation

struct Video: Identifiable, Codable {
    let id: UUID
    let videoId: String          // YouTube video ID
    let title: String
    var views: Int
    var watchTime: Int
    var thumbnailCTR: Double
    var averageViewDuration: Int // seconds
    var dropOffSecond: Int
    
    // Optional analytics object for Coach calculations
    var analytics: VideoAnalytics?
    
    // MARK: - Computed property for thumbnail URL
    var thumbnailURL: String? {
        "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
    }
    
    // MARK: - Computed properties for Coach
    var primaryFix: CoachFix {
        guard let stats = analytics else { return .none }
        
        if stats.ctr < 0.05 { return .thumbnail }
        if stats.averageViewDuration < 20 { return .hook }
        if stats.retention < 0.35 { return .retention }
        if stats.views < stats.expectedViews { return .discovery }
        return .none
    }
    
    var healthScore: Int {
        var score = 100
        switch primaryFix {
        case .thumbnail: score -= 30
        case .hook: score -= 40
        case .retention: score -= 25
        case .discovery: score -= 15
        case .none: break
        }
        return max(score, 0)
    }
    
    // MARK: - Init for Codable
    init(
        id: UUID = UUID(),
        videoId: String,
        title: String,
        views: Int,
        watchTime: Int,
        thumbnailCTR: Double,
        averageViewDuration: Int,
        dropOffSecond: Int,
        analytics: VideoAnalytics? = nil
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.views = views
        self.watchTime = watchTime
        self.thumbnailCTR = thumbnailCTR
        self.averageViewDuration = averageViewDuration
        self.dropOffSecond = dropOffSecond
        self.analytics = analytics
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, videoId, title, views, watchTime, thumbnailCTR, averageViewDuration, dropOffSecond, analytics
    }
}

// MARK: - Analytics helper for Coach
struct VideoAnalytics: Codable {
    let ctr: Double
    let averageViewDuration: Int
    let retention: Double
    let expectedViews: Int
    
    var views: Int { expectedViews }
}

// MARK: - Mock data
extension Video {
    static func mockList() -> [Video] {
        [
            Video(
                videoId: "abc123",
                title: "My Best Video Ever",
                views: 1200,
                watchTime: 8,
                thumbnailCTR: 0.125,
                averageViewDuration: 45,
                dropOffSecond: 80,
                analytics: VideoAnalytics(
                    ctr: 0.125,
                    averageViewDuration: 45,
                    retention: 0.7,
                    expectedViews: 1000
                )
            ),
            Video(
                videoId: "def456",
                title: "This One Flopped",
                views: 150,
                watchTime: 1,
                thumbnailCTR: 0.023,
                averageViewDuration: 12,
                dropOffSecond: 15,
                analytics: VideoAnalytics(
                    ctr: 0.023,
                    averageViewDuration: 12,
                    retention: 0.2,
                    expectedViews: 800
                )
            )
        ]
    }
}
