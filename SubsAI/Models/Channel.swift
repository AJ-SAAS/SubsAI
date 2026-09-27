import Foundation

// MARK: - Channel (UI-friendly)
struct Channel: Codable, Identifiable {
    let id: String
    let name: String
    var subscribers: Int = 0
    var totalViews: Int = 0
    var watchTime: Double = 0       // hours
    var videoCount: Int = 0
    var thumbnailCTR: Double = 0
    let profilePicURL: String
    let bannerURL: String?
    
    /// true when the creator hides their sub count (or YouTube didn't send it).
    /// When true, `subscribers` is NOT a real number, so never show it.
    var subscribersHidden: Bool? = nil

    // Default initializer
    init(
        id: String = "",
        name: String = "",
        subscribers: Int = 0,
        totalViews: Int = 0,
        watchTime: Double = 0,
        videoCount: Int = 0,
        thumbnailCTR: Double = 0,
        profilePicURL: String = "",
        bannerURL: String? = nil,
        subscribersHidden: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.subscribers = subscribers
        self.totalViews = totalViews
        self.watchTime = watchTime
        self.videoCount = videoCount
        self.thumbnailCTR = thumbnailCTR
        self.profilePicURL = profilePicURL
        self.bannerURL = bannerURL
        self.subscribersHidden = subscribersHidden
    }
}

// Backend response model (for API decoding)
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
