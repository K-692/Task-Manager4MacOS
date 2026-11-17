import SwiftUI

/// Premium card container with layered background, soft shadow, and hairline border.
public struct CardView<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutClass) private var layoutClass

    public init(padding: CGFloat = AppTheme.Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
        let effectivePadding = layoutClass == .compact ? min(padding, 12) : padding

        content
            .padding(effectivePadding)
            .background(
                shape
                    .fill(AppTheme.Colors.cardBackground)
                    .overlay(
                        shape.fill(
                            LinearGradient(
                                colors: [Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 6, y: 2)
            )
            .overlay(
                shape.strokeBorder(AppTheme.Colors.subtleBorder, lineWidth: 1)
            )
    }
}
