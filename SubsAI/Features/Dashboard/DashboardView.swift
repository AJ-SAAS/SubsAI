// Features/Dashboard/DashboardView.swift
// New Home: minimal white page, black + purple gradient header,
// milestone + streak cards, then stacked cards: latest video, views, subs, watch time, goals.
import SwiftUI
import StoreKit

// MARK: - Look

enum HomeLook {
    static let page        = Color.white
    static let ink         = Color(red: 0.04, green: 0.04, blue: 0.04)   // #0A0A0A
    static let secondary   = Color(red: 0.42, green: 0.42, blue: 0.42)   // #6B6B6B
    static let hairline    = Color(red: 0.91, green: 0.91, blue: 0.91)   // #E8E8E8
    static let fill        = Color(red: 0.957, green: 0.957, blue: 0.957) // #F4F4F4
    static let purple      = Color(red: 0.357, green: 0.169, blue: 0.910) // #5B2BE8  (data going up)
    static let purpleLight = Color(red: 0.549, green: 0.388, blue: 1.0)   // #8C63FF
    static let orange      = Color(red: 0.910, green: 0.467, blue: 0.180) // #E8772E  (data going down)
    static let orangeText  = Color(red: 0.706, green: 0.325, blue: 0.035) // #B45309  (orange text on white)
}

// MARK: - Home

struct DashboardView: View {
    @StateObject private var vm = HomeViewModel()
    @ObservedObject var coachVM: CoachViewModel
    @ObservedObject private var premium = PremiumStatus.shared

    @State private var showGoalSheet = false
    @State private var authErrorMessage: String?
    @State private var scrollY: CGFloat = 0

    // Custom goals are saved, so they survive an app restart
    @AppStorage("home.customGoals") private var customGoalsRaw: String = ""

    // MARK: - Review Request
    @Environment(\.requestReview) private var requestReview

    @AppStorage("lastReviewRequestDate") private var lastReviewRequestDate: Double = 0
    @AppStorage("reviewRequestsThisYear") private var reviewRequestsThisYear: Int = 0

    private let subsMilestones = [
        100, 500, 1_000, 5_000, 10_000, 25_000, 50_000,
        100_000, 250_000, 500_000, 1_000_000, 10_000_000
    ]
    private let watchHourTarget = 4_000.0

    // MARK: - Derived values

    private var subsKnown: Bool {
        guard let channel = vm.channelInfo else { return false }
        if channel.subscribersHidden == true { return false }
        return channel.subscribersHidden == false || channel.subscribers > 0
    }

    private var subs: Int { vm.channelInfo?.subscribers ?? 0 }

    private var nextSubsMilestone: Int {
        subsMilestones.first { $0 > subs } ?? subsMilestones.last!
    }

    private var completedSubsMilestones: [Int] {
        subsMilestones.filter { $0 <= subs }
    }

    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var periodDays: Int { vm.selectedPeriod.days }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let topInset = geo.safeAreaInsets.top

