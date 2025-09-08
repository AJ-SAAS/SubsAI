import Foundation

struct AnalyticsStats: Codable {
    let rows: [[String]]?

    enum CodingKeys: String, CodingKey {
        case rows
    }
}
