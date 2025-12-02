// Features/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if vm.isLoading {
                        ProgressView("Loading your channel…")
                            .padding()
                    } else if let channel = vm.channelInfo {
                        VStack(spacing: 20) {
                            AsyncImage(url: URL(string: channel.thumbnailURL)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(.gray)
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())

                            Text(channel.title)
                                .font(.title2.bold())

                            VStack(spacing: 16) {
                                StatCard(title: "Subscribers",   value: channel.subscribers.formatted(),   iconName: "person.3.fill", color: .blue)
                                StatCard(title: "Total Views",   value: channel.totalViews.formatted(),    iconName: "eye.fill",      color: .green)
                                StatCard(title: "Videos",        value: channel.totalVideos.formatted(),   iconName: "play.rectangle.fill", color: .orange)
                                StatCard(title: "Watch Hours",   value: "Coming soon",                     iconName: "clock.fill",    color: .purple)
                            }
                        }
                        .padding()
                    } else {
                        Text(vm.errorMessage ?? "Sign in to see your stats")
                            .foregroundColor(.secondary)
                    }

                    Button("Refresh") {
                        vm.loadChannelStats()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .task {
                vm.loadChannelStats()
            }
        }
    }
}

// Nice number formatting
extension Int {
    func formatted() -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
