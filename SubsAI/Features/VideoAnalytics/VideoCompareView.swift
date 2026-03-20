// Features/VideoAnalytics/VideoCompareView.swift
import SwiftUI

struct VideoCompareView: View {
    let currentVideo: Video
    let allVideos: [Video]

    private var sortedVideos: [Video] {
        allVideos
            .filter { $0.analytics != nil }
            .sorted { ($0.analytics?.retention ?? 0) > ($1.analytics?.retention ?? 0) }
            .prefix(6)
            .map { $0 }
    }

    private var avgRetention: Double {
        let vals = sortedVideos.compactMap { $0.analytics?.retention }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Video comparison list
                sectionLabel("Your videos · sorted by retention")

                if sortedVideos.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(sortedVideos) { video in
                            VideoCompareRow(
                                video: video,
                                isCurrentVideo: video.id == currentVideo.id
                            )
                        }
                    }
                }

                // MARK: - What the pattern tells you
                sectionLabel("What this tells you")

                InsightBlock(
                    title: "The key pattern",
                    content: "Look at the videos with the highest retention — what do they have in common? That's your formula. The goal is to find what you did right and do it again on purpose, not by accident.",
                    accentColor: AppTheme.accent
                )

                if let worst = sortedVideos.last,
                   worst.id != currentVideo.id {
                    InsightBlock(
                        title: "Your lowest performer",
                        content: "'\(worst.title.prefix(40))…' had the weakest numbers. Compare how that video starts vs your best one. The difference in the first 30 seconds usually explains the gap.",
                        accentColor: .red
                    )
                }

                if avgRetention > 0 {
                    InsightBlock(
                        title: "Your channel average",
                        content: "Across these videos, you're keeping \(Int(avgRetention * 100))% of viewers on average. Anything above that is a win worth studying. Anything below is worth understanding before you make another video like it.",
                        accentColor: .green
                    )
                }

                // MARK: - Channel pattern — coming soon
                sectionLabel("Channel pattern analysis")
                channelPatternComingSoon

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: - Coming soon card
    private var channelPatternComingSoon: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.accent)
                Text("Deep pattern analysis")
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
            Text("We'll scan all your videos and find what your best ones have in common — the title style, video length, opening format, and posting time that works best for your channel specifically.")
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

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "video.slash")
                .font(.system(size: 30))
                .foregroundColor(AppTheme.textTertiary)
            Text("Not enough videos to compare yet")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .kerning(0.8)
    }
}

// MARK: - VideoCompareRow
struct VideoCompareRow: View {
    let video: Video
    let isCurrentVideo: Bool

    private var retention: Double { video.analytics?.retention ?? 0 }
    private var ctr: Double { video.analytics?.ctr ?? 0 }
    private var retPct: Int { Int(retention * 100) }

    private var scoreColor: Color {
        if retPct >= 45 { return .green }
        if retPct >= 30 { return .yellow }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    // "This video" badge for current
                    if isCurrentVideo {
                        Text("This video")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.1))
                            .cornerRadius(6)
                    }
                    Text(video.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(retPct)%")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundColor(scoreColor)
                    Text("retention")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }

            VStack(spacing: 6) {
                CompareBar(
                    label: "CTR",
                    value: min(ctr / 0.10, 1.0),
                    displayValue: String(format: "%.1f%%", ctr * 100),
                    color: AppTheme.accent
                )
                CompareBar(
                    label: "Retention",
                    value: min(retention / 0.60, 1.0),
                    displayValue: String(format: "%.0f%%", retention * 100),
                    color: scoreColor
                )
            }
        }
        .padding(14)
        .background(
            isCurrentVideo
                ? AppTheme.accent.opacity(0.06)
                : AppTheme.cardBackground
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isCurrentVideo
                        ? AppTheme.accent.opacity(0.3)
                        : AppTheme.borderSubtle,
                    lineWidth: isCurrentVideo ? 1 : 0.5
                )
        )
    }
}

// MARK: - CompareBar
struct CompareBar: View {
    let label: String
    let value: Double
    let displayValue: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textTertiary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(
                            width: geo.size.width * min(max(value, 0), 1),
                            height: 4
                        )
                        .animation(.easeOut(duration: 0.5), value: value)
                }
                .frame(height: 4)
                .padding(.top, 5)
            }
            .frame(height: 14)

            Text(displayValue)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}
