import SwiftUI
import TaskManagerCore

/// Dedicated in-depth CPU telemetry and microarchitecture inspector.
public struct CPUDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let cpu = sampling.latestCPU?.value
        let processes = (sampling.latestProcesses?.value ?? []).sorted { $0.cpuPercent > $1.cpuPercent }
        let topCPUProcesses = Array(processes.prefix(6))

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: "cpu")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.indigo)
                            Text("CPU — Processor & Microarchitecture")
                                .font(.system(size: 22, weight: .bold))
                        }
                        Text("\(env.deviceProfile.cpuName) • \(cpu?.physicalCores ?? env.deviceProfile.physicalCores) Physical Cores • \(cpu?.logicalCores ?? env.deviceProfile.logicalCores) Logical Threads")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.indigo)
                        Text("TOTAL UTILIZATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // 60-Second Real-Time Utilization Chart
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("60-Second Utilization History")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("100%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        CPUTimeSeriesChart(
                            dataPoints: sampling.cpuHistory.values.isEmpty ? [0, 0] : sampling.cpuHistory.values
                        )

                        HStack {
                            Text("60s ago")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("0s (Live)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.indigo)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Core Load Breakdown & Architecture Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Execution Time Distribution")
                                .font(.system(size: 13, weight: .semibold))

                            VStack(spacing: 8) {
                                statRow(label: "User Space Load", value: String(format: "%.1f%%", cpu?.userPercent ?? 0.0), color: .indigo)
                                statRow(label: "System / Kernel Load", value: String(format: "%.1f%%", cpu?.systemPercent ?? 0.0), color: .rose)
                                statRow(label: "Idle Capacity", value: String(format: "%.1f%%", cpu?.idlePercent ?? 100.0), color: .emerald)
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Microarchitecture & Topology")
                                .font(.system(size: 13, weight: .semibold))

                            VStack(spacing: 8) {
                                specRow(label: "Architecture", value: "\(env.deviceProfile.architecture) (64-bit Little Endian)")
                                specRow(label: "Physical Cores", value: "\(cpu?.physicalCores ?? env.deviceProfile.physicalCores)")
                                specRow(label: "Logical Threads", value: "\(cpu?.logicalCores ?? env.deviceProfile.logicalCores)")
                                specRow(label: "Page Size", value: "16 KB (Mach VM)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Top CPU Consuming Processes
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Top CPU Consumers")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("Real-Time Sample")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 6) {
                            HStack {
                                Text("PID")
                                    .frame(width: 50, alignment: .leading)
                                Text("Process Name")
                                    .frame(minWidth: 150, alignment: .leading)
                                Spacer()
                                Text("Architecture")
                                    .frame(width: 90, alignment: .trailing)
                                Text("CPU %")
                                    .frame(width: 70, alignment: .trailing)
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                            Divider()

                            ForEach(topCPUProcesses) { proc in
                                HStack {
                                    Text("\(proc.pid)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 50, alignment: .leading)

                                    HStack(spacing: 6) {
                                        Image(systemName: proc.isActive ? "app.fill" : "gearshape.2")
                                            .font(.system(size: 10))
                                            .foregroundColor(proc.isActive ? .indigo : .secondary)
                                        Text(proc.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .frame(minWidth: 150, alignment: .leading)

                                    Spacer()

                                    Text(proc.architecture)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(width: 90, alignment: .trailing)
                                        .lineLimit(1)

                                    Text(String(format: "%.1f%%", proc.cpuPercent))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.indigo)
                                        .frame(width: 70, alignment: .trailing)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}
