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

/// Per-series statistics used by the publication markings.
private struct SeriesStats {
    let name: String
    let color: Color
    let points: [ChartPoint]
    let mean: Double
    let median: Double
    let sd: Double
    let minPoint: ChartPoint?
    let maxPoint: ChartPoint?
    let last: ChartPoint?
    let trendStart: Double
    let trendEnd: Double
    let movingAverage: [ChartPoint]

    init(series: ChartSeries, scale: Double, interval: Double, window: Double, maWindow: Int) {
        name = series.name
        color = series.color
        let values = series.values.map { $0 / scale }
        let n = values.count
        points = values.enumerated().map { i, v in
            ChartPoint(id: "\(series.name)-\(i)", series: series.name, seconds: -Double(n - 1 - i) * interval, value: v)
        }
        mean = n == 0 ? 0 : values.reduce(0, +) / Double(n)
        let sorted = values.sorted()
        median = n == 0 ? 0 : (n % 2 == 1 ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2)
        let m = mean
        sd = n == 0 ? 0 : sqrt(values.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(n))
        minPoint = points.min(by: { $0.value < $1.value })
        maxPoint = points.max(by: { $0.value < $1.value })
        last = points.last
        // Least-squares linear trend over time.
        if n >= 2 {
            let xs = points.map(\.seconds)
            let xMean = xs.reduce(0, +) / Double(n)
            var num = 0.0, den = 0.0
            for (x, y) in zip(xs, values) { num += (x - xMean) * (y - m); den += (x - xMean) * (x - xMean) }
            let slope = den == 0 ? 0 : num / den
            let intercept = m - slope * xMean
            trendStart = intercept + slope * (xs.first ?? 0)
            trendEnd = intercept + slope * (xs.last ?? 0)
        } else {
            trendStart = m
            trendEnd = m
        }
        // Trailing moving average.
        let k = max(2, maWindow)
        var ma: [ChartPoint] = []
        if n >= k {
            for i in (k - 1)..<n {
                let avg = values[(i - k + 1)...i].reduce(0, +) / Double(k)
                ma.append(ChartPoint(id: "\(series.name)-ma-\(i)", series: series.name, seconds: points[i].seconds, value: avg))
            }
        }
        movingAverage = ma
    }
}

/// Shared time-series chart used everywhere (dashboard, detail pages, captured figures).
///
/// Standard theme: soft area fill, minimal axes, no markings.
/// Publication theme: white plot, labelled axes and the reference markings the user
/// enabled in Settings → Theme → Publication markings.
public struct TelemetryChart: View {
    public let series: [ChartSeries]
    /// nil = automatic (used for network throughput).
    public let yDomain: ClosedRange<Double>?
    public let unit: String
    /// Converts a raw value into the plotted value (e.g. bytes/s → MB/s).
    public let scale: Double
    public let showLegend: Bool

    @Environment(\.visualTheme) private var theme
    @Environment(\.publicationMarkings) private var marks
    @Environment(\.layoutClass) private var layoutClass
    @Environment(\.sampleInterval) private var sampleInterval
    @Environment(\.showsMarkingsKey) private var showsKey

    public init(series: [ChartSeries], yDomain: ClosedRange<Double>?, unit: String, scale: Double = 1, showLegend: Bool = false) {
        self.series = series
        self.yDomain = yDomain
        self.unit = unit
        self.scale = scale
        self.showLegend = showLegend
    }

