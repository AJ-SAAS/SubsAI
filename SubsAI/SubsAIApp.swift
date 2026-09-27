import SwiftUI
import RevenueCat
import GoogleSignIn

@main
struct SubsAIApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var auth = AuthManager.shared
    @StateObject private var purchaseVM = PurchaseViewModel()

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var showingSplash = true
    @State private var showingAnalysis = false
    @State private var showPaywallAfterOnboarding = false

    init() {
        Purchases.configure(withAPIKey: "appl_hHzGiYMOlFmbZQycQzGXreCikix")
        
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showingSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSplash = false
                        }
                    }
                } else if !hasSeenWelcome {
                    WelcomeView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            hasSeenWelcome = true
                        }
                    }
                } else if !auth.isSignedIn {
                    SignInView()
                } else if !auth.isYouTubeConnected {
                    ConnectYouTubeView()
                } else if showingAnalysis {
                    AnalysisLoadingView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showingAnalysis = false
                            hasCompletedOnboarding = true
                        }
                        // Check the subscription FIRST, so paying users never see the paywall
                        Task {
                            await purchaseVM.checkSubscriptionStatusAsync()
                            guard !purchaseVM.isPremium else { return }
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            showPaywallAfterOnboarding = true
                        }
                    }
                }
                else if showPaywallAfterOnboarding && !purchaseVM.isPremium {
                    MainTabView()
                        .fullScreenCover(isPresented: $showPaywallAfterOnboarding) {
                            PaywallContainer()
                                .presentationBackground(.ultraThinMaterial)
                                .presentationCornerRadius(28)
                                .presentationDragIndicator(.visible)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .onDisappear {
                            purchaseVM.checkSubscriptionStatus()
                        }
                }
                else {
                    MainTabView()
                }
            }
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.35), value: showingSplash)
            .animation(.easeInOut(duration: 0.35), value: hasSeenWelcome)
            .animation(.easeInOut(duration: 0.35), value: auth.isSignedIn)
            .animation(.easeInOut(duration: 0.35), value: auth.isYouTubeConnected)
            .animation(.easeInOut(duration: 0.35), value: showingAnalysis)
            .animation(.easeInOut(duration: 0.35), value: showPaywallAfterOnboarding)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .signInGoogleCompleted)) { _ in
                if !showingAnalysis {
                    withAnimation { showingAnalysis = true }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .userSignedOut)) { _ in
                showingAnalysis = false
                showPaywallAfterOnboarding = false
                hasCompletedOnboarding = false
                // Forget the old channel on ANY sign out, not just from Settings
                YouTubeService.shared.clearCache()
                AnalysisLoadingView.resetIntro()
            }
        }
    }
}
