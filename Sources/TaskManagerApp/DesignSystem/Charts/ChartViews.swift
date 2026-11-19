import SwiftUI
import Charts
import TaskManagerCore

/// One line in a telemetry chart.
public struct ChartSeries: Identifiable {
    public let id: String
    public let name: String
    public let values: [Double]
    public let color: Color
    public let dashed: Bool

    public init(name: String, values: [Double], color: Color, dashed: Bool = false) {
        self.id = name
        self.name = name
        self.values = values
        self.color = color
        self.dashed = dashed
    }
}

private struct ChartPoint: Identifiable {
    let id: String
    let series: String
    let seconds: Double
    let value: Double
}

/// Shared time-series chart used everywhere (dashboard, detail pages, captured figures).
///
/// Standard theme: soft area fill, minimal axes.
/// Publication theme: white plot, black axes, labelled time axis (s), y-axis unit,
/// dashed mean reference line, and a marked peak — suitable for papers.
public struct TelemetryChart: View {
    public let series: [ChartSeries]
    /// nil = automatic (used for network throughput).
    public let yDomain: ClosedRange<Double>?
    public let unit: String
    /// Converts a raw value into the plotted value (e.g. bytes/s → MB/s).
    public let scale: Double
    public let showLegend: Bool
    /// Force publication markings on/off; nil = follow the theme.
    public let markings: Bool?

    @Environment(\.visualTheme) private var theme
    @Environment(\.layoutClass) private var layoutClass
    @Environment(\.sampleInterval) private var sampleInterval

    public init(series: [ChartSeries], yDomain: ClosedRange<Double>?, unit: String, scale: Double = 1, showLegend: Bool = false, markings: Bool? = nil) {
        self.series = series
        self.yDomain = yDomain
        self.unit = unit
        self.scale = scale
        self.showLegend = showLegend
        self.markings = markings
    }

    public var body: some View {
        let pub = theme.isPublication
        let showMarks = markings ?? pub
        let interval = sampleInterval > 0 ? sampleInterval : 1
        let window = Double(max(59, (series.map(\.values.count).max() ?? 1) - 1)) * interval
        let points = series.flatMap { s in
            s.values.enumerated().map { i, v in
                ChartPoint(id: "\(s.name)-\(i)", series: s.name,
                           seconds: -Double(s.values.count - 1 - i) * interval,
                           value: v / scale)
            }
        }
        let primary = series.first
        let primaryValues = (primary?.values ?? []).map { $0 / scale }
        let mean = primaryValues.isEmpty ? 0 : primaryValues.reduce(0, +) / Double(primaryValues.count)
        let peakIndex = primaryValues.indices.max(by: { primaryValues[$0] < primaryValues[$1] })
        let peakPoint: ChartPoint? = peakIndex.map { i in
            ChartPoint(id: "peak", series: primary?.name ?? "", seconds: -Double(primaryValues.count - 1 - i) * interval, value: primaryValues[i])
        }
        let colorMap = Dictionary(uniqueKeysWithValues: series.map { ($0.name, $0.color) })

        let chart = Chart {
            ForEach(points) { p in
                if !pub && series.count == 1 {
                    AreaMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(colors: [(colorMap[p.series] ?? .accentColor).opacity(0.38), (colorMap[p.series] ?? .accentColor).opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
                LineMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value), series: .value("Series", p.series))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(by: .value("Series", p.series))
                    .lineStyle(StrokeStyle(
                        lineWidth: pub ? 1.6 : 2,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: (series.first { $0.name == p.series }?.dashed ?? false) ? [5, 3] : []
                    ))
            }

            if showMarks, !primaryValues.isEmpty {
                RuleMark(y: .value("Mean", mean))
                    .foregroundStyle(pub ? PublicationPalette.black.opacity(0.75) : Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text("mean \(Self.format(mean, unit: unit))")
                            .font(.system(size: 9, design: pub ? .serif : .rounded))
                            .padding(.leading, 4)
                            .foregroundColor(pub ? PublicationPalette.secondaryText : .secondary)
                    }
                if let peak = peakPoint, peak.value > 0 {
                    PointMark(x: .value("Time (s)", peak.seconds), y: .value(unit, peak.value))
                        .symbol(.triangle)
                        .symbolSize(40)
                        .foregroundStyle(pub ? PublicationPalette.black : Color.primary)
                        .annotation(position: peak.seconds < -window * 0.85 ? .topTrailing : .top, spacing: 3) {
                            Text("peak \(Self.format(peak.value, unit: unit))")
                                .font(.system(size: 9, weight: .semibold, design: pub ? .serif : .rounded))
                                .foregroundColor(pub ? PublicationPalette.text : .primary)
                        }
                }
            }
        }
        .chartForegroundStyleScale(domain: series.map(\.name), range: series.map(\.color))
        .chartXScale(domain: -window...0)
        .chartLegend(showLegend ? .visible : .hidden)
        .chartLegend(position: .top, alignment: .trailing)

        return Group {
            if pub {
                publicationAxes(chart, window: window)
            } else {
                standardAxes(chart)
            }
        }
        .frame(minHeight: 56, idealHeight: 180, maxHeight: .infinity)
    }

    // MARK: Axes

    @ViewBuilder
    private func standardAxes<C: View>(_ chart: C) -> some View {
        let base = chart
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(Self.axisLabel(d, unit: unit))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        if let yDomain {
            base.chartYScale(domain: yDomain)
        } else {
            base
        }
    }

    @ViewBuilder
    private func publicationAxes<C: View>(_ chart: C, window: Double) -> some View {
        let step = window > 120 ? 30.0 : (window > 60 ? 20.0 : 10.0)
        let xTicks = Array(stride(from: -(window / step).rounded(.down) * step, through: 0, by: step))
        let base = chart
            .chartXAxis {
                AxisMarks(position: .bottom, values: xTicks) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(PublicationPalette.grid)
                    AxisTick(length: 4, stroke: StrokeStyle(lineWidth: 0.8))
                        .foregroundStyle(PublicationPalette.axis)
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(String(format: "%.0f", d))
                                .font(.system(size: 9, design: .serif))
                                .foregroundColor(PublicationPalette.text)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(PublicationPalette.grid)
                    AxisTick(length: 4, stroke: StrokeStyle(lineWidth: 0.8))
                        .foregroundStyle(PublicationPalette.axis)
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(Self.axisNumber(d))
                                .font(.system(size: 9, design: .serif))
                                .foregroundColor(PublicationPalette.text)
                        }
                    }
                }
            }
            .chartXAxisLabel(position: .bottom, alignment: .center) {
                Text("Time (s)")
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(PublicationPalette.text)
            }
            .chartYAxisLabel(position: .leading, alignment: .center) {
                Text(unit)
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(PublicationPalette.text)
            }
            .chartPlotStyle { plot in
                plot
                    .background(Color.white)
                    .border(PublicationPalette.axis, width: 0.8)
            }
        if let yDomain {
            base.chartYScale(domain: yDomain)
        } else {
            base
        }
    }

    private var yAxisValues: AxisMarkValues {
        if let yDomain, yDomain == 0...100 {
            return layoutClass == .compact && !theme.isPublication ? .stride(by: 50) : .stride(by: 25)
        }
        return .automatic(desiredCount: theme.isPublication ? 5 : 3)
    }

    // MARK: Formatting

    static func format(_ v: Double, unit: String) -> String {
        if unit.contains("%") { return String(format: "%.1f%%", v) }
        let suffix = unit.contains("KB/s") ? "KB/s" : "MB/s"
        return String(format: v >= 100 ? "%.0f %@" : (v >= 10 ? "%.1f %@" : "%.2f %@"), v, suffix)
    }

    static func axisLabel(_ v: Double, unit: String) -> String {
        if unit.contains("%") { return "\(Int(v))%" }
        return "\(axisNumber(v)) \(unit.contains("KB/s") ? "KB/s" : (unit.contains("MB/s") ? "MB/s" : unit))"
    }

    static func axisNumber(_ v: Double) -> String {
        if v == v.rounded() { return String(format: "%.0f", v) }
        return abs(v) < 1 ? String(format: "%.2f", v) : String(format: "%.1f", v)
    }
}

