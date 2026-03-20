// Features/Onboarding/OnboardingView.swift
import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct OnboardingView: View {
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // App Logo
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 100))
                .foregroundColor(.red)
                .symbolEffect(.pulse, options: .repeating)

            // App Name
            Text("SubsAI")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Description
            Text("Sign in with your YouTube channel to track real-time stats, get coaching insights, and grow faster.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            // Sign-in area
            if isSigningIn {
                ProgressView("Connecting to YouTube…")
                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                    .scaleEffect(1.2)
            } else {
                GoogleSignInButton(
                    scheme: .dark,
                    style: .wide,
                    state: .normal
                ) {
                    Task { await signInWithGoogle() }
                }
                .frame(height: 52)
                .padding(.horizontal, 40)
                .disabled(isSigningIn)
                .opacity(isSigningIn ? 0.6 : 1.0)
            }

            // Error display
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Google Sign-In Flow
    private func signInWithGoogle() async {
        isSigningIn = true
        errorMessage = nil

        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        else {
            errorMessage = "Cannot present sign-in screen. Please restart the app."
            isSigningIn = false
            return
        }

        let scopes = [
            "https://www.googleapis.com/auth/youtube.readonly",
            "https://www.googleapis.com/auth/yt-analytics.readonly"
        ]

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootVC,
                hint: nil,
                additionalScopes: scopes
            )

            // Success → update shared auth manager
            AuthManager.shared.handleSuccessfulSignIn(user: result.user)
            print("✅ Google Sign-In successful | User: \(result.user.profile?.email ?? "unknown")")

            // Optional haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        } catch let error as GIDSignInError {
            // Modern GIDSignInError handling (GSI 7+)
            switch error.code {
            case .canceled:
                errorMessage = nil  // User canceled → no message
            case .hasNoAuthInKeychain:
                errorMessage = "No previous sign-in found. Please try again."
            default:
                errorMessage = "Sign-in failed: \(error.localizedDescription)"
            }
            print("❌ Google Sign-In error (\(error.code.rawValue)): \(error.localizedDescription)")

        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            print("❌ Unexpected sign-in error: \(error)")
        }

        isSigningIn = false
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
}
