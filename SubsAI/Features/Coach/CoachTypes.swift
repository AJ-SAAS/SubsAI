// Features/Coach/CoachTypes.swift
import Foundation
import SwiftUI

// MARK: - Coach Fix
enum CoachFix: String, Codable, CaseIterable, Identifiable {
    case thumbnail
    case hook
    case retention
    case discovery
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thumbnail:  return "Fix your thumbnail & title"
        case .hook:       return "Fix your first 10 seconds"
        case .retention:  return "Improve mid-video retention"
        case .discovery:  return "Improve discovery & SEO"
        case .none:       return "This video is healthy"
        }
    }

    var description: String {
        switch self {
        case .thumbnail:  return "Your video isn't getting clicked enough. Improve the thumbnail and title."
        case .hook:       return "Viewers are leaving early. Make the first 10 seconds more engaging."
        case .retention:  return "Viewers lose interest mid-video. Add a payoff sooner."
        case .discovery:  return "The video performs well but isn't being surfaced. Check metadata and SEO."
        case .none:       return "No immediate action needed."
        }
    }

    var systemImage: String {
        switch self {
        case .thumbnail:  return "photo"
        case .hook:       return "bolt.fill"
        case .retention:  return "clock.fill"
        case .discovery:  return "magnifyingglass"
        case .none:       return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .thumbnail, .hook: return .red
        case .retention:        return .yellow
        case .discovery:        return Color(red: 0.49, green: 0.44, blue: 1.0)
        case .none:             return .green
        }
    }

    var coachLine: String {
        switch self {
        case .thumbnail:
            return "CTR is too low — your title reads like a tutorial, not a story. Reframe around a specific result."
        case .hook:
            return "Viewers are leaving in the first 30 seconds. Open with the payoff, not the setup."
        case .retention:
            return "Drop-off mid-video. Add a re-hook before the 3-minute mark to pull viewers back in."
        case .discovery:
            return "Views are below expectations. Your metadata isn't helping YouTube surface this video."
        case .none:
            return "Performing well. Study this hook and repeat the format on your next upload."
        }
    }
}

// MARK: - Coach Verdict
struct CoachVerdict: Codable, Equatable, Hashable {
    let fix: CoachFix

    init(video: Video) {
        self.fix = video.primaryFix
    }

    var emoji: String {
        switch fix {
        case .none: return "✅"
        default:    return "⚠️"
        }
    }

    var text: String {
        switch fix {
        case .none: return "Performing Well"
        default:    return "Needs Attention"
        }
    }

    var description: String { fix.description }
    var color: Color { fix.color.opacity(0.15) }
    var iconColor: Color { fix.color }

    var severity: Int {
        switch fix {
        case .none:       return 0
        case .discovery:  return 1
        case .retention:  return 2
        case .hook:       return 3
        case .thumbnail:  return 4
        }
    }

    // ✅ Removed Int.random — now deterministic per fix type
    // Real score comes from Video.healthScore which uses actual analytics
    var healthLabel: String {
        switch fix {
        case .none:                   return "Healthy"
        case .discovery, .retention:  return "Watch"
        case .hook, .thumbnail:       return "Fix now"
        }
    }

    var healthColor: Color {
        switch fix {
        case .none:                   return .green
        case .discovery, .retention:  return .yellow
        case .hook, .thumbnail:       return .red
        }
    }

    var filledSegments: Int {
        switch fix {
        case .none:       return 5
        case .discovery:  return 3
        case .retention:  return 3
        case .hook:       return 2
        case .thumbnail:  return 2
        }
    }
}
