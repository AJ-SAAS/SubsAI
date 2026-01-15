// Features/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner
                    if let bannerURL = vm.channelInfo?.bannerURL,
                       let url = URL(string: bannerURL + "=w2560-h1440-c-k-c0x00ffffff-no-rj") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .empty, .failure:
                                fallbackBanner
                            @unknown default:
                                fallbackBanner
                            }
                        }
                        .frame(height: 220)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    } else {
                        fallbackBanner
                    }

                    // Profile + Stats
                    VStack(spacing: 24) {
                        if vm.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                Text("Loading your channel stats…")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 60)
                        }

                        if let channel = vm.channelInfo {
                            // Profile picture overlay
                            ZStack(alignment: .bottomLeading) {
                                Color.clear.frame(height: 80)
                                AsyncImage(url: URL(string: channel.thumbnailURL)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(.gray.opacity(0.3))
                                }
                                .frame(width: 140, height: 140)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 6))
                                .offset(y: -70)
                                .padding(.leading, 24)
                            }

                            VStack(spacing: 8) {
                                Text(channel.title)
                                    .font(.title.bold())
                                    .multilineTextAlignment(.center)

                                Text("\(channel.subscribers.formatted()) subscribers")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, -60)

                            VStack(spacing: 16) {
                                StatCard(title: "Subscribers", value: channel.subscribers.formatted(), iconName: "person.3.fill", color: .blue)
                                StatCard(title: "Total Views", value: channel.totalViews.formatted(), iconName: "eye.fill", color: .green)
                                StatCard(title: "Videos", value: channel.totalVideos.formatted(), iconName: "play.rectangle.fill", color: .orange)
                                StatCard(
                                    title: "Watch Hours",
                                    value: channel.totalWatchTime > 0
                                        ? String(format: "%.0f hrs", channel.totalWatchTime)
                                        : "Loading…",
                                    iconName: "clock.fill",
                                    color: .purple
                                )
                            }
                            .padding(.horizontal)

                            if let error = vm.errorMessage {
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }

                        Button("Refresh") {
                            Task { await vm.loadChannelStats() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 20)
                        .disabled(vm.isLoading)
                    }
                    .padding()
                }
            }
            .refreshable {
                await vm.loadChannelStats()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .top)
            .task {
                await vm.loadChannelStats()
            }
        }
    }

    private var fallbackBanner: some View {
        return Rectangle()  // ← Added explicit return here
            .fill(LinearGradient(gradient: Gradient(colors: [.gray, .black]), startPoint: .top, endPoint: .bottom))
            .frame(height: 220)
            .overlay(
                Text("Your Channel Banner")
                    .font(.title2.bold())
                    .foregroundColor(.white.opacity(0.6))
            )
    }
}

// Helper extensions unchanged...
extension Double {
    func formatted(_ style: FloatingPointFormatStyle<Double> = .number) -> String {
        style.format(self)
    }
}

extension Int {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
