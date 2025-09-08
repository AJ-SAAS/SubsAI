import Foundation
import Combine

class MonetizationViewModel: ObservableObject {
    @Published var subscribers: Int = 0
    @Published var watchTimeMinutes: Int = 0
    @Published var views: Int = 0
    @Published var errorMessage: String?
    private var cancellables = Set<AnyCancellable>()
    private let apiManager = YouTubeAPIManager()

    func fetchMonetizationStats() {
        // Fetch channel stats for subscribers
        apiManager.fetchChannelStats()
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("MonetizationViewModel: Error fetching stats: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] stats in
                self?.subscribers = Int(stats.subscriberCount) ?? 0
                print("MonetizationViewModel: Fetched subscribers: \(self?.subscribers ?? 0)")
            })
            .store(in: &cancellables)

        // Fetch analytics data for watch time and views (last 365 days for watch time, 90 days for views)
        let watchTimeStartDate = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        let viewsStartDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let endDate = Date()

        // Watch time (last 365 days)
        apiManager.fetchAnalyticsMetrics(metrics: "watchTimeMinutes", startDate: watchTimeStartDate, endDate: endDate)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("MonetizationViewModel: Error fetching watch time: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] stats in
                if let row = stats.rows?.first, row.count >= 1 {
                    self?.watchTimeMinutes = Int(Float(row[0]) ?? 0)
                    print("MonetizationViewModel: Fetched watch time: \(self?.watchTimeMinutes ?? 0) minutes")
                }
            })
            .store(in: &cancellables)

        // Views (last 90 days)
        apiManager.fetchAnalyticsMetrics(metrics: "views", startDate: viewsStartDate, endDate: endDate)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("MonetizationViewModel: Error fetching views: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] stats in
                if let row = stats.rows?.first, row.count >= 1 {
                    self?.views = Int(row[0]) ?? 0
                    print("MonetizationViewModel: Fetched views: \(self?.views ?? 0)")
                }
            })
            .store(in: &cancellables)
    }
}
