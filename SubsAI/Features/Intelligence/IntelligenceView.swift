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
                                .font(.system(size: 28, weight: .medium, design: .serif))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("What the data says about your channel")
                                .font(.system(size: 13))
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

        // Patterns first — the most immediately actionable insight
        if !report.winningPatterns.isEmpty {
            sectionLabel("Winning patterns")
            WinningPatternsCard(patterns: report.winningPatterns, videos: vm.videos)
        }

        if !report.structuralWeaknesses.isEmpty {
            sectionLabel("What to fix")
            StructuralWeaknessCard(weaknesses: report.structuralWeaknesses)
        }

        sectionLabel("Should you make more?")
        replicationExplainer
        replicationSection(report)

        let gpvVideos = vm.videos
            .filter { $0.growthPerView > 0 }
            .sorted { $0.growthPerView > $1.growthPerView }
        if !gpvVideos.isEmpty {
            sectionLabel("Best converting videos")
            GPVLeaderboard(videos: Array(gpvVideos.prefix(5)), allVideos: vm.videos)
        }

        // Score last — supporting context, not the headline
        sectionLabel("Growth quality score")
        GrowthQualityCard(score: report.growthQualityScore, videos: vm.videos)

        comingSoonCard
    }

    private var replicationExplainer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.accent)
                .padding(.top, 1)
                .frame(width: 20)

            Text("Each video is rated based on whether it outperformed your channel average. Replicate means make more like it. One-off means it was a lucky spike. Avoid means this format isn't working for your channel.")
                .font(.system(size: 12))
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

    private func replicationSection(_ report: ChannelIntelligenceReport) -> some View {
        VStack(spacing: 8) {
            ForEach(vm.videosByPriority.prefix(6)) { video in
                NavigationLink {
                    CoachReviewView(video: video, allVideos: vm.videos)
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

    private var comingSoonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.accent)
                Text("Next video recommendation")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("Coming soon")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(8)
            }
            Text("AI-powered recommendation based on your winning patterns — exact title, hook, format, and posting time for your next upload.")
                .font(.system(size: 13))
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
                .font(.system(size: 40))
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
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .kerning(1.0)
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
                            .font(.system(size: 42, weight: .light, design: .serif))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(score.grade.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(gradeColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(gradeColor.opacity(0.12))
                            .cornerRadius(10)
                    }
                    Text("out of 10")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Subs per 1K views")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textTertiary)
                    if channelAvgGPV > 0 {
                        Text(String(format: "%.1f avg", channelAvgGPV))
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundColor(gpvColor)
                    } else {
                        Text(String(format: "~%.1f est.", score.subsPerThousandViews))
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    if let best = bestGPVVideo {
                        Text("Best: \(String(format: "%.1f", best.growthPerView))/1K")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
            }

            Text("Your Growth Quality Score measures how efficiently your channel converts views into subscribers and watch time. A higher score means each view is working harder for your channel.")
                .font(.system(size: 12))
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
// Each row now links to CoachReviewView for that video
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
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundColor(index == 0 ? .green : AppTheme.textTertiary)
                            .frame(width: 24, alignment: .leading)

                        VideoThumbnailMini(video: video)
                            .frame(width: 56, height: 32)
                            .cornerRadius(6)
                            .clipped()

                        Text(video.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%.1f", video.growthPerView))
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundColor(gpvColor(video.growthPerView))
                            Text("per 1K")
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.textTertiary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
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
                .font(.system(size: 12))
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
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

// MARK: - WinningPatternsCard
// Now accepts videos so it can find the best example for each pattern
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

    // Find the highest GPV video as the best example for any pattern
    private func bestVideo(for pattern: WinningPattern) -> Video? {
        videos.filter { $0.growthPerView > 0 }
              .max(by: { $0.growthPerView < $1.growthPerView })
    }
}

// MARK: - WinningPatternRow
// Now shows "Best example: [title] →" linking to CoachReviewView
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
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.success)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(pattern.description)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(2)
                }
                Spacer()
                Text(pattern.liftText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(pattern.liftIsPositive ? AppTheme.success : AppTheme.danger)
                    .multilineTextAlignment(.trailing)
            }

            // Best example link
            if let video = bestVideo {
                NavigationLink {
                    CoachReviewView(video: video, allVideos: allVideos)
                } label: {
                    HStack(spacing: 5) {
                        Text("Best example: \"\(String(video.title.prefix(30)))\"")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.accent)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
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
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 4 }

            VStack(alignment: .leading, spacing: 3) {
                Text(weakness.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                Text(weakness.detail)
                    .font(.system(size: 12))
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

            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(viewsText)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                    if video.growthPerView > 0 {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textTertiary)
                        Text(video.growthPerViewLabel)
                            .font(.system(size: 11))
                            .foregroundColor(gpvColor(video.growthPerView))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(score.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(scoreColor)
                Image(systemName: score.icon)
                    .font(.system(size: 11))
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
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(score.rawValue)
                .font(.system(size: 10, weight: .semibold))
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
