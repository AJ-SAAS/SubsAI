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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                showPaywallAfterOnboarding = true
                            }
                        }
                    }
                }
                // ✅ FIXED PAYWALL SECTION
                else if showPaywallAfterOnboarding && !purchaseVM.isPremium {
                    PaywallView()
                        .onDisappear {
                            // Refresh premium status when paywall closes (buy or dismiss)
                            purchaseVM.checkSubscriptionStatus()
                            showPaywallAfterOnboarding = false
                        }
                }
                else {
                    MainTabView()
                }
            }
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
            }
        }
    }
}
