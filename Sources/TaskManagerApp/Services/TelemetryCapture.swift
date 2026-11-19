import SwiftUI
import AppKit
import TaskManagerCore

/// Immutable copy of all live telemetry taken at a single instant, so the five
/// captured figures describe exactly the same moment.
struct TelemetrySnapshot {
    let date: Date
    let interval: TimeInterval
    let deviceName: String
    let osVersion: String
    let cpuName: String
    let cpu: [Double]
    let gpu: [Double]
    let memory: [Double]
    let storage: [Double]
    let netIn: [Double]
    let netOut: [Double]
    let gpuName: String
    let memoryDetail: String
    let storageDetail: String
    let networkDetail: String

    @MainActor
    init(env: AppEnvironment) {
        let s = env.samplingCoordinator
        date = Date()
        interval = s.samplingInterval > 0 ? s.samplingInterval : 1
        deviceName = env.deviceProfile.marketingName
        osVersion = env.deviceProfile.osVersion.replacingOccurrences(of: "Version ", with: "")
        cpuName = "\(env.deviceProfile.cpuName), \(env.deviceProfile.physicalCores) cores"
        cpu = s.cpuHistory.values
        gpu = s.gpuHistory.values
        memory = s.memoryHistory.values
        storage = s.diskHistory.values
        netIn = s.networkInHistory.values
        netOut = s.networkOutHistory.values
        gpuName = s.latestGPU?.value?.deviceName ?? env.deviceProfile.gpuNames.first ?? "GPU"
        if let m = s.latestMemory?.value {
            memoryDetail = "\(m.formattedUsed) of \(m.formattedTotal) used"
        } else {
            memoryDetail = env.deviceProfile.formattedMemory
        }
        if let d = s.latestStorage?.value?.first {
            storageDetail = "\(d.name), \(d.formattedUsed) of \(d.formattedTotal) used"
        } else {
            storageDetail = "Primary volume"
        }
        networkDetail = "Interface \(s.latestNetwork?.value?.primaryInterfaceName ?? "en0")"
    }

    func values(for kind: TelemetryKind) -> [Double] {
        switch kind {
        case .cpu: return cpu
        case .gpu: return gpu
        case .memory: return memory
        case .storage: return storage
        case .network: return netIn
        }
    }

    func subtitle(for kind: TelemetryKind) -> String {
        switch kind {
        case .cpu: return cpuName
        case .gpu: return gpuName
        case .memory: return memoryDetail
        case .storage: return storageDetail
        case .network: return networkDetail
        }
    }
}

/// A single self-contained figure (title, chart, statistics, caption) for one component.
struct TelemetryFigureView: View {
    let kind: TelemetryKind
    let snapshot: TelemetrySnapshot
    let theme: VisualTheme
    let colorScheme: ColorScheme

    static let size = CGSize(width: 960, height: 540)