                ZStack(alignment: .top) {
                    HomeLook.page

                    ScrollView(showsIndicators: false) {
                        ZStack(alignment: .top) {
                            GradientHeader()
                                .frame(height: topInset + 196)

                            VStack(spacing: 0) {
                                GeometryReader { g in
                                    Color.clear.preference(
                                        key: HomeScrollKey.self,
                                        value: g.frame(in: .named("homeScroll")).minY
                                    )
                                }
                                .frame(height: 0)

                                headerContent
                                    .padding(.top, topInset + 10)
                                    .padding(.horizontal, 20)

                                topCards
                                    .padding(.top, 22)
                                    .padding(.horizontal, 16)

                                VStack(alignment: .leading, spacing: 14) {
                                    latestVideoSection
                                    periodHeader
                                    metricCard(.views)
                                    metricCard(.subs)
                                    metricCard(.watch)
                                    goalsSection

                                    if let error = vm.errorMessage {
                                        errorBanner(error)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 20)

                                Spacer(minLength: 120)
                            }
                        }
                    }
                    .coordinateSpace(name: "homeScroll")
                    .refreshable { await vm.loadChannelStats() }
                    .onPreferenceChange(HomeScrollKey.self) { scrollY = $0 }

                    // Keeps the status bar readable once the header scrolls away
                    HomeLook.ink
                        .frame(height: topInset)
                        .frame(maxWidth: .infinity)
                        .opacity(scrollY < -120 ? 1 : 0)
                        .animation(.easeOut(duration: 0.2), value: scrollY < -120)
                        .allowsHitTesting(false)   // never blocks taps on the header
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showGoalSheet) {
            GoalPickerSheet(isPresented: $showGoalSheet) { type, target in
                addGoal(type, target)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            Task { await vm.loadChannelStats() }
            Task { await premium.refresh() }
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

    // MARK: - Header

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SubsAI")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 14) {
                avatar(size: 64)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(greetingPrefix),")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.72))

                    Text(vm.channelInfo?.name ?? "Your channel")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func avatar(size: CGFloat) -> some View {
        Group {
            if let urlString = vm.channelInfo?.profilePicURL,
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    HomeLook.purple.opacity(0.5)
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [HomeLook.purple, HomeLook.purpleLight],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 3))
    }

    // MARK: - Top cards (milestone + streak)

    private var topCards: some View {
        HStack(alignment: .top, spacing: 12) {
            milestoneCard
            streakCard
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var milestoneCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            smallLabel("NEXT MILESTONE")

            if vm.channelInfo == nil {
                placeholderBlock
            } else if !subsKnown {
                Text("Subs hidden")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(HomeLook.ink)
                Text("Show your sub count on YouTube to track this.")
                    .font(.system(size: 12))
                    .foregroundColor(HomeLook.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                (Text(subs.formatted())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(HomeLook.ink)
                 + Text(" / \(compact(nextSubsMilestone))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(HomeLook.secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                ThinBar(fraction: Double(subs) / Double(nextSubsMilestone), height: 6)

                Text("\(max(nextSubsMilestone - subs, 0).formatted()) subs to go")
                    .font(.system(size: 12))
                    .foregroundColor(HomeLook.secondary)
            }
        }
        .modifier(FloatingCard())
    }

    private var streakCard: some View {
        let weeks = Array(vm.uploadWeeks.suffix(8))
        let dots = weeks.isEmpty ? Array(repeating: false, count: 8) : weeks
        let streak = vm.uploadStreak

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                smallLabel("UPLOAD STREAK")
                Spacer(minLength: 4)
                Image(systemName: "flame")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HomeLook.purple)
            }

            (Text(streak >= 12 ? "12+" : "\(streak)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(HomeLook.ink)
             + Text(streak == 1 ? " week" : " weeks")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(HomeLook.secondary))

            HStack(spacing: 0) {
                ForEach(Array(dots.enumerated()), id: \.offset) { index, posted in
                    weekDot(posted: posted, isThisWeek: index == dots.count - 1)
                    if index < dots.count - 1 { Spacer(minLength: 2) }
                }
            }

            Text(vm.postedThisWeek
                 ? "Posted this week"
                 : (streak > 0 ? "Post to keep it going" : "Post this week to start"))
                .font(.system(size: 12))
                .foregroundColor(HomeLook.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .modifier(FloatingCard())
    }

    private func weekDot(posted: Bool, isThisWeek: Bool) -> some View {
        ZStack {
            if posted {
                Circle().fill(HomeLook.purple)
            } else if isThisWeek {
                // This week is still open
                Circle().stroke(HomeLook.purple, lineWidth: 1.5)
            } else {
                Circle().fill(HomeLook.fill)
            }
        }
        .frame(width: 12, height: 12)
        .overlay(
            Circle()
                .stroke(HomeLook.purple, lineWidth: 1.5)
                .padding(-3.5)
                .opacity(posted && isThisWeek ? 1 : 0)
        )
    }

    // MARK: - Growth cards (Views, Subs, Watch time)

    /// Small row above the metric cards. One picker sets the days for all three.
    private var periodHeader: some View {
        HStack {
            Text("Your growth")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(HomeLook.ink)

            Spacer()

            Menu {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Button("Last \(period.days) days") { vm.changePeriod(to: period) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(periodDays) days")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(HomeLook.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(HomeLook.fill))
            }
            .disabled(vm.isLoading)
        }
        .padding(.top, 6)
    }

    private func metricCard(_ metric: HomeMetric) -> some View {
        let rising = chartRising(metric)

        let label: String
        let value: String
        let caption: String
        var badge: Int? = nil

        switch metric {
        case .views:
            label = "VIEWS"
            value = (vm.viewGrowth?.absolute ?? 0).formatted()
            caption = "Last \(periodDays) days"
        case .subs:
            label = "SUBSCRIBERS"
            value = subsKnown ? subs.formatted() : "Hidden"
            caption = subsKnown ? "Total subscribers" : "Show your sub count on YouTube to see this"
            if subsKnown { badge = vm.subscriberGrowth?.absolute }
        case .watch:
            label = "WATCH TIME"
            value = hoursText(vm.channelInfo?.watchTime ?? 0)
            caption = "Last \(periodDays) days"
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                smallLabel(label)
                Spacer()
                if let badge {
                    changeBadge(badge)
                }
            }

            if vm.channelInfo == nil {
                RoundedRectangle(cornerRadius: 6)
                    .fill(HomeLook.fill)
                    .frame(width: 120, height: 38)
                    .padding(.vertical, 2)
            } else {
                Text(value)
                    .font(.system(size: 38, weight: .bold))
                    .kerning(-1)
                    .foregroundColor(HomeLook.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Text(caption)
                .font(.system(size: 13))
                .foregroundColor(HomeLook.secondary)

            chart(for: metric, rising: rising)
                .padding(.top, 8)
        }
        .modifier(StackCard())
    }

    private func changeBadge(_ change: Int) -> some View {
        let up = change > 0, down = change < 0
        let color = up ? HomeLook.purple : (down ? HomeLook.orangeText : HomeLook.secondary)
        let icon = up ? "arrow.up" : (down ? "arrow.down" : "minus")
        let text = change == 0 ? "No change" : abs(change).formatted()

        return HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(color)
    }

    @ViewBuilder
    private func chart(for metric: HomeMetric, rising: Bool) -> some View {
        let values = chartValues(metric)
        if values.count >= 2, values.contains(where: { $0 != 0 }) {
            TrendChart(values: values, color: rising ? HomeLook.purple : HomeLook.orange)
                .frame(height: 84)
        } else if vm.trend == nil && vm.isLoading {
            HStack { Spacer(); ProgressView().tint(HomeLook.secondary); Spacer() }
                .frame(height: 84)
        } else if vm.channelInfo != nil {
            Text("Not enough data yet.")
                .font(.system(size: 13))
                .foregroundColor(HomeLook.secondary)
        }
    }

    /// Real numbers from YouTube, one per day.
    private func chartValues(_ metric: HomeMetric) -> [Double] {
        guard let trend = vm.trend else { return [] }
        switch metric {
        case .subs:
            // Running total that ends at today's sub count
            guard subsKnown else { return [] }
            let total = trend.netSubs.reduce(0, +)
            var running = Double(subs) - total
            return trend.netSubs.map { running += $0; return running }
        case .views:
            return trend.views
        case .watch:
            return trend.watchHours
        }
    }

    /// Purple if the trend is flat or going up, orange if it's going down.
    private func chartRising(_ metric: HomeMetric) -> Bool {
        guard let trend = vm.trend else { return true }
        if metric == .subs { return trend.netSubs.reduce(0, +) >= 0 }
        let values = chartValues(metric)
        guard values.count >= 3 else { return true }
        let k = max(values.count / 3, 1)
        let first = values.prefix(k).reduce(0, +) / Double(k)
        let last = values.suffix(k).reduce(0, +) / Double(k)
        return last >= first
    }

    // MARK: - Latest video

    private var latestVideoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text((vm.latestVideo?.isShort ?? false) ? "LATEST SHORT" : "LATEST VIDEO")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.1)
                .foregroundColor(.white.opacity(0.55))

            if let video = vm.latestVideo {
                // Everyone gets the full review of their latest video.
                // Free users see it as a preview (deep analysis locked).
                NavigationLink {
                    CoachReviewView(
                        video: coachVM.videos.first { $0.videoId == video.videoId } ?? video,
                        allVideos: coachVM.videos,
                        vm: coachVM,
                        isFreePreview: !premium.isPremium
                    )
                } label: {
                    latestVideoRow(video)
                }
                .buttonStyle(.plain)
            } else if vm.isLoadingLatestVideo {
                HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                    .frame(height: 90)
            } else {
                Text("No videos yet. Your latest upload will show here.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.65))
            }
        }
        .modifier(BlackCard())
    }

    private func latestVideoRow(_ video: Video) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VideoThumbnailView(video: video)
                    .frame(width: 112, height: 63)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(daysAgo(video.publishedAt))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }

            HStack(alignment: .top, spacing: 0) {
                viewsStat(video)
                middleStat(video)
                rankStat
            }
            .padding(.top, 14)
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }

            if let footnote = latestFootnote {
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .bold))
                Text(premium.isPremium ? "See the full video review" : "Free: see what's holding it back")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(HomeLook.purpleLight)
            .padding(.top, 2)
        }
        .contentShape(Rectangle())
    }

