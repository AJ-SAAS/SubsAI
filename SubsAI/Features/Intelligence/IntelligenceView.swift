// Features/Intelligence/IntelligenceView.swift
// New look, same as Home and Settings: gradient header, white page, white cards
// with a thin grey border, one black hero card. Purple = good, orange = needs work.
// Uses HomeLook + GradientHeader from DashboardView.swift.
import SwiftUI

// MARK: - Intelligence look

enum IntelLook {
    static let good      = HomeLook.purple      // good numbers
    static let bad       = HomeLook.orange      // bars, dots
    static let badText   = HomeLook.orangeText  // orange text on white
    static let neutral   = HomeLook.secondary
}

/// White card with a thin grey border (same as Home's cards)
struct IntelCard: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
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

/// Black card with a soft purple glow (same as Home's latest video card)
struct IntelBlackCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    HomeLook.ink
                    RadialGradient(
                        colors: [HomeLook.purple.opacity(0.35), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 260
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}

/// Thin line between rows inside a white card
private struct IntelDivider: View {
    var body: some View {
        Rectangle().fill(HomeLook.hairline).frame(height: 1)
    }
}

private struct IntelScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Intelligence

struct IntelligenceView: View {

    @ObservedObject var vm: CoachViewModel
    /// True when opened from Coach (pushed), so it shows a back button
    var showsBack: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var authError: AuthError?
    @State private var scrollY: CGFloat = 0

    init(vm: CoachViewModel, showsBack: Bool = false) {
        self.vm = vm
        self.showsBack = showsBack
    }

    private var showingShorts: Bool { vm.hasBothFormats && vm.formatFilter == .shorts }

    var body: some View {
        Group {
            if showsBack {
                page
            } else {
                NavigationStack { page }
            }
        }
        .onAppear {
            Task { await loadSafely() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .signInGoogleCompleted)) { _ in
            Task { await loadSafely() }
        }
        .alert(item: $authError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var page: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top

            ZStack(alignment: .top) {
                HomeLook.page

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        GeometryReader { g in
                            Color.clear.preference(
                                key: IntelScrollKey.self,
                                value: g.frame(in: .named("intelScroll")).minY
                            )
                        }
                        .frame(height: 0)

                        header
                            .padding(.top, topInset + 10)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GradientHeader())

                        VStack(alignment: .leading, spacing: 14) {
                            if vm.isLoading && vm.videos.isEmpty {
                                loadingState
                            } else if !vm.isLoading && vm.shownVideos.filter({ $0.analytics != nil }).count < 3 {
                                notEnoughDataState
                            } else if let report = vm.intelligenceReport {
                                intelligenceContent(report)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        Spacer(minLength: 120)
                    }
                }
                .coordinateSpace(name: "intelScroll")
                .refreshable { await vm.loadVideos() }
                .onPreferenceChange(IntelScrollKey.self) { scrollY = $0 }

                // Keeps the status bar readable once the header scrolls away
                HomeLook.ink
                    .frame(height: topInset)
                    .frame(maxWidth: .infinity)
                    .opacity(scrollY < -120 ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: scrollY < -120)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Text("Intelligence")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)

                if showsBack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("What the data says")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Patterns, fixes and chances to grow, from your last \(vm.shownVideos.count) \(showingShorts ? "Shorts" : "videos").")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Shorts and long videos are judged apart. Only shows when the channel has both.
            if vm.hasBothFormats {
                FormatSwitch(selection: $vm.formatFilter)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func intelligenceContent(_ report: ChannelIntelligenceReport) -> some View {

        sectionLabel("Your top 3 fixes right now")
        TopFixesCard(videos: vm.shownVideos, weaknesses: report.structuralWeaknesses)

        if !report.winningPatterns.isEmpty {
            sectionLabel("What's working on your channel")
            WinningPatternsCard(patterns: report.winningPatterns, videos: vm.shownVideos)
        }

        sectionLabel("How well views turn into subs")
        GrowthQualityCard(score: report.growthQualityScore, videos: vm.shownVideos)

        if let insight = vm.postingTimeInsight {
            sectionLabel("When should you post?")
            PostingTimeCard(insight: insight)
        }

        // Best performing = most views. Can't be won by luck like a ratio can.
        let topByViews = vm.shownVideos
            .filter { $0.views > 0 }
            .sorted { $0.views > $1.views }
        if !topByViews.isEmpty {
            sectionLabel(showingShorts ? "Your best performing Shorts" : "Your best performing videos")
            GPVLeaderboard(videos: Array(topByViews.prefix(5)), allVideos: vm.videos, rankBy: .views)
        }

        // Best at getting subscribers: only videos with 1,000+ views,
        // so 2 subs on a 44-view video can't come out on top
        let topBySubs = vm.shownVideos
            .filter { $0.views >= 1_000 && $0.growthPerView > 0 }
            .sorted { $0.growthPerView > $1.growthPerView }
        if topBySubs.count >= 3 {
            sectionLabel("Best at getting subscribers")
            GPVLeaderboard(videos: Array(topBySubs.prefix(5)), allVideos: vm.videos, rankBy: .subsPer1K)
        }

        let replicateVideos = vm.videosByPriority
            .filter { report.replicationScore(for: $0) == .replicate }
            .prefix(4)
        if !replicateVideos.isEmpty {
            sectionLabel("Videos worth repeating")
            VStack(alignment: .leading, spacing: 0) {
                Text("These beat your usual on views and on how much people watch. Make more like them.")
                    .font(.system(size: 14))
                    .foregroundColor(HomeLook.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)

                ForEach(Array(replicateVideos.enumerated()), id: \.element.id) { _, video in
                    IntelDivider()
                    NavigationLink {
                        CoachReviewView(
                            video: video,
                            allVideos: vm.videos,
                            postingTimeInsight: vm.postingTimeInsight,
                            vm: vm
                        )
                    } label: {
                        ReplicationRow(video: video, score: report.replicationScore(for: video))
                    }
                    .buttonStyle(.plain)
                }
            }
            .modifier(IntelCard())
        }

        comingSoonCard
            .padding(.top, 8)
    }

    // MARK: - Coming soon card

    private var comingSoonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HomeLook.purple)
                Text("Next video plan")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(HomeLook.ink)
                Spacer()
                Text("Coming soon")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HomeLook.purple)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(HomeLook.purple.opacity(0.1)))
            }
            Text("A plan for your next upload, based on what already works on your channel: title, hook, format and when to post.")
                .font(.system(size: 14))
                .foregroundColor(HomeLook.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(IntelCard())
    }

    // MARK: - Loading / not enough data

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Looking at your channel…")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(HomeLook.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var notEnoughDataState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36))
                .foregroundColor(HomeLook.hairline)
            Text("Not enough data yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(HomeLook.ink)
            Text("You need at least 3 \(showingShorts ? "Shorts" : "videos") with data. Check back after your next upload.")
                .font(.system(size: 15))
                .foregroundColor(HomeLook.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(HomeLook.ink)
            .padding(.top, 14)
    }

    private func loadSafely() async {
        guard vm.videos.isEmpty else { return }
        do {
            _ = try await AuthManager.shared.getValidToken()
            await vm.loadVideos()
        } catch {
            authError = .sessionExpired
        }
    }
}

