import SwiftUI

/// App-wide visual theme.
///
/// - `standard`: the regular colorful UI (follows the System / Light / Dark appearance).
/// - `publication`: a minimal, paper-ready look for screenshots and figures — white
///   background, black axes, serif type, colour-blind-safe series colours, labelled
///   time axis, and reference markings (mean line, peak marker).
public enum VisualTheme: String, CaseIterable, Codable, Sendable {
    case standard
    case publication

    public var title: String {
        switch self {
        case .standard: return "Standard"
        case .publication: return "Publication"
        }
    }

    public var subtitle: String {
        switch self {
        case .standard: return "Colorful app look"
        case .publication: return "Paper-ready, minimal"
        }
    }

    public var icon: String {
        switch self {
        case .standard: return "paintpalette"
        case .publication: return "doc.richtext"
        }
    }

    public var isPublication: Bool { self == .publication }
}

/// The five live telemetry components.
public enum TelemetryKind: String, CaseIterable, Sendable {
    case cpu, gpu, memory, storage, network

    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "Memory"
        case .storage: return "Storage"
        case .network: return "Network"
        }
    }

    public var figureTitle: String {
        switch self {
        case .cpu: return "CPU Utilization"
        case .gpu: return "GPU Utilization"
        case .memory: return "Memory Usage"
        case .storage: return "Storage Usage (Primary Volume)"
        case .network: return "Network Throughput"
        }
    }

    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "cube.transparent"
        case .memory: return "memorychip"
        case .storage: return "internaldrive"
        case .network: return "network"
        }
    }

    /// Accent colour in the standard theme.
    public var standardColor: Color {
        switch self {
        case .cpu: return .indigo
        case .gpu: return .purple
        case .memory: return .blue
        case .storage: return .emerald
        case .network: return .cyan
        }
    }

    /// Okabe–Ito colour-blind-safe colour in the publication theme.
    public var publicationColor: Color {
        switch self {
        case .cpu: return PublicationPalette.blue
        case .gpu: return PublicationPalette.vermillion
        case .memory: return PublicationPalette.bluishGreen
        case .storage: return PublicationPalette.reddishPurple
        case .network: return PublicationPalette.blue
        }
    }

    public func color(for theme: VisualTheme) -> Color {
        theme.isPublication ? publicationColor : standardColor
    }
}

/// Okabe–Ito palette (colour-blind safe, prints well in greyscale with line styles).
public enum PublicationPalette {
    public static let black = Color(red: 0, green: 0, blue: 0)
    public static let orange = Color(red: 0.902, green: 0.624, blue: 0.0)
    public static let skyBlue = Color(red: 0.337, green: 0.706, blue: 0.914)
    public static let bluishGreen = Color(red: 0.0, green: 0.620, blue: 0.451)
    public static let blue = Color(red: 0.0, green: 0.447, blue: 0.698)
    public static let vermillion = Color(red: 0.835, green: 0.369, blue: 0.0)
    public static let reddishPurple = Color(red: 0.800, green: 0.475, blue: 0.655)
    public static let axis = Color(white: 0.15)
    public static let grid = Color(white: 0.80)
    public static let text = Color(white: 0.08)
    public static let secondaryText = Color(white: 0.35)
}

private struct VisualThemeKey: EnvironmentKey {
    static let defaultValue: VisualTheme = .standard
}

private struct SampleIntervalKey: EnvironmentKey {
    static let defaultValue: TimeInterval = 1
}

public extension EnvironmentValues {
    var visualTheme: VisualTheme {
        get { self[VisualThemeKey.self] }
        set { self[VisualThemeKey.self] = newValue }
    }

    /// Seconds between telemetry samples (used to label chart time axes).
    var sampleInterval: TimeInterval {
        get { self[SampleIntervalKey.self] }
        set { self[SampleIntervalKey.self] = newValue }
    }
}

// MARK: - Publication markings

