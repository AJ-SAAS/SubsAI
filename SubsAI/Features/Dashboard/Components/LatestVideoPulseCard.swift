// Features/Dashboard/Components/LatestVideoPulseCard.swift
import SwiftUI

struct LatestVideoPulseCard: View {
    let video: Video

    private var ctr: Double       { video.analytics?.ctr ?? 0 }
    private var retention: Double { video.analytics?.retention ?? 0 }

    private var daysAgoText: String {
        let days = Calendar.current.dateComponents(
            [.day], from: video.publishedAt, to: Date()
        ).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Thumbnail
            ZStack(alignment: .topTrailing) {
                VideoThumbnailView(video: video)
                    .frame(height: 110)
                    .cornerRadius(12)
                    .clipped()

                Text(daysAgoText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(8)
                    .padding(8)
            }

            // Title
            Text(video.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)
                .lineSpacing(2)

            // Metrics row
            HStack(spacing: 0) {
                PulseMetric(
                    value: video.views > 0 ? formatViews(video.views) : "—",
                    label: "Views",
                    badge: viewsBadge,
                    badgeColor: viewsBadgeColor
                )

                Divider()
                    .frame(height: 40)
                    .background(AppTheme.border)

                PulseMetric(
                    value: ctr > 0 ? String(format: "%.1f%%", ctr * 100) : "—",
                    label: "CTR",
                    badge: ctrBadge,
                    badgeColor: ctrBadgeColor
                )

                Divider()
                    .frame(height: 40)
                    .background(AppTheme.border)

                PulseMetric(
                    value: retention > 0
                        ? String(format: "%.0f%%", retention * 100) : "—",
                    label: "Retention",
                    badge: retentionBadge,
                    badgeColor: retentionBadgeColor
                )
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

    // MARK: - Badge helpers
    private var viewsBadge: String {
        guard video.views > 0 else { return "New" }
        if video.views > 10_000 { return "Strong" }
        if video.views > 1_000  { return "Growing" }
        return "Early"
    }
    private var viewsBadgeColor: Color {
        guard video.views > 0 else { return AppTheme.textSecondary }
        if video.views > 10_000 { return AppTheme.success }
        if video.views > 1_000  { return AppTheme.warning }
        return AppTheme.textSecondary
    }

    private var ctrBadge: String {
        if ctr >= 0.08 { return "Top 10%" }
        if ctr >= 0.05 { return "Good" }
        if ctr > 0     { return "Low" }
        return "—"
    }
    private var ctrBadgeColor: Color {
        if ctr >= 0.08 { return AppTheme.success }
        if ctr >= 0.05 { return AppTheme.warning }
        return ctr > 0 ? AppTheme.danger : AppTheme.textSecondary
    }

    private var retentionBadge: String {
        if retention >= 0.50 { return "Excellent" }
        if retention >= 0.35 { return "Good" }
        if retention > 0     { return "Improve" }
        return "—"
    }
    private var retentionBadgeColor: Color {
        if retention >= 0.50 { return AppTheme.success }
        if retention >= 0.35 { return AppTheme.warning }
        return retention > 0 ? AppTheme.danger : AppTheme.textSecondary
    }

    private func formatViews(_ views: Int) -> String {
        if views >= 1_000_000 { return String(format: "%.1fM", Double(views) / 1_000_000) }
        if views >= 1_000     { return String(format: "%.1fK", Double(views) / 1_000) }
        return "\(views)"
    }
}

// MARK: - PulseMetric
private struct PulseMetric: View {
    let value: String
    let label: String
    let badge: String
    let badgeColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)

            Text(badge)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.12))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
    }
}
