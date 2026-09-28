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
        case .thumbnail:  return "Fix your thumbnail and title"
        case .hook:       return "Fix your first 30 seconds"
        case .retention:  return "Keep people watching longer"
        case .discovery:  return "Help more people find it"
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

    // Brand colors: purple = good, orange = needs work
    var color: Color {
        switch self {
        case .none: return HomeLook.purple
        default:    return HomeLook.orange
        }
    }

    var coachLine: String {
        switch self {
        case .thumbnail:
            return "Few people click it. Show one clear result in the thumbnail, and make the title promise it."
        case .hook:
            return "People leave in the first 30 seconds. Start with the best part, not the setup."
        case .retention:
            return "People leave in the middle. Cut the slow parts and tease what's coming next."
        case .discovery:
            return "Fewer views than usual. Use the words people search for in the title and description."
        case .none:
            return "Doing well. Make another video like this one."
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

    // Purple = good, grey = keep an eye on it, orange = fix it
    var healthColor: Color {
        switch fix {
        case .none:                   return HomeLook.purple
        case .discovery, .retention:  return HomeLook.secondary
        case .hook, .thumbnail:       return HomeLook.orangeText
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
