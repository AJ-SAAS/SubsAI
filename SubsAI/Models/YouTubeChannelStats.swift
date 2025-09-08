import Foundation

struct YouTubeChannelStats: Codable {
    let subscriberCount: String
    let viewCount: String
    let videoCount: String

    enum CodingKeys: String, CodingKey {
        case subscriberCount
        case viewCount
        case videoCount
    }
}

struct YouTubeChannelStatsResponse: Codable {
    let items: [YouTubeChannelItem]

    struct YouTubeChannelItem: Codable {
        let statistics: YouTubeChannelStats
    }
}
