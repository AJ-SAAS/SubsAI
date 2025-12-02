import Foundation

enum MilestoneType: String, CaseIterable, Codable {
    case subscribers
    case views
    case watchHours
    case thumbnailCTR
}

struct Milestone: Identifiable, Codable {
    let id: UUID
    let type: MilestoneType
    let target: Double
    
    init(id: UUID = UUID(), type: MilestoneType, target: Double) {
        self.id = id
        self.type = type
        self.target = target
    }
}
