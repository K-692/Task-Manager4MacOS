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
                            .foregroundStyle(markColor(MarkingColor.band, st, single).opacity(0.08))
                    }
                    if m.stdDevBand {
                        RectangleMark(xStart: .value("Time (s)", -window), xEnd: .value("Time (s)", 0),
                                      yStart: .value(unit, max(0, st.mean - st.sd)),
                                      yEnd: .value(unit, isPercent ? min(100, st.mean + st.sd) : st.mean + st.sd))
                            .foregroundStyle(markColor(MarkingColor.band, st, single).opacity(0.16))
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
                    let primary = st.name == stats.first?.name
                    if m.movingAverage {
                        ForEach(st.movingAverage) { p in
                            LineMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value), series: .value("Series", "\(st.name) moving average"))
                                .interpolationMethod(.linear)
                                .foregroundStyle(markColor(MarkingColor.movingAverage, st, single))
                                .lineStyle(StrokeStyle(lineWidth: 1.3, dash: [1, 2]))
                        }
                    }
                    if m.trendLine, st.points.count >= 2 {
                        LineMark(x: .value("Time (s)", st.points.first!.seconds), y: .value(unit, clampY(st.trendStart, isPercent)), series: .value("Series", "\(st.name) trend"))
                            .foregroundStyle(markColor(MarkingColor.trend, st, single))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [8, 3, 2, 3]))
                        LineMark(x: .value("Time (s)", st.points.last!.seconds), y: .value(unit, clampY(st.trendEnd, isPercent)), series: .value("Series", "\(st.name) trend"))
                            .foregroundStyle(markColor(MarkingColor.trend, st, single))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [8, 3, 2, 3]))
                    }
                    if m.mean {
                        RuleMark(y: .value("Mean", st.mean))
                            .foregroundStyle(markColor(MarkingColor.mean, st, single))
                            .lineStyle(StrokeStyle(lineWidth: 1.1, dash: [3, 3]))
                            .annotation(position: .top, alignment: .leading, spacing: 2) {
                                inside(primary ? "mean \(Self.format(st.mean, unit: unit))" : "", m).padding(.leading, 4)
                            }
                    }
                    if m.median {
                        RuleMark(y: .value("Median", st.median))
                            .foregroundStyle(markColor(MarkingColor.median, st, single))
                            .lineStyle(StrokeStyle(lineWidth: 1.1, dash: [6, 2, 1, 2]))
                            .annotation(position: .bottom, alignment: .leading, spacing: 2) {
                                inside(primary ? "median \(Self.format(st.median, unit: unit))" : "", m).padding(.leading, 4)
                            }
                    }
                    if m.peak, let p = st.maxPoint, p.value > 0 {
                        PointMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value))
                            .symbol(.triangle)
                            .symbolSize(44)
                            .foregroundStyle(markColor(MarkingColor.peak, st, single))
                            .annotation(position: p.seconds < -window * 0.85 ? .topTrailing : (p.seconds > -window * 0.15 ? .topLeading : .top), spacing: 3) {
                                inside(single ? "peak \(Self.format(p.value, unit: unit))" : "\(st.name.lowercased()) peak \(Self.format(p.value, unit: unit))", m)
                            }
                    }
                    if m.minimum, let p = st.minPoint {
                        PointMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value))
                            .symbol(.diamond)
                            .symbolSize(40)
                            .foregroundStyle(markColor(MarkingColor.minimum, st, single))
                            .annotation(position: p.seconds < -window * 0.85 ? .bottomTrailing : (p.seconds > -window * 0.15 ? .bottomLeading : .bottom), spacing: 3) {
                                inside(primary ? "min \(Self.format(p.value, unit: unit))" : "", m)
                            }
                    }
                    if m.latest, let p = st.last {
                        PointMark(x: .value("Time (s)", p.seconds), y: .value(unit, p.value))
                            .symbol(.circle)
                            .symbolSize(40)
                            .foregroundStyle(markColor(MarkingColor.latest, st, single))
                            .annotation(position: .topLeading, spacing: 2) {
                                inside(primary ? "now \(Self.format(p.value, unit: unit))" : "", m)
                            }
                    }
                }
                if m.threshold, isPercent {
                    RuleMark(y: .value("Threshold", m.thresholdValue))
                        .foregroundStyle(single ? markColor(MarkingColor.threshold, stats[0], true) : MarkingColor.threshold)
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [10, 4]))
                        .annotation(position: .top, alignment: .trailing, spacing: 2) {
                            inside("threshold \(Int(m.thresholdValue))%", m)
                        }
                }
            }
        }
        .chartForegroundStyleScale(domain: series.map(\.name), range: series.map(\.color))
        .chartXScale(domain: -window...0)
        // Publication charts use the custom key below (real line styles) instead of Charts' dot legend.
        .chartLegend((!pub && showLegend) ? .visible : .hidden)
        .chartLegend(position: .bottom, alignment: .trailing)

        // Legend always sits below the graph, aligned to the right.
        return VStack(alignment: .trailing, spacing: 4) {
            Group {
                if pub {
                    publicationAxes(chart, window: window, m: m)
                } else {
                    standardAxes(chart)
                }
            }
            if pub && m.legend && (m.hasStatisticalMarks || series.count > 1) {
                MarkingsKey(entries: legendEntries(stats: stats, m: m, single: single, isPercent: isPercent))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(minHeight: 56, idealHeight: 180, maxHeight: .infinity)
    }

    /// Keeps derived lines (e.g. the trend) inside the plotted range.
    private func clampY(_ v: Double, _ isPercent: Bool) -> Double {
        isPercent ? min(100, max(0, v)) : max(0, v)
    }

    /// Marking colour: its own publication colour on single-series charts (adjusted if it
    /// would match the data line), the series colour on multi-series charts.
    private func markColor(_ preferred: Color, _ st: SeriesStats, _ single: Bool) -> Color {
        single ? MarkingColor.distinct(preferred, from: st.color) : st.color
    }

    /// Text written inside the plot (only when labels are placed inside).
    @ViewBuilder
    private func inside(_ text: String, _ m: PublicationMarkings) -> some View {
        if m.valueLabels && m.labelPlacement == .inside && !text.isEmpty {
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundColor(PublicationPalette.text)
        }
    }

    /// Legend entries: series, then each active marking with its colour/style and (when the
    /// values go in the legend) its value.
    private func legendEntries(stats: [SeriesStats], m: PublicationMarkings, single: Bool, isPercent: Bool) -> [LegendEntry] {
        let withValues = m.valueLabels && m.labelPlacement == .legend
        let neutral = PublicationPalette.text
        func values(_ pick: (SeriesStats) -> Double?) -> String {
            guard withValues else { return "" }
            let parts: [String] = stats.compactMap { st in
                guard let v = pick(st) else { return nil }
                return single ? Self.format(v, unit: unit) : "\(st.name.prefix(1)) \(Self.format(v, unit: unit))"
            }
            return parts.isEmpty ? "" : " " + parts.joined(separator: ", ")
        }
        func color(_ preferred: Color) -> Color {
            single ? markColor(preferred, stats[0], true) : neutral
        }

        var e: [LegendEntry] = []
        if !single {
            for s in series { e.append(.init(label: s.name, style: .line(dash: s.dashed ? [5, 3] : [], width: 2), color: s.color)) }
        }
        if m.mean { e.append(.init(label: "Mean" + values { $0.mean }, style: .line(dash: [3, 3], width: 1.3), color: color(MarkingColor.mean))) }
        if m.median { e.append(.init(label: "Median" + values { $0.median }, style: .line(dash: [6, 2, 1, 2], width: 1.3), color: color(MarkingColor.median))) }
        if m.trendLine { e.append(.init(label: "Linear trend", style: .line(dash: [8, 3, 2, 3], width: 1.3), color: color(MarkingColor.trend))) }
        if m.movingAverage { e.append(.init(label: "Moving avg (\(m.movingAverageWindow))", style: .line(dash: [1, 2], width: 1.5), color: color(MarkingColor.movingAverage))) }
        if m.threshold && isPercent {
            e.append(.init(label: "Threshold" + (withValues ? " \(Int(m.thresholdValue))%" : ""), style: .line(dash: [10, 4], width: 1.3),
                           color: single ? markColor(MarkingColor.threshold, stats[0], true) : MarkingColor.threshold))
        }
        if m.stdDevBand {
            let sd = values { $0.sd }
            e.append(.init(label: "Mean ± 1σ" + (sd.isEmpty ? "" : " (σ =\(sd))"), style: .band(opacity: 0.25), color: color(MarkingColor.band)))
        }
        if m.rangeBand { e.append(.init(label: "Min–max range", style: .band(opacity: 0.12), color: color(MarkingColor.band))) }
        if m.peak { e.append(.init(label: "Peak" + values { $0.maxPoint?.value }, style: .symbol("triangle.fill"), color: color(MarkingColor.peak))) }
        if m.minimum { e.append(.init(label: "Minimum" + values { $0.minPoint?.value }, style: .symbol("diamond.fill"), color: color(MarkingColor.minimum))) }
        if m.latest { e.append(.init(label: "Latest" + values { $0.last?.value }, style: .symbol("circle.fill"), color: color(MarkingColor.latest))) }
        return e
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
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7)).foregroundStyle(PublicationPalette.grid)
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
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7)).foregroundStyle(PublicationPalette.grid)
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
            // No plot background here: it would be drawn over the gridlines (the panel
            // behind the chart is already white in the Publication theme).
            .chartPlotStyle { plot in
                plot.border(m.plotFrame ? PublicationPalette.axis : Color.clear, width: 0.8)
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

/// One legend row: a sample (line, band or symbol) in the marking's colour plus its text.
struct LegendEntry: Identifiable {
    enum Style {
        case line(dash: [CGFloat], width: CGFloat)
        case band(opacity: Double)
        case symbol(String)
    }
    var id: String { label }
    let label: String
    let style: Style
    let color: Color
}

/// Legend drawn below the graph (right-aligned), wrapping onto extra lines when needed.
struct MarkingsKey: View {
    let entries: [LegendEntry]

    var body: some View {
        FlowLayout(spacing: 12, lineSpacing: 3, alignment: .trailing) {
            ForEach(entries) { entry in
                HStack(spacing: 4) {
                    sample(entry)
                    Text(entry.label)
                        .font(.system(size: 9, design: .serif))
                        .foregroundColor(PublicationPalette.text)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func sample(_ entry: LegendEntry) -> some View {
        switch entry.style {
        case .line(let dash, let width):
            Path { p in p.move(to: CGPoint(x: 0, y: 4)); p.addLine(to: CGPoint(x: 20, y: 4)) }
                .stroke(entry.color, style: StrokeStyle(lineWidth: width, dash: dash))
                .frame(width: 20, height: 8)
        case .band(let opacity):
            Rectangle().fill(entry.color.opacity(opacity)).frame(width: 16, height: 8)
        case .symbol(let name):
            Image(systemName: name).font(.system(size: 7)).foregroundColor(entry.color)
        }
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
