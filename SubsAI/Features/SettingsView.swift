// Features/SettingsView.swift
import SwiftUI
import GoogleSignIn

struct SettingsView: View {

    @ObservedObject private var auth = AuthManager.shared
    @State private var showDisconnectAlert = false
    @State private var showDeleteAlert = false
    @State private var statusMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                Form {

                    // MARK: - Account
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accent.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: providerIcon)
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.accent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(auth.currentUser?.displayName ?? "Signed in")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(providerLabel)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Account")
                    }

                    // MARK: - YouTube connection
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: auth.isYouTubeConnected
                                  ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(auth.isYouTubeConnected ? .green : .red)
                            Text(auth.isYouTubeConnected
                                 ? "YouTube channel connected"
                                 : "No YouTube channel connected")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        if auth.isYouTubeConnected {
                            Button(role: .destructive) {
                                showDisconnectAlert = true
                            } label: {
                                Label("Disconnect YouTube", systemImage: "link.badge.minus")
                            }
                        }
                    } header: {
                        Text("YouTube")
                    }

                    // MARK: - Legal
                    Section {
                        Link("Privacy Policy",
                             destination: URL(string: "https://www.trysubsai.com/r/privacy")!)
                        Link("Terms of Use",
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Button {
                            if let url = URL(string: "mailto:gridking111@gmail.com") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Contact Support")
                        }
                    } header: {
                        Text("Legal & Support")
                    }

                    // MARK: - Sign out / delete
                    Section {
                        Button(role: .destructive) {
                            AuthManager.shared.signOut()
                        } label: {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        }

                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete account", systemImage: "trash")
                        }
                    } header: {
                        Text("Account actions")
                    } footer: {
                        Text("Deleting your account removes all your data from SubsAI. This cannot be undone.")
                            .font(.system(size: 11))
                    }

                    if !statusMessage.isEmpty {
                        Section {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .alert("Disconnect YouTube?", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    Task { await disconnectYouTube() }
                }
            } message: {
                Text("This will remove YouTube access. You can reconnect anytime.")
            }
            .alert("Delete account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await AuthManager.shared.deleteAccount() }
                }
            } message: {
                Text("This will permanently delete your SubsAI account and all associated data. This cannot be undone.")
            }
        }
    }

    private var providerIcon: String {
        switch auth.currentUser?.provider {
        case .apple:  return "apple.logo"
        case .google: return "globe"
        case nil:     return "person.circle"
        }
    }

    private var providerLabel: String {
        switch auth.currentUser?.provider {
        case .apple:  return "Signed in with Apple"
        case .google: return "Signed in with Google"
        case nil:     return "Signed in"
        }
    }

    private func disconnectYouTube() async {
        statusMessage = "Disconnecting…"
        try? await GIDSignIn.sharedInstance.disconnect()
        AuthManager.shared.setYouTubeConnected(false)
        statusMessage = "YouTube disconnected"
        NotificationCenter.default.post(name: .youtubeAccessRevoked, object: nil)
    }
}
