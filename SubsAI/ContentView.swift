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
        // Alert for authentication errors from AuthManager
        .alert("Authentication Error", isPresented: Binding<Bool>(
            get: { auth.authError != nil },
            set: { _ in auth.authError = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = auth.authError {
                Text(error.localizedDescription)
            } else {
                Text("An unknown error occurred.")
            }
        }
        // Listen for YouTube access revoked notification → sign out
        .onReceive(NotificationCenter.default.publisher(for: .youtubeAccessRevoked)) { _ in
            auth.signOut()
        }
        // Optional: accessibility label for screen readers
        .accessibilityElement(children: .combine)
        .accessibilityLabel(auth.isSignedIn ? "Main app view" : "Onboarding screen")
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