/// Where the numeric values of markings are shown.
public enum LabelPlacement: String, Codable, CaseIterable, Sendable {
    /// Values listed in the legend below the graph; nothing is written inside the plot.
    case legend
    /// Small labels inside the plot next to each marking.
    case inside

    public var title: String {
        switch self {
        case .legend: return "In legend"
        case .inside: return "Inside graph"
        }
    }
}

/// Distinct publication colours (Okabe–Ito) for each marking, so every line or symbol
/// can be identified from the legend alone.
public enum MarkingColor {
    public static let mean = PublicationPalette.black
    public static let median = PublicationPalette.reddishPurple
    public static let trend = PublicationPalette.bluishGreen
    public static let movingAverage = PublicationPalette.skyBlue
    public static let threshold = PublicationPalette.vermillion
    public static let peak = PublicationPalette.orange
    public static let minimum = Color(white: 0.42)
    public static let latest = PublicationPalette.black
    public static let band = Color(white: 0.45)

    /// Avoids drawing a marking in the same colour as the data line it annotates.
    public static func distinct(_ preferred: Color, from series: Color) -> Color {
        preferred == series ? (preferred == PublicationPalette.black ? Color(white: 0.35) : PublicationPalette.black) : preferred
    }
}

/// Which reference markings the Publication theme draws on charts (and captured figures).
public struct PublicationMarkings: Codable, Equatable, Sendable {
    // Reference lines
    public var mean = true
    public var median = false
    public var threshold = false
    public var thresholdValue: Double = 80
    public var trendLine = false
    public var movingAverage = false
    public var movingAverageWindow = 5
    // Point markers
    public var peak = true
    public var minimum = false
    public var latest = false
    public var dataPoints = false
    // Bands
    public var stdDevBand = false
    public var rangeBand = false
    // Axes & layout
    public var gridlines = true
    public var plotFrame = true
    public var axisTitles = true
    public var axisTicks = true
    public var legend = true
    public var valueLabels = true
    public var smoothCurves = false
    /// Where marking values are written: in the legend below the graph (clean plot)
    /// or as small labels inside the plot next to each marking.
    public var labelPlacement: LabelPlacement = .legend

    public init() {}

    public static let standard = PublicationMarkings()


    public static var minimal: PublicationMarkings {
        var m = PublicationMarkings()
        m.mean = false
        m.peak = false
        m.gridlines = false
        m.valueLabels = false
        m.legend = true
        return m
    }

    public static var all: PublicationMarkings {
        var m = PublicationMarkings()
        m.mean = true; m.median = true; m.threshold = true; m.trendLine = true; m.movingAverage = true
        m.peak = true; m.minimum = true; m.latest = true; m.dataPoints = true
        m.stdDevBand = true; m.rangeBand = true
        m.gridlines = true; m.plotFrame = true; m.axisTitles = true; m.axisTicks = true
        m.legend = true; m.valueLabels = true
        return m
    }

    /// True when the chart should draw a key explaining the active markings.
    public var hasStatisticalMarks: Bool {
        mean || median || threshold || trendLine || movingAverage || peak || minimum || latest || stdDevBand || rangeBand
    }

    // Decode tolerantly so settings saved by older versions still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PublicationMarkings()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? def }
        mean = v(.mean, d.mean); median = v(.median, d.median)
        threshold = v(.threshold, d.threshold); thresholdValue = v(.thresholdValue, d.thresholdValue)
        trendLine = v(.trendLine, d.trendLine)
        movingAverage = v(.movingAverage, d.movingAverage); movingAverageWindow = v(.movingAverageWindow, d.movingAverageWindow)
        peak = v(.peak, d.peak); minimum = v(.minimum, d.minimum); latest = v(.latest, d.latest); dataPoints = v(.dataPoints, d.dataPoints)
        stdDevBand = v(.stdDevBand, d.stdDevBand); rangeBand = v(.rangeBand, d.rangeBand)
        gridlines = v(.gridlines, d.gridlines); plotFrame = v(.plotFrame, d.plotFrame); axisTitles = v(.axisTitles, d.axisTitles)
        axisTicks = v(.axisTicks, d.axisTicks); legend = v(.legend, d.legend); valueLabels = v(.valueLabels, d.valueLabels)
        smoothCurves = v(.smoothCurves, d.smoothCurves); labelPlacement = v(.labelPlacement, d.labelPlacement)
    }
}

