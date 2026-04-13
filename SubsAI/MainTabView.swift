import SwiftUI

struct MainTabView: View {

    @StateObject private var coachVM = CoachViewModel(autoLoad: false)
    @StateObject private var purchaseVM = PurchaseViewModel()

    @ObservedObject private var auth = AuthManager.shared   // ← Added to check demo mode

    @State private var selectedTab = 0
    @State private var showPaywall = false
    @State private var pendingTab: Int? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(coachVM: coachVM)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            // Intelligence Tab
            IntelligenceView(vm: coachVM)
                .tabItem {
                    Label("Intelligence", systemImage: "brain.head.profile")
                }
                .tag(1)
                .disabled(!shouldAllowAccess(to: 1))

            // Coach Tab
            CoachView(vm: coachVM)
                .tabItem {
                    Label("Coach", systemImage: "figure.mind.and.body")
                }
                .tag(2)
                .disabled(!shouldAllowAccess(to: 2))

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(AppTheme.accent)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .onDisappear {
                    purchaseVM.checkSubscriptionStatus()
                    
                    // If user closed with X → go back to Home
                    if !purchaseVM.isPremium {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedTab = 0
                        }
                    }
                    // If subscribed → go to the tab they wanted
                    else if let pending = pendingTab {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedTab = pending
                            pendingTab = nil
                        }
                    }
                }
        }
        // Handle tab selection for paywall
        .onChange(of: selectedTab) { newTab in
            if (newTab == 1 || newTab == 2) && !shouldAllowAccess(to: newTab) {
                pendingTab = newTab
                selectedTab = 0                    // Stay on Home
                showPaywall = true                 // Show paywall
            }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await coachVM.loadVideos()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authRestored)) { _ in
            Task { await coachVM.loadVideos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .signInCompleted)) { _ in
            Task { await coachVM.loadVideos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .signInGoogleCompleted)) { _ in
            Task { await coachVM.loadVideos() }
        }
    }

    // MARK: - Helper to decide if user can access Coach/Intelligence
    private func shouldAllowAccess(to tab: Int) -> Bool {
        // Demo account = full access, no paywall
        if auth.isDemoMode {
            return true
        }
        // Real users need premium for tabs 1 and 2
        return purchaseVM.isPremium
    }
}
