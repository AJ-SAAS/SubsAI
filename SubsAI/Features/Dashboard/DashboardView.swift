// Features/Dashboard/DashboardView.swift
import SwiftUI
import StoreKit

struct DashboardView: View {
    @StateObject private var vm = HomeViewModel()
    var coachVM: CoachViewModel
    @State private var showGoalSheet = false
    @State private var customGoals: [(GoalType, Int)] = []
    @State private var authErrorMessage: String?

    // MARK: - Review Request
    @Environment(\.requestReview) private var requestReview

    @AppStorage("lastReviewRequestDate") private var lastReviewRequestDate: Double = 0
    @AppStorage("reviewRequestsThisYear") private var reviewRequestsThisYear: Int = 0

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

    // MARK: - Greeting helpers
    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:       return "Good evening"
        }
    }

    private var greetingSubtitle: String {
        "Your channel moved today. Here's what matters."
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.65),
                        AppTheme.accent.opacity(0.40),
                        AppTheme.accent.opacity(0.15),
                        Color.black.opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    RadialGradient(
                        colors: [AppTheme.accent.opacity(0.25), Color.clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 380
                    )
                    .frame(height: 360)
                    .ignoresSafeArea(edges: .top)
                    Spacer()
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Greeting header (FIXED VISUAL POSITION)
                        if let channel = vm.channelInfo {
                            greetingHeader(channel)
                                .padding(.horizontal, 18)
                                .padding(.top, 56)   // ⬅️ LOWER ON SCREEN (was 28)
                                .padding(.bottom, 6) // tightened gap to carousel
                        } else {
                            greetingHeaderFallback
                                .padding(.horizontal, 18)
                                .padding(.top, 56)   // same fix applied
                                .padding(.bottom, 6)
                        }

                        // MARK: - Hero metric carousel (rebalanced spacing)
                        MetricCarouselView(vm: vm)
                            .padding(.bottom, 2) // ⬅️ reduced outer spacing

                        VStack(spacing: 0) {

                            sectionDivider

                            // What's happening right now
                            if let channel = vm.channelInfo {
                                VStack(alignment: .leading, spacing: 10) {
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
                                .padding(.horizontal, 18)
                            }

                            sectionDivider

                            // Latest video
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    sectionLabel("Latest video")
                                    Spacer()
                                    Text("All videos")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(AppTheme.accent)
                                }
                                latestVideoContent()
                            }
                            .padding(.horizontal, 18)

                            sectionDivider

                            // Channel growth
                            if vm.channelInfo != nil {
                                VStack(alignment: .leading, spacing: 10) {
                                    sectionLabel("Channel growth")
                                    periodSelector
                                    if let channel = vm.channelInfo {
                                        statsGrid(channel)
                                    }
                                }
                                .padding(.horizontal, 18)
                            }

                            sectionDivider

                            // Where I'm headed
                            if let channel = vm.channelInfo {
                                VStack(alignment: .leading, spacing: 10) {
                                    sectionLabel("Where I'm headed")
                                    milestonesSection(channel)
                                }
                                .padding(.horizontal, 18)
                            }

                            if vm.isLoading && vm.channelInfo == nil {
                                loadingState
                                    .padding(.horizontal, 18)
                            }

                            if let error = vm.errorMessage {
                                errorBanner(error)
                                    .padding(.horizontal, 18)
                            }

                            Spacer(minLength: 40)
                        }
                    }
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
            attemptReviewRequest()
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

    // MARK: - Review Request Logic
    private func attemptReviewRequest() {
        let now = Date().timeIntervalSince1970
        let oneYearAgo = now - (365 * 24 * 60 * 60)

        if lastReviewRequestDate < oneYearAgo {
            reviewRequestsThisYear = 0
        }

        guard reviewRequestsThisYear < 3 else { return }
        guard vm.channelInfo != nil && !vm.isLoading else { return }

        if now - lastReviewRequestDate < (30 * 24 * 60 * 60) {
            return
        }

        requestReview()
        lastReviewRequestDate = now
        reviewRequestsThisYear += 1
    }

    // MARK: - Greeting header
    private func greetingHeader(_ channel: Channel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingPrefix)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.accent)
                .kerning(0.5)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Hey, \(channel.name.components(separatedBy: " ").first ?? channel.name) 👋")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Text(greetingSubtitle)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 14)
    }

    private var greetingHeaderFallback: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingPrefix)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.accent)
                .kerning(0.5)
                .textCase(.uppercase)

            Text("Hey 👋")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(greetingSubtitle)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 14)
    }

    // MARK: - Section divider
    private var sectionDivider: some View {
        Divider()
            .opacity(0.12)
            .padding(.vertical, 8)
            .padding(.horizontal, 18)
    }

    // MARK: - Focus card
    private func focusCard(_ channel: Channel) -> some View {
        let focus = channelFocus(channel)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 5, height: 5)

                Text("Your focus right now")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .kerning(1.0)
                    .textCase(.uppercase)

                Spacer()

                if focus.linksToCoach {
                    HStack(spacing: 3) {
                        Text("See Coach")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }

            Text(focus.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(focus.body)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent)
        .cornerRadius(20)
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
                            size: 14,
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
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
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
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
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
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            Text("Add a custom goal")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
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
                        .font(.system(size: 13, weight: .medium, design: .rounded))
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
                        .font(.system(size: 13, weight: .medium, design: .rounded))
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
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
        }
    }

    // MARK: - MetricCarouselView - Much taller hero cards with bigger graph
    struct MetricCarouselView: View {
        @ObservedObject var vm: HomeViewModel

        private struct MetricItem: Identifiable {
            let id = UUID()
            let label: String
            let value: String
            let delta: String
            let isPositive: Bool?
            let color: Color
            let dataPoints: [Double]
        }

        private var metrics: [MetricItem] {
            guard let channel = vm.channelInfo else { return [] }

            let viewDelta   = vm.viewGrowth?.absolute ?? 0
            let subsDelta   = vm.subscriberGrowth?.absolute ?? 0
            let watchDelta  = vm.watchTimeGrowth?.absolute ?? 0

            return [
                MetricItem(
                    label: "Total views",
                    value: channel.totalViews.formatted(),
                    delta: viewDelta > 0 ? "+\(viewDelta.formatted()) this month" :
                           viewDelta < 0 ? "\(viewDelta.formatted()) this month" : "No change this month",
                    isPositive: viewDelta > 0 ? true : (viewDelta < 0 ? false : nil),
                    color: AppTheme.accent,
                    dataPoints: [44, 40, 42, 34, 32, 37, 24, 18, 26, 21, 29, 13, 8, 15, 18, 12]
                ),
                MetricItem(
                    label: "Subscribers",
                    value: channel.subscribers.formatted(),
                    delta: subsDelta > 0 ? "+\(subsDelta.formatted()) this month" :
                           subsDelta < 0 ? "\(subsDelta.formatted()) this month" : "No change this month",
                    isPositive: subsDelta > 0 ? true : (subsDelta < 0 ? false : nil),
                    color: AppTheme.success,
                    dataPoints: [28, 28, 27, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28]
                ),
                MetricItem(
                    label: "Watch time",
                    value: channel.watchTime > 0 ? String(format: "%.0fh", channel.watchTime) : "—",
                    delta: watchDelta > 0 ? "+\(watchDelta)h this month" :
                           watchDelta < 0 ? "\(watchDelta)h this month" : "No change this month",
                    isPositive: watchDelta > 0 ? true : (watchDelta < 0 ? false : nil),
                    color: .cyan,
                    dataPoints: [46, 44, 40, 34, 26, 18, 12, 8, 6, 6, 7, 8, 9, 8, 7, 6]
                )
            ]
        }

        @State private var currentIndex: Int = 0

        var body: some View {
            if vm.channelInfo == nil { return AnyView(EmptyView()) }
            return AnyView(
                VStack(spacing: 6) {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                            metricCard(metric)
                                .tag(index)
                                .padding(.horizontal, 18)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(minHeight: 380, maxHeight: 440)

                    HStack(spacing: 6) {
                        ForEach(0..<metrics.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentIndex ? AppTheme.accent : Color(.systemFill))
                                .frame(width: i == currentIndex ? 18 : 5, height: 5)
                                .animation(.easeInOut(duration: 0.25), value: currentIndex)
                        }
                    }
                }
            )
        }

        private func metricCard(_ metric: MetricItem) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(metric.color).frame(width: 7, height: 7)
                        Text(metric.label)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textTertiary)
                            .textCase(.uppercase)
                            .kerning(0.5)
                    }
                    Spacer()
                    Text("Last 28 days")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemFill))
                        .cornerRadius(6)
                }
                .padding(.bottom, 12)

                Text(metric.value)
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 2)

                Text(metric.delta)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(
                        metric.isPositive == true ? AppTheme.success :
                        metric.isPositive == false ? .red :
                        AppTheme.textTertiary
                    )
                    .padding(.bottom, 16)

                SparklineView(dataPoints: metric.dataPoints, color: metric.color)
                    .frame(height: 150)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
            )
        }
    }

    // MARK: - SparklineView
    struct SparklineView: View {
        let dataPoints: [Double]
        let color: Color

        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let minVal = dataPoints.min() ?? 0
                let maxVal = dataPoints.max() ?? 1
                let range = maxVal - minVal == 0 ? 1 : maxVal - minVal
                let step = w / CGFloat(dataPoints.count - 1)

                let points: [CGPoint] = dataPoints.enumerated().map { i, val in
                    CGPoint(
                        x: CGFloat(i) * step,
                        y: h - CGFloat((val - minVal) / range) * h
                    )
                }

                ZStack {
                    Path { path in
                        guard points.count > 1 else { return }
                        path.move(to: CGPoint(x: points[0].x, y: h))
                        path.addLine(to: points[0])
                        for pt in points.dropFirst() { path.addLine(to: pt) }
                        path.addLine(to: CGPoint(x: points.last!.x, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.25), color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        guard points.count > 1 else { return }
                        path.move(to: points[0])
                        for pt in points.dropFirst() { path.addLine(to: pt) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
