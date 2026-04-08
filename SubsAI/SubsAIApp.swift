import SwiftUI
import GoogleSignIn
import FirebaseCore     // ← Added for App Check

@main
struct SubsAIApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var auth = AuthManager.shared
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showingSplash = true
    @State private var showingAnalysis = false

    init() {
        FirebaseApp.configure()   // ← Added (required for App Check)
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
                        }
                    }
                } else {
                    MainTabView()
                }
            }
            .animation(.easeInOut(duration: 0.35), value: showingSplash)
            .animation(.easeInOut(duration: 0.35), value: hasSeenWelcome)
            .animation(.easeInOut(duration: 0.35), value: auth.isSignedIn)
            .animation(.easeInOut(duration: 0.35), value: auth.isYouTubeConnected)
            .animation(.easeInOut(duration: 0.35), value: showingAnalysis)
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
            }
        }
    }
}
