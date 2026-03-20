// Features/Dashboard/DashboardModels.swift
import Foundation

public struct ChannelInfo: Codable, Equatable {
    public let title: String
    public let thumbnailURL: String
    public let bannerURL: String?
    public let subscribers: Int
    public let totalViews: Int
    public let totalVideos: Int
    public var totalWatchTime: Double
    public let thumbnailCTR: Double

    public var subscriberGrowth: GrowthData?
    public var viewGrowth: GrowthData?
    public var videoGrowth: GrowthData?
    public var watchTimeGrowth: GrowthData?
}

public struct GrowthData: Codable, Equatable {
    public let absolute: Int
    public let percentage: Double
    public let trend: TrendDirection

    public enum TrendDirection: String, Codable {
        case up, down, neutral
    }

    public var formattedAbsolute: String {
        let prefix = trend == .up ? "+" : (trend == .down ? "-" : "")
        return "\(prefix)\(abs(absolute).formattedShort())"
    }

    public var formattedPercentage: String {
        let prefix = trend == .up ? "+" : (trend == .down ? "-" : "")
        return "\(prefix)\(String(format: "%.1f", abs(percentage)))%"
    }
}

// ✅ Added Hashable + Equatable, shortened rawValues for UI display
public enum TimePeriod: String, CaseIterable, Hashable, Equatable {
    case week    = "7d"
    case month   = "28d"
    case quarter = "90d"

    public var days: Int {
        switch self {
        case .week:    return 7
        case .month:   return 28
        case .quarter: return 90
        }
    }

    public var label: String {
        switch self {
        case .week:    return "this week"
        case .month:   return "this month"
        case .quarter: return "this quarter"
        }
    }
}

// MARK: - Int formatting
extension Int {
    func formattedShort() -> String {
        let absValue = abs(self)
        if absValue >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000.0) }
        if absValue >= 1_000     { return String(format: "%.1fK", Double(self) / 1_000.0) }
        return "\(self)"
    }
}
