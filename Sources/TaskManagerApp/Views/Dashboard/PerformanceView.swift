import SwiftUI
import TaskManagerCore

/// Unified Technical Performance & Hardware Dashboard:
/// Comprehensive single-view telemetry for CPU, GPU, Memory, Disk, Network, and System Hardware.
public struct PerformanceView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let cpu = sampling.latestCPU?.value
        let mem = sampling.latestMemory?.value
        let gpu = sampling.latestGPU?.value
        let net = sampling.latestNetwork?.value
        let disks = sampling.latestStorage?.value ?? []
        let procCount = sampling.latestProcesses?.value?.count ?? 0

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: 1. System Overview Banner
                systemSummaryBanner(cpu: cpu, gpu: gpu, mem: mem, net: net, procCount: procCount)

                // MARK: 2. CPU Telemetry (Processor & Cores)
                cpuSection(cpu: cpu)

                // MARK: 3. GPU Telemetry (Graphics Pipeline & VRAM) — Immediately after CPU
                gpuSection(gpu: gpu)

                // MARK: 4. Memory Telemetry (Mach VM & Memory Pressure)
                memorySection(mem: mem)

                // MARK: 5. Storage / Disk Telemetry (Mounted Volumes)
                diskSection(disks: disks)

                // MARK: 6. Network Telemetry (Throughput & Interfaces)
                networkSection(net: net)

                // MARK: 7. Platform Specifications & Capabilities Matrix
                hardwareSpecsSection()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onAppear {
            sampling.isDashboardActive = true
        }
        .onDisappear {
            sampling.isDashboardActive = false
        }
    }

    // MARK: - 1. System Summary Banner
    private func systemSummaryBanner(cpu: CPUMetrics?, gpu: GPUMetrics?, mem: MemoryMetrics?, net: NetworkMetrics?, procCount: Int) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.indigo)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(env.deviceProfile.marketingName)
                            .font(.system(size: 16, weight: .bold))
                        Text("\(env.deviceProfile.cpuName) • \(env.deviceProfile.architecture) • macOS \(env.deviceProfile.osVersion) (\(env.deviceProfile.osBuild))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Uptime & Thermal Chip
                HStack(spacing: 8) {
                    Label(formattedUptime, systemImage: "clock")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    thermalStateBadge
                }
            }

            Divider()

            // Quick Hardware Telemetry Ticker
            HStack(spacing: 12) {
                tickerItem(label: "CPU", value: String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0), color: .indigo)
                Divider().frame(height: 18)
                tickerItem(label: "GPU", value: String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0), color: .purple)
                Divider().frame(height: 18)
                tickerItem(label: "MEMORY", value: "\(String(format: "%.0f%%", mem?.usagePercentage ?? 0.0)) (\(mem?.formattedUsed ?? "—"))", color: .blue)
                Divider().frame(height: 18)
                tickerItem(label: "NET IN", value: net?.formattedInPerSecond ?? "0 B/s", color: .cyan)
                Divider().frame(height: 18)
                tickerItem(label: "NET OUT", value: net?.formattedOutPerSecond ?? "0 B/s", color: .indigo)
                Divider().frame(height: 18)
                tickerItem(label: "PROCS", value: "\(procCount)", color: .secondary)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func tickerItem(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    // MARK: - 2. CPU Section
    private func cpuSection(cpu: CPUMetrics?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.indigo)
                    Text("CPU — Processor & Microarchitecture")
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                Text(String(format: "%.1f%% UTILIZATION", cpu?.totalUsagePercent ?? 0.0))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.indigo)
            }

            // Real-time 60s Chart Card
            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Utilization History (Last 60 Seconds)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    CPUTimeSeriesChart(
                        dataPoints: sampling.cpuHistory.values.isEmpty ? [0, 0] : sampling.cpuHistory.values
                    )
                    .frame(height: 140)
                }
            }

            // High-Density Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                techStatCard(title: "User Load", value: String(format: "%.1f%%", cpu?.userPercent ?? 0.0), icon: "person.fill")
                techStatCard(title: "System Load", value: String(format: "%.1f%%", cpu?.systemPercent ?? 0.0), icon: "gearshape.fill")
                techStatCard(title: "Idle State", value: String(format: "%.1f%%", cpu?.idlePercent ?? 0.0), icon: "moon.fill")
                techStatCard(title: "Physical Cores", value: "\(cpu?.physicalCores ?? env.deviceProfile.physicalCores)", icon: "cpu")
                techStatCard(title: "Logical Cores", value: "\(cpu?.logicalCores ?? env.deviceProfile.logicalCores)", icon: "cpu.fill")
                techStatCard(title: "Architecture", value: env.deviceProfile.architecture, icon: "cube.transparent")
                techStatCard(title: "Thermal Status", value: thermalStateText, icon: "thermometer.medium")
                techStatCard(title: "Uptime", value: formattedUptime, icon: "timer")
            }
        }
    }

    // MARK: - 3. GPU Section (Immediately after CPU)
    private func gpuSection(gpu: GPUMetrics?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "display.trianglebadge.exclamationmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.purple)
                    Text("GPU — Graphics Pipeline & Acceleration")
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                Text(String(format: "%.1f%% UTILIZATION", gpu?.utilizationPercent ?? 0.0))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
            }

            // Real-time 60s Chart Card
            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(gpu?.deviceName ?? (env.deviceProfile.gpuNames.first ?? "Apple Silicon GPU")) • 60s Load History")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    GPUTimeSeriesChart(
                        dataPoints: sampling.gpuHistory.values.isEmpty ? [0, 0] : sampling.gpuHistory.values
                    )
                    .frame(height: 140)
                }
            }

            // High-Density Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                techStatCard(title: "Device Load", value: String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0), icon: "gauge.medium")
                techStatCard(title: "3D Renderer Core", value: String(format: "%.1f%%", gpu?.rendererUtilizationPercent ?? 0.0), icon: "paintbrush.fill")
                techStatCard(title: "Tiler Pipeline", value: String(format: "%.1f%%", gpu?.tilerUtilizationPercent ?? 0.0), icon: "square.grid.3x3.fill")
                techStatCard(title: "Memory Subsystem", value: (gpu?.hasUnifiedMemory ?? true) ? "Unified (UMA)" : "Discrete", icon: "link")

                if let inUse = gpu?.inUseMemoryBytes, inUse > 0 {
                    techStatCard(title: "Active VRAM", value: formatBytes(inUse), icon: "bolt.fill")
                } else {
                    techStatCard(title: "Active VRAM", value: "Dynamic Shared", icon: "bolt.fill")
                }

                if let alloc = gpu?.allocatedMemoryBytes, alloc > 0 {
                    techStatCard(title: "Allocated VRAM", value: formatBytes(alloc), icon: "internaldrive")
                } else {
                    techStatCard(title: "Allocated VRAM", value: "Zero-Copy Pool", icon: "internaldrive")
                }

                techStatCard(title: "Displays Connected", value: "\(env.deviceProfile.displayCount)", icon: "display")
                techStatCard(title: "Metal Engine", value: "Metal 3 Native", icon: "sparkles")
            }
        }
    }

    // MARK: - 4. Memory Section
    private func memorySection(mem: MemoryMetrics?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Memory — Mach Virtual Memory Architecture")
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                Text("\(mem?.formattedUsed ?? "—") / \(env.deviceProfile.formattedMemory) (\(String(format: "%.0f%%", mem?.usagePercentage ?? 0.0)))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
            }

            // Real-time 60s Chart Card
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("RAM Allocation History (Last 60 Seconds)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    MemoryTimeSeriesChart(
                        dataPoints: sampling.memoryHistory.values.isEmpty ? [0, 0] : sampling.memoryHistory.values
                    )
                    .frame(height: 140)

                    // Stacked VM composition bar
                    if let m = mem {
                        VStack(alignment: .leading, spacing: 6) {
                            GeometryReader { geo in
                                let w = geo.size.width
                                let activeW = w * CGFloat(Double(m.activeBytes) / Double(max(1, m.totalBytes)))
                                let wiredW = w * CGFloat(Double(m.wiredBytes) / Double(max(1, m.totalBytes)))
                                let compW = w * CGFloat(Double(m.compressedBytes) / Double(max(1, m.totalBytes)))
                                let freeW = max(0, w - activeW - wiredW - compW)

                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.blue).frame(width: activeW)
                                    RoundedRectangle(cornerRadius: 2).fill(Color.indigo).frame(width: wiredW)
                                    RoundedRectangle(cornerRadius: 2).fill(Color.purple).frame(width: compW)
                                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.08)).frame(width: freeW)
                                }
                            }
                            .frame(height: 8)

                            HStack(spacing: 14) {
                                Label("Active: \(formatBytes(m.activeBytes))", systemImage: "circle.fill").foregroundColor(.blue).font(.system(size: 10))
                                Label("Wired: \(formatBytes(m.wiredBytes))", systemImage: "circle.fill").foregroundColor(.indigo).font(.system(size: 10))
                                Label("Compressed: \(formatBytes(m.compressedBytes))", systemImage: "circle.fill").foregroundColor(.purple).font(.system(size: 10))
                                Label("Free: \(formatBytes(m.freeBytes))", systemImage: "circle.fill").foregroundColor(.secondary).font(.system(size: 10))
                            }
                        }
                    }
                }
            }

            // High-Density Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                techStatCard(title: "Installed Memory", value: env.deviceProfile.formattedMemory, icon: "memorychip")
                techStatCard(title: "In-Use Memory", value: mem?.formattedUsed ?? "—", icon: "chart.bar.fill")
                techStatCard(title: "Available Free", value: formatBytes(mem?.freeBytes ?? 0), icon: "sparkles")
                techStatCard(title: "Memory Pressure", value: mem?.pressureLevel ?? "Normal", icon: "speedometer")
            }
        }
    }

    // MARK: - 5. Disk / Storage Section
    private func diskSection(disks: [VolumeInfo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.emerald)
                    Text("Disk & Volumes — Filesystem Hierarchy")
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                Text("\(disks.count) VOLUMES MOUNTED")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Volume Cards
            ForEach(disks, id: \.id) { vol in
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text(vol.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    if vol.isRoot {
                                        Text("System Root")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.emerald.opacity(0.12))
                                            .foregroundColor(.emerald)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("Mount: \(vol.mountPath) • Format: \(vol.fileSystemType)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(String(format: "%.0f%%", vol.usagePercentage)) USED")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                        }

                        // Progress Gauge
                        GeometryReader { geo in
                            let w = geo.size.width
                            let usedW = w * CGFloat(vol.usagePercentage / 100.0)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.06))
                                RoundedRectangle(cornerRadius: 3).fill(Color.emerald).frame(width: usedW)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Text("Free: \(vol.formattedAvailable)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Total: \(vol.formattedTotal)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 6. Network Section
    private func networkSection(net: NetworkMetrics?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("Network — Real-Time Interface Throughput")
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                Text("↓ \(net?.formattedInPerSecond ?? "0 B/s")   ↑ \(net?.formattedOutPerSecond ?? "0 B/s")")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            // Real-time 60s Chart Card
            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Active Interface: \(net?.primaryInterfaceName ?? "en0") • Inbound & Outbound History")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Live Bandwidth")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    NetworkThroughputChart(
                        inboundPoints: sampling.networkInHistory.values.isEmpty ? [0, 0] : sampling.networkInHistory.values,
                        outboundPoints: sampling.networkOutHistory.values.isEmpty ? [0, 0] : sampling.networkOutHistory.values
                    )
                    .frame(height: 140)
                }
            }

            // High-Density Metrics Grid
            if let n = net {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    techStatCard(title: "Download Speed", value: n.formattedInPerSecond, icon: "arrow.down.circle.fill")
                    techStatCard(title: "Upload Speed", value: n.formattedOutPerSecond, icon: "arrow.up.circle.fill")
                    techStatCard(title: "Total Inbound", value: n.formattedTotalIn, icon: "tray.and.arrow.down.fill")
                    techStatCard(title: "Total Outbound", value: n.formattedTotalOut, icon: "tray.and.arrow.up.fill")
                }
            }
        }
    }

    // MARK: - 7. Platform Specifications Matrix
    private func hardwareSpecsSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                Text("Hardware & Platform Specifications")
                    .font(.system(size: 14, weight: .bold))
            }

            CardView {
                VStack(spacing: 8) {
                    specRow(label: "Device Model", value: "\(env.deviceProfile.marketingName) (\(env.deviceProfile.modelIdentifier))")
                    Divider()
                    specRow(label: "Processor Chip", value: "\(env.deviceProfile.cpuName) • \(env.deviceProfile.physicalCores) Physical Cores")
                    Divider()
                    specRow(label: "Architecture", value: "\(env.deviceProfile.architecture) • Apple Silicon Unified Pipeline")
                    Divider()
                    specRow(label: "Installed Memory", value: env.deviceProfile.formattedMemory)
                    Divider()
                    specRow(label: "Graphics Hardware", value: env.deviceProfile.gpuNames.first ?? "Apple Silicon GPU")
                    Divider()
                    specRow(label: "Darwin Kernel", value: "macOS \(env.deviceProfile.osVersion) (Build \(env.deviceProfile.osBuild))")
                    Divider()
                    specRow(label: "Form Factor", value: env.deviceProfile.isLaptop ? "Apple Laptop (Integrated Battery & Display)" : "Desktop Mac (Mac Studio / Mac mini / iMac)")
                }
            }
        }
    }

    // MARK: - Reusable Tech Components
    private func techStatCard(title: String, value: String, icon: String) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(2)
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private var formattedUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let mins = (Int(uptime) % 3600) / 60
        let secs = Int(uptime) % 60
        return String(format: "%dh %02dm %02ds", hours, mins, secs)
    }

    private var thermalStateBadge: some View {
        let state = ProcessInfo.processInfo.thermalState
        let (label, color): (String, Color) = {
            switch state {
            case .nominal: return ("Thermal: Nominal", .emerald)
            case .fair: return ("Thermal: Fair", .blue)
            case .serious: return ("Thermal: Serious", .amber)
            case .critical: return ("Thermal: Critical", .rose)
            @unknown default: return ("Thermal: Normal", .emerald)
            }
        }()

        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var thermalStateText: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Nominal (Cool)"
        case .fair: return "Fair Load"
        case .serious: return "Elevated"
        case .critical: return "Throttling"
        @unknown default: return "Nominal"
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
