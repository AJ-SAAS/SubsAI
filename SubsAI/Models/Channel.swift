import Foundation

// MARK: - Channel (UI-friendly)
struct Channel: Codable, Identifiable {
    let id: String
    let name: String
    let subscribers: Int
    let totalViews: Int
    let watchTime: Double   // hours (frontend-friendly)
    let videoCount: Int
    let thumbnailCTR: Double
    let profilePicURL: String
    let bannerURL: String?
}

// MARK: - Backend response model
struct ChannelStatsResponse: Codable {
    struct ChannelItem: Codable {
        let id: String
        let name: String
        let subscribers: String
        let viewCount: String
        let videoCount: String
    }
    let items: [ChannelItem]?
}
