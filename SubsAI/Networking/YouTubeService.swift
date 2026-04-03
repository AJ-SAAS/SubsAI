// Networking/YouTubeService.swift
import Foundation
import GoogleSignIn

@MainActor
final class YouTubeService {

    static let shared = YouTubeService()
    private init() {}

    // MARK: - Mock Data for Demo Account (Apple Review + Testing)
    private func mockChannel() -> Channel {
        Channel(
            id: "UCdemoTechGrowth2026",
            name: "TechGrowth Daily",
            subscribers: 124800,
            totalViews: 4520000,
            watchTime: 18420,
            videoCount: 87,
            thumbnailCTR: 0.062,
            profilePicURL: "https://picsum.photos/id/1015/300/300",
            bannerURL: nil
        )
    }

    private func mockVideos() -> [Video] {
        let now = Date()
        return [
            Video(
                videoId: "demo1",
                title: "I Tried the New YouTube Algorithm for 30 Days – Here’s What Happened",
                publishedAt: now.addingTimeInterval(-86400 * 4),
                views: 42800,
                watchTime: 12400,
                thumbnailCTR: 0.078,
                averageViewDuration: 142,
                dropOffSecond: 18,
                analytics: VideoAnalytics(ctr: 0.078, averageViewDuration: 142, retention: 0.48, expectedViews: 52000, subscribersGained: 1240)
            ),
            Video(
                videoId: "demo2",
                title: "How to Get 10x More Views with Better Thumbnails (2026 Update)",
                publishedAt: now.addingTimeInterval(-86400 * 11),
                views: 67300,
                watchTime: 18900,
                thumbnailCTR: 0.091,
                averageViewDuration: 98,
                dropOffSecond: 12,
                analytics: VideoAnalytics(ctr: 0.091, averageViewDuration: 98, retention: 0.55, expectedViews: 58000, subscribersGained: 890)
            ),
            Video(
                videoId: "demo3",
                title: "Why Your Retention Drops at 47 Seconds (and How to Fix It)",
                publishedAt: now.addingTimeInterval(-86400 * 19),
                views: 21900,
                watchTime: 6700,
                thumbnailCTR: 0.044,
                averageViewDuration: 67,
                dropOffSecond: 47,
                analytics: VideoAnalytics(ctr: 0.044, averageViewDuration: 67, retention: 0.31, expectedViews: 35000, subscribersGained: 320)
            ),
            Video(
                videoId: "demo4",
                title: "7 Thumbnail Mistakes Killing Your CTR Right Now",
                publishedAt: now.addingTimeInterval(-86400 * 26),
                views: 35100,
                watchTime: 9800,
                thumbnailCTR: 0.067,
                averageViewDuration: 115,
                dropOffSecond: 22,
                analytics: VideoAnalytics(ctr: 0.067, averageViewDuration: 115, retention: 0.42, expectedViews: 41000, subscribersGained: 610)
            )
        ]
    }

    private func mockPeriodAnalytics(_ period: TimePeriod) -> (views: Int, watchHours: Double, netSubs: Int) {
        switch period {
        case .week:    return (12400, 620, 340)
        case .month:   return (48700, 2480, 920)
        case .quarter: return (142000, 7100, 2150)
        }
    }

    // Public helper for demo
    func demoVideos() -> [Video] {
        mockVideos()
    }

    // MARK: - Channel Info
    func fetchChannel() async throws -> Channel {
        if AuthManager.shared.isDemoMode {
            return mockChannel()
        }
        
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
        if AuthManager.shared.isDemoMode {
            return mockPeriodAnalytics(period)
        }
        
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
