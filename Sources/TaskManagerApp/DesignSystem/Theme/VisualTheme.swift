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
    public static let grid = Color(white: 0.86)
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
