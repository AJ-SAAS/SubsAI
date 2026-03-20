// Features/Dashboard/Components/MilestoneCard.swift
import SwiftUI

struct MilestoneCard: View {
    let current: Int
    let target: Int
    let label: String
    let weeklyGrowth: Int

    private var progress: Double {
        min(Double(current) / Double(target), 1.0)
    }

    private var remaining: Int {
        max(target - current, 0)
    }

    private var daysToGoal: Int? {
        guard weeklyGrowth > 0 else { return nil }
        let perDay = Double(weeklyGrowth) / 7.0
        return Int(ceil(Double(remaining) / perDay))
    }

    private var percentText: String {
        "\(Int(progress * 100))% there"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next goal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .kerning(0.6)
                        .textCase(.uppercase)
                    Text(label)
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)
                }
                Spacer()
                Text(percentText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent.opacity(0.12))
                    .cornerRadius(20)
            }
            .padding(.bottom, 14)

            // Numbers
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(current.formatted())
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundColor(AppTheme.textPrimary)
                Text("/")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(AppTheme.textTertiary)
                Text(target.formatted())
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(.bottom, 14)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemFill))
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.accent)
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.easeOut(duration: 1.2), value: progress)
                }
            }
            .frame(height: 10)
            .padding(.bottom, 10)

            // Remaining
            HStack {
                Text("Remaining")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("\(remaining.formatted()) subscribers")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }
            .padding(.bottom, 14)

            // Velocity
            if weeklyGrowth > 0 {
                Divider()
                    .padding(.bottom, 12)

                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.success.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.success)
                    }

                    Group {
                        if let days = daysToGoal {
                            Text("At +\(weeklyGrowth.formatted())/week you'll hit this in ")
                            + Text("~\(days) days.")
                                .foregroundColor(AppTheme.success)
                            + Text(" Keep it up.")
                        } else {
                            Text("Growing at +\(weeklyGrowth.formatted()) this week.")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(3)
                }
            }
        }
        .padding(20)
        .background(AppTheme.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - MiniMilestoneCard
struct MiniMilestoneCard: View {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color

    private var progress: Double {
        min(current / target, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .kerning(0.6)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.systemFill))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 5)
                        .animation(.easeOut(duration: 1.0), value: progress)
                }
            }
            .frame(height: 5)

            HStack {
                Text(formatValue(current) + unit)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(formatValue(target) + unit)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }

    private func formatValue(_ val: Double) -> String {
        if val >= 1_000_000 { return String(format: "%.1fM", val / 1_000_000) }
        if val >= 1_000     { return String(format: "%.1fK", val / 1_000) }
        return "\(Int(val))"
    }
}

// MARK: - CompletedMilestoneRow
struct CompletedMilestoneRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.success)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.success)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(AppTheme.success.opacity(0.06))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.success.opacity(0.2), lineWidth: 0.5)
        )
    }
}
