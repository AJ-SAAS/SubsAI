import SwiftUI
import GoogleSignIn

struct ConnectYouTubeView: View {

    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // Header / Illustration
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 92, height: 92)
                        
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 42))
                            .foregroundColor(.red)
                    }

                    VStack(spacing: 8) {
                        Text("Connect your YouTube channel")
                            .font(.system(size: 26, weight: .medium, design: .serif))
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("SubsAI needs read-only access to your analytics. We never post, edit, or delete anything on your channel.")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 40)

                // Access Details
                VStack(alignment: .leading, spacing: 12) {
                    accessRow(icon: "eye.fill", color: .green, text: "Read your channel stats and analytics")
                    accessRow(icon: "chart.bar.fill", color: .blue, text: "View video performance data")
                    accessRow(icon: "lock.fill", color: AppTheme.accent, text: "Never post, edit, or delete anything")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

                // Action Buttons
                VStack(spacing: 16) {
                    Button {
                        connectYouTube()
                    } label: {
                        HStack(spacing: 10) {
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 16))
                                Text("Connect YouTube Channel")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.accent)
                        .cornerRadius(16)
                    }
                    .disabled(isConnecting)

                    // Demo Account Button
                    Button {
                        AuthManager.shared.enterDemoMode()
                    } label: {
                        Text("Skip and Use Demo Account")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                    }

                    // Sign Out Button
                    Button {
                        AuthManager.shared.signOut()
                    } label: {
                        Text("Sign out")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                    }
                }
                .padding(.horizontal, 32)

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                }

                // Note
                Text("You can disconnect anytime in Settings.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.top, 12)
                    .padding(.bottom, 40)

                Spacer()
            }
        }
    }

    private func accessRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(text)
                .font(.system(size: 14.5))
                .foregroundColor(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.6)
        )
    }

    private func connectYouTube() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        isConnecting = true
        errorMessage = nil

        GIDSignIn.sharedInstance.signIn(
            withPresenting: root,
            hint: nil,
            additionalScopes: [
                "https://www.googleapis.com/auth/youtube.readonly",
                "https://www.googleapis.com/auth/yt-analytics.readonly"
            ]
        ) { result, error in
            isConnecting = false
            if let error {
                errorMessage = error.localizedDescription
                return
            }
            guard result?.user != nil else { return }
            Task { @MainActor in
                AuthManager.shared.setYouTubeConnected(true)
                NotificationCenter.default.post(name: .signInGoogleCompleted, object: nil)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ConnectYouTubeView()
}