// MARK: - PostingTimeCard

struct PostingTimeCard: View {
    let insight: PostingTimeInsight

    private var gapPercent: Int {
        guard insight.bestDayAvgViews > 0, insight.worstDayAvgViews > 0 else { return 0 }
        let gap = Double(insight.bestDayAvgViews - insight.worstDayAvgViews)
            / Double(insight.worstDayAvgViews) * 100
        return Int(gap)
    }

    private func formatViews(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 8) {
                Text("Based on \(insight.sampleSize) videos")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(HomeLook.secondary)
                Spacer()
                Text(insight.isReliable ? "Strong signal" : "Early signal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(insight.isReliable ? IntelLook.good : IntelLook.badText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((insight.isReliable ? IntelLook.good : IntelLook.bad).opacity(0.1)))
            }

            HStack(spacing: 10) {
                dayBox(label: "BEST DAY", day: insight.bestDay, views: insight.bestDayAvgViews,
                       color: IntelLook.good, textColor: IntelLook.good)
                dayBox(label: "WORST DAY", day: insight.worstDay, views: insight.worstDayAvgViews,
                       color: IntelLook.bad, textColor: IntelLook.badText)
            }

            if gapPercent > 0 {
                Text(LocalizedStringKey("\(insight.bestDay) uploads get **\(gapPercent)% more views** than \(insight.worstDay). Post your next video on a \(insight.bestDay)."))
                    .font(.system(size: 14))
                    .foregroundColor(HomeLook.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !insight.isReliable {
                Text("This is an early signal from \(insight.sampleSize) videos. It gets better the more you post.")
                    .font(.system(size: 13))
                    .foregroundColor(HomeLook.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .modifier(IntelCard())
    }

    private func dayBox(label: String, day: String, views: Int, color: Color, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.8)
                .foregroundColor(textColor)
            Text(day)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HomeLook.ink)
            Text("\(formatViews(views)) avg views")
                .font(.system(size: 13))
                .foregroundColor(HomeLook.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.07))
        )
    }
}

