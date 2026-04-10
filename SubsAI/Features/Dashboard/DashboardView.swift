// Features/Dashboard/DashboardView.swift
import SwiftUI
import StoreKit   // ← Added for App Store review request

struct DashboardView: View {
    @StateObject private var vm = HomeViewModel()
    var coachVM: CoachViewModel
    @State private var showGoalSheet = false
    @State private var customGoals: [(GoalType, Int)] = []
    @State private var authErrorMessage: String?

    // MARK: - Review Request
    @Environment(\.requestReview) private var requestReview
    @AppStorage("hasRequestedReviewAfterConnect") private var hasRequestedReviewAfterConnect = false

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
                    VStack(spacing: 24) {

                        // 1 — Channel header
                        if let channel = vm.channelInfo {
                            channelHeader(channel)
                        }

                        // 2 — What's happening right now
                        if let channel = vm.channelInfo {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionLabel("What's happening right now")
                                let focus = channelFocus(channel)
                                if focus.linksToCoach {
                                    NavigationLink {
                                        CoachView(vm: coachVM)
                                    } label: {
                                        focusCard(channel)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    focusCard(channel)
                                }
                            }
                        }

                        // 3 — How is my latest video doing?
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("How is my latest video doing?")
                            latestVideoContent()
                        }

                        // 4 — How has my channel grown?
                        if vm.channelInfo != nil {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionLabel("How has my channel grown?")
                                periodSelector
                                if let channel = vm.channelInfo {
                                    statsGrid(channel)
                                }
                            }
                        }

                        // 5 — Where am I headed?
                        if let channel = vm.channelInfo {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionLabel("Where am I headed?")
                                milestonesSection(channel)
                            }
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
            // Safe — loadChannelStats guards on isYouTubeConnected internally
            Task { await vm.loadChannelStats() }
            
            // NEW: Request App Store review ~60 seconds after landing on dashboard
            // (Only once after first YouTube connection)
            if !hasRequestedReviewAfterConnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                    requestReview()
                    
                    // Mark as shown so it doesn't trigger again
                    hasRequestedReviewAfterConnect = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authRestored)) { _ in
            Task { await vm.loadChannelStats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .signInGoogleCompleted)) { _ in
            Task { await vm.loadChannelStats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .signInCompleted)) { _ in
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

    // MARK: - Focus card
    private func focusCard(_ channel: Channel) -> some View {
        let focus = channelFocus(channel)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(focus.color)
                    .frame(width: 5, height: 5)
                Text("Your focus right now")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(focus.color)
                    .kerning(1.0)
                    .textCase(.uppercase)

                Spacer()

                if focus.linksToCoach {
                    HStack(spacing: 3) {
                        Text("See Coach")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(focus.color)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(focus.color)
                    }
                }
            }

            Text(focus.title)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(focus.body)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(focus.color.opacity(0.06))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(focus.color.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Focus logic
    private struct ChannelFocus {
        let title: String
        let body: String
        let color: Color
        var linksToCoach: Bool = false
    }

    private func channelFocus(_ channel: Channel) -> ChannelFocus {
        let netSubs    = vm.subscriberGrowth?.absolute ?? 0
        let views      = vm.viewGrowth?.absolute ?? 0
        let watchHours = channel.watchTime

        if views == 0 && watchHours == 0 {
            return ChannelFocus(
                title: "Start by uploading consistently.",
                body: "Your channel doesn't have enough recent data to diagnose yet. The fastest way to grow is to keep uploading — the patterns will show up within a few videos.",
                color: AppTheme.accent
            )
        }

        if netSubs < -2 {
            return ChannelFocus(
                title: "You're losing more subscribers than you're gaining.",
                body: "This usually means your recent videos aren't matching what your audience subscribed for. Look at your last 3 videos on the Coach page — check what changed.",
                color: .red,
                linksToCoach: true
            )
        }

        if watchHours > 0 && views < 500 {
            return ChannelFocus(
                title: "Your content is being watched — but not enough people are clicking.",
                body: "You have solid watch time, which means viewers who do watch are staying. The problem is getting them to click in the first place. Your thumbnails or titles need work.",
                color: .orange
            )
        }

        if netSubs == 0 && views < 1000 {
            return ChannelFocus(
                title: "Growth has stalled this period.",
                body: "Views and subscriber gains are both low. Check the Coach page — it'll tell you which of your videos has the best chance of turning this around.",
                color: .yellow,
                linksToCoach: true
            )
        }

        if netSubs > 0 && views > 0 {
            return ChannelFocus(
                title: "Your channel is growing. Keep the momentum.",
                body: "You gained subscribers and views \(vm.selectedPeriod.label). The best thing you can do right now is upload again — consistency compounds.",
                color: .green
            )
        }

        return ChannelFocus(
            title: "Check your latest video performance.",
            body: "Tap the video below to see how it's doing and what to improve for your next upload.",
            color: AppTheme.accent
        )
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
                color: AppTheme.accent,
                percentage: vm.viewGrowth?.formattedPercentage
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
                color: .cyan,
                percentage: vm.watchTimeGrowth.flatMap { growth in
                    growth.absolute > 0 ? growth.formattedPercentage : nil
                }
            )

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
                color: AppTheme.success,
                percentage: vm.subscriberGrowth?.formattedPercentage
            )
        }
    }

    // MARK: - Latest video content
    private func latestVideoContent() -> some View {
        Group {
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

    // MARK: - Section label
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundColor(AppTheme.textPrimary)
    }
}
