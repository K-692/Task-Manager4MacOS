import SwiftUI

/// Premium card container with layered background, soft shadow, and hairline border.
public struct CardView<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutClass) private var layoutClass
    @Environment(\.visualTheme) private var theme

    public init(padding: CGFloat = AppTheme.Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        let effectivePadding = layoutClass == .compact ? min(padding, 12) : padding
        if theme.isPublication {
            // Paper-ready: flat white panel with a thin dark rule, no shadow or gradient.
            content
                .padding(effectivePadding)
                .background(Rectangle().fill(Color.white))
                .overlay(Rectangle().strokeBorder(PublicationPalette.axis.opacity(0.55), lineWidth: 0.75))
        } else {
            standard(effectivePadding)
        }
    }

    private func standard(_ effectivePadding: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)

        return content
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