// MARK: - TopFixesCard

struct TopFixesCard: View {
    let videos: [Video]
    let weaknesses: [StructuralWeakness]

    private var topFixes: [(number: Int, title: String, detail: String)] {
        let enriched = videos.filter { $0.analytics != nil }
        guard !enriched.isEmpty else { return [] }

        var fixes: [(priority: Int, title: String, detail: String)] = []

        // CTR: only videos where YouTube gave us a real number
        let withCTR = enriched.filter { $0.analytics?.hasCTR ?? false }
        if withCTR.count >= 3 {
            let avgCTR = withCTR.compactMap { $0.analytics?.ctr }.reduce(0, +) / Double(withCTR.count)
            let lowCTRCount = withCTR.filter { ($0.analytics?.ctr ?? 0) < 0.04 }.count
            if avgCTR < 0.04 && lowCTRCount >= 2 {
                fixes.append((
                    priority: 3,
                    title: "Fix your thumbnails and titles",
                    detail: "\(lowCTRCount) of \(withCTR.count) videos have CTR under 4%. People see your videos but don't click. Better clicks help every other number."
                ))
            }
        }

        let avgRetention = enriched.compactMap { $0.analytics?.retention }.reduce(0, +) / Double(enriched.count)
        let lowHookCount = enriched.filter { ($0.analytics?.retention ?? 0) < 0.30 }.count
        if lowHookCount >= 2 {
            fixes.append((
                priority: 2,
                title: "Keep people watching longer",
                detail: "On \(lowHookCount) of your last \(enriched.count) videos, people watch less than 30%. Start with the best part, not the setup."
            ))
        } else if avgRetention < 0.35 {
            fixes.append((
                priority: 1,
                title: "Keep people watching to the middle",
                detail: "People watch \(Int(avgRetention * 100))% of your videos on average. Tease what's coming next every few minutes."
            ))
        }

        // "Usual" is the middle video, so half are always below it.
        // Only count videos far below (under half) that are a month old or more.
        let mature = enriched.filter { $0.ageInDays >= 28 }
        let farBelowCount = mature.filter {
            let usual = $0.analytics?.expectedViews ?? 0
            return usual > 0 && $0.views * 2 < usual
        }.count
        if farBelowCount >= 3 {
            fixes.append((
                priority: 1,
                title: "Help YouTube find your videos",
                detail: "\(farBelowCount) of your videos got less than half your usual views. Use the words people search for in your titles, descriptions, tags, thumbnail file names and in the video itself."
            ))
        }

        if fixes.count < 3 {
            for weakness in weaknesses.prefix(3 - fixes.count) {
                fixes.append((priority: 0, title: weakness.title, detail: weakness.detail))
            }
        }

        let sorted = fixes.sorted { $0.priority > $1.priority }.prefix(3)
        return sorted.enumerated().map { index, fix in
            (number: index + 1, title: fix.title, detail: fix.detail)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            if topFixes.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(IntelLook.good)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No big problems found")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(HomeLook.ink)
                        Text("Your numbers look healthy. Keep posting on a steady schedule.")
                            .font(.system(size: 14))
                            .foregroundColor(HomeLook.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .modifier(IntelCard())
            } else {
                // #1 gets the black hero card, like Home's latest video
                if let first = topFixes.first {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FIX THIS FIRST")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1.1)
                            .foregroundColor(HomeLook.purpleLight)
                        Text(first.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(first.detail)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.75))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .modifier(IntelBlackCard())
                }

                // #2 and #3 in one white card
                if topFixes.count > 1 {
                    VStack(spacing: 0) {
                        ForEach(Array(topFixes.dropFirst().enumerated()), id: \.offset) { index, fix in
                            if index > 0 { IntelDivider() }
                            TopFixRow(number: fix.number, title: fix.title, detail: fix.detail)
                        }
                    }
                    .modifier(IntelCard(padding: 4))
                }
            }
        }
    }
}

