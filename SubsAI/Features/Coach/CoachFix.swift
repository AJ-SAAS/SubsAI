import Foundation

enum CoachFix {
    case thumbnail
    case hook
    case retention
    case discovery
    case none

    // MARK: - Short title for cards
    var title: String {
        switch self {
        case .thumbnail: return "Fix your thumbnail & title"
        case .hook: return "Fix your first 10 seconds"
        case .retention: return "Improve mid-video retention"
        case .discovery: return "Improve discovery & SEO"
        case .none: return "This video is healthy"
        }
    }

    // MARK: - Long description for review screen
    var description: String {
        switch self {
        case .thumbnail:
            return "Your video isn’t getting clicked enough to unlock reach."
        case .hook:
            return "Viewers are leaving before YouTube trusts the video."
        case .retention:
            return "Viewers lose interest before the payoff."
        case .discovery:
            return "The video performs well, but isn’t being surfaced."
        case .none:
            return "No immediate action needed."
        }
    }

    // MARK: - SF Symbol for visual cue
    var systemImage: String {
        switch self {
        case .thumbnail: return "photo"
        case .hook: return "bolt.fill"
        case .retention: return "clock.fill"
        case .discovery: return "magnifyingglass"
        case .none: return "checkmark.circle.fill"
        }
    }
}
