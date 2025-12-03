// AuthManager.swift
import Foundation
import Combine
import GoogleSignIn

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isSignedIn: Bool = false
    @Published var accessToken: String? = nil
    
    private init() {
        // Restore previous sign-in state on app launch
        restorePreviousSignInIfAvailable()
    }
    
    private func restorePreviousSignInIfAvailable() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            if let user = user, error == nil {
                Task { @MainActor in
                    self?.accessToken = user.accessToken.tokenString
                    self?.isSignedIn = true
                }
            }
        }
    }
    
    func signIn(accessToken: String) {
        self.accessToken = accessToken
        self.isSignedIn = true
    }
    
    // FULL SIGN OUT — clears Google session + your state
    func signOut() {
        GIDSignIn.sharedInstance.signOut()   // This clears Google session
        accessToken = nil
        isSignedIn = false
        print("Signed out completely")
    }
    
    func getValidToken() async throws -> String {
        guard let token = accessToken else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        return token
    }
}