private struct PublicationMarkingsKey: EnvironmentKey {
    static let defaultValue = PublicationMarkings()
}

public extension EnvironmentValues {
    var publicationMarkings: PublicationMarkings {
        get { self[PublicationMarkingsKey.self] }
        set { self[PublicationMarkingsKey.self] = newValue }
    }
}

// MARK: - Usage colour shading

/// How a value maps onto the continuous green → red usage colour.
public enum UsageScale: Sendable {
    /// 0 % → green, 100 % → red.
    case percent
    /// Network throughput in bytes/s: ≥ 1 MB/s → green, ≤ 400 KB/s → red,
    /// continuous (logarithmic) in between.
    case network
}

/// Continuous green → yellow → red colour for a value (no fixed steps).
/// Used for the menu bar item.
public enum UsageColor {
    static let greenHue = 0.36
    static let redHue = 0.0

    /// t = 0 → green, t = 1 → red.
    public static func color(t rawT: Double) -> Color {
        let t = min(1, max(0, rawT))
        let hue = greenHue + (redHue - greenHue) * t
        // Vivid but readable on both white and dark backgrounds; yellow is pulled
        // slightly darker so it stays legible on white paper.
        let brightness = 0.80 - 0.04 * sin(t * .pi)
        let saturation = 0.78 + 0.12 * sin(t * .pi)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    public static func badness(_ value: Double, scale: UsageScale) -> Double {
        switch scale {
        case .percent:
            return value / 100
        case .network:
            let low = 400.0 * 1024, high = 1_048_576.0
            if value <= low { return 1 }
            if value >= high { return 0 }
            return 1 - (log(value) - log(low)) / (log(high) - log(low))
        }
    }

    public static func color(_ value: Double, scale: UsageScale) -> Color {
        color(t: badness(value, scale: scale))
    }

    /// Menu bar variant tuned for legibility on the current menu bar background.
    /// Dark menu bar: bright, pastel shades leaning toward white.
    /// Light menu bar: deeper, more saturated shades so they stand out on white.
    public static func menuBarColor(_ value: Double, scale: UsageScale, darkMenuBar: Bool) -> Color {
        let t = min(1, max(0, badness(value, scale: scale)))
        let hue = greenHue + (redHue - greenHue) * t
        if darkMenuBar {
            return Color(hue: hue, saturation: 0.42 + 0.08 * t, brightness: 1.0)
        } else {
            return Color(hue: hue, saturation: 0.85, brightness: 0.62 + 0.08 * (1 - sin(t * .pi)))
        }
    }

    /// Whether the system menu bar is currently dark (follows macOS Dark Mode).
    public static var systemMenuBarIsDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle")?.lowercased() == "dark"
    }
}


// MARK: - Theme-aware secondary text

/// Secondary text: the system's soft grey in the Standard theme, a solid dark grey in the
/// Publication theme so labels stay crisp on white.
struct ThemedSecondaryText: ViewModifier {
    @Environment(\.visualTheme) private var theme

    func body(content: Content) -> some View {
        content.foregroundColor(theme.isPublication ? PublicationPalette.publicationSecondary : .secondary)
    }
}

public extension View {
    func themedSecondary() -> some View { modifier(ThemedSecondaryText()) }
}

public extension PublicationPalette {
    /// Solid (opaque) dark grey used for secondary text in the Publication theme.
    static let publicationSecondary = Color(white: 0.22)
}
