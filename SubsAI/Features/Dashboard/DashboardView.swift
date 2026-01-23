import SwiftUI

struct DashboardView: View {
    @StateObject private var vm = HomeViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // HERO BANNER
                        ZStack(alignment: .bottom) {
                            bannerImage
                                .frame(height: 260)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .offset(y: -60) // crop to center strip
                            
                            if let channel = vm.channelInfo {
                                AsyncImage(url: URL(string: channel.thumbnailURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(.gray.opacity(0.3))
                                        .overlay(ProgressView().tint(.white))
                                }
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemBackground), lineWidth: 5)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                                .offset(y: 55)
                            }
                        }
                        .frame(height: 260)
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                        
                        // MAIN CONTENT
                        VStack(spacing: 24) {
                            if let channel = vm.channelInfo {
                                channelInfoSection(channel)
                                timePeriodSelector
                                statsGrid(channel)
                                
                                if let error = vm.errorMessage {
                                    errorBanner(error)
                                }
                                
                                lastUpdatedText
                            } else if vm.isLoading {
                                loadingState
                            }
                        }
                        .padding(.top, 60) // overlap profile pic
                        .padding(.bottom, 40)
                        .padding(.horizontal, 20)
                    }
                }
                .edgesIgnoringSafeArea(.top)
                .refreshable {
                    await vm.loadChannelStats()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await vm.loadChannelStats()
            }
        }
    }
    
    // MARK: - Banner Image
    private var bannerImage: some View {
        Group {
            if let bannerURL = vm.channelInfo?.bannerURL,
               let url = URL(string: bannerURL + "=w2560-h1440-c-k-c0x00ffffff-no-rj") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackBanner
                    }
                }
            } else {
                fallbackBanner
            }
        }
        .overlay(bannerGradient)
    }
    
    private var bannerGradient: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.35), .black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var fallbackBanner: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.3, blue: 0.5),
                        Color(red: 0.1, green: 0.1, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    // MARK: - Channel Info Section
    private func channelInfoSection(_ channel: ChannelInfo) -> some View {
        VStack(spacing: 8) {
            Text(channel.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            
            VStack(spacing: 4) {
                Text("\(channel.subscribers.formatted()) subscribers")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                if let growth = channel.subscriberGrowth {
                    HStack(spacing: 6) {
                        Image(systemName: growth.trend == .up ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .foregroundColor(growth.trend == .up ? .green : .red)
                        
                        Text("\(growth.formattedAbsolute) \(vm.selectedPeriod.label)")
                            .font(.caption)
                        
                        Text("(\(growth.formattedPercentage))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var timePeriodSelector: some View {
        HStack(spacing: 12) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.selectedPeriod = period
                    }
                    Task { await vm.loadChannelStats() }
                } label: {
                    Text(period.rawValue)
                        .font(.subheadline.weight(vm.selectedPeriod == period ? .semibold : .regular))
                        .foregroundColor(vm.selectedPeriod == period ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            vm.selectedPeriod == period
                            ? Color.blue
                            : Color(.secondarySystemBackground)
                        )
                        .cornerRadius(20)
                }
                .disabled(vm.isLoading)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func statsGrid(_ channel: ChannelInfo) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    title: "Subscribers",
                    value: channel.subscribers.formatted(),
                    iconName: "person.3.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Views",
                    value: channel.totalViews.formatted(),
                    iconName: "eye.fill",
                    color: .green
                )
            }
            .padding(.horizontal, 16)
            
            HStack(spacing: 12) {
                StatCard(
                    title: "Videos",
                    value: channel.totalVideos.formatted(),
                    iconName: "play.rectangle.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Watch Hours",
                    value: channel.totalWatchTime > 0
                        ? String(format: "%.0f hrs", channel.totalWatchTime)
                        : "—",
                    iconName: "clock.fill",
                    color: .purple
                )
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.2)
            Text("Loading your channel stats…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(error).font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var lastUpdatedText: some View {
        Group {
            if let lastUpdated = vm.lastUpdated {
                Text("Updated \(timeAgoString(from: lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
