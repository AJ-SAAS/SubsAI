import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    @Published var subscribers: Int = 0
    @Published var views: Int = 0
    @Published var videos: Int = 0
    @Published var errorMessage: String?
    private var cancellables = Set<AnyCancellable>()
    private let apiManager = YouTubeAPIManager()

    func fetchStats(completion: ((Error?) -> Void)? = nil) {
        print("DashboardViewModel: Fetching stats")

        // Fetch channel stats
        apiManager.fetchChannelStats()
            .sink(receiveCompletion: { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    print("DashboardViewModel: Error fetching channel stats: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    completion?(error)
                }
            }, receiveValue: { [weak self] stats in
                self?.subscribers = Int(stats.subscriberCount) ?? 0
                self?.views = Int(stats.viewCount) ?? 0
                self?.videos = Int(stats.videoCount) ?? 0
                print("DashboardViewModel: Fetched channel stats - Subscribers: \(self?.subscribers ?? 0), Views: \(self?.views ?? 0), Videos: \(self?.videos ?? 0)")
                completion?(nil)
            })
            .store(in: &cancellables)

        // Fetch analytics data
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let endDate = Date()
        apiManager.fetchAnalyticsMetrics(metrics: "watchTimeMinutes,views", startDate: startDate, endDate: endDate)
            .sink(receiveCompletion: { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    print("DashboardViewModel: Error fetching analytics: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    completion?(error)
                }
            }, receiveValue: { [weak self] stats in
                if let row = stats.rows?.first, row.count >= 2 {
                    self?.views = Int(row[1]) ?? self?.views ?? 0
                    print("DashboardViewModel: Fetched analytics - Views: \(self?.views ?? 0)")
                    completion?(nil)
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid analytics data"])
                    self?.errorMessage = error.localizedDescription
                    completion?(error)
                }
            })
            .store(in: &cancellables)
    }
}
