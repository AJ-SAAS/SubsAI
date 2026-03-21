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

                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                    }

                    Text("Connect your YouTube channel")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("SubsAI needs read-only access to your YouTube analytics. We never post, delete, or modify anything.")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)

                // What we access
                VStack(alignment: .leading, spacing: 10) {
                    accessRow(
                        icon: "eye.fill",
                        color: .green,
                        text: "Read your channel stats and analytics"
                    )
                    accessRow(
                        icon: "chart.bar.fill",
                        color: .blue,
                        text: "View video performance data"
                    )
                    accessRow(
                        icon: "lock.fill",
                        color: AppTheme.accent,
                        text: "Never post, edit, or delete anything"
                    )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                VStack(spacing: 12) {
                    Button {
                        connectYouTube()
                    } label: {
                        HStack(spacing: 8) {
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 15))
                                Text("Connect with Google")
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.accent)
                        .cornerRadius(14)
                    }
                    .disabled(isConnecting)
                    .padding(.horizontal, 32)

                    Button {
                        AuthManager.shared.signOut()
                    } label: {
                        Text("Sign out")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }

                Spacer()
            }
        }
    }

    private func accessRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
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
