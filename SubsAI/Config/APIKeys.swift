import Foundation

struct APIKeys {
    static var youtubeAPIKey: String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["YouTubeAPIKey"] as? String else {
            fatalError("YouTube API Key not found")
        }
        return key
    }
}
