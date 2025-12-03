// Features/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // FULL QUALITY BANNER (2560×1440)
                    if let bannerURL = vm.channelInfo?.bannerURL,
                       let url = URL(string: bannerURL + "=w2560-h1440-c-k-c0x00ffffff-no-rj") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure(_):
                                fallbackBanner
                            case .empty:
                                fallbackBanner
                            @unknown default:
                                fallbackBanner
                            }
                        }
                        .frame(height: 220)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    } else {
                        fallbackBanner
                    }

                    // PROFILE + STATS
                    VStack(spacing: 20) {
                        if vm.isLoading {
                            ProgressView("Loading your channel…").padding()
                        } else if let channel = vm.channelInfo {
                            ZStack(alignment: .bottomLeading) {
                                Color.clear.frame(height: 70)

                                AsyncImage(url: URL(string: channel.thumbnailURL)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { Circle().fill(.gray) }
                                .frame(width: 130, height: 130)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 5))
                                .offset(y: -65)
                                .padding(.leading, 20)
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

                            VStack(spacing: 18) {
                                StatCard(title: "Subscribers", value: channel.subscribers.formatted(), iconName: "person.3.fill", color: .blue)
                                StatCard(title: "Total Views", value: channel.totalViews.formatted(), iconName: "eye.fill", color: .green)
                                StatCard(title: "Videos", value: channel.totalVideos.formatted(), iconName: "play.rectangle.fill", color: .orange)
                                StatCard(
                                    title: "Watch Hours",
                                    value: channel.totalWatchTime > 0
                                        ? String(format: "%.0f", channel.totalWatchTime)
                                        : "Loading…",
                                    iconName: "clock.fill",
                                    color: .purple
                                )
                            }
                            .padding(.top, 10)
                        } else {
                            Text(vm.errorMessage ?? "Sign in to see your stats")
                                .foregroundColor(.secondary)
                                .padding()
                        }

                        Button("Refresh") {
                            vm.loadChannelStats()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 30)
                    }
                    .padding()
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .task { vm.loadChannelStats() }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var fallbackBanner: some View {
        Rectangle()
            .fill(LinearGradient(gradient: Gradient(colors: [.gray, .black]), startPoint: .top, endPoint: .bottom))
            .frame(height: 220)
            .overlay(
                Text("Your Channel Banner")
                    .font(.title2.bold())
                    .foregroundColor(.white.opacity(0.7))
            )
    }
}

extension Int {
    func formatted() -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
