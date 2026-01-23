import Foundation
import SwiftUI
import GoogleSignIn

// MARK: - Required Decodable Models for YouTube API

struct ChannelListResponse: Codable {
    let items: [ChannelItem]

    struct ChannelItem: Codable {
        let contentDetails: ContentDetails
    }

    struct ContentDetails: Codable {
        let relatedPlaylists: RelatedPlaylists
    }

    struct RelatedPlaylists: Codable {
        let uploads: String
    }
}

struct PlaylistItemsResponse: Codable {
    let items: [PlaylistItem]

    struct PlaylistItem: Codable {
        let snippet: Snippet?
        let contentDetails: ContentDetails?

        struct Snippet: Codable {
            let title: String?
        }

        struct ContentDetails: Codable {
            let videoId: String?
        }
    }
}

struct AnalyticsReportResponse: Codable {
    let rows: [[String]]?
}

// MARK: - Coach ViewModel

@MainActor
final class CoachViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var latestVideo: Video?

    init() {
        Task {
            await loadVideos()
        }
    }

    // MARK: - Load Videos
    func loadVideos() async {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            loadMockData()
            return
        }

        let token = user.accessToken.tokenString

        do {
            let uploadsPlaylistId = try await fetchUploadsPlaylist(accessToken: token)
            let videoList = try await fetchPlaylistVideos(playlistId: uploadsPlaylistId, accessToken: token)
            let videosWithAnalytics = try await fetchAnalytics(for: videoList, accessToken: token)

            let sorted = videosWithAnalytics.sorted { $0.views > $1.views }
            self.videos = sorted
            self.latestVideo = sorted.first
        } catch {
            print("Error fetching videos: \(error)")
            loadMockData()
        }
    }

    // MARK: - Fetch uploads playlist
    private func fetchUploadsPlaylist(accessToken: String) async throws -> String {
        let urlStr = "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&mine=true"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var request = URLRequest(url: url, bearerToken: accessToken)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChannelListResponse.self, from: data)

        guard let uploadsId = response.items.first?.contentDetails.relatedPlaylists.uploads else {
            throw NSError(domain: "CoachViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Uploads playlist not found"])
        }

        return uploadsId
    }

    // MARK: - Fetch playlist videos
    private func fetchPlaylistVideos(playlistId: String, accessToken: String) async throws -> [Video] {
        let urlStr = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&maxResults=50&playlistId=\(playlistId)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var request = URLRequest(url: url, bearerToken: accessToken)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)

        return response.items.compactMap { item in
            guard
                let snippet = item.snippet,
                let videoId = item.contentDetails?.videoId,
                let title = snippet.title
            else { return nil }

            return Video(
                videoId: videoId,
                title: title,
                views: 0,
                watchTime: 0,
                thumbnailCTR: 0,
                averageViewDuration: 0,
                dropOffSecond: 0,
                analytics: nil
            )
        }
    }

    // MARK: - Fetch video analytics
    private func fetchAnalytics(for videos: [Video], accessToken: String) async throws -> [Video] {
        var updatedVideos: [Video] = []

        for var video in videos {
            let urlStr = """
            https://youtubeanalytics.googleapis.com/v2/reports?dimensions=video&metrics=views,averageViewDuration,estimatedMinutesWatched&filters=video==\(video.videoId)&startDate=2025-01-01&endDate=2025-12-31
            """
            guard let url = URL(string: urlStr) else {
                updatedVideos.append(video)
                continue
            }

            do {
                var request = URLRequest(url: url, bearerToken: accessToken)
                let (data, _) = try await URLSession.shared.data(for: request)
                let report = try JSONDecoder().decode(AnalyticsReportResponse.self, from: data)

                if let row = report.rows?.first,
                   let views = Int(row[0]),
                   let avgDuration = Double(row[1]) {

                    let analytics = VideoAnalytics(
                        ctr: 0, // placeholder
                        averageViewDuration: Int(avgDuration),
                        retention: 0.7, // placeholder
                        expectedViews: views
                    )

                    video.analytics = analytics
                    video.views = views
                }
            } catch {
                print("Analytics fetch failed for \(video.title): \(error)")
            }

            updatedVideos.append(video)
        }

        return updatedVideos
    }

    // MARK: - Fallback Mock Data
    func loadMockData() {
        let mock = Video.mockList()
        videos = mock
        latestVideo = mock.first
    }

    // MARK: - Coach Helpers
    func primaryFix(for video: Video) -> CoachFix { video.primaryFix }
    func healthScore(for video: Video) -> Int { video.healthScore }
}
