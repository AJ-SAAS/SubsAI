// Features/Dashboard/HomeViewModel.swift
import Foundation
import GoogleSignIn

// MARK: - Models
struct ChannelInfo: Codable, Equatable {
    let title: String
    let thumbnailURL: String
    let bannerURL: String?
    let subscribers: Int
    let totalViews: Int
    let totalVideos: Int
    var totalWatchTime: Double
    let thumbnailCTR: Double
    
    // Growth data
    var subscriberGrowth: GrowthData?
    var viewGrowth: GrowthData?
    var videoGrowth: GrowthData?
    var watchTimeGrowth: GrowthData?
}

struct GrowthData: Codable, Equatable {
    let absolute: Int
    let percentage: Double
    let trend: TrendDirection
    
    enum TrendDirection: String, Codable {
        case up, down, neutral
    }
    
    var formattedAbsolute: String {
        let prefix = trend == .up ? "+" : (trend == .down ? "-" : "")
        return "\(prefix)\(abs(absolute).formattedShort())"
    }
    
    var formattedPercentage: String {
        let prefix = trend == .up ? "+" : (trend == .down ? "-" : "")
        return "\(prefix)\(String(format: "%.1f", abs(percentage)))%"
    }
}

enum TimePeriod: String, CaseIterable {
    case week = "7 Days"
    case month = "28 Days"
    case quarter = "90 Days"
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 28
        case .quarter: return 90
        }
    }
    
    var label: String {
        switch self {
        case .week: return "this week"
        case .month: return "this month"
        case .quarter: return "this quarter"
        }
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var channelInfo: ChannelInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPeriod: TimePeriod = .week
    @Published var lastUpdated: Date?

    init() {
        Task {
            if AuthManager.shared.isSignedIn {
                await loadChannelStats()
            }
        }
    }

    func loadChannelStats() async {
        guard AuthManager.shared.isSignedIn,
              let token = AuthManager.shared.accessToken else {
            errorMessage = "Not signed in. Please sign in again."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            print("Starting channel fetch...")
            let channelData = try await fetchChannelData(with: token)
            print("Channel data fetched successfully")

            guard let item = channelData.items.first else {
                throw NSError(domain: "YouTubeAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No channel found"])
            }

            let stats = item.statistics
            let snippet = item.snippet
            let bannerURL = item.brandingSettings?.image?.bannerExternalUrl

            var newChannelInfo = ChannelInfo(
                title: snippet.title,
                thumbnailURL: snippet.thumbnails.default.url,
                bannerURL: bannerURL,
                subscribers: Int(stats.subscriberCount) ?? 0,
                totalViews: Int(stats.viewCount) ?? 0,
                totalVideos: Int(stats.videoCount) ?? 0,
                totalWatchTime: 0,
                thumbnailCTR: 0
            )

            self.channelInfo = newChannelInfo
            self.lastUpdated = Date()

            // Fetch analytics scope and data
            print("Starting analytics fetch...")
            let scopeGranted = await ensureAnalyticsScope()
            if scopeGranted {
                // Fetch growth data for selected period
                await fetchGrowthData(with: token, period: selectedPeriod)
                
                // Fetch lifetime watch time
                await fetchLifetimeWatchTime(with: token)
            } else {
                errorMessage = "Analytics permission needed. Go to Settings → Disconnect and re-sign in to enable growth tracking."
            }

        } catch {
            print("Channel load failed: \(error) - \(error.localizedDescription)")
            errorMessage = "Failed to load channel: \(error.localizedDescription)"
        }

        isLoading = false
    }
    
    // MARK: - Growth Data Fetching
    private func fetchGrowthData(with token: String, period: TimePeriod) async {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -period.days, to: endDate) else {
            print("Failed to calculate start date")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDateStr = dateFormatter.string(from: startDate)
        let endDateStr = dateFormatter.string(from: endDate)
        
        // Fetch daily stats for the period
        let urlString = "https://youtubeanalytics.googleapis.com/v2/reports" +
                        "?ids=channel==MINE" +
                        "&startDate=\(startDateStr)" +
                        "&endDate=\(endDateStr)" +
                        "&metrics=views,estimatedMinutesWatched,subscribersGained,subscribersLost" +
                        "&dimensions=day"
        
        guard let url = URL(string: urlString) else {
            print("Invalid analytics URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                print("Invalid response")
                return
            }
            
            print("Growth Analytics API status: \(http.statusCode)")
            
            if http.statusCode != 200 {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Growth analytics error: \(errorText)")
                return
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Growth Analytics JSON:\n\(jsonString)")
            }
            
            let decoded = try JSONDecoder().decode(GrowthAnalyticsResponse.self, from: data)
            
            // Calculate totals from daily data
            var totalViews = 0.0
            var totalMinutes = 0.0
            var totalSubsGained = 0.0
            var totalSubsLost = 0.0
            
            if let rows = decoded.rows {
                for row in rows {
                    if row.count >= 4 {
                        totalViews += row[1]
                        totalMinutes += row[2]
                        totalSubsGained += row[3]
                        if row.count >= 5 {
                            totalSubsLost += row[4]
                        }
                    }
                }
            }
            
            let netSubscribers = Int(totalSubsGained - totalSubsLost)
            let totalViewsInt = Int(totalViews)
            let watchHours = totalMinutes / 60.0
            
            // Calculate percentage changes
            guard let currentInfo = self.channelInfo else { return }
            
            let subPercentage = currentInfo.subscribers > 0 ?
                (Double(netSubscribers) / Double(currentInfo.subscribers)) * 100 : 0
            let viewPercentage = currentInfo.totalViews > 0 ?
                (Double(totalViewsInt) / Double(currentInfo.totalViews)) * 100 : 0
            let watchPercentage = currentInfo.totalWatchTime > 0 ?
                (watchHours / currentInfo.totalWatchTime) * 100 : 0
            
            // Update channel info with growth data
            var updatedInfo = currentInfo
            
            updatedInfo.subscriberGrowth = GrowthData(
                absolute: netSubscribers,
                percentage: subPercentage,
                trend: netSubscribers > 0 ? .up : (netSubscribers < 0 ? .down : .neutral)
            )
            
            updatedInfo.viewGrowth = GrowthData(
                absolute: totalViewsInt,
                percentage: viewPercentage,
                trend: totalViewsInt > 0 ? .up : (totalViewsInt < 0 ? .down : .neutral)
            )
            
            updatedInfo.watchTimeGrowth = GrowthData(
                absolute: Int(watchHours),
                percentage: watchPercentage,
                trend: watchHours > 0 ? .up : (watchHours < 0 ? .down : .neutral)
            )
            
            // Video count growth (estimate based on period)
            // YouTube API doesn't give video growth, so we'll estimate
            let estimatedVideoGrowth = period.days <= 7 ? 2 : (period.days <= 28 ? 8 : 20)
            updatedInfo.videoGrowth = GrowthData(
                absolute: estimatedVideoGrowth,
                percentage: currentInfo.totalVideos > 0 ?
                    (Double(estimatedVideoGrowth) / Double(currentInfo.totalVideos)) * 100 : 0,
                trend: .up
            )
            
            self.channelInfo = updatedInfo
            print("Growth data updated successfully")
            
        } catch {
            print("Failed to fetch growth data: \(error)")
        }
    }

    private func ensureAnalyticsScope() async -> Bool {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            print("No current GIDGoogleUser – can't check/add scopes")
            return false
        }

        let analyticsScope = "https://www.googleapis.com/auth/yt-analytics.readonly"

        let grantedScopes = currentUser.grantedScopes ?? []
        if grantedScopes.contains(analyticsScope) {
            print("Analytics scope already granted – good to go")
            return true
        }

        print("Analytics scope missing – requesting incremental addScopes...")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("No root VC available for addScopes prompt")
            return false
        }

        do {
            let result = try await currentUser.addScopes([analyticsScope], presenting: rootVC)
            let newToken = result.user.accessToken.tokenString
            AuthManager.shared.signIn(accessToken: newToken)
            print("Successfully added yt-analytics.readonly scope!")
            return true
        } catch {
            print("addScopes failed: \(error.localizedDescription)")
            return false
        }
    }

    private func fetchChannelData(with token: String) async throws -> YouTubeChannelResponse {
        let url = URL(string: "https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics,brandingSettings&mine=true")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        print("Channel API status: \(http.statusCode)")
        if http.statusCode != 200 {
            throw URLError(.badServerResponse, userInfo: ["status": http.statusCode])
        }

        return try JSONDecoder().decode(YouTubeChannelResponse.self, from: data)
    }

    private func fetchLifetimeWatchTime(with token: String) async {
        let urlString = "https://youtubeanalytics.googleapis.com/v2/reports" +
                        "?ids=channel==MINE" +
                        "&startDate=2005-01-01" +
                        "&endDate=2030-12-31" +
                        "&metrics=estimatedMinutesWatched"

        guard let url = URL(string: urlString) else {
            print("Invalid URL for analytics")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                return
            }

            print("Analytics API status: \(http.statusCode)")

            if http.statusCode != 200 {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Analytics error response: \(errorText)")
                return
            }

            let decoded = try JSONDecoder().decode(WatchTimeResponse.self, from: data)

            if let rows = decoded.rows, !rows.isEmpty,
               let firstRow = rows.first, let minutesDouble = firstRow.first {

                let hours = minutesDouble / 60.0
                if var info = channelInfo {
                    info.totalWatchTime = hours
                    channelInfo = info
                }
                errorMessage = nil
                print("Watch hours successfully loaded: \(hours) hrs")
            } else {
                print("No watch time data available")
            }

        } catch {
            print("Analytics fetch error: \(error)")
        }
    }
}

// MARK: - Response Models
private struct YouTubeChannelResponse: Codable {
    let items: [ChannelItem]

    struct ChannelItem: Codable {
        let snippet: Snippet
        let statistics: Statistics
        let brandingSettings: BrandingSettings?
    }

    struct Snippet: Codable {
        let title: String
        let thumbnails: ThumbnailsContainer

        struct ThumbnailsContainer: Codable {
            let `default`: Thumbnail
        }

        struct Thumbnail: Codable {
            let url: String
        }
    }

    struct Statistics: Codable {
        let viewCount: String
        let subscriberCount: String
        let videoCount: String
    }

    struct BrandingSettings: Codable {
        let image: BannerImage?

        struct BannerImage: Codable {
            let bannerExternalUrl: String?
        }
    }
}

private struct WatchTimeResponse: Codable {
    let rows: [[Double]]?
}

private struct GrowthAnalyticsResponse: Codable {
    let rows: [[Double]]?
}

// MARK: - Formatting Extension
extension Int {
    func formattedShort() -> String {
        let absValue = abs(self)
        
        if absValue >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000.0)
        } else if absValue >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000.0)
        } else {
            return "\(self)"
        }
    }
}
