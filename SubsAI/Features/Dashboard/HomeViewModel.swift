// Features/Dashboard/HomeViewModel.swift
import Foundation
import Combine

struct ChannelInfo: Codable {
    let title: String
    let thumbnailURL: String
    let subscribers: Int
    let totalViews: Int
    let totalVideos: Int
    let totalWatchTime: Double
    let thumbnailCTR: Double
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var channelInfo: ChannelInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        AuthManager.shared.$isSignedIn
            .dropFirst()
            .sink { [weak self] signedIn in
                if signedIn { self?.loadChannelStats() }
            }
            .store(in: &cancellables)
    }

    func loadChannelStats() {
        guard AuthManager.shared.isSignedIn,
              let token = AuthManager.shared.accessToken else {
            errorMessage = "Not signed in"
            return
        }

        isLoading = true
        errorMessage = nil

        let url = URL(string: "https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics&mine=true")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: YouTubeChannelResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let item = response.items.first else { return }

                let stats = item.statistics
                let snippet = item.snippet

                self?.channelInfo = ChannelInfo(
                    title: snippet.title,
                    thumbnailURL: snippet.thumbnails.default.url,
                    subscribers: Int(stats.subscriberCount) ?? 0,
                    totalViews: Int(stats.viewCount) ?? 0,
                    totalVideos: Int(stats.videoCount) ?? 0,
                    totalWatchTime: 0,
                    thumbnailCTR: 0
                )
            }
            .store(in: &cancellables)
    }
}

// MARK: - YouTube Response Models
private struct YouTubeChannelResponse: Codable {
    let items: [ChannelItem]

    struct ChannelItem: Codable {
        let snippet: Snippet
        let statistics: Statistics
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
}
