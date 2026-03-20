// Features/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @StateObject private var vm = HomeViewModel()
    @State private var authErrorMessage: String?
    @State private var showGoalSheet = false
    @State private var customGoals: [(GoalType, Int)] = []

    private let subsMilestones = [
        1_000, 5_000, 10_000, 25_000, 50_000,
        100_000, 500_000, 1_000_000
    ]
    private let watchHourTarget = 4_000.0

    private var nextSubsMilestone: Int {
        let subs = vm.channelInfo?.subscribers ?? 0
        return subsMilestones.first { $0 > subs } ?? 1_000_000
    }

    private var completedSubsMilestones: [Int] {
        let subs = vm.channelInfo?.subscribers ?? 0
        return subsMilestones.filter { $0 <= subs }
    }

    private var weeklyGrowth: Int {
        vm.subscriberGrowth?.absolute ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        if let channel = vm.channelInfo {
                            channelHeader(channel)
                        }

                        periodSelector

                        if let channel = vm.channelInfo {
                            statsGrid(channel)
                            aiInsightStrip(channel)
                        }

                        latestVideoSection()

                        if let channel = vm.channelInfo {
                            milestonesSection(channel)
                        }

                        if vm.isLoading && vm.channelInfo == nil {
                            loadingState
                        }

                        if let error = vm.errorMessage {
                            errorBanner(error)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                }
                .refreshable { await vm.loadChannelStats() }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showGoalSheet) {
            GoalPickerSheet(isPresented: $showGoalSheet) { type, target in
                customGoals.append((type, target))
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            Task { await vm.loadChannelStats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .signInGoogleCompleted)) { _ in
            Task { await vm.loadChannelStats() }
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { authErrorMessage != nil },
            set: { _ in authErrorMessage = nil }
        )) {
            Button("OK") { }
        } message: {
            Text(authErrorMessage ?? "Unknown error")
        }
    }

    // MARK: - Channel header
    private func channelHeader(_ channel: Channel) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: channel.profilePicURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color(.systemFill))
                    .overlay(ProgressView())
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(AppTheme.accent.opacity(0.5), lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("\(channel.subscribers.formatted()) subscribers")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                if let growth = vm.subscriberGrowth, growth.absolute > 0 {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppTheme.success)
                            .frame(width: 5, height: 5)
                        Text("+\(growth.absolute.formatted()) \(vm.selectedPeriod.label)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.success)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.success.opacity(0.1))
                    .cornerRadius(20)
                }
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Period selector
    private var periodSelector: some View {
        HStack(spacing: 6) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.changePeriod(to: period)
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.system(
                            size: 13,
                            weight: vm.selectedPeriod == period ? .semibold : .regular
                        ))
                        .foregroundColor(
                            vm.selectedPeriod == period
                                ? .white
                                : AppTheme.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            vm.selectedPeriod == period
                                ? AppTheme.accent
                                : Color(.systemFill)
                        )
                        .cornerRadius(20)
                }
                .disabled(vm.isLoading)
            }
        }
    }

    // MARK: - Stats grid
    private func statsGrid(_ channel: Channel) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            StatCard(
                title: "Views",
                value: channel.totalViews.formatted(),
                delta: vm.viewGrowth.map {
                    "+\($0.absolute.formatted()) \(vm.selectedPeriod.label)"
                },
                iconName: "eye.fill",
                color: AppTheme.accent
            )

            StatCard(
                title: "Watch time",
                value: channel.watchTime > 0
                    ? String(format: "%.0fh", channel.watchTime)
                    : "—",
                delta: vm.watchTimeGrowth.map { growth in
                    growth.absolute > 0
                        ? "+\(growth.absolute)h \(vm.selectedPeriod.label)"
                        : "No data this period"
                },
                iconName: "clock.fill",
                color: .cyan
            )

            // ✅ No fake delta — shows total video count only
            StatCard(
                title: "Videos",
                value: channel.videoCount.formatted(),
                delta: nil,
                iconName: "play.rectangle.fill",
                color: .orange
            )

            StatCard(
                title: "Subscribers",
                value: channel.subscribers.formatted(),
                delta: vm.subscriberGrowth.map { growth in
                    let prefix = growth.absolute >= 0 ? "+" : ""
                    return "\(prefix)\(growth.absolute.formatted()) \(vm.selectedPeriod.label)"
                },
                iconName: "person.2.fill",
                color: AppTheme.success
            )
        }
    }

    // MARK: - AI insight strip
    private func aiInsightStrip(_ channel: Channel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                Text("Channel focus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                    .kerning(0.5)
                    .textCase(.uppercase)
            }

            Text(aiInsightText(channel))
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.07))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func aiInsightText(_ channel: Channel) -> String {
        if let growth = vm.subscriberGrowth, growth.absolute > 0 {
            return "You gained \(growth.absolute.formatted()) subscribers \(vm.selectedPeriod.label). Keep your upload pace consistent to maintain this momentum."
        }
        if let growth = vm.viewGrowth, growth.absolute > 0 {
            return "Your videos got \(growth.absolute.formatted()) views \(vm.selectedPeriod.label). Focus on improving CTR on your next upload to accelerate growth."
        }
        if channel.totalViews > 0 {
            return "Your channel has \(channel.totalViews.formatted()) total views. Improving your thumbnail and title CTR is the fastest way to grow right now."
        }
        return "Welcome back. Check your latest video performance below."
    }

    // MARK: - Latest video section
    private func latestVideoSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Latest video")

            if let video = vm.latestVideo {
                NavigationLink {
                    VideoDeepAnalysisView(video: video, allVideos: [video])
                } label: {
                    LatestVideoPulseCard(video: video)
                }
                .buttonStyle(.plain)

            } else if vm.isLoadingLatestVideo {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.cardBackground)
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Loading latest video…")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
                    )

            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.cardBackground)
                    .frame(height: 80)
                    .overlay(
                        Text("No videos found on this channel")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textTertiary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - Milestones section
    private func milestonesSection(_ channel: Channel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Milestones")

            MilestoneCard(
                current: channel.subscribers,
                target: nextSubsMilestone,
                label: "\(nextSubsMilestone.formatted()) subscribers",
                weeklyGrowth: weeklyGrowth
            )

            HStack(spacing: 10) {
                MiniMilestoneCard(
                    label: "Watch hours",
                    current: channel.watchTime,
                    target: watchHourTarget,
                    unit: "h",
                    color: AppTheme.accent
                )
                MiniMilestoneCard(
                    label: "50K subs",
                    current: Double(channel.subscribers),
                    target: 50_000,
                    unit: "",
                    color: AppTheme.accent
                )
            }

            ForEach(Array(customGoals.enumerated()), id: \.offset) { _, goal in
                let (type, target) = goal
                MiniMilestoneCard(
                    label: type.rawValue,
                    current: currentValue(for: type, channel: channel),
                    target: Double(target),
                    unit: type.unit,
                    color: type.color
                )
            }

            if !completedSubsMilestones.isEmpty {
                VStack(spacing: 8) {
                    ForEach(completedSubsMilestones.suffix(2), id: \.self) { milestone in
                        CompletedMilestoneRow(
                            title: "\(milestone.formatted()) subscribers reached",
                            subtitle: "Completed"
                        )
                    }
                }
            }

            Button {
                showGoalSheet = true
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.textTertiary, lineWidth: 1)
                            .frame(width: 20, height: 20)
                        Text("+")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    Text("Add a custom goal")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            AppTheme.borderSubtle,
                            style: StrokeStyle(lineWidth: 0.5, dash: [5, 4])
                        )
                )
            }
        }
    }

    private func currentValue(for type: GoalType, channel: Channel) -> Double {
        switch type {
        case .subscribers: return Double(channel.subscribers)
        case .watchHours:  return channel.watchTime
        case .views:       return Double(channel.totalViews)
        case .videos:      return Double(channel.videoCount)
        }
    }

    // MARK: - Loading / error
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your channel…")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            Text(error)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .kerning(1.0)
    }
}