    // Views
    private func viewsStat(_ video: Video) -> some View {
        videoStat(
            value: video.views > 0 ? compact(video.views) : "0",
            label: "Views",
            note: nil,
            noteColor: .clear
        )
    }

    // Thumbnail CTR when YouTube has it, otherwise average watch time
    @ViewBuilder
    private func middleStat(_ video: Video) -> some View {
        if let ctr = vm.latestCTR {
            let good = ctr >= 0.06, low = ctr < 0.03
            videoStat(
                value: String(format: "%.1f%%", ctr * 100),
                label: "Thumbnail CTR",
                note: good ? "Great" : (low ? "Low" : "Normal"),
                noteColor: good ? HomeLook.purpleLight : (low ? HomeLook.orange : .white.opacity(0.6))
            )
        } else {
            let retention = video.analytics?.retention ?? 0
            videoStat(
                value: video.averageViewDuration > 0 ? duration(video.averageViewDuration) : "-",
                label: "Avg. watch",
                note: retention > 0 ? "\(Int((retention * 100).rounded()))% watched" : nil,
                // Shorts are short, so people watch most of them. Judge them on a higher bar.
                noteColor: video.isShort
                    ? (retention >= 0.9 ? HomeLook.purpleLight : (retention >= 0.7 ? .white.opacity(0.6) : HomeLook.orange))
                    : (retention >= 0.5 ? HomeLook.purpleLight : (retention >= 0.35 ? .white.opacity(0.6) : HomeLook.orange))
            )
        }
    }

