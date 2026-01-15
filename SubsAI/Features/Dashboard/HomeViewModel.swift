// Features/Dashboard/HomeViewModel.swift
import Foundation
import GoogleSignIn

struct ChannelInfo: Codable, Equatable {
    let title: String
    let thumbnailURL: String
    let bannerURL: String?
    let subscribers: Int
    let totalViews: Int
    let totalVideos: Int
    var totalWatchTime: Double
    let thumbnailCTR: Double
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var channelInfo: ChannelInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?

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

        defer {
            Task {
                try? await Task.sleep(for: .seconds(25))
                await MainActor.run { isLoading = false }
            }
        }

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

            let newChannelInfo = ChannelInfo(
                title: snippet.title,
                thumbnailURL: snippet.thumbnails.default.url,
                bannerURL: bannerURL,
                subscribers: Int(stats.subscriberCount) ?? 0,
                totalViews: Int(stats.viewCount) ?? 0,
                totalVideos: Int(stats.videoCount) ?? 0,
                totalWatchTime: 0,
                thumbnailCTR: 0
            )

            await MainActor.run {
                self.channelInfo = newChannelInfo
            }

            print("Starting watch time fetch...")
            let scopeGranted = await ensureAnalyticsScope()
            if scopeGranted {
                await fetchLifetimeWatchTime(with: token)
            } else {
                await MainActor.run {
                    errorMessage = "Analytics permission still missing. Disconnect in Settings and re-sign in."
                }
            }

        } catch {
            print("Channel load failed: \(error) - \(error.localizedDescription)")
            errorMessage = "Failed to load channel: \(error.localizedDescription)"
        }

        isLoading = false
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
            await MainActor.run { isLoading = false }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                await MainActor.run { errorMessage = "Invalid response"; isLoading = false }
                return
            }

            print("Analytics API status: \(http.statusCode)")

            if http.statusCode != 200 {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Analytics error response: \(errorText)")
                await MainActor.run {
                    errorMessage = "Analytics API failed (status \(http.statusCode)): \(errorText)"
                    isLoading = false
                }
                return
            }

            // Log raw JSON for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw Analytics JSON response:\n\(jsonString)")
            }

            // Decode with flexible numeric rows
            let decoded = try JSONDecoder().decode(WatchTimeResponse.self, from: data)

            if let rows = decoded.rows, !rows.isEmpty,
               let firstRow = rows.first, let minutesDouble = firstRow.first {

                print("Extracted minutes value: \(minutesDouble)")

                let hours = minutesDouble / 60.0
                await MainActor.run {
                    if var info = channelInfo {
                        info.totalWatchTime = hours
                        channelInfo = info
                    }
                    errorMessage = nil
                    print("Watch hours successfully loaded: \(hours) hrs")
                }
            } else {
                print("No rows or empty data")
                await MainActor.run {
                    errorMessage = "No lifetime watch time data available yet (new channel or no data processed)"
                    isLoading = false
                }
            }

        } catch let decodingError as DecodingError {
            print("Decoding error details: \(decodingError)")
            await MainActor.run {
                errorMessage = "Failed to parse Analytics response: \(decodingError.localizedDescription)"
                isLoading = false
            }
        } catch {
            print("Analytics fetch error: \(error)")
            await MainActor.run {
                errorMessage = "Failed to fetch watch hours: \(error.localizedDescription)"
                isLoading = false
            }
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

// UPDATED: Use [[Double]]? to match raw numbers in rows
private struct WatchTimeResponse: Codable {
    let rows: [[Double]]?
}
