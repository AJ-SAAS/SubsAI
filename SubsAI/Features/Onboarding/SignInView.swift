import SwiftUI
import GoogleSignIn
import AuthenticationServices

struct SignInView: View {

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // Logo / Wordmark
                VStack(spacing: 16) {
                    Image("AppIconImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: AppTheme.accent.opacity(0.3), radius: 20, x: 0, y: 8)

                    Text("SubsAI")
                        .font(.system(size: 34, weight: .medium, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Know what to fix before your next upload.")
                        .font(.system(size: 15.5))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 60)

                // Sign in buttons
                VStack(spacing: 14) {

                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        AuthManager.shared.handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .cornerRadius(16)

                    // Sign in with Google
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.borderSubtle, lineWidth: 0.8)
                        )
                    }
                    .disabled(isLoading)

                    // Demo Account Button
                    Button {
                        continueWithDemoAccount()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.accent)
                            Text("Continue with Demo Account")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.borderSubtle, lineWidth: 0.8)
                        )
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 32)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                }

                Spacer()

                // Legal footer
                VStack(spacing: 4) {
                    Text("By continuing you agree to our")
                        .font(.system(size: 11.5))
                        .foregroundColor(AppTheme.textTertiary)

                    HStack(spacing: 4) {
                        Link("Privacy Policy", destination: URL(string: "https://www.trysubsai.com/r/privacy")!)
                        Text("and")
                            .foregroundColor(AppTheme.textTertiary)
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }
                    .font(.system(size: 11.5))
                    .foregroundColor(AppTheme.accent)
                }
                .padding(.bottom, 48)
            }
        }
    }

    private func signInWithGoogle() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        isLoading = true
        errorMessage = nil

        GIDSignIn.sharedInstance.signIn(
            withPresenting: root,
            hint: nil,
            additionalScopes: [
                "https://www.googleapis.com/auth/youtube.readonly",
                "https://www.googleapis.com/auth/yt-analytics.readonly"
            ]
        ) { result, error in
            isLoading = false
            if let error {
                errorMessage = error.localizedDescription
                return
            }
            guard let user = result?.user else { return }
            Task { @MainActor in
                AuthManager.shared.handleGoogleSignIn(user: user)
            }
        }
    }

    private func continueWithDemoAccount() {
        AuthManager.shared.enterDemoMode()
    }
}
