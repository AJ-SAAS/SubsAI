// Features/Coach/CoachReviewView.swift
import SwiftUI

struct CoachReviewView: View {
    let video: Video
    var allVideos: [Video] = []
    var postingTimeInsight: PostingTimeInsight? = nil
    var vm: CoachViewModel? = nil

    private var verdict: CoachVerdict { video.verdict }
    private var fix: CoachFix { video.primaryFix }

    private var daysAgo: String {
        let days = Calendar.current.dateComponents([.day], from: video.publishedAt, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    private var gpvColor: Color {
        let gpv = video.growthPerView
        if gpv >= 3.0 { return .green }
        if gpv >= 1.0 { return .yellow }
        if gpv > 0    { return .red }
        return AppTheme.textTertiary
    }

    // MARK: - Pattern detection across all videos
    private var isPatternAcrossChannel: Bool {
        guard allVideos.count >= 3 else { return false }
        let videosWithData = allVideos.filter { $0.analytics != nil }
        guard videosWithData.count >= 3 else { return false }

        switch fix {
        case .thumbnail:
            let lowCTR = videosWithData.filter { ($0.analytics?.ctr ?? 0) < 0.05 }
            return Double(lowCTR.count) / Double(videosWithData.count) >= 0.6
        case .hook:
            let lowRetention = videosWithData.filter { ($0.analytics?.retention ?? 0) < 0.30 }
            return Double(lowRetention.count) / Double(videosWithData.count) >= 0.6
        case .retention:
            let midDrop = videosWithData.filter { ($0.analytics?.retention ?? 0) < 0.35 }
            return Double(midDrop.count) / Double(videosWithData.count) >= 0.6
        case .discovery:
            let belowExpected = videosWithData.filter {
                $0.views < ($0.analytics?.expectedViews ?? 0)
            }
            return Double(belowExpected.count) / Double(videosWithData.count) >= 0.6
        case .none:
            return false
        }
    }

    private var patternText: String {
        let videosWithData = allVideos.filter { $0.analytics != nil }
        let total = videosWithData.count

        switch fix {
        case .thumbnail:
            let count = videosWithData.filter { ($0.analytics?.ctr ?? 0) < 0.05 }.count
            return "\(count) of your last \(total) videos have CTR below 5%. This is a channel-wide pattern, not just this video — your thumbnail strategy needs a systematic rethink."
        case .hook:
            let count = videosWithData.filter { ($0.analytics?.retention ?? 0) < 0.30 }.count
            return "\(count) of your last \(total) videos have retention below 30%. Your hook is consistently losing people — this is the single highest-leverage thing to fix across your whole channel."
        case .retention:
            let count = videosWithData.filter { ($0.analytics?.retention ?? 0) < 0.35 }.count
            return "\(count) of your last \(total) videos drop below 35% retention. Mid-video pacing is a channel pattern — add a re-hook every 3–4 minutes across all your upcoming videos."
        case .discovery:
            let count = videosWithData.filter {
                $0.views < ($0.analytics?.expectedViews ?? 0)
            }.count
            return "\(count) of your last \(total) videos are underperforming on views despite decent CTR. This suggests a metadata pattern — your titles and descriptions may not be helping YouTube surface your content."
        case .none:
            return ""
        }
    }

    private var isolatedText: String {
        switch fix {
        case .thumbnail:
            return "This is isolated to this video — your other videos have decent CTR. Something specific about this thumbnail or title isn't landing."
        case .hook:
            return "This is isolated to this video — your other videos hold retention better. Something specific about how this one starts isn't working."
        case .retention:
            return "This is isolated to this video — your retention is generally solid. There may be a specific section in this video where pacing dropped."
        case .discovery:
            return "This is isolated to this video — your other videos are getting expected views. Something specific about this video's metadata may be holding it back."
        case .none:
            return ""
        }
    }

    // MARK: - Posting day label
    private var publishedDayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: video.publishedAt)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {

                    // MARK: - Thumbnail
                    thumbnailSection

                    // MARK: - Title
                    Text(video.title)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // MARK: - Growth scorecard strip
                    if video.analytics != nil {
                        growthScorecardStrip
                    }

                    // MARK: - Verdict
                    verdictCard

                    // MARK: - Metrics
                    metricsCard

                    // MARK: - #1 Fix
                    if fix != .none {
                        fixCard
                    }

                    // MARK: - What's working
                    workingWellCard

                    // MARK: - Is this a pattern?
                    if fix != .none {
                        patternStrip
                    }

                    // MARK: - Deep Analyze button
                    NavigationLink {
                        VideoDeepAnalysisView(video: video, allVideos: allVideos)
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 15))
                                Text("Deep analyze this video")
                                    .font(.system(size: 15, weight: .medium))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.accent)
                            .cornerRadius(16)

