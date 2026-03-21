// SubsAIApp.swift
import SwiftUI
import GoogleSignIn

@main
struct SubsAIApp: App {

    @ObservedObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !auth.isSignedIn {
                    // Not signed in at all
                    SignInView()
                } else if !auth.isYouTubeConnected {
                    // Signed in but YouTube not connected (Apple sign-in users)
                    ConnectYouTubeView()
                } else {
                    // Fully set up
                    MainTabView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: auth.isSignedIn)
            .animation(.easeInOut(duration: 0.3), value: auth.isYouTubeConnected)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .userSignedOut)) { _ in
                // State change handled by @Published properties
            }
        }
    }
}
