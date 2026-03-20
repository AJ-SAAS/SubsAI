// Features/Coach/CoachVideoCard.swift
import SwiftUI

struct CoachVideoCard: View {
    let video: Video
    var replicationScore: ReplicationScore?

    private var verdict: CoachVerdict { video.verdict }
    private var fix: CoachFix { video.primaryFix }

    private var viewsText: String {
        if video.views >= 1_000_000 { return String(format: "%.1fM views", Double(video.views) / 1_000_000) }
        if video.views >= 1_000     { return String(format: "%.0fK views", Double(video.views) / 1_000) }
        return video.views > 0 ? "\(video.views) views" : "No data yet"
    }

    private var daysAgoText: String {
        let days = Calendar.current.dateComponents([.day], from: video.publishedAt, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    private var repColor: Color {
        switch replicationScore {
        case .replicate: return .green
        case .oneOff:    return .yellow
        case .avoid:     return .red
        case nil:        return .clear
        }
    }

    // ✅ GPV color
    private var gpvColor: Color {
        let gpv = video.growthPerView
        if gpv >= 3.0 { return .green }
        if gpv >= 1.0 { return .yellow }
        if gpv > 0    { return .red }
        return AppTheme.textTertiary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Top row
            HStack(spacing: 10) {

                // Thumbnail
                ZStack(alignment: .topTrailing) {
                    VideoThumbnailMini(video: video)
                        .frame(width: 90, height: 52)
                        .cornerRadius(8)
                        .clipped()

                    Circle()
                        .fill(verdict.healthColor)
                        .frame(width: 7, height: 7)
                        .padding(5)
                }

                // Title + meta
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // ✅ GPV added to meta line
                    HStack(spacing: 4) {
                        Text(viewsText)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textTertiary)

                        if video.growthPerView > 0 {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textTertiary)
                            Text(video.growthPerViewLabel)
                                .font(.system(size: 11))
                                .foregroundColor(gpvColor)
                        }
                    }

                    Text(daysAgoText)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Score + replication
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(video.healthScore)")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundColor(verdict.healthColor)
                        .lineLimit(1)

                    Text(verdict.healthLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(verdict.healthColor)
                        .kerning(0.4)
                        .textCase(.uppercase)

                    if let rep = replicationScore {
                        Text(rep.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(repColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(repColor.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
                .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.bottom, 10)

            // MARK: - Coach line
            Divider()
                .padding(.bottom, 8)

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(fix.color.opacity(0.1))
                        .frame(width: 26, height: 26)
                    Image(systemName: fix.systemImage)
                        .font(.system(size: 11))
                        .foregroundColor(fix.color)
                }
                .frame(width: 26, height: 26)

                Text(fix.coachLine)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(3)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}
