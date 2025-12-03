// Features/SettingsView.swift
import SwiftUI
import GoogleSignIn

struct SettingsView: View {
    @State private var showingRevokeAlert = false
    @State private var statusMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Connected to YouTube")
                            .font(.headline)
                    }
                }

                Section("Account Actions") {
                    Button(role: .destructive) {
                        showingRevokeAlert = true
                    } label: {
                        Label("Disconnect YouTube Channel", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("Legal") {
                    Link("Privacy Policy", destination: URL(string: "https://subsai.app/privacy")!)
                    Link("Terms of Use", destination: URL(string: "https://subsai.app/terms")!)
                }

                if !statusMessage.isEmpty {
                    Section {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Disconnect YouTube?", isPresented: $showingRevokeAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    Task { await revokeAccess() }
                }
            } message: {
                Text("This will sign you out completely. You can reconnect anytime.")
            }
        }
    }

    @MainActor
    private func revokeAccess() async {
        statusMessage = "Signing out..."

        // Sign out from Google (clears the cached user)
        GIDSignIn.sharedInstance.signOut()

        // Optional: completely revoke access (breaks refresh tokens too)
        do {
            try await GIDSignIn.sharedInstance.disconnect()
            print("Google access revoked completely")
        } catch {
            print("Disconnect failed (this is okay):", error)
        }

        // Clear your app state
        AuthManager.shared.signOut()

        statusMessage = "Signed out successfully"
        
        // Notify rest of app
        NotificationCenter.default.post(name: .youtubeAccessRevoked, object: nil)
    }
}

extension Notification.Name {
    static let youtubeAccessRevoked = Notification.Name("youtubeAccessRevoked")
}
