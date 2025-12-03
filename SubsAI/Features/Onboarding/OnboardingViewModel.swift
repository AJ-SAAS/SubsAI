// Features/Onboarding/OnboardingViewModel.swift
import Foundation
import GoogleSignIn
import GoogleSignInSwift

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                throw NSError(domain: "Onboarding", code: 1)
            }

            // Step 1: Clean sign-in (no scopes first)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

            // Step 2: Add YouTube scope
            let youtubeResult = try await result.user.addScopes(
                ["https://www.googleapis.com/auth/youtube.readonly"],
                presenting: rootVC
            )

            // Step 3: Add Analytics scope
            _ = try await youtubeResult.user.addScopes(
                ["https://www.googleapis.com/auth/yt-analytics-readonly"],
                presenting: rootVC
            )

            // Final token has both scopes
            let accessToken = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString
            if let token = accessToken {
                AuthManager.shared.signIn(accessToken: token)
            }

        } catch {
            errorMessage = "Sign-in failed: \(error.localizedDescription)"
            print("Google Sign-In Error:", error)
        }

        isLoading = false
    }
}