    var body: some View {
        let pub = theme.isPublication
        let text = pub ? PublicationPalette.text : Color.primary
        let secondary = pub ? PublicationPalette.secondaryText : Color.secondary

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.figureTitle)
                        .font(.system(size: 22, weight: pub ? .regular : .bold, design: pub ? .serif : .rounded))
                        .foregroundColor(text)
                    Text("\(snapshot.subtitle(for: kind)) · \(snapshot.deviceName) · macOS \(snapshot.osVersion)")
                        .font(.system(size: 12, design: pub ? .serif : .default))
                        .foregroundColor(secondary)
                }
                Spacer()
                if !pub {
                    Text(currentText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(kind.standardColor)
                }
            }

            chart
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            statsRow(text: text, secondary: secondary)

            Text(caption)
                .font(.system(size: 10, design: pub ? .serif : .default))
                .italic(pub)
                .foregroundColor(secondary)
        }
        .padding(28)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(background)
        .environment(\.visualTheme, theme)
        .environment(\.sampleInterval, snapshot.interval)
        .environment(\.layoutClass, .wide)
        .environment(\.colorScheme, pub ? .light : colorScheme)
    }

    @ViewBuilder
    private var chart: some View {
        switch kind {
        case .network:
            // Captured figures always show the reference markings.
            VStack(alignment: .trailing, spacing: 6) {
                lineLegend
                TelemetryChart(
                    series: [
                        ChartSeries(name: "Download", values: padded(snapshot.netIn), color: downColor),
                        ChartSeries(name: "Upload", values: padded(snapshot.netOut), color: upColor, dashed: true)
                    ],
                    yDomain: nil,
                    unit: "Throughput (\(netUnit.name))",
                    scale: netUnit.scale,
                    showLegend: false,
                    markings: true
                )
            }
        default:
            TelemetryChart(
                series: [ChartSeries(name: kind.title, values: padded(snapshot.values(for: kind)), color: kind.color(for: theme))],
                yDomain: 0...100,
                unit: kind == .cpu || kind == .gpu ? "Utilization (%)" : "Usage (%)",
                markings: true
            )
        }
    }

    private var downColor: Color { theme.isPublication ? PublicationPalette.blue : .cyan }
    private var upColor: Color { theme.isPublication ? PublicationPalette.orange : .indigo }

    private var netUnit: (name: String, scale: Double) {
        ThroughputUnit.pick(maxBytesPerSecond: max(snapshot.netIn.max() ?? 0, snapshot.netOut.max() ?? 0))
    }

    /// Legend drawn with real line samples (solid vs dashed) so it reads in greyscale too.
    private var lineLegend: some View {
        HStack(spacing: 16) {
            legendItem("Download", color: downColor, dashed: false)
            legendItem("Upload", color: upColor, dashed: true)
        }
    }

    private func legendItem(_ name: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 5))
                p.addLine(to: CGPoint(x: 26, y: 5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [5, 3] : []))
            .frame(width: 26, height: 10)
            Text(name)
                .font(.system(size: 11, design: theme.isPublication ? .serif : .default))
                .foregroundColor(theme.isPublication ? PublicationPalette.text : .primary)
        }
    }

    @ViewBuilder
    private var background: some View {
        if theme.isPublication {
            Color.white
        } else {
            ZStack {
                Color(nsColor: colorScheme == .dark ? NSColor(white: 0.11, alpha: 1) : NSColor(white: 0.97, alpha: 1))
                LinearGradient(colors: [kind.standardColor.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    private func statsRow(text: Color, secondary: Color) -> some View {
        HStack(spacing: 28) {
            ForEach(stats, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: theme.isPublication ? .serif : .default))
                        .tracking(0.5)
                        .foregroundColor(secondary)
                    Text(item.1)
                        .font(.system(size: 14, weight: .medium, design: theme.isPublication ? .serif : .monospaced))
                        .foregroundColor(text)
                }
            }
            Spacer()
        }
    }

    // MARK: Statistics

    private var primary: [Double] {
        kind == .network ? snapshot.netIn.map { $0 / netUnit.scale } : snapshot.values(for: kind)
    }

    private func fmt(_ v: Double) -> String {
        kind == .network ? TelemetryChart.format(v, unit: netUnit.name) : String(format: "%.1f%%", v)
    }

    private var currentText: String { fmt(primary.last ?? 0) }

    private var stats: [(String, String)] {
        let v = primary
        guard !v.isEmpty else { return [("Samples", "0")] }
        let mean = v.reduce(0, +) / Double(v.count)
        let sd = sqrt(v.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(v.count))
        var items: [(String, String)] = [
            (kind == .network ? "Current ↓" : "Current", fmt(v.last ?? 0)),
            ("Mean", fmt(mean)),
            ("Std. dev.", fmt(sd)),
            ("Min", fmt(v.min() ?? 0)),
            ("Max", fmt(v.max() ?? 0))
        ]
        if kind == .network {
            let up = snapshot.netOut.map { $0 / netUnit.scale }
            let upMean = up.isEmpty ? 0 : up.reduce(0, +) / Double(up.count)
            items.append(("Mean ↑", fmt(upMean)))
        }
        items.append(("Samples", "\(v.count) @ \(String(format: "%.1f", snapshot.interval)) s"))
        return items
    }

    private var caption: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        let window = Double(max(1, primary.count - 1)) * snapshot.interval
        let markings = kind == .network
            ? "Solid line: download; dashed line: upload. Dotted horizontal line: mean download; ▲: peak download."
            : "Dotted horizontal line: mean over the window; ▲: peak value."
        return "Captured \(f.string(from: snapshot.date)) with Task Manager for macOS. Window: last \(Int(window)) s, sampled every \(String(format: "%.1f", snapshot.interval)) s. \(markings)"
    }

    /// Ensures the chart always has at least two points to draw.
    private func padded(_ values: [Double]) -> [Double] {
        values.count >= 2 ? values : (values + [0, 0]).prefix(2).map { $0 }
    }
}

/// Renders the five figures from one snapshot and writes them to a new folder on the Desktop.
@MainActor
enum TelemetryCaptureService {
    struct Result {
        let folder: URL
        let files: [URL]
    }

    static func captureAll(env: AppEnvironment, colorScheme: ColorScheme) throws -> Result {
        // 1. Freeze every series at the same instant.
        let snapshot = TelemetrySnapshot(env: env)
        let theme = env.visualTheme

        // 2. Create the output folder on the Desktop.
        let stamp: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
            return f.string(from: snapshot.date)
        }()
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let folder = desktop.appendingPathComponent("Task Manager Capture \(stamp) (\(theme.title))", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // 3. Render each figure at 3× (≈ 288 dpi for a 960×540 pt figure) and save as PNG.
        var files: [URL] = []
        for (index, kind) in TelemetryKind.allCases.enumerated() {
            let view = TelemetryFigureView(kind: kind, snapshot: snapshot, theme: theme, colorScheme: colorScheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            renderer.proposedSize = ProposedViewSize(TelemetryFigureView.size)
            guard let cg = renderer.cgImage else { throw CaptureError.renderFailed(kind.title) }
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = TelemetryFigureView.size  // 72-dpi points → PNG carries the 3× pixel density
            guard let png = rep.representation(using: .png, properties: [:]) else { throw CaptureError.renderFailed(kind.title) }
            let url = folder.appendingPathComponent("\(index + 1)-\(kind.title).png")
            try png.write(to: url)
            files.append(url)
        }
        return Result(folder: folder, files: files)
    }

    enum CaptureError: LocalizedError {
        case renderFailed(String)
        var errorDescription: String? {
            switch self {
            case .renderFailed(let name): return "Could not render the \(name) figure."
            }
        }
    }
}
