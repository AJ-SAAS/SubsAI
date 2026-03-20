import Foundation

enum AuthError: Identifiable, LocalizedError {
    case sessionExpired
    case accessRevoked
    case unknown

    // MARK: - Identifiable
    var id: String {
        localizedDescription
    }

    // MARK: - LocalizedError
    var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .accessRevoked:
            return "YouTube access was revoked. Please reconnect your account."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    var title: String {
        "Authentication Error"
    }
}
