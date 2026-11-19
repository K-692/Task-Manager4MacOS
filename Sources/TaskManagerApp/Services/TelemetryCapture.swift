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

/// A single figure for one component: just the title and the graph.
struct TelemetryFigureView: View {
    let kind: TelemetryKind
    let snapshot: TelemetrySnapshot
    let theme: VisualTheme
    let marks: PublicationMarkings
    let panelIndex: Int
    let colorScheme: ColorScheme

    static let size = CGSize(width: 960, height: 540)

    var body: some View {
        let pub = theme.isPublication
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 22, weight: pub ? .regular : .bold, design: pub ? .serif : .rounded))
                .foregroundColor(pub ? PublicationPalette.text : .primary)
            chart
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(28)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(background)
        .environment(\.visualTheme, theme)
        .environment(\.publicationMarkings, marks)
        .environment(\.sampleInterval, snapshot.interval)
        .environment(\.layoutClass, .wide)
        .environment(\.colorScheme, pub ? .light : colorScheme)
    }

    private var title: String {
        guard theme.isPublication && marks.panelLabels else { return kind.figureTitle }
        let letter = Character(UnicodeScalar(UInt8(97 + panelIndex)))
        return "(\(letter)) \(kind.figureTitle)"
    }

    @ViewBuilder
    private var chart: some View {
        switch kind {
        case .network:
            let u = ThroughputUnit.pick(maxBytesPerSecond: max(snapshot.netIn.max() ?? 0, snapshot.netOut.max() ?? 0))
            TelemetryChart(
                series: [
                    ChartSeries(name: "Download", values: padded(snapshot.netIn), color: theme.isPublication ? PublicationPalette.blue : .cyan),
                    ChartSeries(name: "Upload", values: padded(snapshot.netOut), color: theme.isPublication ? PublicationPalette.orange : .indigo, dashed: theme.isPublication)
                ],
                yDomain: nil,
                unit: theme.isPublication ? "Throughput (\(u.name))" : u.name,
                scale: u.scale,
                showLegend: true
            )
        default:
            TelemetryChart(
                series: [ChartSeries(name: kind.title, values: padded(snapshot.values(for: kind)), color: kind.color(for: theme))],
                yDomain: 0...100,
                unit: theme.isPublication ? (kind == .cpu || kind == .gpu ? "Utilization (%)" : "Usage (%)") : "%"
            )
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
            let view = TelemetryFigureView(kind: kind, snapshot: snapshot, theme: theme, marks: env.publicationMarkings, panelIndex: index, colorScheme: colorScheme)
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
