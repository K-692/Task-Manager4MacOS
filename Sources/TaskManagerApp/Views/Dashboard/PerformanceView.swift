import SwiftUI
import TaskManagerCore

/// Unified Technical Performance Dashboard:
/// Single, non-scrollable window command-center showcasing real-time 60s graphs for
/// CPU, GPU (immediately after CPU), Memory, Disk, and Network.
public struct PerformanceView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let cpu = sampling.latestCPU?.value
        let gpu = sampling.latestGPU?.value
        let mem = sampling.latestMemory?.value
        let net = sampling.latestNetwork?.value
        let primaryDisk = sampling.latestStorage?.value?.first
        let procCount = sampling.latestProcesses?.value?.count ?? 0

        VStack(spacing: 12) {
            // MARK: Top System Ticker Header
            systemTickerHeader(cpu: cpu, gpu: gpu, mem: mem, net: net, primaryDisk: primaryDisk, procCount: procCount)

            // MARK: Main Non-Scrollable Telemetry Grid
            GeometryReader { geo in
                let availableHeight = geo.size.height
                let row1Height = max(160, (availableHeight - 12) * 0.52)
                let row2Height = max(140, (availableHeight - 12) * 0.48)

                VStack(spacing: 12) {
                    // ROW 1: CPU and GPU (50% / 50%) — GPU immediately follows CPU
                    HStack(spacing: 12) {
                        // 1. CPU Card
                        dashboardCard(
                            destination: .cpu,
                            title: "CPU",
                            subtitle: "\(env.deviceProfile.cpuName) • \(cpu?.physicalCores ?? env.deviceProfile.physicalCores) Cores",
                            icon: "cpu",
                            accentColor: .indigo,
                            primaryMetric: String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0),
                            secondaryMetric: "User: \(String(format: "%.0f%%", cpu?.userPercent ?? 0))  Kernel: \(String(format: "%.0f%%", cpu?.systemPercent ?? 0))"
                        ) {
                            CPUTimeSeriesChart(
                                dataPoints: sampling.cpuHistory.values.isEmpty ? [0, 0] : sampling.cpuHistory.values
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: row1Height)

                        // 2. GPU Card (Immediately after CPU)
                        dashboardCard(
                            destination: .gpu,
                            title: "GPU",
                            subtitle: "\(gpu?.deviceName ?? "Apple Silicon GPU") • Metal 3",
                            icon: "display.trianglebadge.exclamationmark",
                            accentColor: .purple,
                            primaryMetric: String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0),
                            secondaryMetric: "Renderer: \(String(format: "%.0f%%", gpu?.rendererUtilizationPercent ?? 0))  VRAM: \(gpu?.formattedInUseMemory ?? "0 MB")"
                        ) {
                            GPUTimeSeriesChart(
                                dataPoints: sampling.gpuHistory.values.isEmpty ? [0, 0] : sampling.gpuHistory.values
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: row1Height)
                    }

                    // ROW 2: Memory, Disk, Network (33.3% / 33.3% / 33.3%)
                    HStack(spacing: 12) {
                        // 3. Memory Card
                        dashboardCard(
                            destination: .memory,
                            title: "Memory",
                            subtitle: "\(mem?.formattedUsed ?? "—") of \(mem?.formattedTotal ?? env.deviceProfile.formattedMemory)",
                            icon: "memorychip",
                            accentColor: .blue,
                            primaryMetric: String(format: "%.0f%%", mem?.usagePercentage ?? 0.0),
                            secondaryMetric: "Pressure: \(mem?.pressureLevel.capitalized ?? "Normal")  Free: \(mem?.formattedFree ?? "—")"
                        ) {
                            MemoryTimeSeriesChart(
                                dataPoints: sampling.memoryHistory.values.isEmpty ? [0, 0] : sampling.memoryHistory.values
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: row2Height)

                        // 4. Disk Card
                        dashboardCard(
                            destination: .disk,
                            title: "Disk",
                            subtitle: "\(primaryDisk?.name ?? "Startup Disk") • \(primaryDisk?.fileSystemType ?? "APFS")",
                            icon: "internaldrive",
                            accentColor: .emerald,
                            primaryMetric: String(format: "%.0f%%", primaryDisk?.usagePercentage ?? 0.0),
                            secondaryMetric: "\(primaryDisk?.formattedAvailable ?? "—") Free of \(primaryDisk?.formattedTotal ?? "—")"
                        ) {
                            DiskTimeSeriesChart(
                                dataPoints: sampling.diskHistory.values.isEmpty ? [0, 0] : sampling.diskHistory.values
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: row2Height)

                        // 5. Network Card
                        dashboardCard(
                            destination: .network,
                            title: "Network",
                            subtitle: "Primary: \(net?.primaryInterfaceName ?? "en0")",
                            icon: "network",
                            accentColor: .cyan,
                            primaryMetric: net?.formattedInPerSecond ?? "0 B/s",
                            secondaryMetric: "↓ \(net?.formattedInPerSecond ?? "0 B/s")  ↑ \(net?.formattedOutPerSecond ?? "0 B/s")"
                        ) {
                            NetworkThroughputChart(
                                inboundPoints: sampling.networkInHistory.values.isEmpty ? [0, 0] : sampling.networkInHistory.values,
                                outboundPoints: sampling.networkOutHistory.values.isEmpty ? [0, 0] : sampling.networkOutHistory.values
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: row2Height)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .onAppear {
            sampling.isDashboardActive = true
        }
    }

    // MARK: - Reusable Non-Scrollable Dashboard Card
    private func dashboardCard<Content: View>(
        destination: AppDestination,
        title: String,
        subtitle: String,
        icon: String,
        accentColor: Color,
        primaryMetric: String,
        secondaryMetric: String,
        @ViewBuilder chart: () -> Content
    ) -> some View {
        Button(action: {
            env.selectedDestination = destination
        }) {
            CardView {
                VStack(alignment: .leading, spacing: 6) {
                    // Card Top Row
                    HStack(alignment: .top) {
                        HStack(spacing: 7) {
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(accentColor)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(title)
                                    .font(.system(size: 13, weight: .bold))
                                Text(subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(primaryMetric)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(accentColor)
                            HStack(spacing: 2) {
                                Text("Details")
                                    .font(.system(size: 9, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 7, weight: .bold))
                            }
                            .foregroundColor(.secondary.opacity(0.8))
                        }
                    }

                    // 60-Second Real-Time Chart
                    chart()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Card Bottom Stats Footer
                    HStack {
                        Text(secondaryMetric)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("60s Window")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - System Ticker Header Banner
    private func systemTickerHeader(
        cpu: CPUMetrics?,
        gpu: GPUMetrics?,
        mem: MemoryMetrics?,
        net: NetworkMetrics?,
        primaryDisk: VolumeInfo?,
        procCount: Int
    ) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.indigo)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Performance Dashboard")
                        .font(.system(size: 15, weight: .bold))
                    Text("\(env.deviceProfile.marketingName) • macOS \(env.deviceProfile.osVersion) (\(env.deviceProfile.osBuild))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Quick Live Pill Ticker
            HStack(spacing: 10) {
                pillItem(label: "CPU", val: String(format: "%.0f%%", cpu?.totalUsagePercent ?? 0), color: .indigo)
                pillItem(label: "GPU", val: String(format: "%.0f%%", gpu?.utilizationPercent ?? 0), color: .purple)
                pillItem(label: "RAM", val: String(format: "%.0f%%", mem?.usagePercentage ?? 0), color: .blue)
                pillItem(label: "DISK", val: String(format: "%.0f%%", primaryDisk?.usagePercentage ?? 0), color: .emerald)
                pillItem(label: "NET", val: net?.formattedInPerSecond ?? "0 B/s", color: .cyan)
                pillItem(label: "PROCS", val: "\(procCount)", color: .secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func pillItem(label: String, val: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            Text(val)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
