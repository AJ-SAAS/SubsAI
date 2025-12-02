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
                    Section { Text(statusMessage).font(.caption).foregroundColor(.secondary) }
                }
            }
            .navigationTitle("Settings")
            .alert("Disconnect YouTube?", isPresented: $showingRevokeAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    Task { await revokeAccess() }
                }
            } message: {
                Text("You can reconnect anytime.")
            }
        }
    }

    private func revokeAccess() async {
        statusMessage = "Disconnecting..."
        AuthManager.shared.signOut()  // ← This does everything safely
        statusMessage = "Disconnected from YouTube"
        NotificationCenter.default.post(name: .youtubeAccessRevoked, object: nil)
    }
}

extension Notification.Name {
    static let youtubeAccessRevoked = Notification.Name("youtubeAccessRevoked")
}
