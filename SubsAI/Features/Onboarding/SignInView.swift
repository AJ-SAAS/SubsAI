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

                // Logo / wordmark
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppTheme.accent.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 30))
                            .foregroundColor(AppTheme.accent)
                    }

                    Text("SubsAI")
                        .font(.system(size: 32, weight: .medium, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Know what to fix before your next upload.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.bottom, 56)

                // Sign in buttons
                VStack(spacing: 12) {

                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        AuthManager.shared.handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .cornerRadius(14)

                    // Sign in with Google
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Continue with Google")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
                        )
                    }
                    .disabled(isLoading)

                    // NEW: Demo Account button (safe, uses same style)
                    Button {
                        continueWithDemoAccount()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.accent)
                            Text("Continue with Demo Account")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
                        )
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 32)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }

                Spacer()

                // Legal
                VStack(spacing: 4) {
                    Text("By continuing you agree to our")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textTertiary)
                    HStack(spacing: 4) {
                        Link("Privacy Policy", destination: URL(string: "https://subsai.app/privacy")!)
                        Text("and")
                            .foregroundColor(AppTheme.textTertiary)
                        Link("Terms of Use", destination: URL(string: "https://subsai.app/terms")!)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.accent)
                }
                .padding(.bottom, 40)
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

    // NEW: Demo account entry (very safe)
    private func continueWithDemoAccount() {
        AuthManager.shared.enterDemoMode()
    }
}
