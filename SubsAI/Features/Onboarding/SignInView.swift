import SwiftUI
import GoogleSignIn
import AuthenticationServices

struct SignInView: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var shimmer = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // MARK: - Header
                VStack(spacing: 16) {

                    // ICON WITH IMPROVED SHIMMER
                    ZStack {
                        Image("AppIconImage")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: AppTheme.accent.opacity(0.25), radius: 20, x: 0, y: 8)
                            .overlay(
                                shimmerOverlay()
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                            )
                    }

                    Text("Ready to unlock faster YouTube growth?")
                        .font(.system(size: 30, weight: .medium))   // Increased by 2px
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Text("Sign in to get personalized insights for your channel.")
                        .font(.system(size: 15.5))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)

                // MARK: - Buttons
                VStack(spacing: 14) {

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        AuthManager.shared.handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .cornerRadius(16)

                    Button {
                        signInWithGoogle()
                    } label: {

                        ZStack {
                            HStack(spacing: 10) {
                                Image("Googleicon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)

                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                            }

                            HStack {
                                Spacer()

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .disabled(isLoading)

                    Text("Recommended for YouTube creators")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))   // Lighter gray - much more readable
                        .padding(.top, -4)
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

                // MARK: - Footer + Demo Link (Moved Lower)
                VStack(spacing: 12) {
                    Button {
                        continueWithDemoAccount()
                    } label: {
                        Text("Try demo account")
                            .font(.system(size: 14.5))
                            .foregroundColor(AppTheme.accent)
                    }

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
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            shimmer = true
        }
    }

    // MARK: - IMPROVED SHIMMER EFFECT
    private func shimmerOverlay() -> some View {
        GeometryReader { geo in
            let width = geo.size.width

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.30),
                    .init(color: Color.white.opacity(0.12), location: 0.45),
                    .init(color: Color.white.opacity(0.45), location: 0.52),   // Stronger peak
                    .init(color: Color.white.opacity(0.12), location: 0.58),
                    .init(color: .clear, location: 0.70),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 1.8)
            .blur(radius: 6)
            .rotationEffect(.degrees(30))
            .offset(x: shimmer ? width * 1.8 : -width * 1.2)
            .animation(
                .easeInOut(duration: 2.8)
                    .delay(0.8)
                    .repeatForever(autoreverses: false),
                value: shimmer
            )
        }
        .blendMode(.screen)
        .opacity(0.75)
    }

    // MARK: - Google Sign In
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

    // MARK: - Demo
    private func continueWithDemoAccount() {
        AuthManager.shared.enterDemoMode()
    }
}
