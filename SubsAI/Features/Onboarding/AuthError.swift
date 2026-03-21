import Foundation

enum AuthError: Identifiable, LocalizedError {
    case notSignedIn
    case tokenExpired
    case sessionExpired
    case accessRevoked
    case unknown

    var id: String { localizedDescription }

    var title: String {
        switch self {
        case .notSignedIn:             return "Not Signed In"
        case .tokenExpired,
             .sessionExpired:          return "Session Expired"
        case .accessRevoked:           return "Access Revoked"
        case .unknown:                 return "Authentication Error"
        }
    }

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Please sign in to continue."
        case .tokenExpired, .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .accessRevoked:
            return "YouTube access was revoked. Please reconnect your account."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
