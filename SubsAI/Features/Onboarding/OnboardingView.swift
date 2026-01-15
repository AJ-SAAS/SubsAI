// Features/Onboarding/OnboardingView.swift
import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 100))
                .foregroundColor(.red)

            Text("SubsAI")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sign in with your YouTube channel to see real-time stats & analytics")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if viewModel.isLoading || isSigningIn {
                ProgressView("Signing in…")
                    .progressViewStyle(.circular)
            } else {
                GoogleSignInButton(scheme: .dark, style: .wide, state: .normal) {
                    Task { await signInWithGoogle() }
                }
                .frame(height: 50)
                .padding(.horizontal, 40)
            }

            if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            Spacer()
        }
        .padding()
    }

    private func signInWithGoogle() async {
        isSigningIn = true
        viewModel.errorMessage = nil

        // Get presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            viewModel.errorMessage = "Unable to present sign-in screen"
            isSigningIn = false
            return
        }

        // Required scopes for YouTube Data API + Analytics API
        let requiredScopes = [
            "https://www.googleapis.com/auth/youtube.readonly",
            "https://www.googleapis.com/auth/yt-analytics.readonly"
        ]

        do {
            let signInResult = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: requiredScopes
            )

            let user = signInResult.user
            let accessToken = user.accessToken.tokenString  // ← This is non-optional String

            // Success
            AuthManager.shared.signIn(accessToken: accessToken)
            print("Signed in successfully! Access token acquired.")

        } catch {
            print("Sign-in failed: \(error.localizedDescription)")
            viewModel.errorMessage = error.localizedDescription
        }

        isSigningIn = false
    }
}
