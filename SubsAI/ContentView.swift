// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthManager.shared
    
    var body: some View {
        Group {
            if auth.isSignedIn {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .youtubeAccessRevoked)) { _ in
            auth.isSignedIn = false
        }
    }
}
