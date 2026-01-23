import SwiftUI

struct GrowthIndicator: View {
    let growth: GrowthData
    let period: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)

            Text("\(growth.formattedAbsolute) \(period)")
                .font(.caption)

            Text("(\(growth.formattedPercentage))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .foregroundColor(color)
    }

    private var icon: String {
        switch growth.trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "arrow.right"
        }
    }

    private var color: Color {
        switch growth.trend {
        case .up: return .green
        case .down: return .red
        case .neutral: return .gray
        }
    }
}
