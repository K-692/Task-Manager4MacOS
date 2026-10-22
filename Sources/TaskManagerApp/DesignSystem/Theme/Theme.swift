import SwiftUI

/// Central design system tokens: spacing, radii, typography, and semantic colors.
public enum AppTheme {
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 20
    }

    public enum Colors {
        public static let primaryAccent = Color.indigo
        public static let success = Color.emerald
        public static let warning = Color.amber
        public static let danger = Color.rose
        public static let info = Color.blue
        public static let secondaryText = Color.secondary
        public static let subtleBorder = Color.primary.opacity(0.08)
        public static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.7)
    }
}

public extension Color {
    static let emerald = Color(red: 0.06, green: 0.72, blue: 0.51)
    static let amber = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let rose = Color(red: 0.95, green: 0.27, blue: 0.38)
    static let slate = Color(red: 0.39, green: 0.45, blue: 0.55)

    static func projectColor(for token: String) -> Color {
        switch token.lowercased() {
        case "indigo": return .indigo
        case "blue": return .blue
        case "emerald", "green": return .emerald
        case "amber", "orange", "yellow": return .amber
        case "rose", "red": return .rose
        case "purple": return .purple
        case "teal": return .teal
        case "cyan": return .cyan
        default: return .indigo
        }
    }
}
