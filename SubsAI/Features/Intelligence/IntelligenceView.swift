// Features/Intelligence/IntelligenceView.swift
import SwiftUI

struct IntelligenceView: View {

    @ObservedObject var vm: CoachViewModel
    @State private var authError: AuthError?

    init(vm: CoachViewModel) {
        self.vm = vm
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Intelligence")
                                .font(.system(size: 29, weight: .medium, design: .serif)) // was 28
                                .foregroundColor(AppTheme.textPrimary)
                            Text("What the data says about your channel")
                                .font(.system(size: 14)) // was 13
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 8)

                        if vm.isLoading && vm.videos.isEmpty {
                            loadingState
                        } else if !vm.isLoading && vm.videos.filter({ $0.analytics != nil }).count < 3 {
                            notEnoughDataState
                        } else if let report = vm.intelligenceReport {
                            intelligenceContent(report)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18)
                }
                .refreshable { await vm.loadVideos() }
            }
            .navigationBarHidden(true)
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

    @ViewBuilder
    private func intelligenceContent(_ report: ChannelIntelligenceReport) -> some View {

        if !report.winningPatterns.isEmpty {
            sectionLabel("What's working on your channel")
            WinningPatternsCard(patterns: report.winningPatterns, videos: vm.videos)
        }

        sectionLabel("How efficiently is your channel growing?")
        GrowthQualityCard(score: report.growthQualityScore, videos: vm.videos)

        sectionLabel("Your top 3 fixes right now")
        TopFixesCard(videos: vm.videos, weaknesses: report.structuralWeaknesses)

        if let insight = vm.postingTimeInsight {
            sectionLabel("When should you post?")
            PostingTimeCard(insight: insight)
        }

        let gpvVideos = vm.videos
            .filter { $0.growthPerView > 0 }
            .sorted { $0.growthPerView > $1.growthPerView }
        if !gpvVideos.isEmpty {
            sectionLabel("Your best converting videos")
            GPVLeaderboard(videos: Array(gpvVideos.prefix(5)), allVideos: vm.videos)
        }

        let replicateVideos = vm.videosByPriority
            .filter { report.replicationScore(for: $0) == .replicate }
            .prefix(4)
        if !replicateVideos.isEmpty {
            sectionLabel("Videos worth repeating")
            replicationExplainer
            VStack(spacing: 8) {
                ForEach(Array(replicateVideos)) { video in
                    NavigationLink {
                        CoachReviewView(
                            video: video,
                            allVideos: vm.videos,
                            postingTimeInsight: vm.postingTimeInsight,
                            vm: vm
                        )
                    } label: {
                        ReplicationRow(
                            video: video,
                            score: report.replicationScore(for: video)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        comingSoonCard
    }

    private var replicationExplainer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14)) // was 13
                .foregroundColor(AppTheme.accent)
                .padding(.top, 1)
                .frame(width: 20)

            Text("These videos outperformed your channel average on both retention and subscriber conversion. Make more like them.")
                .font(.system(size: 13)) // was 12
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(AppTheme.accent.opacity(0.05))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.accent.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var comingSoonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14)) // was 13
                    .foregroundColor(AppTheme.accent)
                Text("Next video recommendation")
                    .font(.system(size: 15, weight: .medium)) // was 14
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("Coming soon")
                    .font(.system(size: 11, weight: .medium)) // was 10
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(8)
            }
            Text("AI-powered recommendation based on your winning patterns — exact title, hook, format, and posting time for your next upload.")
                .font(.system(size: 14)) // was 13
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)
        }
        .padding(16)
        .background(AppTheme.accent.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.accent.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Analysing your channel…")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var notEnoughDataState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 41)) // was 40
                .foregroundColor(AppTheme.textTertiary)
            Text("Not enough data yet")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
            Text("Intelligence requires at least 3 videos with analytics data.")
                .font(.subheadline)
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold, design: .serif)) // was 16
            .foregroundColor(AppTheme.textPrimary)
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

    private var reliabilityColor: Color {
        insight.isReliable ? .green : .orange
    }

    private var reliabilityLabel: String {
        insight.isReliable ? "Reliable signal" : "Early signal"
    }

    private var gapPercent: Int {
        guard insight.worstDayAvgViews > 0 else { return 0 }
        let gap = Double(insight.bestDayAvgViews - insight.worstDayAvgViews)
            / Double(insight.bestDayAvgViews) * 100
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
                Image(systemName: "clock.fill")
                    .font(.system(size: 14)) // was 13
                    .foregroundColor(.cyan)
                Text("Based on \(insight.sampleSize) videos")
                    .font(.system(size: 12)) // was 11
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text(reliabilityLabel)
                    .font(.system(size: 11, weight: .medium)) // was 10
                    .foregroundColor(reliabilityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(reliabilityColor.opacity(0.1))
                    .cornerRadius(8)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best day")
                        .font(.system(size: 11, weight: .medium)) // was 10
                        .foregroundColor(.green)
                        .kerning(0.5)
                        .textCase(.uppercase)
                    Text(insight.bestDay)
                        .font(.system(size: 23, weight: .medium, design: .serif)) // was 22
                        .foregroundColor(AppTheme.textPrimary)
                    Text("\(formatViews(insight.bestDayAvgViews)) avg views")
                        .font(.system(size: 13)) // was 12
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.green.opacity(0.06))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.green.opacity(0.2), lineWidth: 0.5)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Worst day")
                        .font(.system(size: 11, weight: .medium)) // was 10
                        .foregroundColor(.red)
                        .kerning(0.5)
                        .textCase(.uppercase)
                    Text(insight.worstDay)
                        .font(.system(size: 23, weight: .medium, design: .serif)) // was 22
                        .foregroundColor(AppTheme.textPrimary)
                    Text("\(formatViews(insight.worstDayAvgViews)) avg views")
                        .font(.system(size: 13)) // was 12
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.red.opacity(0.06))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                )
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12)) // was 11
                    .foregroundColor(.cyan)
                    .padding(.top, 1)
                Text("\(insight.bestDay) uploads get \(gapPercent)% more views on average than \(insight.worstDay). Schedule your next upload for \(insight.bestDay).")
                    .font(.system(size: 13)) // was 12
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !insight.isReliable {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12)) // was 11
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                    Text("This is an early signal based on \(insight.sampleSize) videos. It will sharpen as you upload more consistently.")
                        .font(.system(size: 12)) // was 11
                        .foregroundColor(AppTheme.textTertiary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - TopFixesCard
struct TopFixesCard: View {
    let videos: [Video]
    let weaknesses: [StructuralWeakness]

    private var topFixes: [(number: Int, title: String, detail: String, color: Color)] {
        let enriched = videos.filter { $0.analytics != nil }
        guard !enriched.isEmpty else { return [] }

        var fixes: [(priority: Int, title: String, detail: String, color: Color)] = []

        let avgCTR = enriched.compactMap { $0.analytics?.ctr }.reduce(0, +) / Double(enriched.count)
        let lowCTRCount = enriched.filter { ($0.analytics?.ctr ?? 0) < 0.05 }.count
        if avgCTR < 0.05 && lowCTRCount >= 2 {
            fixes.append((
                priority: 3,
                title: "Fix your thumbnails and titles",
                detail: "\(lowCTRCount) of your last \(enriched.count) videos have CTR below 5%. Viewers are seeing your content but not clicking. This is your highest-leverage fix — improving CTR multiplies every other metric.",
                color: .red
            ))
        }

        let avgRetention = enriched.compactMap { $0.analytics?.retention }.reduce(0, +) / Double(enriched.count)
        let lowHookCount = enriched.filter { ($0.analytics?.retention ?? 0) < 0.30 }.count
        if lowHookCount >= 2 {
            fixes.append((
                priority: 2,
                title: "Strengthen your opening 30 seconds",
                detail: "\(lowHookCount) of your last \(enriched.count) videos lose most viewers before the 30% mark. Your hooks need to create immediate curiosity — start with the payoff, not the setup.",
                color: .orange
            ))
        } else if avgRetention < 0.35 {
            fixes.append((
                priority: 1,
                title: "Improve mid-video retention",
                detail: "Your average retention is \(Int(avgRetention * 100))% — below the 35% benchmark. Add a re-hook every 3–4 minutes to pull viewers back before they leave.",
                color: .orange
            ))
        }

        let belowExpectedCount = enriched.filter {
            $0.views < ($0.analytics?.expectedViews ?? 0)
        }.count
        if belowExpectedCount >= 2 {
            fixes.append((
                priority: 1,
                title: "Improve how YouTube finds your videos",
                detail: "\(belowExpectedCount) of your last \(enriched.count) videos are getting fewer views than expected for your CTR. Your titles and descriptions may not be helping YouTube surface your content to the right audience.",
                color: .yellow
            ))
        }

        if fixes.count < 3 {
            for weakness in weaknesses.prefix(3 - fixes.count) {
                fixes.append((
                    priority: 0,
                    title: weakness.title,
                    detail: weakness.detail,
                    color: .yellow
                ))
            }
        }

        let sorted = fixes.sorted { $0.priority > $1.priority }.prefix(3)
        return sorted.enumerated().map { index, fix in
            (number: index + 1, title: fix.title, detail: fix.detail, color: fix.color)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if topFixes.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 21)) // was 20
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No major issues found")
                            .font(.system(size: 15, weight: .medium)) // was 14
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Your channel metrics are above benchmark. Keep uploading consistently.")
                            .font(.system(size: 13)) // was 12
                            .foregroundColor(AppTheme.textSecondary)
                            .lineSpacing(3)
                    }
                }
                .padding(16)
            } else {
                ForEach(Array(topFixes.enumerated()), id: \.offset) { index, fix in
                    if index > 0 {
                        Divider().padding(.horizontal, 16)
                    }
                    TopFixRow(number: fix.number, title: fix.title, detail: fix.detail, color: fix.color)
                }
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - TopFixRow
struct TopFixRow: View {
    let number: Int
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 14, weight: .semibold)) // was 13
                    .foregroundColor(color)
            }
            .frame(width: 28)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium)) // was 13
                    .foregroundColor(AppTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 13)) // was 12
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
    }
}

