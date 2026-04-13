import SwiftUI

enum AppTheme {
    // MARK: - Accent (Your stronger purple)
    static let accent = Color(hex: "#4A00C8")

    // MARK: - Backgrounds
    static var background: Color      { Color(.systemBackground) }
    static var cardBackground: Color  { Color(.secondarySystemBackground) }
    static var deepBackground: Color  { Color(.tertiarySystemBackground) }

    // MARK: - Text
    static var textPrimary: Color     { Color(.label) }
    static var textSecondary: Color   { Color(.secondaryLabel) }
    static var textTertiary: Color    { Color(.tertiaryLabel) }

    // MARK: - Borders
    static var border: Color          { Color(.separator).opacity(0.6) }
    static var borderSubtle: Color    { Color(.separator).opacity(0.3) }

    // MARK: - Status
    static var success: Color         { Color(.systemGreen) }
    static var warning: Color         { Color(.systemYellow) }
    static var danger: Color          { Color(.systemRed) }
    static var info: Color            { Color(.systemBlue) }
    
    // MARK: - Paywall Specific
    static let darkCardPurple = Color(hex: "#1d004f")
}

// MARK: - Hex Color Helper (only defined once here)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
