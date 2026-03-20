import Foundation
import GoogleAPIClientForREST_YouTube
import GoogleAPIClientForREST_YouTubeAnalytics
import GoogleSignIn
import GTMSessionFetcherCore

@MainActor
final class YouTubeService {

    static let shared = YouTubeService()

    private let youtube: GTLRYouTubeService
    private let analytics: GTLRYouTubeAnalyticsService

    private init() {
        self.youtube = GTLRYouTubeService()
        self.analytics = GTLRYouTubeAnalyticsService()

        let fetcherService = GTMSessionFetcherService()
        youtube.fetcherService = fetcherService
        analytics.fetcherService = fetcherService
    }

    // MARK: - Authorization
    private func ensureAuthorized() async throws {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw NSError(
                domain: "AuthError",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "No signed-in user"]
            )
        }
        try await user.refreshTokensIfNeeded()
        youtube.authorizer = user.fetcherAuthorizer
        analytics.authorizer = user.fetcherAuthorizer
    }

    // MARK: - Channel Info
    func fetchChannel() async throws -> Channel {
        try await ensureAuthorized()

        return try await withCheckedThrowingContinuation { cont in
            let query = GTLRYouTubeQuery_ChannelsList.query(
                withPart: ["snippet", "statistics", "brandingSettings"]
            )
            query.mine = true

            youtube.executeQuery(query) { _, res, err in
                if let err {
                    cont.resume(throwing: err)
                    return
                }

                guard
                    let list = res as? GTLRYouTube_ChannelListResponse,
                    let item = list.items?.first
                else {
                    cont.resume(throwing: NSError(
                        domain: "ChannelError", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No channel found"]
                    ))
                    return
                }

                let thumbnails = item.snippet?.thumbnails
                let channel = Channel(
                    id: item.identifier ?? "",
                    name: item.snippet?.title ?? "Unknown Channel",
                    subscribers: Int(item.statistics?.subscriberCount?.stringValue ?? "0") ?? 0,
                    totalViews: Int(item.statistics?.viewCount?.stringValue ?? "0") ?? 0,
                    watchTime: 0,
                    videoCount: Int(item.statistics?.videoCount?.stringValue ?? "0") ?? 0,
                    thumbnailCTR: 0,
                    profilePicURL: thumbnails?.high?.url
                        ?? thumbnails?.medium?.url
                        ?? thumbnails?.defaultProperty?.url
                        ?? "",
                    bannerURL: item.brandingSettings?.image?.bannerExternalUrl
                )
                cont.resume(returning: channel)
            }
        }
    }

    // MARK: - Analytics
    func fetchPeriodAnalytics(_ period: TimePeriod) async throws -> (views: Int, watchHours: Double, netSubs: Int) {
        try await ensureAuthorized()

        let end = Date()
        guard let start = Calendar.current.date(
            byAdding: .day, value: -period.days, to: end
        ) else {
            throw NSError(domain: "DateError", code: -1)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let query = GTLRYouTubeAnalyticsQuery_ReportsQuery()
        query.ids        = "channel==MINE"
        query.startDate  = formatter.string(from: start)
        query.endDate    = formatter.string(from: end)
        query.metrics    = "views,estimatedMinutesWatched,subscribersGained,subscribersLost"
        query.dimensions = "day"

        return try await withCheckedThrowingContinuation { cont in
            analytics.executeQuery(query) { _, res, err in
                if let err {
                    cont.resume(throwing: err)
                    return
                }

                guard let response = res as? GTLRYouTubeAnalytics_QueryResponse else {
                    cont.resume(throwing: NSError(domain: "AnalyticsError", code: -1))
                    return
                }

                var views = 0.0, minutes = 0.0, gained = 0.0, lost = 0.0
                var viewsIndex = -1, minutesIndex = -1, gainedIndex = -1, lostIndex = -1

                response.columnHeaders?.enumerated().forEach { index, header in
                    switch header.name {
                    case "views":                   viewsIndex   = index
                    case "estimatedMinutesWatched": minutesIndex = index
                    case "subscribersGained":       gainedIndex  = index
                    case "subscribersLost":         lostIndex    = index
                    default: break
                    }
                }

                // ✅ response.rows is [Any]? from GTLR — cast each row safely
                if let rows = response.rows as? [[Any]] {
                    for row in rows {
                        func num(_ i: Int) -> Double {
                            guard i >= 0, i < row.count else { return 0 }
                            if let n = row[i] as? NSNumber { return n.doubleValue }
                            if let s = row[i] as? String   { return Double(s) ?? 0 }
                            return 0
                        }
                        views   += num(viewsIndex)
                        minutes += num(minutesIndex)
                        gained  += num(gainedIndex)
                        lost    += num(lostIndex)
                    }
                }

                let watchHours = minutes / 60.0
                print("🔍 Analytics — views: \(Int(views)), watchHours: \(watchHours), gained: \(Int(gained)), lost: \(Int(lost))")

                cont.resume(returning: (Int(views), watchHours, Int(gained - lost)))
            }
        }
    }
}
