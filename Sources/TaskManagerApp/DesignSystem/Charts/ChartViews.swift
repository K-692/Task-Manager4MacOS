import SwiftUI
import Charts
import TaskManagerCore

/// Reusable time-series chart point.
private struct MetricPoint: Identifiable {
    let id: Int
    let value: Double
}

/// Interactive Swift Charts time-series view for CPU load.
public struct CPUTimeSeriesChart: View {
    public let dataPoints: [Double]

    public init(dataPoints: [Double]) {
        self.dataPoints = dataPoints
    }

    public var body: some View {
        let points = dataPoints.enumerated().map { MetricPoint(id: $0.offset, value: $0.element) }

        Chart(points) { point in
            AreaMark(
                x: .value("Time", point.id),
                y: .value("CPU %", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.blue.opacity(0.35), Color.blue.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", point.id),
                y: .value("CPU %", point.value)
            )
            .foregroundStyle(Color.blue)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(height: 180)
    }
}

/// Interactive Swift Charts time-series view for Memory usage %.
public struct MemoryTimeSeriesChart: View {
    public let dataPoints: [Double]

    public init(dataPoints: [Double]) {
        self.dataPoints = dataPoints
    }

    public var body: some View {
        let points = dataPoints.enumerated().map { MetricPoint(id: $0.offset, value: $0.element) }

        Chart(points) { point in
            AreaMark(
                x: .value("Time", point.id),
                y: .value("Memory %", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.purple.opacity(0.35), Color.purple.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", point.id),
                y: .value("Memory %", point.value)
            )
            .foregroundStyle(Color.purple)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(height: 180)
    }
}

/// Interactive Swift Charts time-series view for GPU load %.
public struct GPUTimeSeriesChart: View {
    public let dataPoints: [Double]

    public init(dataPoints: [Double]) {
        self.dataPoints = dataPoints
    }

    public var body: some View {
        let points = dataPoints.enumerated().map { MetricPoint(id: $0.offset, value: $0.element) }

        Chart(points) { point in
            AreaMark(
                x: .value("Time", point.id),
                y: .value("GPU %", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.emerald.opacity(0.35), Color.emerald.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", point.id),
                y: .value("GPU %", point.value)
            )
            .foregroundStyle(Color.emerald)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(height: 180)
    }
}

/// Swift Charts view for Network throughput (Inbound & Outbound).
public struct NetworkThroughputChart: View {
    public let inboundPoints: [Double]
    public let outboundPoints: [Double]

    public init(inboundPoints: [Double], outboundPoints: [Double]) {
        self.inboundPoints = inboundPoints
        self.outboundPoints = outboundPoints
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
            points.append(NetPoint(id: "in_\(idx)", timeIndex: idx, direction: "Download (Inbound)", rateKB: val / 1024.0))
        }
        for (idx, val) in outboundPoints.enumerated() {
            points.append(NetPoint(id: "out_\(idx)", timeIndex: idx, direction: "Upload (Outbound)", rateKB: val / 1024.0))
        }

        return Chart(points) { point in
            LineMark(
                x: .value("Time", point.timeIndex),
                y: .value("Rate (KB/s)", point.rateKB)
            )
            .foregroundStyle(by: .value("Direction", point.direction))
            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .chartForegroundStyleScale([
            "Download (Inbound)": Color.cyan,
            "Upload (Outbound)": Color.indigo
        ])
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let dVal = value.as(Double.self) {
                        Text(String(format: "%.0f KB/s", dVal))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .trailing)
        .frame(height: 180)
    }
}
