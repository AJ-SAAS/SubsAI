// Features/Coach/CoachVideoCard.swift
// One video in the Coach list. White card, thin grey border (same as Home).
// Purple = good, orange = needs work.
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
        case .replicate: return HomeLook.purple
        case .oneOff:    return HomeLook.secondary
        case .avoid:     return HomeLook.orangeText
        case nil:        return .clear
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Thumbnail, title, score
            HStack(alignment: .top, spacing: 12) {
                VideoThumbnailMini(video: video)
                    .frame(width: 96, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .background(HomeLook.fill.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HomeLook.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(metaLine)
                        .font(.system(size: 12))
                        .foregroundColor(HomeLook.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(video.healthScore)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(verdict.healthColor)
                    Text(verdict.healthLabel)
                        .font(.system(size: 10, weight: .bold))
                        .kerning(0.4)
                        .textCase(.uppercase)
                        .foregroundColor(verdict.healthColor)
                    if let rep = replicationScore {
                        Text(rep.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(repColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(repColor.opacity(0.1)))
                            .padding(.top, 2)
                    }
                }
                .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.bottom, 12)

            Rectangle().fill(HomeLook.hairline).frame(height: 1)
                .padding(.bottom, 10)

            // What to do about it
            HStack(spacing: 10) {
                Image(systemName: fix.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(fix.color)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(fix.color.opacity(0.12)))

                Text(fix.coachLine)
                    .font(.system(size: 13))
                    .foregroundColor(HomeLook.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HomeLook.hairline)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(HomeLook.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    /// "12K views · 2.1 subs/1K · 5d ago"
    private var metaLine: String {
        var parts = [viewsText]
        if video.views >= 1_000 && video.growthPerView > 0 {
            parts.append(String(format: "%.1f subs/1K", video.growthPerView))
        }
        parts.append(daysAgoText)
        return parts.joined(separator: " · ")
    }
}