// MARK: - GrowthQualityCard
struct GrowthQualityCard: View {
    let score: GrowthQualityScore
    var videos: [Video] = []

    private var gradeColor: Color {
        switch score.grade {
        case .aPlus, .a: return .green
        case .bPlus, .b: return .yellow
        case .cPlus, .c: return .red
        }
    }

    private var channelAvgGPV: Double {
        let gpvVideos = videos.filter { $0.growthPerView > 0 }
        guard !gpvVideos.isEmpty else { return 0 }
        return gpvVideos.map { $0.growthPerView }.reduce(0, +) / Double(gpvVideos.count)
    }

    private var bestGPVVideo: Video? {
        videos.filter { $0.growthPerView > 0 }
              .max(by: { $0.growthPerView < $1.growthPerView })
    }

    private var gpvColor: Color {
        let gpv = channelAvgGPV
        if gpv >= 3.0 { return .green }
        if gpv >= 1.0 { return .yellow }
        if gpv > 0    { return .red }
        return AppTheme.textTertiary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(String(format: "%.1f", score.composite))
                            .font(.system(size: 43, weight: .light, design: .serif)) // was 42
                            .foregroundColor(AppTheme.textPrimary)
                        Text(score.grade.rawValue)
                            .font(.system(size: 14, weight: .semibold)) // was 13
                            .foregroundColor(gradeColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(gradeColor.opacity(0.12))
                            .cornerRadius(10)
                    }
                    Text("out of 10")
                        .font(.system(size: 13)) // was 12
                        .foregroundColor(AppTheme.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Subs per 1K views")
                        .font(.system(size: 12)) // was 11
                        .foregroundColor(AppTheme.textTertiary)
                    if channelAvgGPV > 0 {
                        Text(String(format: "%.1f avg", channelAvgGPV))
                            .font(.system(size: 17, weight: .medium, design: .serif)) // was 16
                            .foregroundColor(gpvColor)
                    } else {
                        Text(String(format: "~%.1f est.", score.subsPerThousandViews))
                            .font(.system(size: 17, weight: .medium, design: .serif)) // was 16
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    if let best = bestGPVVideo {
                        Text("Best: \(String(format: "%.1f", best.growthPerView))/1K")
                            .font(.system(size: 11)) // was 10
                            .foregroundColor(.green)
                    }
                }
            }

            Text("How efficiently your channel converts views into subscribers. A higher score means each view is working harder for your channel.")
                .font(.system(size: 13)) // was 12
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)

