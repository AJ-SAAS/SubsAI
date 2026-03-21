// Features/Dashboard/Components/StatCard.swift
import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let delta: String?
    let iconName: String
    let color: Color
    var percentage: String? = nil  // ← add this

    init(
        title: String,
        value: String,
        delta: String? = nil,
        iconName: String,
        color: Color,
        percentage: String? = nil  // ← add this
    ) {
        self.title = title
        self.value = value
        self.delta = delta
        self.iconName = iconName
        self.color = color
        self.percentage = percentage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .kerning(0.6)
            }

            Text(value)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            if let delta = delta {
                HStack(spacing: 4) {
                    Text(delta)
                        .font(.system(size: 11))
                        .foregroundColor(color.opacity(0.9))
                    if let pct = percentage {
                        Text("(\(pct))")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
            } else {
                Text(" ")
                    .font(.system(size: 11))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}
