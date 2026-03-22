// Networking/YouTubeService.swift
import Foundation
import GoogleSignIn

@MainActor
final class YouTubeService {

    static let shared = YouTubeService()
    private init() {}

    // MARK: - Channel Info
    func fetchChannel() async throws -> Channel {
        let token = try await AuthManager.shared.getValidToken()

        var components = URLComponents(
            string: "https://www.googleapis.com/youtube/v3/channels"
        )!
        components.queryItems = [
            .init(name: "part", value: "snippet,statistics,brandingSettings"),
            .init(name: "mine", value: "true")
        ]

        let request = URLRequest(url: components.url!, bearerToken: token)
        let (data, _) = try await URLSession.shared.data(for: request)

        struct Response: Codable {
            let items: [Item]
            struct Item: Codable {
                let id: String?
                let snippet: Snippet?
                let statistics: Statistics?
                let brandingSettings: BrandingSettings?

                struct Snippet: Codable {
                    let title: String?
                    let thumbnails: Thumbnails?
                    struct Thumbnails: Codable {
                        let high: Thumb?
                        let medium: Thumb?
                        let `default`: Thumb?
                        struct Thumb: Codable { let url: String? }
                    }
                }
                struct Statistics: Codable {
                    let subscriberCount: String?
                    let viewCount: String?
                    let videoCount: String?
                }
                struct BrandingSettings: Codable {
                    let image: Image?
                    struct Image: Codable {
                        let bannerExternalUrl: String?
                    }
                }
            }
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let item = decoded.items.first else {
            throw NSError(domain: "ChannelError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No channel found"])
        }

        let thumbs = item.snippet?.thumbnails
        return Channel(
            id: item.id ?? "",
            name: item.snippet?.title ?? "Unknown Channel",
            subscribers: Int(item.statistics?.subscriberCount ?? "0") ?? 0,
            totalViews: Int(item.statistics?.viewCount ?? "0") ?? 0,
            watchTime: 0,
            videoCount: Int(item.statistics?.videoCount ?? "0") ?? 0,
            thumbnailCTR: 0,
            profilePicURL: thumbs?.high?.url
                ?? thumbs?.medium?.url
                ?? thumbs?.default?.url
                ?? "",
            bannerURL: item.brandingSettings?.image?.bannerExternalUrl
        )
    }

    // MARK: - Period Analytics
    func fetchPeriodAnalytics(_ period: TimePeriod) async throws -> (views: Int, watchHours: Double, netSubs: Int) {
        let token = try await AuthManager.shared.getValidToken()

        let end = Date()
        guard let start = Calendar.current.date(
            byAdding: .day, value: -period.days, to: end
        ) else {
            throw NSError(domain: "DateError", code: -1)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var components = URLComponents(
            string: "https://youtubeanalytics.googleapis.com/v2/reports"
        )!
        components.queryItems = [
            .init(name: "ids",        value: "channel==MINE"),
            .init(name: "startDate",  value: formatter.string(from: start)),
            .init(name: "endDate",    value: formatter.string(from: end)),
            .init(name: "metrics",    value: "views,estimatedMinutesWatched,subscribersGained,subscribersLost"),
            .init(name: "dimensions", value: "day")
        ]

        let request = URLRequest(url: components.url!, bearerToken: token)
        let (data, _) = try await URLSession.shared.data(for: request)

        struct Response: Codable {
            let columnHeaders: [Header]?
            let rows: [[AnalyticsValue]]?
            struct Header: Codable { let name: String? }
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)

        var viewsIndex = -1, minutesIndex = -1, gainedIndex = -1, lostIndex = -1
        decoded.columnHeaders?.enumerated().forEach { index, header in
            switch header.name {
            case "views":                   viewsIndex   = index
            case "estimatedMinutesWatched": minutesIndex = index
            case "subscribersGained":       gainedIndex  = index
            case "subscribersLost":         lostIndex    = index
            default: break
            }
        }

        var views = 0.0, minutes = 0.0, gained = 0.0, lost = 0.0
        for row in decoded.rows ?? [] {
            func num(_ i: Int) -> Double {
                guard i >= 0, i < row.count else { return 0 }
                return row[i].doubleValue
            }
            views   += num(viewsIndex)
            minutes += num(minutesIndex)
            gained  += num(gainedIndex)
            lost    += num(lostIndex)
        }

        let watchHours = minutes / 60.0
        print("🔍 Analytics — views: \(Int(views)), watchHours: \(watchHours), gained: \(Int(gained)), lost: \(Int(lost))")

        return (Int(views), watchHours, Int(gained - lost))
    }
}