            Divider()

            VStack(spacing: 10) {
                IntelligenceMetricBar(
                    label: "Sub conversion",
                    value: channelAvgGPV > 0
                        ? min(channelAvgGPV / 3.0, 1.0)
                        : min(score.subsPerThousandViews / 2.0, 1.0),
                    displayValue: channelAvgGPV > 0
                        ? String(format: "%.1f/1K", channelAvgGPV)
                        : String(format: "%.2f%%", score.subsPerThousandViews / 10.0),
                    color: AppTheme.accent
                )
                IntelligenceMetricBar(
                    label: "Value / impression",
                    value: min(score.valuePerImpression / 3.0, 1.0),
                    displayValue: String(format: "%.1f min", score.valuePerImpression),
                    color: .cyan
                )
                IntelligenceMetricBar(
                    label: "Retention strength",
                    value: min(score.retentionStrength / 0.50, 1.0),
                    displayValue: String(format: "%.0f%%", score.retentionStrength * 100),
                    color: .green
                )
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - GPVLeaderboard
struct GPVLeaderboard: View {
    let videos: [Video]
    var allVideos: [Video] = []

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                if index > 0 {
                    Divider().padding(.horizontal, 14)
                }
                NavigationLink {
                    CoachReviewView(video: video, allVideos: allVideos)
                } label: {
                    HStack(spacing: 10) {
                        Text("#\(index + 1)")
                            .font(.system(size: 13, weight: .medium, design: .serif)) // was 12
                            .foregroundColor(index == 0 ? .green : AppTheme.textTertiary)
                            .frame(width: 24, alignment: .leading)

                        VideoThumbnailMini(video: video)
                            .frame(width: 56, height: 32)
                            .cornerRadius(6)
                            .clipped()
                            .background(Color.gray.opacity(0.2).cornerRadius(6))

                        Text(video.title)
                            .font(.system(size: 13, weight: .medium)) // was 12
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%.1f", video.growthPerView))
                                .font(.system(size: 15, weight: .medium, design: .serif)) // was 14
                                .foregroundColor(gpvColor(video.growthPerView))
                            Text("per 1K")
                                .font(.system(size: 10)) // was 9
                                .foregroundColor(AppTheme.textTertiary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11)) // was 10
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }

    private func gpvColor(_ gpv: Double) -> Color {
        if gpv >= 3.0 { return .green }
        if gpv >= 1.0 { return .yellow }
        return .red
    }
}

// MARK: - IntelligenceMetricBar
struct IntelligenceMetricBar: View {
    let label: String
    let value: Double
    let displayValue: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13)) // was 12
                .foregroundColor(AppTheme.textSecondary)
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
                .font(.system(size: 13, weight: .medium)) // was 12
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

// MARK: - WinningPatternsCard
struct WinningPatternsCard: View {
    let patterns: [WinningPattern]
    var videos: [Video] = []

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(patterns.enumerated()), id: \.offset) { index, pattern in
                if index > 0 {
                    Divider().padding(.horizontal, 16)
                }
                WinningPatternRow(
                    pattern: pattern,
                    bestVideo: bestVideo(for: pattern),
                    allVideos: videos
                )
                .padding(14)
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }

