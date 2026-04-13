// SettingsView.swift — Reorganized with Premium Card + Full Sections

import SwiftUI
import GoogleSignIn
import RevenueCat

struct SettingsView: View {

    @ObservedObject private var auth = AuthManager.shared
    @StateObject private var purchaseVM = PurchaseViewModel()

    @State private var showDisconnectAlert = false
    @State private var showDeleteAlert = false
    @State private var showDemoToRealAlert = false
    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var statusMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Premium Card (Top)
                    premiumStatusCard

                    Form {

                        // MARK: - Account
                        Section {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.accent.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: providerIcon)
                                        .font(.system(size: 18))
                                        .foregroundColor(AppTheme.accent)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(auth.currentUser?.displayName ?? "Signed in")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text(providerLabel)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("Account")
                        }

                        // MARK: - YouTube
                        Section {
                            if auth.isDemoMode {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(AppTheme.accent)
                                        Text("Demo Account")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.textPrimary)
                                    }
                                    Text("You're currently using demo data. Connect your real YouTube channel to see your actual stats and insights.")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Button {
                                    showDemoToRealAlert = true
                                } label: {
                                    Label("Connect My Real YouTube Channel", systemImage: "link")
                                        .foregroundColor(AppTheme.accent)
                                }
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: auth.isYouTubeConnected
                                          ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(auth.isYouTubeConnected ? .green : .red)
                                    Text(auth.isYouTubeConnected
                                         ? "YouTube channel connected"
                                         : "No YouTube channel connected")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textPrimary)
                                }

                                if auth.isYouTubeConnected {
                                    Button(role: .destructive) {
                                        showDisconnectAlert = true
                                    } label: {
                                        Label("Disconnect YouTube", systemImage: "link.badge.minus")
                                    }
                                }
                            }
                        } header: {
                            Text("YouTube")
                        }

                        // MARK: - Premium
                        Section {
                            Button {
                                Task { await restorePurchases() }
                            } label: {
                                HStack {
                                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                                    if isRestoring {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .foregroundStyle(AppTheme.textPrimary)
                            }
                            .disabled(isRestoring)

                            Button {
                                openSubscriptionManagement()
                            } label: {
                                Label("Manage Subscription", systemImage: "gear")
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        } header: {
                            Text("Premium")
                        }

                        // MARK: - Support
                        Section {
                            Link(destination: URL(string: "mailto:support@trysubsai.com")!) {
                                Label("Contact Us", systemImage: "envelope.fill")
                                    .foregroundColor(.blue)
                            }

                            Button {
                                sendFeedback()
                            } label: {
                                Label("Share Your Feedback", systemImage: "message")
                                    .foregroundColor(.blue)
                            }

                            Button {
                                if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Rate Us ⭐️", systemImage: "star.fill")
                                    .foregroundColor(.blue)
                            }
                        } header: {
                            Text("Support")
                        }

                        // MARK: - Legal
                        Section {
                            Link("Terms of Use",
                                 destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .foregroundStyle(AppTheme.textPrimary)

                            Link("Privacy Policy",
                                 destination: URL(string: "https://www.trysubsai.com/r/privacy")!)
                                .foregroundStyle(AppTheme.textPrimary)

                            Link("Visit Website",
                                 destination: URL(string: "https://www.trysubsai.com")!)
                                .foregroundStyle(AppTheme.textPrimary)
                        } header: {
                            Text("Legal")
                        }

                        // MARK: - Account Actions
                        Section {
                            Button(role: .destructive) {
                                AuthManager.shared.signOut()
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }

                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete Account", systemImage: "trash")
                            }
                        } footer: {
                            Text("Deleting your account removes all your data from SubsAI. This cannot be undone.")
                                .font(.system(size: 11))
                        }

                        if !statusMessage.isEmpty {
                            Section {
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Settings")
            .alert("Disconnect YouTube?", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    Task { await disconnectYouTube() }
                }
            } message: {
                Text("This will remove YouTube access. You can reconnect anytime.")
            }
            .alert("Connect Real Channel?", isPresented: $showDemoToRealAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Continue") {
                    exitDemoAndGoToSignIn()
                }
            } message: {
                Text("This will sign you out of demo mode and take you back to sign in so you can connect your real YouTube channel.")
            }
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await AuthManager.shared.deleteAccount() }
                }
            } message: {
                Text("This will permanently delete your SubsAI account and all associated data. This cannot be undone.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                purchaseVM.checkSubscriptionStatus()
            }
        }
    }

    // MARK: - Premium Status Card
    private var premiumStatusCard: some View {
        let isPremium = purchaseVM.isPremium

        return VStack(alignment: .leading, spacing: 10) {
            if isPremium {
                HStack(spacing: 12) {
                    Text("SubsAI Premium")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                Text("Unlocked ✨ All access to deep analytics, channel & video insights, growth tools and more.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Upgrade to SubsAI Premium")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Unlock all access to deep analytics, channel & video insights, growth tools and more.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#7B2FFF"),
                    Color(hex: "#4A00C8")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        .onTapGesture {
            if !isPremium {
                showPaywall = true
            }
        }
    }

    // MARK: - Helpers
    private var providerIcon: String {
        auth.isDemoMode ? "sparkles" :
        (auth.currentUser?.provider == .apple ? "apple.logo" : "globe")
    }

    private var providerLabel: String {
        auth.isDemoMode ? "Demo Account" :
        (auth.currentUser?.provider == .apple ? "Signed in with Apple" : "Signed in with Google")
    }

    private func disconnectYouTube() async {
        statusMessage = "Disconnecting…"
        try? await GIDSignIn.sharedInstance.disconnect()
        AuthManager.shared.setYouTubeConnected(false)
        statusMessage = "YouTube disconnected"
        NotificationCenter.default.post(name: .youtubeAccessRevoked, object: nil)
    }

    private func exitDemoAndGoToSignIn() {
        AuthManager.shared.exitDemoMode()
    }

    private func sendFeedback() {
        let subject = "Feedback%20on%20SubsAI%20App"
        if let url = URL(string: "mailto:support@trysubsai.com?subject=\(subject)") {
            UIApplication.shared.open(url)
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        await purchaseVM.restorePurchases()
        isRestoring = false
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}