    public var body: some View {
        let pub = theme.isPublication
        let m = pub ? marks : PublicationMarkings.minimal
        let interval = sampleInterval > 0 ? sampleInterval : 1
        let window = Double(max(59, (series.map(\.values.count).max() ?? 1) - 1)) * interval
        let stats = series.map { SeriesStats(series: $0, scale: scale, interval: interval, window: window, maWindow: m.movingAverageWindow) }
        let single = stats.count == 1
        let isPercent = unit.contains("%")
        let interpolation: InterpolationMethod = (pub && !m.smoothCurves) ? .linear : .monotone

        let chart = Chart {
            // Bands (drawn first, underneath the data)
            if pub {
                ForEach(stats, id: \.name) { st in
                    if m.rangeBand, let lo = st.minPoint, let hi = st.maxPoint {
                        RectangleMark(xStart: .value("Time (s)", -window), xEnd: .value("Time (s)", 0),
                                      yStart: .value(unit, lo.value), yEnd: .value(unit, hi.value))
                            .foregroundStyle(markColor(st, single).opacity(0.06))
                    }
                    if m.stdDevBand {
                        RectangleMark(xStart: .value("Time (s)", -window), xEnd: .value("Time (s)", 0),
                                      yStart: .value(unit, max(0, st.mean - st.sd)),
                                      yEnd: .value(unit, isPercent ? min(100, st.mean + st.sd) : st.mean + st.sd))
                            .foregroundStyle(markColor(st, single).opacity(0.12))
                    }
                }
            }

            // Data
            ForEach(stats, id: \.name) { st in
                let dashed = series.first { $0.name == st.name }?.dashed ?? false
                let style = StrokeStyle(lineWidth: pub ? 1.6 : 2, lineCap: .round, lineJoin: .round, dash: dashed ? [5, 3] : [])
                ForEach(st.points) { p in
                    if !pub && single {
                        AreaMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value))
                            .interpolationMethod(interpolation)
                            .foregroundStyle(
                                LinearGradient(colors: [st.color.opacity(0.38), st.color.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    LineMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value), series: .value("Series", st.name))
                        .interpolationMethod(interpolation)
                        .foregroundStyle(by: .value("Series", st.name))
                        .lineStyle(style)
                    if pub && m.dataPoints {
                        PointMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value))
                            .symbol(.circle)
                            .symbolSize(10)
                            .foregroundStyle(st.color)
                    }
                }
            }

