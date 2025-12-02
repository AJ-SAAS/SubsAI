import Foundation
import Combine

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isSignedIn: Bool = false
    @Published var accessToken: String? = nil
    
    private init() {}
    
    func signIn(accessToken: String) {
        self.accessToken = accessToken
        self.isSignedIn = true
    }
    
    func signOut() {
        self.accessToken = nil
        self.isSignedIn = false
    }
    
    func getValidToken() async throws -> String {
        guard let token = accessToken else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        // Optionally, check with Railway backend if token expired
        return token
    }
}