    // Ranking vs your recent videos
    @ViewBuilder
    private var rankStat: some View {
        if let rank = vm.latestRank {
            let topThird = rank.rank <= max(1, rank.total / 3)
            let bottomThird = rank.rank > rank.total - max(1, rank.total / 3)
            let note: String = rank.rank == 1 ? "Your best"
                : (topThird ? "Top video" : (bottomThird ? "Below usual" : "About usual"))
            let color: Color = topThird ? HomeLook.purpleLight
                : (bottomThird ? HomeLook.orange : .white.opacity(0.6))

            VStack(alignment: .leading, spacing: 3) {
                (Text("#\(rank.rank)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                 + Text(" of \(rank.total)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55)))
                Text("Ranking")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                Text(note)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            videoStat(
                value: "-",
                label: "Ranking",
                note: vm.rankPending ? "Ready tomorrow" : nil,
                noteColor: .white.opacity(0.6)
            )
        }
    }

    /// One small line that says how the numbers work, so people trust them.
    private var latestFootnote: String? {
        var parts: [String] = []
        if let rank = vm.latestRank {
            let dayWord = rank.days == 1 ? "day" : "days"
            let kind = (vm.latestVideo?.isShort ?? false) ? "Shorts" : "long videos"
            parts.append("Ranked by views in the first \(rank.days) \(dayWord), vs. your last \(rank.total) \(kind).")
        }
        if vm.latestCTR == nil && !(vm.latestVideo?.isShort ?? false) && !AuthManager.shared.isDemoMode {
            parts.append("Thumbnail CTR shows up 1 to 2 days after you connect.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func videoStat(value: String, label: String, note: String?, noteColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))
            Text(note ?? " ")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(noteColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Goals

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            smallLabel("YOUR GOALS")
                .padding(.bottom, 6)

            goalRow(
                label: "Watch hours (12 months)",
                current: vm.yearWatchHours ?? 0,
                target: watchHourTarget,
                unit: "h"
            )

            ForEach(Array(customGoals.enumerated()), id: \.offset) { index, goal in
                goalRow(
                    label: goal.type.rawValue,
                    current: currentValue(for: goal.type),
                    target: Double(goal.target),
                    unit: goal.type.unit
                )
                .contextMenu {
                    Button(role: .destructive) {
                        removeGoal(at: index)
                    } label: {
                        Label("Remove goal", systemImage: "trash")
                    }
                }
            }

            ForEach(completedSubsMilestones.suffix(2), id: \.self) { milestone in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(HomeLook.purple)
                    Text("\(milestone.formatted()) subs reached")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(HomeLook.ink)
                    Spacer()
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { Rectangle().fill(HomeLook.hairline).frame(height: 1) }
            }

            Button {
                showGoalSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add a goal")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(HomeLook.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(HomeLook.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .modifier(StackCard())
    }

    private func goalRow(label: String, current: Double, target: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(HomeLook.ink)
                Spacer()
                Text("\(shortNumber(current))\(unit) / \(shortNumber(target))\(unit)")
                    .font(.system(size: 13))
                    .foregroundColor(HomeLook.secondary)
            }
            ThinBar(fraction: target > 0 ? current / target : 0, height: 4)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(HomeLook.hairline).frame(height: 1) }
    }

    private var customGoals: [(type: GoalType, target: Int)] {
        customGoalsRaw
            .split(separator: ";")
            .compactMap { part in
                let bits = part.split(separator: "|")
                guard bits.count == 2,
                      let type = GoalType(rawValue: String(bits[0])),
                      let target = Int(bits[1]) else { return nil }
                return (type, target)
            }
    }

    private func addGoal(_ type: GoalType, _ target: Int) {
        let entry = "\(type.rawValue)|\(target)"
        customGoalsRaw = customGoalsRaw.isEmpty ? entry : customGoalsRaw + ";" + entry
    }

    private func removeGoal(at index: Int) {
        var parts = customGoalsRaw.split(separator: ";").map(String.init)
        guard parts.indices.contains(index) else { return }
        parts.remove(at: index)
        customGoalsRaw = parts.joined(separator: ";")
    }

    private func currentValue(for type: GoalType) -> Double {
        guard let channel = vm.channelInfo else { return 0 }
        switch type {
        case .subscribers: return Double(channel.subscribers)
        case .watchHours:  return vm.yearWatchHours ?? channel.watchTime
        case .views:       return Double(channel.totalViews)
        case .videos:      return Double(channel.videoCount)
        }
    }

    // MARK: - Small pieces

    private var hairline: some View {
        Rectangle().fill(HomeLook.hairline).frame(height: 1)
    }

    private func smallLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.1)
            .foregroundColor(HomeLook.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var placeholderBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(HomeLook.fill).frame(width: 90, height: 22)
            RoundedRectangle(cornerRadius: 3).fill(HomeLook.fill).frame(height: 6)
            RoundedRectangle(cornerRadius: 3).fill(HomeLook.fill).frame(width: 70, height: 10)
        }
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(HomeLook.orangeText)
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(HomeLook.orangeText)
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(HomeLook.orange.opacity(0.10)))
    }

    // MARK: - Formatting

    /// 1_000 -> "1K", 25_000 -> "25K", 1_000_000 -> "1M"
    private func compact(_ n: Int) -> String {
        switch n {
        case 1_000_000...:
            let v = Double(n) / 1_000_000
            return v == v.rounded() ? "\(Int(v))M" : String(format: "%.1fM", v)
        case 1_000...:
            let v = Double(n) / 1_000
            return v == v.rounded() ? "\(Int(v))K" : String(format: "%.1fK", v)
        default:
            return "\(n)"
        }
    }

    private func shortNumber(_ value: Double) -> String {
        // 1,840 / 4,000 reads better than 1.8K / 4K. Only shorten big numbers.
        if value >= 10_000 { return compact(Int(value.rounded())) }
        if value > 0 && value < 10 { return String(format: "%.1f", value) }
        return Int(value.rounded()).formatted()
    }

    private func hoursText(_ hours: Double) -> String {
        hours >= 10 ? "\(Int(hours.rounded()))h" : String(format: "%.1fh", hours)
    }

    private func duration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func daysAgo(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }
}

