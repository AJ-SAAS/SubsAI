// Features/VideoAnalytics/HookAnalysisView.swift
import SwiftUI

struct HookAnalysisView: View {
    let analysis: VideoDeepAnalysis

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Hook bar breakdown
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("Who stayed · first 15 seconds")

                    VStack(spacing: 10) {
                        ForEach(analysis.hookSegments) { segment in
                            HookSegmentRow(segment: segment)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
                    )

                    if let weak = analysis.hookWeakPoint {
                        hookVerdictCard(weak)
                    }
                }

                // MARK: - What it means
                sectionLabel("What this means")

                ForEach(hookInsights(for: analysis), id: \.title) { insight in
                    InsightBlock(
                        title: insight.title,
                        content: insight.body,
                        accentColor: insight.color
                    )
                }

                // MARK: - Hook rewrite — coming soon
                sectionLabel("Hook rewrite")
                hookRewriteComingSoon

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: - Verdict card
    private func hookVerdictCard(_ segment: HookSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What happened here")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textTertiary)
                .kerning(0.6)
                .textCase(.uppercase)
            Text(hookVerdictText(for: segment))
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.accent.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Coming soon card
    private var hookRewriteComingSoon: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.accent)
                Text("AI hook rewrite")
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
            Text("We'll look at how your video starts, find the weak spot, and write you a stronger opening line — based on what's already working on your channel.")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(AppTheme.accent.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.accent.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .kerning(0.8)
    }

    private func hookVerdictText(for segment: HookSegment) -> String {
        switch segment.status {
        case .weak:
            return "You lost a lot of viewers in the \(segment.label) window. Most of the time this happens because the video starts with an explanation — telling people what's about to happen instead of just showing it. The best hooks drop you into the middle of something already going on."
        case .warning:
            return "A few viewers dropped off in the \(segment.label) window. Try getting to the good part 2–3 seconds faster. Cut the setup and start with the most interesting thing."
        case .strong:
            return "Your hook held strong through \(segment.label) — people stayed. Now make sure the rest of the video keeps that energy going."
        }
    }

    private struct HookInsight {
        let title: String
        let body: String
        let color: Color
    }

    private func hookInsights(for analysis: VideoDeepAnalysis) -> [HookInsight] {
        var insights: [HookInsight] = []

        let weakSegments   = analysis.hookSegments.filter { $0.status == .weak }
        let strongSegments = analysis.hookSegments.filter { $0.status == .strong }

        if !weakSegments.isEmpty {
            insights.append(HookInsight(
                title: "The drop at \(weakSegments.first?.label ?? "the start")",
                body: "People left before they gave your video a real chance. This usually means the first few seconds felt slow or unclear. Instead of explaining what the video is about, just start doing it — show the result first, explain later.",
                color: .red
            ))
        }

        if !strongSegments.isEmpty {
            insights.append(HookInsight(
                title: "What kept people watching",
                body: "The viewers who made it past \(strongSegments.last?.label ?? "the hook") stuck around. That means your content is actually good — the opening just needs to match that quality so more people get to see it.",
                color: .green
            ))
        }

        insights.append(HookInsight(
            title: "A pattern on your channel",
            body: "Story-style openings — where you start in the middle of something happening — tend to keep more people watching in your first 15 seconds. The more you can open like that, the better.",
            color: AppTheme.accent
        ))

        return insights
    }
}

// MARK: - HookSegmentRow
struct HookSegmentRow: View {
    let segment: HookSegment

    private var barColor: Color {
        switch segment.status {
        case .strong:  return .green
        case .warning: return .yellow
        case .weak:    return .red
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(segment.label)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 7)
                    Capsule()
                        .fill(barColor)
                        .frame(
                            width: geo.size.width * segment.retention,
                            height: 7
                        )
                        .animation(.easeOut(duration: 0.6), value: segment.retention)
                }
                .frame(height: 7)
                .padding(.top, 4)
            }
            .frame(height: 14)

            Text("\(Int(segment.retention * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - InsightBlock
struct InsightBlock: View {
    let title: String
    let content: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(accentColor)
                .kerning(0.6)

            Text(content)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
        .overlay(
            Rectangle()
                .fill(accentColor)
                .frame(width: 2),
            alignment: .leading
        )
    }
}
