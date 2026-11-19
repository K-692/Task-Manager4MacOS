import SwiftUI
import TaskManagerCore

/// Dedicated in-depth CPU telemetry and microarchitecture inspector.
public struct CPUDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator
    @Environment(\.layoutClass) private var layoutClass

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let cpu = sampling.latestCPU?.value
        let processes = (sampling.latestProcesses?.value ?? []).sorted { $0.cpuPercent > $1.cpuPercent }
        let topCPUProcesses = Array(processes.prefix(6))

        DetailPage {
            DetailHeader(
                icon: "cpu",
                tint: .indigo,
                title: "Processor",
                subtitle: "\(env.deviceProfile.cpuName) • \(cpu?.physicalCores ?? env.deviceProfile.physicalCores) cores • \(cpu?.logicalCores ?? env.deviceProfile.logicalCores) threads",
                metric: String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0),
                metricLabel: "Total utilization"
            )

            SectionCard("Utilization History", icon: "waveform.path.ecg", tint: .indigo, accessory: {
                PillTag("60s", tint: .indigo)
            }) {
                CPUTimeSeriesChart(
                    dataPoints: sampling.cpuHistory.values.isEmpty ? [0, 0] : sampling.cpuHistory.values
                )
                .frame(height: layoutClass == .compact ? 140 : 200)
                ChartTimeAxis(tint: .indigo)
            }

            AdaptiveGrid(minimum: 300) {
                SectionCard("Execution Time", icon: "clock", tint: .indigo) {
                    VStack(spacing: 8) {
                        UsageBarRow(label: "User", value: cpu?.userPercent ?? 0, tint: .indigo)
                        UsageBarRow(label: "System", value: cpu?.systemPercent ?? 0, tint: .rose)
                        UsageBarRow(label: "Idle", value: cpu?.idlePercent ?? 100, tint: .emerald)
                    }
                }

                SectionCard("Topology", icon: "square.grid.3x3", tint: .indigo) {
                    VStack(spacing: 8) {
                        SpecRow("Architecture", env.deviceProfile.architecture)
                        SpecRow("Physical Cores", "\(cpu?.physicalCores ?? env.deviceProfile.physicalCores)")
                        SpecRow("Logical Threads", "\(cpu?.logicalCores ?? env.deviceProfile.logicalCores)")
                        SpecRow("Page Size", "16 KB (Mach VM)")
                    }
                }
            }

            SectionCard("Top CPU Consumers", icon: "flame", tint: .indigo, accessory: {
                PillTag("LIVE", tint: .emerald)
            }) {
                TopProcessTable(
                    rows: topCPUProcesses.map {
                        .init(id: $0.pid, name: $0.name, architecture: $0.architecture, isActive: $0.isActive, value: String(format: "%.1f%%", $0.cpuPercent))
                    },
                    valueTitle: "CPU %",
                    tint: .indigo
                )
            }
        }
    }
}

/// Label + horizontal bar + percentage, used for utilization breakdowns.
struct UsageBarRow: View {
    let label: String
    let value: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .themedSecondary()
                .frame(width: 64, alignment: .leading)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * CGFloat(min(100, max(0, value)) / 100)))
                }
            }
            .frame(height: 8)
            Text(String(format: "%.1f%%", value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(tint)
                .frame(width: 56, alignment: .trailing)
        }
    }
}
