// Features/Date+YouTube.swift
import Foundation

extension Date {
    /// Returns date formatted as yyyy-MM-dd for YouTube Analytics API
    func youtubeAnalyticsDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}
