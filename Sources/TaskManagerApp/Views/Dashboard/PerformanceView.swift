import SwiftUI
import TaskManagerCore

/// Performance view: Windows Task Manager style resource monitor with sub-tabs for CPU, Memory, GPU, Disk, and Network.
public struct PerformanceView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator
    @State private var selectedTab: PerformanceSubtab = .cpu

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let cpu = sampling.latestCPU?.value
        let mem = sampling.latestMemory?.value
        let gpu = sampling.latestGPU?.value
        let net = sampling.latestNetwork?.value
        let disks = sampling.latestStorage?.value ?? []

        HStack(spacing: 0) {
            // Resource List (Left Column)
            VStack(spacing: 6) {
                // CPU item
                resourceButton(
                    tab: .cpu,
                    title: "CPU",
                    subtitle: "\(String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0))",
                    icon: "cpu",
                    tint: .indigo,
                    dataPoints: sampling.cpuHistory.values
                )

                // Memory item
                resourceButton(
                    tab: .memory,
                    title: "Memory",
                    subtitle: "\(mem?.formattedUsed ?? "0 GB") (\(String(format: "%.0f%%", mem?.usagePercentage ?? 0.0)))",
                    icon: "memorychip",
                    tint: .blue,
                    dataPoints: sampling.memoryHistory.values
                )

                // GPU item
                resourceButton(
                    tab: .gpu,
                    title: "GPU",
                    subtitle: "\(String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0))",
                    icon: "display.trianglebadge.exclamationmark",
                    tint: .purple,
                    dataPoints: sampling.gpuHistory.values
                )

                // Disk item
                resourceButton(
                    tab: .disk,
                    title: "Disk",
                    subtitle: "\(disks.first?.formattedAvailable ?? "0 GB") free",
                    icon: "internaldrive",
                    tint: .emerald,
                    dataPoints: []
                )

                // Network item
                resourceButton(
                    tab: .network,
                    title: "Network",
                    subtitle: "↓ \(net?.formattedInPerSecond ?? "0 B/s")",
                    icon: "network",
                    tint: .cyan,
                    dataPoints: sampling.networkInHistory.values
                )

                Spacer()
            }
            .padding(10)
            .frame(width: 200)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Detailed Resource View (Right Area)
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    switch selectedTab {
                    case .cpu:
                        cpuDetailView(cpu: cpu)
                    case .memory:
                        memoryDetailView(mem: mem)
                    case .gpu:
                        gpuDetailView(gpu: gpu)
                    case .disk:
                        diskDetailView(disks: disks)
                    case .network:
                        networkDetailView(net: net)
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
        }
        .onAppear {
            sampling.isDashboardActive = true
            selectedTab = env.selectedPerformanceSubtab
        }
        .onDisappear {
            sampling.isDashboardActive = false
        }
        .onChange(of: env.selectedPerformanceSubtab) { newTab in
            selectedTab = newTab
        }
    }

    // MARK: - Resource Selection Tile
    private func resourceButton(
        tab: PerformanceSubtab,
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        dataPoints: [Double]
    ) -> some View {
        let isSelected = selectedTab == tab
        return Button(action: {
            selectedTab = tab
            env.selectedPerformanceSubtab = tab
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    Text(subtitle)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CPU Detail
    private func cpuDetailView(cpu: CPUMetrics?) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 24, weight: .bold))
                    Text(env.deviceProfile.cpuName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0))")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.indigo)
            }

            // Real-time 60-second Chart
            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("% Utilization (60 Seconds)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }

                    CPUTimeSeriesChart(
                        dataPoints: sampling.cpuHistory.values.isEmpty ? [0, 0] : sampling.cpuHistory.values
                    )
                    .frame(height: 180)
                }
            }

            // Specs and Telemetry Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: "Utilization", value: String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0), icon: "gauge.high")
                statCard(title: "User Load", value: String(format: "%.1f%%", cpu?.userPercent ?? 0.0), icon: "person.fill")
                statCard(title: "System Load", value: String(format: "%.1f%%", cpu?.systemPercent ?? 0.0), icon: "gearshape.2.fill")
                statCard(title: "Cores (Physical)", value: "\(cpu?.physicalCores ?? env.deviceProfile.physicalCores)", icon: "cpu")
                statCard(title: "Cores (Logical)", value: "\(cpu?.logicalCores ?? env.deviceProfile.logicalCores)", icon: "cpu.fill")
                statCard(title: "Architecture", value: env.deviceProfile.architecture, icon: "cube.transparent")
            }
        }
    }

    // MARK: - Memory Detail
    private func memoryDetailView(mem: MemoryMetrics?) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory")
                        .font(.system(size: 24, weight: .bold))
                    Text("\(mem?.formattedUsed ?? "0 GB") / \(env.deviceProfile.formattedMemory) (\(String(format: "%.0f%%", mem?.usagePercentage ?? 0.0)))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(mem?.pressureLevel ?? "Normal")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.emerald.opacity(0.15))
                    .foregroundColor(.emerald)
                    .clipShape(Capsule())
            }

            // Real-time 60-second Chart
            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memory Usage (60 Seconds)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }

                    MemoryTimeSeriesChart(
                        dataPoints: sampling.memoryHistory.values.isEmpty ? [0, 0] : sampling.memoryHistory.values
                    )
                    .frame(height: 180)
                }
            }

            // Stacked Bar Composition
            if let m = mem {
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Memory Composition").font(.system(size: 13, weight: .semibold))

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

                        HStack(spacing: 16) {
                            Label("Active: \(formatBytes(m.activeBytes))", systemImage: "circle.fill").foregroundColor(.blue).font(.caption)
                            Label("Wired: \(formatBytes(m.wiredBytes))", systemImage: "circle.fill").foregroundColor(.indigo).font(.caption)
                            Label("Compressed: \(formatBytes(m.compressedBytes))", systemImage: "circle.fill").foregroundColor(.purple).font(.caption)
                            Label("Free: \(formatBytes(m.freeBytes))", systemImage: "circle.fill").foregroundColor(.secondary).font(.caption)
                        }
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: "In Use", value: mem?.formattedUsed ?? "—", icon: "memorychip")
                statCard(title: "Free", value: formatBytes(mem?.freeBytes ?? 0), icon: "sparkles")
                statCard(title: "Pressure", value: mem?.pressureLevel ?? "Normal", icon: "speedometer")
            }
        }
    }

    // MARK: - GPU Detail
    private func gpuDetailView(gpu: GPUMetrics?) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPU")
                        .font(.system(size: 24, weight: .bold))
                    Text(gpu?.deviceName ?? (env.deviceProfile.gpuNames.first ?? "Apple GPU"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0))")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
            }

            // Real-time 60-second GPU Chart
            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("GPU Utilization (60 Seconds)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }

                    GPUTimeSeriesChart(
                        dataPoints: sampling.gpuHistory.values.isEmpty ? [0, 0] : sampling.gpuHistory.values
                    )
                    .frame(height: 180)
                }
            }

            // Detailed GPU Statistics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: "Overall Utilization", value: String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0), icon: "display.trianglebadge.exclamationmark")
                statCard(title: "Renderer Utilization", value: String(format: "%.1f%%", gpu?.rendererUtilizationPercent ?? 0.0), icon: "paintbrush.fill")
                statCard(title: "Tiler Utilization", value: String(format: "%.1f%%", gpu?.tilerUtilizationPercent ?? 0.0), icon: "square.grid.3x3.fill")

                if let alloc = gpu?.allocatedMemoryBytes, alloc > 0 {
                    statCard(title: "Allocated VRAM", value: formatBytes(alloc), icon: "internaldrive")
                }
                if let inUse = gpu?.inUseMemoryBytes, inUse > 0 {
                    statCard(title: "In-Use VRAM", value: formatBytes(inUse), icon: "bolt.fill")
                }
                statCard(title: "Unified Memory", value: (gpu?.hasUnifiedMemory ?? true) ? "Yes" : "Dedicated", icon: "link")
            }
        }
    }

    // MARK: - Disk Detail
    private func diskDetailView(disks: [VolumeInfo]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Disk Volumes")
                .font(.system(size: 24, weight: .bold))

            ForEach(disks, id: \.id) { (vol: VolumeInfo) in
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vol.name)
                                    .font(.headline)
                                Text("Mount: \(vol.mountPath) • Format: \(vol.fileSystemType)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(String(format: "%.0f%%", vol.usagePercentage)) Used")
                                .font(.caption.bold())
                        }

                        // Progress bar
                        GeometryReader { geo in
                            let w = geo.size.width
                            let usedW = w * CGFloat(vol.usagePercentage / 100.0)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08))
                                RoundedRectangle(cornerRadius: 4).fill(Color.emerald).frame(width: usedW)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("Free: \(vol.formattedAvailable)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Total: \(vol.formattedTotal)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Network Detail
    private func networkDetailView(net: NetworkMetrics?) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Network Throughput")
                .font(.system(size: 24, weight: .bold))

            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Throughput Activity (60 Seconds)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("In / Out")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }

                    NetworkThroughputChart(
                        inboundPoints: sampling.networkInHistory.values.isEmpty ? [0, 0] : sampling.networkInHistory.values,
                        outboundPoints: sampling.networkOutHistory.values.isEmpty ? [0, 0] : sampling.networkOutHistory.values
                    )
                    .frame(height: 180)
                }
            }

            if let n = net {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(title: "Download Speed", value: n.formattedInPerSecond, icon: "arrow.down.circle.fill")
                    statCard(title: "Upload Speed", value: n.formattedOutPerSecond, icon: "arrow.up.circle.fill")
                    statCard(title: "Total Received", value: n.formattedTotalIn, icon: "tray.and.arrow.down.fill")
                    statCard(title: "Total Sent", value: n.formattedTotalOut, icon: "tray.and.arrow.up.fill")
                }
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(.indigo)
                }
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .lineLimit(1)
            }
            .padding(4)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
