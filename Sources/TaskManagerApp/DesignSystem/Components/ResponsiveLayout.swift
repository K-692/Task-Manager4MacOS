import SwiftUI

// MARK: - Layout Class

/// Width buckets used by every screen to adapt its layout to the window size.
public enum LayoutClass: Int, Comparable, Sendable {
    /// Narrow windows (< 560pt of content width): single column, condensed tables.
    case compact
    /// Medium windows (560–899pt): two columns, most table columns visible.
    case regular
    /// Large windows (≥ 900pt): full multi-column layouts.
    case wide

    public static func from(width: CGFloat) -> LayoutClass {
        if width < 560 { return .compact }
        if width < 900 { return .regular }
        return .wide
    }

    public static func < (lhs: LayoutClass, rhs: LayoutClass) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Horizontal page padding appropriate for this width bucket.
    public var pagePadding: CGFloat {
        switch self {
        case .compact: return 14
        case .regular: return 20
        case .wide: return 24
        }
    }
}

private struct LayoutClassKey: EnvironmentKey {
    static let defaultValue: LayoutClass = .wide
}

private struct ContentSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = CGSize(width: 1000, height: 700)
}

public extension EnvironmentValues {
    /// Width bucket of the detail area the view is rendered in.
    var layoutClass: LayoutClass {
        get { self[LayoutClassKey.self] }
        set { self[LayoutClassKey.self] = newValue }
    }

    /// Exact size of the detail area the view is rendered in.
    var contentSize: CGSize {
        get { self[ContentSizeKey.self] }
        set { self[ContentSizeKey.self] = newValue }
    }
}

/// Measures the space it is given and publishes it to descendants through the
/// `layoutClass` and `contentSize` environment values.
public struct ResponsiveContainer<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            content
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .environment(\.layoutClass, LayoutClass.from(width: geo.size.width))
                .environment(\.contentSize, geo.size)
        }
    }
}

// MARK: - Page Scaffold

/// Standard scrollable detail page with responsive padding.
public struct DetailPage<Content: View>: View {
    @Environment(\.layoutClass) private var layoutClass
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layoutClass == .compact ? 12 : 16) {
                content
            }
            .padding(.horizontal, layoutClass.pagePadding)
            .padding(.top, layoutClass == .compact ? 14 : 20)
            .padding(.bottom, 24)
            .frame(maxWidth: 1400, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

/// Page header with icon, title, subtitle and a large live metric.
/// Wraps the metric below the title when the window is too narrow.
public struct DetailHeader: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let metric: String?
    let metricLabel: String?
    let metricColor: Color?

    @Environment(\.layoutClass) private var layoutClass

    public init(icon: String, tint: Color, title: String, subtitle: String, metric: String? = nil, metricLabel: String? = nil, metricColor: Color? = nil) {
        self.metricColor = metricColor
        self.icon = icon
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.metric = metric
        self.metricLabel = metricLabel
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                titleBlock
                Spacer(minLength: 12)
                metricBlock(alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                metricBlock(alignment: .leading)
            }
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            IconBadge(systemName: icon, tint: tint, size: layoutClass == .compact ? 34 : 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: layoutClass == .compact ? 18 : 22, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 12))
                    .themedSecondary()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func metricBlock(alignment: HorizontalAlignment) -> some View {
        if let metric {
            VStack(alignment: alignment, spacing: 2) {
                Text(metric)
                    .font(.system(size: layoutClass == .compact ? 24 : 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(metricColor ?? tint)
                    .lineLimit(1)
                    .fixedSize()
                if let metricLabel {
                    Text(metricLabel.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .themedSecondary()
                        .fixedSize()
                }
            }
        }
    }
}

/// Rounded, tinted SF Symbol tile used in headers and cards.
public struct IconBadge: View {
    let systemName: String
    let tint: Color
    let size: CGFloat

    public init(systemName: String, tint: Color, size: CGFloat = 28) {
        self.systemName = systemName
        self.tint = tint
        self.size = size
    }

    @Environment(\.visualTheme) private var theme

    public var body: some View {
        if theme.isPublication {
            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .regular))
                .foregroundStyle(PublicationPalette.text)
                .frame(width: size, height: size)
        } else {
            standard
        }
    }

    private var standard: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: tint.opacity(0.3), radius: 3, y: 1)
    }
}

// MARK: - Cards & Rows

/// Card with a title row, optional trailing accessory, and content.
public struct SectionCard<Content: View, Accessory: View>: View {
    let title: String
    let icon: String?
    let tint: Color
    let content: Content
    let accessory: Accessory

    public init(
        _ title: String,
        icon: String? = nil,
        tint: Color = .secondary,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.accessory = accessory()
        self.content = content()
    }

    public var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(tint)
                    }
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    accessory
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

public extension SectionCard where Accessory == EmptyView {
    init(_ title: String, icon: String? = nil, tint: Color = .secondary, @ViewBuilder content: () -> Content) {
        self.init(title, icon: icon, tint: tint, accessory: { EmptyView() }, content: content)
    }
}

/// Label/value row that stacks vertically when there is not enough width.
public struct SpecRow: View {
    let label: String
    let value: String
    let valueColor: Color
    let monospaced: Bool

