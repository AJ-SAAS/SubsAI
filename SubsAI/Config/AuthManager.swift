import Foundation
import Combine
import GoogleSignIn

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var accessToken: String? = nil
    @Published var authError: AuthError? = nil

    private init() {
        restorePreviousSignInIfAvailable()
    }

    // MARK: - Restore Previous Sign-In
    private func restorePreviousSignInIfAvailable() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            guard let self, let user, error == nil else { return }

            Task { @MainActor in          // ✅ explicitly runs on MainActor
                do {
                    let refreshedUser = try await user.refreshTokensIfNeeded()
                    self.accessToken = refreshedUser.accessToken.tokenString
                    self.isSignedIn = true
                } catch {
                    self.signOut()
                }
            }
        }
    }

    // MARK: - Successful Sign-In
    func handleSuccessfulSignIn(user: GIDGoogleUser) {
        accessToken = user.accessToken.tokenString
        isSignedIn = true
        authError = nil
    }

    // MARK: - Token Access
    func getValidToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            signOut()
            throw URLError(.userAuthenticationRequired)
        }

        do {
            let refreshedUser = try await user.refreshTokensIfNeeded()
            return refreshedUser.accessToken.tokenString
        } catch {
            signOut()
            throw error
        }
    }

    // MARK: - Full Sign-Out
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        accessToken = nil
        isSignedIn = false
        print("🔒 Signed out completely")
    }
}
