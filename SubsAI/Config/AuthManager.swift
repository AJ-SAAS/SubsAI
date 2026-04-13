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
    @Published var isDemoMode: Bool = false   // ← NEW for demo

    private let userKey        = "subsai_user"
    private let ytConnectedKey = "subsai_yt_connected"
    private let demoModeKey    = "subsai_demo_mode"   // ← NEW

    // Serialises token refresh — only one GTMAppAuth call in flight at a time
    private var refreshTask: Task<String, Error>?

    var isSignedIn: Bool { currentUser != nil }

    override init() {
        super.init()
        loadPersistedUser()
        isYouTubeConnected = UserDefaults.standard.bool(forKey: ytConnectedKey)
        isDemoMode = UserDefaults.standard.bool(forKey: demoModeKey)   // ← NEW
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

    // MARK: - NEW: Demo Mode Support
    func enterDemoMode() {
        isDemoMode = true
        UserDefaults.standard.set(true, forKey: demoModeKey)
        setYouTubeConnected(true)
        
        if currentUser == nil {
            currentUser = AppUser(
                id: "demo-user",
                provider: .google,
                displayName: "Demo Creator",
                email: "demo@subsai.app"
            )
            persistUser(currentUser!)
        }
        
        NotificationCenter.default.post(name: .signInGoogleCompleted, object: nil)
    }

    // MARK: - NEW: Exit Demo Mode and return to Sign In
    func exitDemoMode() {
        isDemoMode = false
        UserDefaults.standard.removeObject(forKey: demoModeKey)
        
        // Clear demo user if needed
        if currentUser?.id == "demo-user" {
            currentUser = nil
            UserDefaults.standard.removeObject(forKey: userKey)
        }
        
        // Notify the app to go back to SignInView
        NotificationCenter.default.post(name: .userSignedOut, object: nil)
    }

    // MARK: - Get valid token (serialised — only one refresh in flight at a time)
    func getValidToken() async throws -> String {
        if let existing = refreshTask {
            return try await existing.value
        }

        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.notSignedIn
        }

        let task = Task<String, Error> {
            defer { Task { @MainActor in self.refreshTask = nil } }
            try await user.refreshTokensIfNeeded()
            guard let token = user.accessToken.tokenString as String? else {
                throw AuthError.tokenExpired
            }
            return token
        }

        refreshTask = task

        do {
            return try await task.value
        } catch {
            throw AuthError.tokenExpired
        }
    }

    // MARK: - Set auth error
    func setAuthError(_ error: AuthError) {
        authError = error
    }

    // MARK: - Sign out
    func signOut() {
        currentUser = nil
        isYouTubeConnected = false
        isDemoMode = false                    // ← NEW
        authError = nil
        refreshTask = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: ytConnectedKey)
        UserDefaults.standard.removeObject(forKey: demoModeKey)   // ← NEW
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
    static let authRestored          = Notification.Name("authRestored")
}