    private func bestVideo(for pattern: WinningPattern) -> Video? {
        videos.filter { $0.growthPerView > 0 }
              .max(by: { $0.growthPerView < $1.growthPerView })
    }
}

// MARK: - WinningPatternRow
struct WinningPatternRow: View {
    let pattern: WinningPattern
    var bestVideo: Video?
    var allVideos: [Video] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.success.opacity(0.1))
                        .frame(width: 30, height: 30)
                    Image(systemName: pattern.icon)
                        .font(.system(size: 13)) // was 12
                        .foregroundColor(AppTheme.success)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.title)
                        .font(.system(size: 14, weight: .medium)) // was 13
                        .foregroundColor(AppTheme.textPrimary)
                    Text(pattern.description)
                        .font(.system(size: 12)) // was 11
                        .foregroundColor(AppTheme.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(2)
                }
                Spacer()
                Text(pattern.liftText)
                    .font(.system(size: 12, weight: .semibold)) // was 11
                    .foregroundColor(pattern.liftIsPositive ? AppTheme.success : AppTheme.danger)
                    .multilineTextAlignment(.trailing)
            }

            if let video = bestVideo {
                NavigationLink {
                    CoachReviewView(video: video, allVideos: allVideos)
                } label: {
                    HStack(spacing: 5) {
                        Text("Best example: \"\(String(video.title.prefix(30)))\"")
                            .font(.system(size: 12)) // was 11
                            .foregroundColor(AppTheme.accent)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11)) // was 10
                            .foregroundColor(AppTheme.accent)
                    }
                }
                .buttonStyle(.plain)
            }
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
                    Divider().padding(.horizontal, 16)
                }
                WeaknessRow(weakness: weakness)
                    .padding(14)
            }
        }
        .background(Color.orange.opacity(0.05))
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
                .frame(width: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(weakness.title)
                    .font(.system(size: 14, weight: .medium)) // was 13
                    .foregroundColor(AppTheme.textPrimary)
                Text(weakness.detail)
                    .font(.system(size: 13)) // was 12
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
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
        case .replicate: return .green
        case .oneOff:    return .yellow
        case .avoid:     return .red
        }
    }

    private var viewsText: String {
        if video.views >= 1_000_000 { return String(format: "%.1fM views", Double(video.views) / 1_000_000) }
        if video.views >= 1_000     { return String(format: "%.0fK views", Double(video.views) / 1_000) }
        return video.views > 0 ? "\(video.views) views" : "No data yet"
    }

    private func gpvColor(_ gpv: Double) -> Color {
        if gpv >= 3.0 { return .green }
        if gpv >= 1.0 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            VideoThumbnailMini(video: video)
                .frame(width: 72, height: 42)
                .cornerRadius(6)
                .clipped()
                .background(Color.gray.opacity(0.2).cornerRadius(6))

            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 14, weight: .medium)) // was 13
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(viewsText)
                        .font(.system(size: 12)) // was 11
                        .foregroundColor(AppTheme.textSecondary)
                    if video.growthPerView > 0 {
                        Text("·")
                            .font(.system(size: 12)) // was 11
                            .foregroundColor(AppTheme.textTertiary)
                        Text(video.growthPerViewLabel)
                            .font(.system(size: 12)) // was 11
                            .foregroundColor(gpvColor(video.growthPerView))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(score.rawValue)
                    .font(.system(size: 12, weight: .semibold)) // was 11
                    .foregroundColor(scoreColor)
                Image(systemName: score.icon)
                    .font(.system(size: 12)) // was 11
                    .foregroundColor(scoreColor)
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
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
                .font(.system(size: 11)) // was 10
                .foregroundColor(color)
            Text(score.rawValue)
                .font(.system(size: 11, weight: .semibold)) // was 10
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