// MARK: - TopFixRow

struct TopFixRow: View {
    let number: Int
    let title: String
    let detail: String
    var color: Color = IntelLook.bad

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(IntelLook.badText)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(HomeLook.ink)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(HomeLook.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - GrowthQualityCard (bars with a target line)

struct GrowthQualityCard: View {
    let score: GrowthQualityScore
    var videos: [Video] = []

    private enum Status { case good, close, low }

    private func color(_ s: Status) -> Color {
        switch s {
        case .good:  return IntelLook.good
        case .close: return HomeLook.purpleLight
        case .low:   return IntelLook.bad
        }
    }
    private func textColor(_ s: Status) -> Color {
        switch s {
        case .good:  return IntelLook.good
        case .close: return HomeLook.secondary
        case .low:   return IntelLook.badText
        }
    }
    private func label(_ s: Status) -> String {
        switch s {
        case .good:  return "Above target"
        case .close: return "Getting there"
        case .low:   return "Needs work"
        }
    }

    private var gradeStatus: Status {
        switch score.grade {
        case .aPlus, .a: return .good
        case .bPlus, .b: return .close
        case .cPlus, .c: return .low
        }
    }

    // Real: all subs / all views (small videos can't skew it)
    private var channelAvgGPV: Double { score.subsPerThousandViews }

    // Only videos with 1,000+ views can be "best"
    private var bestGPVVideo: Video? {
        videos.filter { $0.views >= 1_000 && $0.growthPerView > 0 }
              .max(by: { $0.growthPerView < $1.growthPerView })
    }

    private struct MetricRow {
        let question: String
        let yourValue: String
        let yourValueSuffix: String
        let targetValue: String
        let fillFraction: Double
        let targetFraction: Double
        let status: Status
        let hint: String?
    }

    private var metricRows: [MetricRow] {
        let gpv = channelAvgGPV
        let retention = score.retentionStrength
        let watchVal  = score.valuePerImpression

        let gpvStatus: Status = gpv >= 0.5 ? .good : (gpv >= 0.2 ? .close : .low)
        let watchStatus: Status = watchVal >= 2.0 ? .good : (watchVal >= 0.5 ? .close : .low)
        let retStatus: Status = retention >= 0.35 ? .good : (retention >= 0.25 ? .close : .low)

        return [
            MetricRow(
                question: "Are viewers subscribing?",
                yourValue: String(format: "%.1f", gpv),
                yourValueSuffix: "subs per 1K views",
                targetValue: "0.5",
                fillFraction: min(gpv / 3.0, 1.0),
                targetFraction: 0.5 / 3.0,
                status: gpvStatus,
                hint: gpv < 0.5 ? "Few viewers subscribe. Give people a reason to come back for the next video." : nil
            ),
            MetricRow(
                question: "How long do people watch?",
                yourValue: String(format: "%.1f", watchVal) + " min",
                yourValueSuffix: "on average",
                targetValue: "2.0 min",
                fillFraction: min(watchVal / 5.0, 1.0),
                targetFraction: 2.0 / 5.0,
                status: watchStatus,
                hint: watchVal < 2.0 ? "People leave before the good part. Start with the best moment." : nil
            ),
            MetricRow(
                question: "How much of each video do they watch?",
                yourValue: String(format: "%.0f%%", retention * 100),
                yourValueSuffix: "on average",
                targetValue: "35%",
                fillFraction: min(retention / 0.50, 1.0),
                targetFraction: 0.35 / 0.50,
                status: retStatus,
                hint: retention < 0.35
                    ? "\(Int((0.35 - retention) * 100)) points below the target. Tease what's coming next every few minutes."
                    : nil
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Score
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(String(format: "%.1f", score.composite))
                            .font(.system(size: 48, weight: .bold))
                            .kerning(-1)
                            .foregroundColor(HomeLook.ink)
                        Text(score.grade.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(textColor(gradeStatus))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(color(gradeStatus).opacity(0.12)))
                    }
                    Text("out of 10")
                        .font(.system(size: 13))
                        .foregroundColor(HomeLook.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Subs per 1K views")
                        .font(.system(size: 12))
                        .foregroundColor(HomeLook.secondary)
                    Text(String(format: "%.1f", channelAvgGPV))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(HomeLook.ink)
                    if let best = bestGPVVideo {
                        Text("Best: \(String(format: "%.1f", best.growthPerView))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(IntelLook.good)
                    }
                }
            }
            .padding(.bottom, 10)

            Text("How well your views turn into subscribers. Higher means each view works harder for you.")
                .font(.system(size: 14))
                .foregroundColor(HomeLook.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            IntelDivider().padding(.bottom, 16)

            VStack(spacing: 0) {
                ForEach(Array(metricRows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        IntelDivider().padding(.vertical, 16)
                    }
                    metricRowView(row)
                }
            }

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(HomeLook.ink)
                    .frame(width: 2, height: 12)
                Text("Black line = target")
                    .font(.system(size: 11))
                    .foregroundColor(HomeLook.secondary)
            }
            .padding(.top, 16)
        }
        .modifier(IntelCard())
    }

    @ViewBuilder
    private func metricRowView(_ row: MetricRow) -> some View {
        VStack(alignment: .leading, spacing: 9) {

            HStack(alignment: .center) {
                Text(row.question)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HomeLook.ink)
                Spacer()
                Text(label(row.status))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textColor(row.status))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(color(row.status).opacity(0.12)))
            }

            // Bar with a target line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(HomeLook.fill)
                        .frame(height: 8)
                    Capsule()
                        .fill(color(row.status))
                        .frame(width: max(geo.size.width * row.fillFraction, 6), height: 8)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(HomeLook.ink)
                        .frame(width: 2, height: 16)
                        .offset(x: geo.size.width * row.targetFraction - 1, y: 0)
                }
                .frame(height: 16)
            }
            .frame(height: 16)

            HStack(alignment: .firstTextBaseline) {
                Text(row.yourValue)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(HomeLook.ink)
                Text(row.yourValueSuffix)
                    .font(.system(size: 13))
                    .foregroundColor(HomeLook.secondary)
                Spacer()
                Text("Target \(row.targetValue)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(HomeLook.secondary)
            }

            if let hint = row.hint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundColor(HomeLook.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - GPVLeaderboard

struct GPVLeaderboard: View {
    enum RankBy { case views, subsPer1K }

    let videos: [Video]
    var allVideos: [Video] = []
    var rankBy: RankBy = .views

    private func viewsText(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 10_000    { return String(format: "%.0fK", Double(n) / 1_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                if index > 0 { IntelDivider() }
                NavigationLink {
                    CoachReviewView(video: video, allVideos: allVideos)
                } label: {
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(index == 0 ? HomeLook.purple : HomeLook.secondary)
                            .frame(width: 20)

                        VideoThumbnailMini(video: video)
                            .frame(width: 56, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .background(HomeLook.fill.clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)))

                        Text(video.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HomeLook.ink)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .trailing, spacing: 1) {
                            switch rankBy {
                            case .views:
                                Text(viewsText(video.views))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(HomeLook.ink)
                                // Subs per 1K only means something with 1,000+ views
                                Text(video.views >= 1_000 && video.growthPerView > 0
                                     ? String(format: "%.1f subs/1K", video.growthPerView)
                                     : "views")
                                    .font(.system(size: 11))
                                    .foregroundColor(HomeLook.secondary)
                            case .subsPer1K:
                                Text(String(format: "%.1f", video.growthPerView))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(gpvColor(video.growthPerView))
                                Text("per 1K · \(viewsText(video.views)) views")
                                    .font(.system(size: 11))
                                    .foregroundColor(HomeLook.secondary)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(HomeLook.hairline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .modifier(IntelCard(padding: 4))
    }

    private func gpvColor(_ gpv: Double) -> Color {
        if gpv >= 3.0 { return IntelLook.good }
        if gpv >= 1.0 { return HomeLook.ink }
        return IntelLook.badText
    }
}

// MARK: - WinningPatternsCard

struct WinningPatternsCard: View {
    let patterns: [WinningPattern]
    var videos: [Video] = []

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(patterns.enumerated()), id: \.offset) { index, pattern in
                if index > 0 { IntelDivider() }
                WinningPatternRow(
                    pattern: pattern,
                    bestVideo: bestVideo(for: pattern),
                    allVideos: videos
                )
                .padding(14)
            }
        }
        .modifier(IntelCard(padding: 4))
    }

    // Patterns don't know which videos they came from yet, so no "best example"
    // (before, every pattern showed the same video, which was misleading)
    private func bestVideo(for pattern: WinningPattern) -> Video? { nil }
}

// MARK: - WinningPatternRow

struct WinningPatternRow: View {
    let pattern: WinningPattern
    var bestVideo: Video?
    var allVideos: [Video] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: pattern.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HomeLook.purple)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(HomeLook.purple.opacity(0.1))
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(pattern.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(HomeLook.ink)
                    Text(pattern.description)
                        .font(.system(size: 13))
                        .foregroundColor(HomeLook.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(pattern.liftText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(pattern.liftIsPositive ? IntelLook.good : IntelLook.badText)
                    .multilineTextAlignment(.trailing)
            }

            if let video = bestVideo {
                NavigationLink {
                    CoachReviewView(video: video, allVideos: allVideos)
                } label: {
                    HStack(spacing: 5) {
                        Text("Best example: \"\(String(video.title.prefix(30)))\"")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(HomeLook.purple)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - ReplicationRow

struct ReplicationRow: View {
    let video: Video
    let score: ReplicationScore

    private var scoreColor: Color {
        switch score {
        case .replicate: return IntelLook.good
        case .oneOff:    return HomeLook.secondary
        case .avoid:     return IntelLook.badText
        }
    }

    private var viewsText: String {
        if video.views >= 1_000_000 { return String(format: "%.1fM views", Double(video.views) / 1_000_000) }
        if video.views >= 1_000     { return String(format: "%.0fK views", Double(video.views) / 1_000) }
        return video.views > 0 ? "\(video.views) views" : "No data yet"
    }

    var body: some View {
        HStack(spacing: 12) {
            VideoThumbnailMini(video: video)
                .frame(width: 72, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .background(HomeLook.fill.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)))

            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HomeLook.ink)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(viewsText)
                    if video.growthPerView > 0 {
                        Text("·")
                        Text(video.growthPerViewLabel)
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(HomeLook.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: score.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(score.rawValue)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(scoreColor)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Kept as they were (may be used on other screens)

// MARK: - IntelligenceMetricBar (kept for any other usage)

struct IntelligenceMetricBar: View {
    let label: String
    let value: Double
    let displayValue: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
                .frame(width: 120, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemFill))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(
                            width: geo.size.width * min(max(value, 0), 1),
                            height: 4
                        )
                        .animation(.easeOut(duration: 0.8), value: value)
                }
                .frame(height: 4)
                .padding(.top, 4)
            }
            .frame(height: 12)

            Text(displayValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

// MARK: - StructuralWeaknessCard

struct StructuralWeaknessCard: View {
    let weaknesses: [StructuralWeakness]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(weaknesses.enumerated()), id: \.offset) { index, weakness in
                if index > 0 {
                    Divider().opacity(0.1).padding(.horizontal, 16)
                }
                WeaknessRow(weakness: weakness)
                    .padding(14)
            }
        }
        .background(Color.orange.opacity(0.06))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - WeaknessRow

struct WeaknessRow: View {
    let weakness: StructuralWeakness

    private var dotColor: Color {
        switch weakness.severity {
        case .critical: return AppTheme.danger
        case .warning:  return .orange
        case .info:     return .yellow
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(weakness.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text(weakness.detail)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - ReplicationBadge

struct ReplicationBadge: View {
    let score: ReplicationScore

    private var color: Color {
        switch score {
        case .replicate: return .green
        case .oneOff:    return .yellow
        case .avoid:     return .red
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: score.icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(score.rawValue)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}
