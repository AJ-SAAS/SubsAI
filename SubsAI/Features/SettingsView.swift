// SettingsView.swift
// New look: gradient header (same as Home), premium card on the header edge,
// grouped white cards with simple rows. Uses HomeLook + GradientHeader from DashboardView.swift.

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
    @State private var channel: Channel?
    @State private var scrollY: CGFloat = 0

    private let groupedBackground = Color(red: 0.961, green: 0.961, blue: 0.969) // #F5F5F7
    private let danger = Color(red: 0.85, green: 0.20, blue: 0.18)

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let topInset = geo.safeAreaInsets.top

                ZStack(alignment: .top) {
                    groupedBackground

                    ScrollView(showsIndicators: false) {
                        ZStack(alignment: .top) {
                            GradientHeader()
                                .frame(height: topInset + 200)

                            VStack(spacing: 0) {
                                GeometryReader { g in
                                    Color.clear.preference(
                                        key: SettingsScrollKey.self,
                                        value: g.frame(in: .named("settingsScroll")).minY
                                    )
                                }
                                .frame(height: 0)

                                header
                                    .padding(.top, topInset + 10)
                                    .padding(.horizontal, 24)

                                premiumCard
                                    .padding(.top, 26)
                                    .padding(.horizontal, 16)

                                VStack(alignment: .leading, spacing: 22) {
                                    channelGroup
                                    subscriptionGroup
                                    supportGroup
                                    legalGroup
                                    accountGroup
                                    footer
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 22)

                                Spacer(minLength: 120)
                            }
                        }
                    }
                    .coordinateSpace(name: "settingsScroll")
                    .onPreferenceChange(SettingsScrollKey.self) { scrollY = $0 }

                    // Keeps the status bar readable once the header scrolls away
                    HomeLook.ink
                        .frame(height: topInset)
                        .frame(maxWidth: .infinity)
                        .opacity(scrollY < -120 ? 1 : 0)
                        .animation(.easeOut(duration: 0.2), value: scrollY < -120)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .alert("Disconnect YouTube?", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    Task { await disconnectYouTube() }
                }
            } message: {
                Text("SubsAI will stop reading your channel. You can connect again anytime.")
            }
            .alert("Connect your real channel?", isPresented: $showDemoToRealAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Continue") {
                    exitDemoAndGoToSignIn()
                }
            } message: {
                Text("We'll close the demo and take you to sign in, so you can connect your own channel.")
            }
            .alert("Delete your account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    resetChannelSession()
                    Task { await AuthManager.shared.deleteAccount() }
                }
            } message: {
                Text("This deletes your SubsAI account and all your data. You can't undo this.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallContainer()
            }
            .task {
                purchaseVM.checkSubscriptionStatus()
                await loadChannel()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 22) {
            Text("Settings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)

            HStack(spacing: 14) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 6) {
                        Image(systemName: headerIcon)
                            .font(.system(size: 13))
                        Text(headerSubtitle)
                            .font(.system(size: 14))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(.white.opacity(0.72))
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var avatar: some View {
        Group {
            if let urlString = channel?.profilePicURL,
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    HomeLook.purple.opacity(0.5)
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [HomeLook.purple, HomeLook.purpleLight],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Text(initials)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 3))
    }

    // MARK: - Premium card

    private var premiumCard: some View {
        let isPremium = purchaseVM.isPremium

        return Button {
            if !isPremium { showPaywall = true }
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HomeLook.purple)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: isPremium ? "checkmark.seal.fill" : "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("SubsAI Premium")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(isPremium ? "You have full access. Thanks!" : "Get your full growth plan.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.78))
                    if !isPremium {
                        Text("Weekly plan · Video ideas · Coach")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                Spacer(minLength: 0)

                if !isPremium {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: HomeLook.ink, location: 0),
                            .init(color: HomeLook.ink, location: 0.55),
                            .init(color: Color(red: 0.165, green: 0.078, blue: 0.439), location: 1) // #2A1470
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(isPremium)
    }

    // MARK: - Groups

    private var channelGroup: some View {
        SettingsGroup(title: "YouTube") {
            if auth.isDemoMode {
                SettingsRow(icon: "play.rectangle", title: "YouTube channel", value: "Demo", showsChevron: false)
                RowDivider()
                SettingsRow(icon: "link", title: "Connect my real channel", tint: HomeLook.purple) {
                    showDemoToRealAlert = true
                }
            } else {
                SettingsRow(
                    icon: "play.rectangle",
                    title: "YouTube channel",
                    value: auth.isYouTubeConnected ? "Connected" : "Not connected",
                    valueColor: auth.isYouTubeConnected ? HomeLook.purple : HomeLook.orangeText,
                    showsChevron: false
                )
                if auth.isYouTubeConnected {
                    RowDivider()
                    SettingsRow(icon: "minus.circle", title: "Disconnect YouTube") {
                        showDisconnectAlert = true
                    }
                }
            }
        }
    }

    private var subscriptionGroup: some View {
        SettingsGroup(title: "Subscription") {
            SettingsRow(icon: "arrow.clockwise", title: "Restore purchases", isLoading: isRestoring) {
                Task { await restorePurchases() }
            }
            .disabled(isRestoring)
            RowDivider()
            SettingsRow(icon: "creditcard", title: "Manage subscription") {
                openURL("https://apps.apple.com/account/subscriptions")
            }
        }
    }

    private var supportGroup: some View {
        SettingsGroup(title: "Help") {
            SettingsRow(icon: "envelope", title: "Contact us") {
                openURL("mailto:support@trysubsai.com")
            }
            RowDivider()
            SettingsRow(icon: "bubble.left", title: "Share feedback") {
                sendFeedback()
            }
            RowDivider()
            SettingsRow(icon: "star", title: "Rate SubsAI") {
                openURL("https://apps.apple.com/app/id6760927904?action=write-review")
            }
        }
    }

    private var legalGroup: some View {
        SettingsGroup(title: "Legal") {
            SettingsRow(icon: "doc.text", title: "Terms of use") {
                openURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
            }
            RowDivider()
            SettingsRow(icon: "lock.shield", title: "Privacy policy") {
                openURL("https://www.trysubsai.com/r/privacy")
            }
            RowDivider()
            SettingsRow(icon: "globe", title: "Website") {
                openURL("https://www.trysubsai.com")
            }
        }
    }

    private var accountGroup: some View {
        SettingsGroup(title: "Account") {
            SettingsRow(icon: providerIcon, title: providerLabel, showsChevron: false)
            RowDivider()
            SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign out", showsChevron: false) {
                resetChannelSession()
                AuthManager.shared.signOut()
            }
            RowDivider()
            SettingsRow(icon: "trash", title: "Delete account", tint: danger, showsChevron: false) {
                showDeleteAlert = true
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(HomeLook.ink)
            }
            Text("Deleting your account removes all your data from SubsAI.")
                .font(.system(size: 12))
                .foregroundColor(HomeLook.secondary)
                .multilineTextAlignment(.center)
            Text(appVersion)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    // MARK: - Header text

    private var displayName: String {
        if let name = channel?.name, !name.isEmpty { return name }
        if auth.isDemoMode { return "Demo channel" }
        return auth.currentUser?.displayName ?? "Your account"
    }

    private var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "S" : letters.uppercased()
    }

    private var headerIcon: String {
        channel != nil ? "play.rectangle" : providerIcon
    }

    private var headerSubtitle: String {
        if auth.isDemoMode { return "Demo account" }
        if let channel, auth.isYouTubeConnected {
            if channel.subscribersHidden == true { return "Channel connected" }
            return "\(channel.subscribers.formatted()) subscribers · Connected"
        }
        return providerLabel
    }

    private var providerIcon: String {
        auth.isDemoMode ? "sparkles" :
        (auth.currentUser?.provider == .apple ? "apple.logo" : "person.crop.circle")
    }

    private var providerLabel: String {
        auth.isDemoMode ? "Demo account" :
        (auth.currentUser?.provider == .apple ? "Signed in with Apple" : "Signed in with Google")
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return version.isEmpty ? "SubsAI" : "SubsAI \(version)"
    }

    // MARK: - Actions

    private func loadChannel() async {
        if let cached = YouTubeService.shared.lastChannel {
            channel = cached
            return
        }
        guard auth.isYouTubeConnected else { return }
        channel = await YouTubeService.shared.fetchChannel(timeout: 5)
    }

    private func disconnectYouTube() async {
        statusMessage = "Disconnecting…"
        try? await GIDSignIn.sharedInstance.disconnect()
        resetChannelSession()
        channel = nil
        AuthManager.shared.setYouTubeConnected(false)
        statusMessage = "YouTube disconnected"
        NotificationCenter.default.post(name: .youtubeAccessRevoked, object: nil)
    }

    private func exitDemoAndGoToSignIn() {
        resetChannelSession()
        AuthManager.shared.exitDemoMode()
    }

    /// Forgets the old channel, so the next channel never sees the old name
    /// or sub count, and gets the "Building your growth plan" screen again.
    private func resetChannelSession() {
        YouTubeService.shared.clearCache()
        AnalysisLoadingView.resetIntro()
    }

    private func sendFeedback() {
        openURL("mailto:support@trysubsai.com?subject=Feedback%20on%20SubsAI%20App")
    }

    private func restorePurchases() async {
        isRestoring = true
        await purchaseVM.restorePurchases()
        isRestoring = false
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Group (white rounded card with a small title above)

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.1)
                .foregroundColor(HomeLook.secondary)
                .padding(.leading, 16)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Row

private struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var valueColor: Color = HomeLook.secondary
    var tint: Color = HomeLook.ink
    var showsChevron: Bool = true
    var isLoading: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) { rowContent }
                .buttonStyle(RowPressStyle())
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(tint)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(tint)

            Spacer(minLength: 8)

            if isLoading {
                ProgressView().scaleEffect(0.8)
            } else if let value {
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(valueColor)
            }

            if showsChevron && action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(white: 0.72))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(HomeLook.hairline)
            .frame(height: 1)
            .padding(.leading, 54)
    }
}

private struct RowPressStyle: ButtonStyle {
    // Full name needed: RevenueCat also has a type called "Configuration"
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .background(configuration.isPressed ? HomeLook.fill : Color.clear)
    }
}

private struct SettingsScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
