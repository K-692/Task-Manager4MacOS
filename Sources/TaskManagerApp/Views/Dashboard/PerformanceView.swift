import SwiftUI
import TaskManagerCore

/// Performance view: interactive CPU time series, memory breakdown, and top processes.
public struct PerformanceView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let cpu = sampling.latestCPU?.value
        let mem = sampling.latestMemory?.value
        let processes = sampling.latestProcesses?.value ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance")
                        .font(.system(size: 26, weight: .bold))
                    Text("Interactive CPU utilization, Mach memory architecture, and active applications.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // CPU Time-Series Chart Card
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CPU Utilization (Last 60 Seconds)")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Current: \(String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0)) • User: \(String(format: "%.1f%%", cpu?.userPercent ?? 0.0)) • System: \(String(format: "%.1f%%", cpu?.systemPercent ?? 0.0))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            StatusBadge(status: sampling.latestCPU?.status ?? .available)
                        }

                        CPUTimeSeriesChart(
                            dataPoints: sampling.cpuHistory.values.isEmpty ? [0, 0] : sampling.cpuHistory.values
                        )
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Memory Composition Card
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Memory Breakdown & Pressure")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Total Installed: \(env.deviceProfile.formattedMemory) • Pressure Level: \(mem?.pressureLevel ?? "Normal")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(mem?.pressureLevel ?? "Normal")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.emerald.opacity(0.15))
                                .foregroundColor(.emerald)
                                .clipShape(Capsule())
                        }

                        if let m = mem {
                            // Stacked Bar
                            GeometryReader { geo in
                                let w = geo.size.width
                                let activeW = w * CGFloat(Double(m.activeBytes) / Double(m.totalBytes))
                                let wiredW = w * CGFloat(Double(m.wiredBytes) / Double(m.totalBytes))
                                let compW = w * CGFloat(Double(m.compressedBytes) / Double(m.totalBytes))
                                let freeW = max(0, w - activeW - wiredW - compW)

                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.blue).frame(width: activeW)
                                    RoundedRectangle(cornerRadius: 3).fill(Color.indigo).frame(width: wiredW)
                                    RoundedRectangle(cornerRadius: 3).fill(Color.purple).frame(width: compW)
                                    RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.08)).frame(width: freeW)
                                }
                            }
                            .frame(height: 12)
                            .padding(.vertical, 4)

                            // Legend & Details
                            HStack(spacing: 16) {
                                Label("Active: \(formatBytes(m.activeBytes))", systemImage: "circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Label("Wired: \(formatBytes(m.wiredBytes))", systemImage: "circle.fill")
                                    .foregroundColor(.indigo)
                                    .font(.caption)
                                Label("Compressed: \(formatBytes(m.compressedBytes))", systemImage: "circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.caption)
                                Label("Free: \(formatBytes(m.freeBytes))", systemImage: "circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Top Running Processes Table
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Active Applications (\(processes.prefix(10).count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    CardView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Application").font(.caption.bold()).frame(width: 200, alignment: .leading)
                                Text("PID").font(.caption.bold()).frame(width: 80, alignment: .leading)
                                Text("Memory").font(.caption.bold()).frame(width: 100, alignment: .leading)
                                Spacer()
                                Text("Status").font(.caption.bold()).frame(width: 80, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            .foregroundColor(.secondary)

                            Divider()

                            ForEach(processes.prefix(8)) { proc in
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "app.fill")
                                            .foregroundColor(.indigo)
                                            .font(.system(size: 12))
                                        Text(proc.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .frame(width: 200, alignment: .leading)

                                    Text("\(proc.pid)")
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .leading)

                                    Text(proc.formattedMemory)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                        .frame(width: 100, alignment: .leading)

                                    Spacer()

                                    Text(proc.isActive ? "Active" : "Background")
                                        .font(.caption)
                                        .foregroundColor(proc.isActive ? .emerald : .secondary)
                                        .frame(width: 80, alignment: .trailing)
                                }
                                .padding(.vertical, 6)

                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .onAppear {
            sampling.isDashboardActive = true
        }
        .onDisappear {
            sampling.isDashboardActive = false
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