// MARK: - Metric tabs

enum HomeMetric: String, CaseIterable, Identifiable {
    case subs, views, watch
    var id: String { rawValue }
    var title: String {
        switch self {
        case .subs:  return "Subs"
        case .views: return "Views"
        case .watch: return "Watch time"
        }
    }
}

// MARK: - Header background (black + purple sweep)

/// Shared with Settings.
/// The real status bar height. A pushed screen with a hidden nav bar can get 0
/// from GeometryReader, which puts the title under the clock.
enum DeviceInsets {
    static var top: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return window?.safeAreaInsets.top ?? 47
    }
}

struct GradientHeader: View {
    var body: some View {
        ZStack {
            HomeLook.ink

            RadialGradient(
                colors: [HomeLook.purple.opacity(0.55), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 380
            )

            SweepShape(startX: 0.38, endY: 0.78)
                .fill(LinearGradient(
                    colors: [HomeLook.purpleLight, HomeLook.purple.opacity(0.85), HomeLook.purple.opacity(0)],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                ))

            SweepShape(startX: 0.60, endY: 0.46)
                .fill(LinearGradient(
                    colors: [Color(red: 0.72, green: 0.61, blue: 1.0).opacity(0.55), .clear],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                ))
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
    }
}

/// A curved band from the top edge down to the right edge.
struct SweepShape: Shape {
    let startX: CGFloat   // where it starts on the top edge (0...1)
    let endY: CGFloat     // where it ends on the right edge (0...1)

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * startX, y: 0))
        p.addCurve(
            to: CGPoint(x: w, y: h * endY),
            control1: CGPoint(x: w * (startX + 0.22), y: h * 0.2),
            control2: CGPoint(x: w * 0.77, y: h * endY * 0.58)
        )
        p.addLine(to: CGPoint(x: w, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - Floating card (white, soft shadow)

private struct FloatingCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
            )
            .compositingGroup()   // shadow on the card only, not on the text and bars inside
            .shadow(color: Color.black.opacity(0.12), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Black card (latest video)

private struct BlackCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    HomeLook.ink
                    // A soft purple glow in the corner, like the header
                    RadialGradient(
                        colors: [HomeLook.purple.opacity(0.35), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 260
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
            .compositingGroup()   // shadow on the card only, not on the text and bars inside
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Stack card (white, thin grey border)

private struct StackCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(HomeLook.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Thin progress bar (fills when it appears)

private struct ThinBar: View {
    let fraction: Double
    var color: Color = HomeLook.purple
    var height: CGFloat = 6

    @State private var shown = false

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(HomeLook.fill)
                Capsule()
                    .fill(color)
                    .frame(width: g.size.width * (shown ? CGFloat(min(max(fraction, 0), 1)) : 0))
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.15)) { shown = true }
        }
    }
}

// MARK: - Trend chart (line + soft fade, no axes)

private struct TrendChart: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 0.0001)
            let inset: CGFloat = 6
            let step = (w - inset * 2) / CGFloat(max(values.count - 1, 1))
            let points = values.enumerated().map { i, v in
                CGPoint(
                    x: inset + CGFloat(i) * step,
                    y: inset + (h - inset * 2) * (1 - CGFloat((v - minV) / range))
                )
            }

            ZStack {
                Path { p in
                    guard let first = points.first, let last = points.last else { return }
                    p.move(to: CGPoint(x: first.x, y: h))
                    points.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: last.x, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [color.opacity(0.22), color.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    points.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(color)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct HomeScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - SparklineView (kept, in case other screens use it)
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
            let step = w / CGFloat(max(dataPoints.count - 1, 1))

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
