import Foundation
import Combine
import KeychainAccess

class YouTubeAPIManager {
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let analyticsURL = "https://youtubeanalytics.googleapis.com/v2"
    private let keychain = Keychain(service: "xyz.subsai.SubsAI")

    func fetchChannelStats() -> AnyPublisher<YouTubeChannelStats, Error> {
        let url = URL(string: "\(baseURL)/channels?part=statistics&mine=true")!
        var request = URLRequest(url: url)
        if let accessToken = try? keychain.get("youtube_access_token") {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token found"])).eraseToAnyPublisher()
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: YouTubeChannelStatsResponse.self, decoder: JSONDecoder())
            .map { response in
                guard let stats = response.items.first?.statistics else {
                    return YouTubeChannelStats(subscriberCount: "0", viewCount: "0", videoCount: "0")
                }
                return stats
            }
            .eraseToAnyPublisher()
    }

    func fetchAnalyticsMetrics(metrics: String, startDate: Date, endDate: Date, filters: String? = nil) -> AnyPublisher<AnalyticsStats, Error> {
        var components = URLComponents(string: "\(analyticsURL)/reports")!
        components.queryItems = [
            URLQueryItem(name: "metrics", value: metrics),
            URLQueryItem(name: "startDate", value: startDate.formatted(.iso8601)),
            URLQueryItem(name: "endDate", value: endDate.formatted(.iso8601)),
            URLQueryItem(name: "ids", value: "channel==MINE")
        ]
        if let filters = filters {
            components.queryItems?.append(URLQueryItem(name: "filters", value: filters))
        }

        guard let url = components.url else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        if let accessToken = try? keychain.get("youtube_access_token") {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token found"])).eraseToAnyPublisher()
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: AnalyticsStats.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