                            Text("Hook analysis · Retention curve · Compare with your best videos")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Video Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pattern strip
    private var patternStrip: some View {
        let isPattern = isPatternAcrossChannel
        let color: Color = isPattern ? .orange : AppTheme.accent

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: isPattern ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(isPattern ? "Channel pattern" : "Isolated to this video")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(color)
                    .kerning(1.0)
                    .textCase(.uppercase)
            }

            Text(isPattern ? patternText : isolatedText)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if isPattern, let vm = vm {
                NavigationLink {
                    IntelligenceView(vm: vm)
                } label: {
                    HStack(spacing: 4) {
                        Text("See full channel analysis in Intelligence")
                            .font(.system(size: 12))
                            .foregroundColor(color)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundColor(color)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Thumbnail
    private var thumbnailSection: some View {
        ZStack(alignment: .bottomTrailing) {
            VideoThumbnailView(video: video)
                .frame(height: 200)
                .cornerRadius(16)
                .clipped()

            Text(daysAgo)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.55))
                .cornerRadius(8)
                .padding(10)
        }
    }

    // MARK: - Growth scorecard strip
    private var growthScorecardStrip: some View {
        HStack(spacing: 0) {
            ScorecardCell(
                value: video.growthPerView > 0
                    ? String(format: "%.1f", video.growthPerView)
                    : "—",
                label: "Subs / 1K views",
                valueColor: video.growthPerView > 0 ? gpvColor : AppTheme.textTertiary
            )

            Divider().frame(height: 36)

            ScorecardCell(
                value: video.analytics.map {
                    $0.averageViewDuration >= 60
                        ? String(format: "%.1fm", Double($0.averageViewDuration) / 60.0)
                        : "\($0.averageViewDuration)s"
                } ?? "—",
                label: "Avg watch time",
                valueColor: AppTheme.textPrimary
            )

            Divider().frame(height: 36)

            ScorecardCell(
                value: video.analytics.map {
                    String(format: "%.0f%%", $0.retention * 100)
                } ?? "—",
                label: "Retention",
                valueColor: video.analytics.map {
                    $0.retention >= 0.35 ? Color.green : ($0.retention >= 0.25 ? Color.yellow : Color.red)
                } ?? AppTheme.textTertiary
            )
        }
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Verdict card
    private var verdictCard: some View {
        let isHealthy = fix == .none
        let cardColor: Color = isHealthy ? .green : .red
        let label = isHealthy ? "Performing well" : "Needs attention"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(cardColor)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(cardColor)
            }

            Text(verdictText)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardColor.opacity(0.06))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(cardColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var verdictText: String {
        guard let stats = video.analytics else {
            return "Analytics are still loading for this video. Check back shortly."
        }
        switch fix {
        case .thumbnail:
            return "Your content is strong — but your thumbnail isn't getting clicked. Fix the packaging, not the video."
        case .hook:
            return "Viewers are clicking but leaving early. Your hook isn't holding them. The first 30 seconds need work."
        case .retention:
            return "Good start, but viewers are dropping before your best content. Your pacing needs attention mid-video."
        case .discovery:
            return "This video performs well when watched — but YouTube isn't surfacing it enough. A metadata issue, not a content issue."
        case .none:
            let ret = Int(stats.retention * 100)
            let ctr = String(format: "%.1f", stats.ctr * 100)
            return "This video is working. \(ctr)% CTR and \(ret)% retention — both above benchmark. Study this format and repeat it."
        }
    }

    // MARK: - Metrics card
    private var metricsCard: some View {
        let postingTimeLine = postingTimeInsight?.reviewLine(for: video)
        let hasPostingTimeRow = postingTimeLine != nil

        return VStack(spacing: 0) {
            if let stats = video.analytics {
                ReviewMetricRow(
                    name: "Click-through rate",
                    value: String(format: "%.1f%%", stats.ctr * 100),
                    benchmark: "Benchmark: 5–7%",
                    progress: min(stats.ctr / 0.07, 1.0),
                    isGood: stats.ctr >= 0.05,
                    explanation: ctrExplanation(stats.ctr),
                    isLast: false
                )
                ReviewMetricRow(
                    name: "Retention",
                    value: String(format: "%.0f%%", stats.retention * 100),
                    benchmark: stats.retention >= 0.35 ? "Above benchmark" : "Benchmark: 35%+",
                    progress: min(stats.retention / 0.50, 1.0),
                    isGood: stats.retention >= 0.35,
                    explanation: retentionExplanation(stats.retention),
                    isLast: false
                )
                ReviewMetricRow(
                    name: "Views",
                    value: formatViews(video.views),
                    benchmark: video.views >= stats.expectedViews
                        ? "Above expected"
                        : "Expected: \(formatViews(stats.expectedViews))+",
                    progress: min(Double(video.views) / Double(max(stats.expectedViews, 1)), 1.0),
                    isGood: video.views >= stats.expectedViews,
                    explanation: viewsExplanation(
                        video.views,
                        expected: stats.expectedViews,
                        ctr: stats.ctr
                    ),
                    isLast: stats.subscribersGained == 0 && !hasPostingTimeRow
                )

                if stats.subscribersGained > 0 {
                    ReviewMetricRow(
                        name: "Subscribers gained",
                        value: "+\(stats.subscribersGained)",
                        benchmark: video.growthPerView >= 1.0
                            ? "Good conversion"
                            : "Avg: 1+ per 1K views",
                        progress: min(video.growthPerView / 3.0, 1.0),
                        isGood: video.growthPerView >= 1.0,
                        explanation: subsExplanation(
                            stats.subscribersGained,
                            gpv: video.growthPerView
                        ),
                        isLast: !hasPostingTimeRow
                    )
                }

                if let line = postingTimeLine {
                    ReviewMetricRow(
                        name: "Posting time",
                        value: publishedDayLabel,
                        benchmark: "Not your best day",
                        progress: 0.3,
                        isGood: false,
                        explanation: line,
                        isLast: true
                    )
                }

            } else {
                Text("Analytics loading…")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Fix card
    private var fixCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your #1 fix")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.red)
                .kerning(1.0)
                .textCase(.uppercase)

            Text(fix.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(2)

            Text(fixInstruction)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let example = fixExample {
                Text(example)
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(AppTheme.accent.opacity(0.9))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.accent.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.accent.opacity(0.2), lineWidth: 0.5)
                    )
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.05))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.red.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var fixInstruction: String {
        switch fix {
        case .thumbnail:
            return "Your title describes what you did, not what the viewer gets. Add a specific outcome, number, or timeframe to make it impossible to scroll past."
        case .hook:
            return "You're explaining what the video is about instead of starting inside the story. Drop viewers into the most interesting moment first — context can come later."
        case .retention:
            return "Viewers are losing interest mid-video. Add a re-hook every 3–4 minutes — a single line that creates new curiosity and pulls them forward."
        case .discovery:
            return "Your title and description aren't helping YouTube understand who to show this to. Use specific, searchable language that matches what your ideal viewer actually types."
        case .none:
            return "No immediate action needed."
        }
    }

    private var fixExample: String? {
        switch fix {
        case .thumbnail:
            return "Instead of: \"How I built a SaaS\" → Try: \"I built a SaaS in 7 days with $0 — here's what happened\""
        case .hook:
            return "Instead of: \"Hey everyone, today we're going to...\" → Try: \"Day 7. Zero dollars. Here's the moment it made its first sale.\""
        case .retention:
            return "At the 3-minute mark, add: \"But here's where it gets interesting — this one thing changed everything...\""
        case .discovery:
            return "Add to your description: the specific problem you solve, who it's for, and what they'll learn — in the first two lines."
        case .none:
            return nil
        }
    }

    // MARK: - What's working
    @ViewBuilder
    private var workingWellCard: some View {
        let wins = workingWell
        if !wins.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("What's working")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(wins, id: \.self) { win in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.top, 3)
                            Text(win)
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.05))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.green.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    private var workingWell: [String] {
        guard let stats = video.analytics else { return [] }
        var wins: [String] = []

        if stats.retention >= 0.40 {
            wins.append("\(Int(stats.retention * 100))% retention — viewers who clicked stayed for over half the video. Your content delivers on its promise.")
        }
        if stats.ctr >= 0.07 {
            wins.append("\(String(format: "%.1f", stats.ctr * 100))% CTR — your thumbnail and title are working. This is above the 7% benchmark.")
        }
        if video.views >= stats.expectedViews {
            wins.append("Views are above expectations for your channel — YouTube is distributing this well.")
        }
        if stats.averageViewDuration > 60 {
            wins.append("Average watch duration of \(stats.averageViewDuration)s — viewers are genuinely engaged with the content.")
        }
        if video.growthPerView >= 2.0 {
            wins.append("This video is converting \(String(format: "%.1f", video.growthPerView)) subscribers per 1,000 views — well above the channel average. It's a growth machine.")
        }
        if fix == .none {
            wins.append("This format is working. Study the hook, title structure, and opening — then repeat it on your next upload.")
        }

        return wins
    }

    // MARK: - Metric explanations
    private func ctrExplanation(_ ctr: Double) -> String {
        let per100 = Int(ctr * 100)
        if ctr >= 0.07 {
            return "About \(per100) in every 100 people who saw your thumbnail clicked. That's above benchmark — your packaging is working."
        } else if ctr >= 0.04 {
            return "About \(per100) in every 100 people clicked. There's room to improve — a stronger title or thumbnail could meaningfully increase your reach."
        } else {
            return "Only \(per100) in every 100 people who saw your thumbnail clicked. This is the single biggest thing holding this video back."
        }
    }

    private func retentionExplanation(_ retention: Double) -> String {
        let pct = Int(retention * 100)
        if retention >= 0.45 {
            return "Viewers watched \(pct)% of the video on average — that's genuinely strong. Your content is keeping people engaged."
        } else if retention >= 0.30 {
            return "Viewers watched \(pct)% on average. Solid, but there's likely a drop-off point mid-video worth investigating in the deep analysis."
        } else {
            return "Viewers only watched \(pct)% on average. Most are leaving early — your hook or early content needs work."
        }
    }

    private func viewsExplanation(_ views: Int, expected: Int, ctr: Double) -> String {
        if views >= expected {
            return "Views are above what we'd expect for a video with this CTR and retention. YouTube is distributing it well."
        } else if ctr < 0.05 {
            return "Views are below expectations — and the low CTR is the reason. More clicks = more views. Fix the thumbnail and this number follows."
        } else {
            return "Views are below expectations despite decent CTR. This suggests a discovery issue — check your title tags and description keywords."
        }
    }

    private func subsExplanation(_ subs: Int, gpv: Double) -> String {
        if gpv >= 3.0 {
            return "This video is converting \(String(format: "%.1f", gpv)) subscribers per 1,000 views — that's exceptional. It's actively building your channel, not just getting views."
        } else if gpv >= 1.0 {
            return "Decent sub conversion at \(String(format: "%.1f", gpv)) per 1,000 views. Videos that convert above 2.0 are your strongest channel-builders."
        } else {
            return "Low sub conversion — viewers are watching but not subscribing. This could mean the content doesn't make a strong case for why they should come back."
        }
    }

    private func formatViews(_ views: Int) -> String {
        if views >= 1_000_000 { return String(format: "%.1fM", Double(views) / 1_000_000) }
        if views >= 1_000     { return String(format: "%.0fK", Double(views) / 1_000) }
        return "\(views)"
    }
}

// MARK: - ReviewMetricRow
struct ReviewMetricRow: View {
    let name: String
    let value: String
    let benchmark: String
    let progress: Double
    let isGood: Bool
    let explanation: String
    let isLast: Bool

    private var barColor: Color {
        isGood ? .green : (progress > 0.6 ? .yellow : .red)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Metric name — larger, primary color, readable in both modes
                Text(name.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .kerning(0.6)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    // Stat number — larger and bolder so it reads as the hero
                    Text(value)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(benchmark)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isGood ? .green : .red)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemFill))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(
                            width: geo.size.width * min(max(progress, 0), 1),
                            height: 4
                        )
                        .animation(.easeOut(duration: 0.8), value: progress)
                }
            }
            .frame(height: 4)

            Text(explanation)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)

        if !isLast {
            Divider()
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - ScorecardCell
struct ScorecardCell: View {
    let value: String
    let label: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(valueColor)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}