// MARK: - Convenience wrappers (keep existing call sites)

private struct ThemedPercentChart: View {
    let kind: TelemetryKind
    let values: [Double]
    @Environment(\.visualTheme) private var theme

    var body: some View {
        TelemetryChart(
            series: [ChartSeries(name: kind.title, values: values, color: kind.color(for: theme))],
            yDomain: 0...100,
            unit: theme.isPublication ? "Utilization (%)" : "%"
        )
    }
}

public struct CPUTimeSeriesChart: View {
    public let dataPoints: [Double]
    public init(dataPoints: [Double]) { self.dataPoints = dataPoints }
    public var body: some View { ThemedPercentChart(kind: .cpu, values: dataPoints) }
}

public struct GPUTimeSeriesChart: View {
    public let dataPoints: [Double]
    public init(dataPoints: [Double]) { self.dataPoints = dataPoints }
    public var body: some View { ThemedPercentChart(kind: .gpu, values: dataPoints) }
}

public struct MemoryTimeSeriesChart: View {
    public let dataPoints: [Double]
    public init(dataPoints: [Double]) { self.dataPoints = dataPoints }
    public var body: some View { ThemedPercentChart(kind: .memory, values: dataPoints) }
}

public struct DiskTimeSeriesChart: View {
    public let dataPoints: [Double]
    public init(dataPoints: [Double]) { self.dataPoints = dataPoints }
    public var body: some View { ThemedPercentChart(kind: .storage, values: dataPoints) }
}

/// Picks KB/s or MB/s so small network rates stay readable.
public enum ThroughputUnit {
    public static func pick(maxBytesPerSecond: Double) -> (name: String, scale: Double) {
        maxBytesPerSecond < 1_048_576 ? ("KB/s", 1024) : ("MB/s", 1_048_576)
    }
}

/// Network throughput (download + upload) chart, auto-scaled to KB/s or MB/s.
public struct NetworkThroughputChart: View {
    public let inboundPoints: [Double]
    public let outboundPoints: [Double]
    public let showsLegend: Bool
    @Environment(\.visualTheme) private var theme

    public init(inboundPoints: [Double], outboundPoints: [Double], showsLegend: Bool = false) {
        self.inboundPoints = inboundPoints
        self.outboundPoints = outboundPoints
        self.showsLegend = showsLegend
    }

    public var body: some View {
        let pub = theme.isPublication
        let u = ThroughputUnit.pick(maxBytesPerSecond: max(inboundPoints.max() ?? 0, outboundPoints.max() ?? 0))
        TelemetryChart(
            series: [
                ChartSeries(name: "Download", values: inboundPoints, color: pub ? PublicationPalette.blue : .cyan),
                ChartSeries(name: "Upload", values: outboundPoints, color: pub ? PublicationPalette.orange : .indigo, dashed: pub)
            ],
            yDomain: nil,
            unit: pub ? "Throughput (\(u.name))" : u.name,
            scale: u.scale,
            showLegend: showsLegend || pub
        )
    }
}
