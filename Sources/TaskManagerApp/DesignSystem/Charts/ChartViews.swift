import SwiftUI
import Charts
import TaskManagerCore

/// Interactive Swift Charts time-series view for CPU load.
public struct CPUTimeSeriesChart: View {
    public let dataPoints: [Double]

    public init(dataPoints: [Double]) {
        self.dataPoints = dataPoints
    }

    private struct ChartPoint: Identifiable {
        let id: Int
        let value: Double
    }

    public var body: some View {
        let points = dataPoints.enumerated().map { ChartPoint(id: $0.offset, value: $0.element) }

        Chart(points) { point in
            AreaMark(
                x: .value("Time", point.id),
                y: .value("CPU %", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.indigo.opacity(0.35), Color.indigo.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", point.id),
                y: .value("CPU %", point.value)
            )
            .foregroundStyle(Color.indigo)
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
        .frame(height: 140)
    }
}

/// Swift Charts view for Network inbound vs outbound throughput.
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
            points.append(NetPoint(id: "in_\(idx)", timeIndex: idx, direction: "Inbound (Download)", rateKB: val / 1024.0))
        }
        for (idx, val) in outboundPoints.enumerated() {
            points.append(NetPoint(id: "out_\(idx)", timeIndex: idx, direction: "Outbound (Upload)", rateKB: val / 1024.0))
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
            "Inbound (Download)": Color.emerald,
            "Outbound (Upload)": Color.blue
        ])
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let dVal = value.as(Double.self) {
                        Text(String(format: "%.0f KB", dVal))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .trailing)
        .frame(height: 140)
    }
}

/// Bar chart showing open task distribution across priority levels.
public struct PriorityDistributionChart: View {
    public let counts: [TaskPriority: Int]

    public init(counts: [TaskPriority: Int]) {
        self.counts = counts
    }

    private struct PriorityPoint: Identifiable {
        var id: String { priority.rawValue }
        let priority: TaskPriority
        let count: Int
    }

    public var body: some View {
        let points = TaskPriority.allCases.map { PriorityPoint(priority: $0, count: counts[$0] ?? 0) }

        Chart(points) { point in
            BarMark(
                x: .value("Priority", point.priority.displayName),
                y: .value("Count", point.count)
            )
            .foregroundStyle(color(for: point.priority))
            .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel()
            }
        }
        .frame(height: 130)
    }

    private func color(for priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .slate
        case .normal: return .blue
        case .high: return .amber
        case .urgent: return .rose
        }
    }
}

/// Circular daily progress ring view.
public struct ProgressRingView: View {
    public let completed: Int
    public let total: Int
    public var size: CGFloat = 64

    public init(completed: Int, total: Int, size: CGFloat = 64) {
        self.completed = completed
        self.total = total
        self.size = size
    }

    private var progress: Double {
        guard total > 0 else { return 0.0 }
        return min(1.0, Double(completed) / Double(total))
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 6)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.indigo, .emerald]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)

            VStack(spacing: 0) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                Text("\(completed)/\(total)")
                    .font(.system(size: size * 0.16))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
