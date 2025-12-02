// Models/Video.swift
import Foundation

struct Video: Identifiable, Codable {
    // This makes Codable ignore the UUID and not try to decode it
    let id = UUID()
    
    let title: String
    let views: Int
    let watchTime: Int
    let thumbnailCTR: Double
    let averageViewDuration: Int // seconds
    let dropOffSecond: Int
    
    // Tell Codable: "id exists, but don't try to read/write it from JSON"
    private enum CodingKeys: String, CodingKey {
        case title, views, watchTime, thumbnailCTR, averageViewDuration, dropOffSecond
        // id is intentionally omitted → no warning, no conflict
    }
}
