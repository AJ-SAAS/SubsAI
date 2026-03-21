// Config/AuthManager.swift
import Foundation
import GoogleSignIn
import AuthenticationServices

// MARK: - Auth State
enum IdentityProvider: String, Codable {
    case apple
    case google
}

struct AppUser: Codable {
    let id: String
    let provider: IdentityProvider
    var displayName: String?
    var email: String?
}

// MARK: - AuthManager
@MainActor
final class AuthManager: NSObject, ObservableObject {

    static let shared = AuthManager()

    @Published var currentUser: AppUser?
    @Published var isYouTubeConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: AuthError?

    private let userKey        = "subsai_user"
    private let ytConnectedKey = "subsai_yt_connected"

    var isSignedIn: Bool { currentUser != nil }

    override init() {
        super.init()
        loadPersistedUser()
        isYouTubeConnected = UserDefaults.standard.bool(forKey: ytConnectedKey)
    }

    // MARK: - Persist / load user
    private func loadPersistedUser() {
        guard
            let data = UserDefaults.standard.data(forKey: userKey),
            let user = try? JSONDecoder().decode(AppUser.self, from: data)
        else { return }
        currentUser = user
    }

    private func persistUser(_ user: AppUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    // MARK: - Sign in with Apple
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let user = AppUser(
                id: credential.user,
                provider: .apple,
                displayName: [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }.joined(separator: " "),
                email: credential.email
            )
            currentUser = user
            persistUser(user)
            NotificationCenter.default.post(name: .signInCompleted, object: nil)

        case .failure(let error):
            print("Apple sign-in failed:", error)
            authError = .unknown
        }
    }

    // MARK: - Sign in with Google (identity only)
    func handleGoogleSignIn(user: GIDGoogleUser) {
        let appUser = AppUser(
            id: user.userID ?? UUID().uuidString,
            provider: .google,
            displayName: user.profile?.name,
            email: user.profile?.email
        )
        currentUser = appUser
        persistUser(appUser)
        // Google sign-in also means YouTube is connected
        setYouTubeConnected(true)
        NotificationCenter.default.post(name: .signInCompleted, object: nil)
        NotificationCenter.default.post(name: .signInGoogleCompleted, object: nil)
    }

    // MARK: - Successful sign-in (called from OnboardingView)
    func handleSuccessfulSignIn(user: GIDGoogleUser) {
        handleGoogleSignIn(user: user)
    }

    // MARK: - YouTube connection (separate from identity)
    func setYouTubeConnected(_ connected: Bool) {
        isYouTubeConnected = connected
        UserDefaults.standard.set(connected, forKey: ytConnectedKey)
    }

    // MARK: - Get valid token (YouTube API calls)
    func getValidToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.notSignedIn
        }
        do {
            try await user.refreshTokensIfNeeded()
        } catch {
            throw AuthError.tokenExpired
        }
        guard let token = user.accessToken.tokenString as String? else {
            throw AuthError.tokenExpired
        }
        return token
    }

    // MARK: - Set auth error (call this from anywhere)
    func setAuthError(_ error: AuthError) {
        authError = error
    }

    // MARK: - Sign out
    func signOut() {
        currentUser = nil
        isYouTubeConnected = false
        authError = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: ytConnectedKey)
        GIDSignIn.sharedInstance.signOut()
        NotificationCenter.default.post(name: .userSignedOut, object: nil)
    }

    // MARK: - Delete account
    func deleteAccount() async {
        isLoading = true
        if GIDSignIn.sharedInstance.currentUser != nil {
            try? await GIDSignIn.sharedInstance.disconnect()
        }
        signOut()
        isLoading = false
    }
}

// MARK: - Notification names
extension Notification.Name {
    static let signInCompleted       = Notification.Name("signInCompleted")
    static let signInGoogleCompleted = Notification.Name("signInGoogleCompleted")
    static let youtubeAccessRevoked  = Notification.Name("youtubeAccessRevoked")
    static let userSignedOut         = Notification.Name("userSignedOut")
}