    public init(_ label: String, _ value: String, valueColor: Color = .primary, monospaced: Bool = true) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.monospaced = monospaced
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                labelText
                Spacer(minLength: 8)
                valueText.lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 2) {
                labelText
                valueText
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var labelText: some View {
        Text(label)
            .font(.system(size: 12))
            .themedSecondary()
            .lineLimit(1)
            .fixedSize()
    }

    private var valueText: some View {
        Text(value)
            .font(.system(size: 12, weight: .medium, design: monospaced ? .monospaced : .default))
            .foregroundColor(valueColor)
            .truncationMode(.middle)
    }
}

/// Grid that picks a column count from the available width (up to `maxColumns`)
/// and stretches every card to fill its column.
public struct AdaptiveGrid<Content: View>: View {
    let minimum: CGFloat
    let maxColumns: Int
    let spacing: CGFloat
    let content: Content

    @Environment(\.contentSize) private var contentSize
    @Environment(\.layoutClass) private var layoutClass

    public init(minimum: CGFloat = 280, maxColumns: Int = 2, spacing: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.minimum = minimum
        self.maxColumns = maxColumns
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        let usable = contentSize.width - layoutClass.pagePadding * 2
        let count = max(1, min(maxColumns, Int((usable + spacing) / (minimum + spacing))))
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: count),
            alignment: .leading,
            spacing: spacing
        ) {
            content
        }
    }
}

/// Horizontal layout that falls back to a vertical stack when content does not fit.
public struct AdaptiveStack<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    public init(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: spacing) { content }
            VStack(alignment: .leading, spacing: spacing) { content }
        }
    }
}

/// Small rounded "pill" tag.
public struct PillTag: View {
    let text: String
    let tint: Color

    public init(_ text: String, tint: Color) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tint.opacity(0.14))
            .foregroundColor(tint)
            .clipShape(Capsule())
            .lineLimit(1)
            .fixedSize()
    }
}

/// Footer under a 60-second chart.
public struct ChartTimeAxis: View {
    let tint: Color
    public init(tint: Color) { self.tint = tint }
    public var body: some View {
        HStack {
            Text("60s ago")
                .themedSecondary()
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(tint).frame(width: 5, height: 5)
                Text("Live")
            }
            .foregroundColor(tint)
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
    }
}

/// Compact top-N process table used by the CPU and Memory pages.
/// Hides the PID and architecture columns when the window is narrow.
public struct TopProcessTable: View {
    public struct Row: Identifiable {
        public let id: Int32
        public let name: String
        public let architecture: String
        public let isActive: Bool
        public let value: String
    }

    let rows: [Row]
    let valueTitle: String
    let tint: Color

    @Environment(\.layoutClass) private var layoutClass

    public init(rows: [Row], valueTitle: String, tint: Color) {
        self.rows = rows
        self.valueTitle = valueTitle
        self.tint = tint
    }

    public var body: some View {
        let showPID = layoutClass != .compact
        let showArch = layoutClass == .wide

        VStack(spacing: 6) {
            HStack(spacing: 8) {
                if showPID { Text("PID").frame(width: 54, alignment: .leading) }
                Text("Process").frame(maxWidth: .infinity, alignment: .leading)
                if showArch { Text("Architecture").frame(width: 110, alignment: .trailing) }
                Text(valueTitle).frame(width: 86, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold))
            .themedSecondary()

            Divider()

            ForEach(rows) { row in
                HStack(spacing: 8) {
                    if showPID {
                        Text("\(row.id)")
                            .font(.system(size: 11, design: .monospaced))
                            .themedSecondary()
                            .frame(width: 54, alignment: .leading)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: row.isActive ? "app.fill" : "gearshape.2")
                            .font(.system(size: 10))
                            .foregroundColor(row.isActive ? tint : .secondary)
                        Text(row.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if showArch {
                        Text(row.architecture)
                            .font(.system(size: 11))
                            .themedSecondary()
                            .lineLimit(1)
                            .frame(width: 110, alignment: .trailing)
                    }
                    Text(row.value)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(tint)
                        .lineLimit(1)
                        .frame(width: 86, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

/// Wrapping layout: places children left-to-right and starts a new line when
/// the row is full (like text wrapping). Rows can be left- or right-aligned.
public struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var alignment: HorizontalAlignment

    public init(spacing: CGFloat = 6, lineSpacing: CGFloat = 6, alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }

    /// Splits subviews into rows that fit `maxWidth`; returns indices, row widths and heights.
    private func rows(_ subviews: Subviews, maxWidth: CGFloat) -> [(items: [Int], width: CGFloat, height: CGFloat)] {
        var result: [(items: [Int], width: CGFloat, height: CGFloat)] = []
        var current: [Int] = []
        var x: CGFloat = 0, height: CGFloat = 0
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if !current.isEmpty && x + spacing + size.width > maxWidth {
                result.append((current, x, height))
                current = []; x = 0; height = 0
            }
            x += (current.isEmpty ? 0 : spacing) + size.width
            height = max(height, size.height)
            current.append(i)
        }
        if !current.isEmpty { result.append((current, x, height)) }
        return result
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let r = rows(subviews, maxWidth: maxWidth)
        let height = r.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, r.count - 1))
        let widest = r.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, maxWidth: bounds.width) {
            var x: CGFloat
            switch alignment {
            case .trailing: x = bounds.maxX - row.width
            case .center: x = bounds.minX + (bounds.width - row.width) / 2
            default: x = bounds.minX
            }
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }
}
