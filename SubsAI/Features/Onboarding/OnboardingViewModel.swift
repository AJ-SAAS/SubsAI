import SwiftUI
import GoogleSignIn
import KeychainAccess
import Combine

class OnboardingViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    private let keychain = Keychain(service: "xyz.subsai.SubsAI")
    private let coordinator = GoogleSignInCoordinator()
    private var cancellables = Set<AnyCancellable>()
    
    func signInWithGoogle(completion: ((Result<Void, Error>) -> Void)? = nil) {
        print("OnboardingViewModel: Starting Google Sign-In process")
        
        // Get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootViewController = windowScene.windows
                .first(where: { $0.isKeyWindow })?.rootViewController else {
            
            let error = NSError(domain: "OnboardingViewModel",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No active window or root view controller found"])
            print("OnboardingViewModel: Error - \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            completion?(.failure(error))
            return
        }
        
        print("OnboardingViewModel: Root view controller found: \(rootViewController.description)")
        
        let scopes = [
            "https://www.googleapis.com/auth/youtube.readonly",
            "https://www.googleapis.com/auth/yt-analytics.readonly"
        ]
        print("OnboardingViewModel: Requesting scopes: \(scopes)")
        
        do {
            try coordinator.signIn(presentingViewController: rootViewController, additionalScopes: scopes) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(_, let accessToken):
                    print("OnboardingViewModel: Google Sign-In successful, access token: \(accessToken.prefix(10))...")
                    
                    // Store the access token securely
                    do {
                        try self.keychain.set(accessToken, key: "youtube_access_token")
                        self.isAuthenticated = true
                        completion?(.success(()))
                    } catch {
                        print("OnboardingViewModel: Failed to save access token - \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        completion?(.failure(error))
                    }
                    
                case .failure(let error):
                    print("OnboardingViewModel: Google Sign-In failed - \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        } catch {
            print("OnboardingViewModel: Error initiating Google Sign-In - \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            completion?(.failure(error))
        }
    }
}
