// Features/Onboarding/OnboardingViewModel.swift
import Foundation
import GoogleSignIn

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                throw NSError(domain: "Onboarding", code: 1)
            }

            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootVC,
                hint: nil,  // ← this was missing
                additionalScopes: ["https://www.googleapis.com/auth/youtube.readonly"]
            )

            let accessToken = result.user.accessToken.tokenString
            AuthManager.shared.signIn(accessToken: accessToken)

        } catch {
            errorMessage = error.localizedDescription
            print("Sign-in error:", error)
        }

        isLoading = false
    }
}