            // Reference lines and point markers
            if pub {
                ForEach(stats, id: \.name) { st in
                    if m.movingAverage {
                        ForEach(st.movingAverage) { p in
                            LineMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value), series: .value("Series", "\(st.name) moving average"))
                                .interpolationMethod(.linear)
                                .foregroundStyle(markColor(st, single).opacity(0.85))
                                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [1, 2]))
                        }
                    }
                    if m.trendLine, st.points.count >= 2 {
                        LineMark(x: .value("Time (s)", st.points.first!.seconds), y: .value(unit, clampY(st.trendStart, isPercent)), series: .value("Series", "\(st.name) trend"))
                            .foregroundStyle(markColor(st, single))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [8, 3, 2, 3]))
                        LineMark(x: .value("Time (s)", st.points.last!.seconds), y: .value(unit, clampY(st.trendEnd, isPercent)), series: .value("Series", "\(st.name) trend"))
                            .foregroundStyle(markColor(st, single))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [8, 3, 2, 3]))
                    }
                    if m.mean {
                        RuleMark(y: .value("Mean", st.mean))
                            .foregroundStyle(markColor(st, single).opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .annotation(position: .top, alignment: .leading, spacing: 2) {
                                label(st.name == stats.first?.name ? "mean \(Self.format(st.mean, unit: unit))" : "", m).padding(.leading, 4)
                            }
                    }
                    if m.median {
                        RuleMark(y: .value("Median", st.median))
                            .foregroundStyle(markColor(st, single).opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 2, 1, 2]))
                            .annotation(position: .bottom, alignment: .leading, spacing: 2) {
                                label(st.name == stats.first?.name ? "median \(Self.format(st.median, unit: unit))" : "", m).padding(.leading, 4)
                            }
                    }
                    if m.peak, let p = st.maxPoint, p.value > 0 {
                        PointMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value))
                            .symbol(.triangle)
                            .symbolSize(40)
                            .foregroundStyle(markColor(st, single))
                            .annotation(position: p.seconds < -window * 0.85 ? .topTrailing : (p.seconds > -window * 0.15 ? .topLeading : .top), spacing: 3) {
                                label(single ? "peak \(Self.format(p.value, unit: unit))" : "\(st.name.lowercased()) peak \(Self.format(p.value, unit: unit))", m, bold: true)
                            }
                    }
                    if m.minimum, let p = st.minPoint {
                        PointMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value))
                            .symbol(.diamond)
                            .symbolSize(36)
                            .foregroundStyle(markColor(st, single))
                            .annotation(position: p.seconds < -window * 0.85 ? .bottomTrailing : (p.seconds > -window * 0.15 ? .bottomLeading : .bottom), spacing: 3) {
                                label(st.name == stats.first?.name ? "min \(Self.format(p.value, unit: unit))" : "", m)
                            }
                    }
                    if m.latest, let p = st.last {
                        PointMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value))
                            .symbol(.circle)
                            .symbolSize(36)
                            .foregroundStyle(markColor(st, single))
                            .annotation(position: .topLeading, spacing: 2) {
                                label(st.name == stats.first?.name ? "now \(Self.format(p.value, unit: unit))" : "", m)
                            }
                    }
                }
                if m.threshold, isPercent {
                    RuleMark(y: .value("Threshold", m.thresholdValue))
                        .foregroundStyle(PublicationPalette.vermillion)
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [10, 4]))
                        .annotation(position: .top, alignment: .trailing, spacing: 2) {
                            label("threshold \(Int(m.thresholdValue))%", m)
                        }
                }
            }
        }
        .chartForegroundStyleScale(domain: series.map(\.name), range: series.map(\.color))
        .chartXScale(domain: -window...0)
        // Publication charts use the custom key below (real line styles) instead of Charts' dot legend.
        .chartLegend((!pub && showLegend) ? .visible : .hidden)
        .chartLegend(position: .top, alignment: .trailing)

        return VStack(alignment: .trailing, spacing: 4) {
            if pub && m.legend && (showsKey || series.count > 1) && (m.hasStatisticalMarks || series.count > 1) {
                MarkingsKey(marks: showsKey ? m : .seriesOnly, isPercent: isPercent, series: series.count > 1 ? series : [])
            }
            Group {
                if pub {
                    publicationAxes(chart, window: window, m: m)
                } else {
                    standardAxes(chart)
                }
            }
        }
        .frame(minHeight: 56, idealHeight: 180, maxHeight: .infinity)
    }

    /// Keeps derived lines (e.g. the trend) inside the plotted range.
    private func clampY(_ v: Double, _ isPercent: Bool) -> Double {
        isPercent ? min(100, max(0, v)) : max(0, v)
    }

    /// Single-series charts draw markings in black for contrast; multi-series use each series' colour.
    private func markColor(_ st: SeriesStats, _ single: Bool) -> Color {
        single ? PublicationPalette.black : st.color
    }

    @ViewBuilder
    private func label(_ text: String, _ m: PublicationMarkings, bold: Bool = false) -> some View {
        if m.valueLabels && !text.isEmpty {
            Text(text)
                .font(.system(size: 9, weight: bold ? .semibold : .regular, design: .serif))
                .foregroundColor(bold ? PublicationPalette.text : PublicationPalette.secondaryText)
        }
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
            base.chartYScale(domain: 0...autoUpperBound)
        }
    }

    @ViewBuilder
    private func publicationAxes<C: View>(_ chart: C, window: Double, m: PublicationMarkings) -> some View {
        let step = window > 120 ? 30.0 : (window > 60 ? 20.0 : 10.0)
        let xTicks = Array(stride(from: -(window / step).rounded(.down) * step, through: 0, by: step))
        let base = chart
            .chartXAxis {
                AxisMarks(position: .bottom, values: xTicks) { value in
                    if m.gridlines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PublicationPalette.grid)
                    }
                    if m.axisTicks {
                        AxisTick(length: 4, stroke: StrokeStyle(lineWidth: 0.8)).foregroundStyle(PublicationPalette.axis)
                    }
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
                    if m.gridlines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PublicationPalette.grid)
                    }
                    if m.axisTicks {
                        AxisTick(length: 4, stroke: StrokeStyle(lineWidth: 0.8)).foregroundStyle(PublicationPalette.axis)
                    }
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
                if m.axisTitles {
                    Text("Time (s)")
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(PublicationPalette.text)
                }
            }
            .chartYAxisLabel(position: .leading, alignment: .center) {
                if m.axisTitles {
                    Text(unit)
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(PublicationPalette.text)
                }
            }
            .chartPlotStyle { plot in
                plot
                    .background(Color.white)
                    .border(m.plotFrame ? PublicationPalette.axis : Color.clear, width: 0.8)
            }
        if let yDomain {
            base.chartYScale(domain: yDomain)
        } else {
            base.chartYScale(domain: 0...autoUpperBound)
        }
    }

    /// Upper bound for auto-scaled (throughput) charts: a "nice" number just above the
    /// highest plotted value, so the axis never dips below zero.
    private var autoUpperBound: Double {
        let maxValue = series.flatMap { $0.values }.map { $0 / scale }.max() ?? 0
        let target = max(maxValue * 1.12, 0.001)
        let exponent = pow(10, floor(log10(target)))
        for step in [1.0, 2.0, 2.5, 5.0, 10.0] where step * exponent >= target {
            return step * exponent
        }
        return 10 * exponent
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

/// Compact key that explains each active marking with its actual line / symbol style.
struct MarkingsKey: View {
    let marks: PublicationMarkings
    let isPercent: Bool
    var series: [ChartSeries] = []
    var publication = true

    var body: some View {
        FlowLayout(spacing: 12, lineSpacing: 4) {
            ForEach(series) { s in
                lineItem(s.name, dash: s.dashed ? [5, 3] : [], color: s.color, width: 2)
            }
            if marks.mean { lineItem("Mean", dash: [3, 3]) }
            if marks.median { lineItem("Median", dash: [6, 2, 1, 2]) }
            if marks.trendLine { lineItem("Linear trend", dash: [8, 3, 2, 3]) }
            if marks.movingAverage { lineItem("Moving avg (\(marks.movingAverageWindow))", dash: [1, 2]) }
            if marks.threshold && isPercent { lineItem("Threshold", dash: [10, 4], color: PublicationPalette.vermillion) }
            if marks.stdDevBand { bandItem("Mean ± 1σ", opacity: 0.18) }
            if marks.rangeBand { bandItem("Min–max range", opacity: 0.09) }
            if marks.peak { symbolItem("Peak", "triangle.fill") }
            if marks.minimum { symbolItem("Minimum", "diamond.fill") }
            if marks.latest { symbolItem("Latest", "circle.fill") }
        }
    }

    private func lineItem(_ name: String, dash: [CGFloat], color: Color = PublicationPalette.black, width: CGFloat = 1.2) -> some View {
        HStack(spacing: 4) {
            Path { p in p.move(to: CGPoint(x: 0, y: 4)); p.addLine(to: CGPoint(x: 20, y: 4)) }
                .stroke(color, style: StrokeStyle(lineWidth: width, dash: dash))
                .frame(width: 20, height: 8)
            text(name)
        }
    }

    private func bandItem(_ name: String, opacity: Double) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(PublicationPalette.black.opacity(opacity)).frame(width: 16, height: 8)
            text(name)
        }
    }

    private func symbolItem(_ name: String, _ symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 7)).foregroundColor(PublicationPalette.black)
            text(name)
        }
    }

    private func text(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 9, design: publication ? .serif : .default))
            .foregroundColor(publication ? PublicationPalette.text : .secondary)
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
            showLegend: showsLegend
        )
    }
}
