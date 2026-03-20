import SwiftUI

enum AppTheme {
    // MARK: - Accent
    static let accent = Color(red: 0.49, green: 0.44, blue: 1.0)

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
}
