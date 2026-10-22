import SwiftUI

/// Premium card container with subtle materials, rounded corners, and delicate border.
public struct CardView<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    public init(padding: CGFloat = AppTheme.Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .fill(AppTheme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.subtleBorder, lineWidth: 1)
            )
    }
}
