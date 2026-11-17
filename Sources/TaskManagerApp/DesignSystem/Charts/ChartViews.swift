import SwiftUI
import Charts
import TaskManagerCore

/// Reusable time-series chart point.
private struct MetricPoint: Identifiable {
    let id: Int
    let value: Double
}

/// Generic, resizable percentage time-series chart (0–100%).
///
/// The chart has an ideal height of 180pt but flexes between `minHeight` and
/// the available space, so it shrinks gracefully inside small windows and grows
/// inside large dashboard cards.
public struct PercentTimeSeriesChart: View {
    public let dataPoints: [Double]
    public let tint: Color
    public let seriesName: String

    @Environment(\.layoutClass) private var layoutClass

    public init(dataPoints: [Double], tint: Color, seriesName: String) {
        self.dataPoints = dataPoints
        self.tint = tint
        self.seriesName = seriesName
    }

    public var body: some View {
        let points = dataPoints.enumerated().map { MetricPoint(id: $0.offset, value: $0.element) }
        let axisValues: [Int] = layoutClass == .compact ? [0, 50, 100] : [0, 25, 50, 75, 100]

        Chart(points) { point in
            AreaMark(
                x: .value("Time", point.id),
                y: .value(seriesName, point.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [tint.opacity(0.38), tint.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", point.id),
                y: .value(seriesName, point.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: 0...max(59, points.count - 1))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: axisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(minHeight: 56, idealHeight: 180, maxHeight: .infinity)
    }
}

/// Swift Charts time-series view for CPU load.
public struct CPUTimeSeriesChart: View {
    public let dataPoints: [Double]
    public init(dataPoints: [Double]) { self.dataPoints = dataPoints }
    public var body: some View {
        PercentTimeSeriesChart(dataPoints: dataPoints, tint: .indigo, seriesName: "CPU %")
    }
}

/// Swift Charts time-series view for GPU load.
public struct GPUTimeSeriesChart: View {
    public let dataPoints: [Double]
    public init(dataPoints: [Double]) { self.dataPoints = dataPoints }
    public var body: some View {
        PercentTimeSeriesChart(dataPoints: dataPoints, tint: .purple, seriesName: "GPU %")
    }
}

/// Swift Charts time-series view for Memory usage %.
public struct MemoryTimeSeriesChart: View {
    public let dataPoints: [Double]
    public init(dataPoints: [Double]) { self.dataPoints = dataPoints }
    public var body: some View {
        PercentTimeSeriesChart(dataPoints: dataPoints, tint: .blue, seriesName: "Memory %")
    }
}

/// Swift Charts time-series view for Disk space usage %.
public struct DiskTimeSeriesChart: View {
    public let dataPoints: [Double]
    public init(dataPoints: [Double]) { self.dataPoints = dataPoints }
    public var body: some View {
        PercentTimeSeriesChart(dataPoints: dataPoints, tint: .emerald, seriesName: "Disk %")
    }
}

/// Swift Charts view for Network throughput (Inbound & Outbound).
public struct NetworkThroughputChart: View {
    public let inboundPoints: [Double]
    public let outboundPoints: [Double]
    public let showsLegend: Bool

    public init(inboundPoints: [Double], outboundPoints: [Double], showsLegend: Bool = false) {
        self.inboundPoints = inboundPoints
        self.outboundPoints = outboundPoints
        self.showsLegend = showsLegend
    }

    private struct NetPoint: Identifiable {
        let id: String
        let timeIndex: Int
        let direction: String
        let rateKB: Double
    }

    public var body: some View {
        var points: [NetPoint] = []
        for (idx, val) in inboundPoints.enumerated() {
            points.append(NetPoint(id: "in_\(idx)", timeIndex: idx, direction: "Download", rateKB: val / 1024.0))
        }
        for (idx, val) in outboundPoints.enumerated() {
            points.append(NetPoint(id: "out_\(idx)", timeIndex: idx, direction: "Upload", rateKB: val / 1024.0))
        }
        let count = max(inboundPoints.count, outboundPoints.count)

        return Chart(points) { point in
            LineMark(
                x: .value("Time", point.timeIndex),
                y: .value("Rate (KB/s)", point.rateKB)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(by: .value("Direction", point.direction))
            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .chartForegroundStyleScale([
            "Download": Color.cyan,
            "Upload": Color.indigo
        ])
        .chartXScale(domain: 0...max(59, count - 1))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel {
                    if let dVal = value.as(Double.self) {
                        Text(Self.formatKB(dVal))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartLegend(showsLegend ? .visible : .hidden)
        .chartLegend(position: .top, alignment: .trailing)
        .frame(minHeight: 56, idealHeight: 180, maxHeight: .infinity)
    }

    private static func formatKB(_ kb: Double) -> String {
        if kb >= 1024 { return String(format: "%.1f MB/s", kb / 1024) }
        return String(format: "%.0f KB/s", kb)
    }
}
