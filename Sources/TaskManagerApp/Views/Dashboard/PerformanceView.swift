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

    @Environment(\.layoutClass) private var layoutClass
    @Environment(\.contentSize) private var contentSize
    @Environment(\.visualTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var captureResult: TelemetryCaptureService.Result?
    @State private var captureError: String?
    @State private var isCapturing = false

    public var body: some View {
        let cpu = sampling.latestCPU?.value
        let gpu = sampling.latestGPU?.value
        let mem = sampling.latestMemory?.value
        let net = sampling.latestNetwork?.value
        let primaryDisk = sampling.latestStorage?.value?.first
        let procCount = sampling.latestProcesses?.value?.count ?? 0
        let pad = layoutClass.pagePadding

        // Large windows get the fixed "command center" layout that fills the window;
        // smaller or shorter windows switch to a scrolling adaptive card grid.
        let fillsWindow = contentSize.width >= 820 && contentSize.height >= 560

        Group {
            if fillsWindow {
                VStack(spacing: 14) {
                    systemTickerHeader(cpu: cpu, gpu: gpu, mem: mem, net: net, primaryDisk: primaryDisk, procCount: procCount)

                    GeometryReader { geo in
                        let availableHeight = geo.size.height - 14
                        VStack(spacing: 14) {
                            HStack(spacing: 14) {
                                cpuCard(cpu)
                                gpuCard(gpu)
                            }
                            .frame(height: availableHeight * 0.52)

                            HStack(spacing: 14) {
                                memoryCard(mem)
                                diskCard(primaryDisk)
                                networkCard(net)
                            }
                            .frame(height: availableHeight * 0.48)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 18)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        systemTickerHeader(cpu: cpu, gpu: gpu, mem: mem, net: net, primaryDisk: primaryDisk, procCount: procCount)

                        let cardHeight: CGFloat = layoutClass == .compact ? 190 : 220
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                            cpuCard(cpu).frame(height: cardHeight)
                            gpuCard(gpu).frame(height: cardHeight)
                            memoryCard(mem).frame(height: cardHeight)
                            diskCard(primaryDisk).frame(height: cardHeight)
                            networkCard(net).frame(height: cardHeight)
                        }
                    }
                    .padding(.horizontal, pad)
                    .padding(.vertical, layoutClass == .compact ? 14 : 18)
                }
            }
        }
        .overlay(alignment: .bottom) { captureToast }
        .animation(.easeOut(duration: 0.2), value: captureResult?.folder)
        .animation(.easeOut(duration: 0.2), value: captureError)
        .onAppear {
            sampling.isDashboardActive = true
        }
    }

    // MARK: - Capture

    private var captureButton: some View {
        Button {
            capture()
        } label: {
            Label(isCapturing ? "Capturing…" : "Capture", systemImage: "camera.viewfinder")
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.isPublication ? PublicationPalette.text : .indigo)
        .controlSize(.regular)
        .disabled(isCapturing)
        .help("Save CPU, GPU, Memory, Storage and Network as five separate figures (same instant, current theme) to a new folder on your Desktop")
        .fixedSize()
    }

    private func capture() {
        isCapturing = true
        captureError = nil
        do {
            captureResult = try TelemetryCaptureService.captureAll(env: env, colorScheme: colorScheme)
        } catch {
            captureResult = nil
            captureError = error.localizedDescription
        }
        isCapturing = false
        let folder = captureResult?.folder
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if captureResult?.folder == folder { captureResult = nil }
            captureError = nil
        }
    }

    @ViewBuilder
    private var captureToast: some View {
        if let result = captureResult {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.emerald)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Saved \(result.files.count) figures to your Desktop")
                        .font(.system(size: 12, weight: .semibold))
                    Text(result.folder.lastPathComponent)
                        .font(.system(size: 10))
                        .themedSecondary()
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(result.files)
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
            .padding(.bottom, 18)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let error = captureError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.rose)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.bottom, 18)
                .transition(.opacity)
        }
    }

    // MARK: - Cards

    private func cpuCard(_ cpu: CPUMetrics?) -> some View {
        dashboardCard(
            destination: .cpu,
            title: "CPU",
            subtitle: "\(env.deviceProfile.cpuName) • \(cpu?.physicalCores ?? env.deviceProfile.physicalCores) Cores",
            icon: "cpu",
            accentColor: TelemetryKind.cpu.color(for: theme),
            primaryMetric: String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0),
            secondaryMetric: "User \(String(format: "%.0f%%", cpu?.userPercent ?? 0)) · System \(String(format: "%.0f%%", cpu?.systemPercent ?? 0))"
        ) {
            CPUTimeSeriesChart(dataPoints: sampling.cpuHistory.values.isEmpty ? [0, 0] : sampling.cpuHistory.values)
        }
    }

    private func gpuCard(_ gpu: GPUMetrics?) -> some View {
        dashboardCard(
            destination: .gpu,
            title: "GPU",
            subtitle: "\(gpu?.deviceName ?? "Apple Silicon GPU") • Metal 3",
            icon: "cube.transparent",
            accentColor: TelemetryKind.gpu.color(for: theme),
            primaryMetric: String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0),
            secondaryMetric: "Renderer \(String(format: "%.0f%%", gpu?.rendererUtilizationPercent ?? 0)) · VRAM \(gpu?.formattedInUseMemory ?? "0 MB")"
        ) {
            GPUTimeSeriesChart(dataPoints: sampling.gpuHistory.values.isEmpty ? [0, 0] : sampling.gpuHistory.values)
        }
    }

    private func memoryCard(_ mem: MemoryMetrics?) -> some View {
        dashboardCard(
            destination: .memory,
            title: "Memory",
            subtitle: "\(mem?.formattedUsed ?? "—") of \(mem?.formattedTotal ?? env.deviceProfile.formattedMemory)",
            icon: "memorychip",
            accentColor: TelemetryKind.memory.color(for: theme),
            primaryMetric: String(format: "%.0f%%", mem?.usagePercentage ?? 0.0),
            secondaryMetric: "Pressure \(mem?.pressureLevel.capitalized ?? "Normal") · Free \(mem?.formattedFree ?? "—")"
        ) {
            MemoryTimeSeriesChart(dataPoints: sampling.memoryHistory.values.isEmpty ? [0, 0] : sampling.memoryHistory.values)
        }
    }

    private func diskCard(_ primaryDisk: VolumeInfo?) -> some View {
        dashboardCard(
            destination: .disk,
            title: "Storage",
            subtitle: "\(primaryDisk?.name ?? "Startup Disk") • \(primaryDisk?.fileSystemType ?? "APFS")",
            icon: "internaldrive",
            accentColor: TelemetryKind.storage.color(for: theme),
            primaryMetric: String(format: "%.0f%%", primaryDisk?.usagePercentage ?? 0.0),
            secondaryMetric: "\(primaryDisk?.formattedAvailable ?? "—") free of \(primaryDisk?.formattedTotal ?? "—")"
        ) {
            DiskTimeSeriesChart(dataPoints: sampling.diskHistory.values.isEmpty ? [0, 0] : sampling.diskHistory.values)
        }
    }

    private func networkCard(_ net: NetworkMetrics?) -> some View {
        dashboardCard(
            destination: .network,
            title: "Network",
            subtitle: "Primary: \(net?.primaryInterfaceName ?? "en0")",
            icon: "network",
            accentColor: TelemetryKind.network.color(for: theme),
            primaryMetric: net?.formattedInPerSecond ?? "0 B/s",
            secondaryMetric: "↓ \(net?.formattedInPerSecond ?? "0 B/s") · ↑ \(net?.formattedOutPerSecond ?? "0 B/s")"
        ) {
            NetworkThroughputChart(
                inboundPoints: sampling.networkInHistory.values.isEmpty ? [0, 0] : sampling.networkInHistory.values,
                outboundPoints: sampling.networkOutHistory.values.isEmpty ? [0, 0] : sampling.networkOutHistory.values
            )
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
        metricColor: Color? = nil,
        secondaryMetric: String,
        @ViewBuilder chart: () -> Content
    ) -> some View {
        Button(action: {
            env.selectedDestination = destination
        }) {
            CardView(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 9) {
                        IconBadge(systemName: icon, tint: accentColor, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                            Text(subtitle)
                                .font(.system(size: 10))
                                .themedSecondary()
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 6)

                        Text(primaryMetric)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(metricColor ?? accentColor)
                            .lineLimit(1)
                            .fixedSize()
                    }

                    chart()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack(spacing: 6) {
                        Text(secondaryMetric)
                            .font(.system(size: 10, design: .monospaced))
                            .themedSecondary()
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 4)
                        HStack(spacing: 2) {
                            Text("Details")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CardPressStyle())
        .focusable(false)
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
        let pills = Group {
            pillItem(label: "CPU", val: String(format: "%.0f%%", cpu?.totalUsagePercent ?? 0), color: TelemetryKind.cpu.color(for: theme))
            pillItem(label: "GPU", val: String(format: "%.0f%%", gpu?.utilizationPercent ?? 0), color: TelemetryKind.gpu.color(for: theme))
            pillItem(label: "RAM", val: String(format: "%.0f%%", mem?.usagePercentage ?? 0), color: TelemetryKind.memory.color(for: theme))
            pillItem(label: "DISK", val: String(format: "%.0f%%", primaryDisk?.usagePercentage ?? 0), color: TelemetryKind.storage.color(for: theme))
            pillItem(label: "NET", val: net?.formattedInPerSecond ?? "0 B/s", color: TelemetryKind.network.color(for: theme))
            pillItem(label: "PROCS", val: "\(procCount)", color: .secondary)
        }

        let title = HStack(spacing: 10) {
            IconBadge(systemName: "gauge.with.dots.needle.bottom.50percent", tint: .indigo, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("Performance")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(env.deviceProfile.marketingName)
                    .font(.system(size: 10, design: .monospaced))
                    .themedSecondary()
                    .lineLimit(1)
            }
        }

        let pub = theme.isPublication
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                title
                Spacer(minLength: 12)
                HStack(spacing: 6) { pills }
                captureButton
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    title
                    Spacer(minLength: 8)
                    captureButton
                }
                FlowLayout(spacing: 6, lineSpacing: 6) { pills }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: pub ? 0 : AppTheme.Radius.lg, style: .continuous)
                .fill(pub
                      ? AnyShapeStyle(Color.white)
                      : AnyShapeStyle(LinearGradient(colors: [Color.indigo.opacity(0.10), Color.cyan.opacity(0.05)], startPoint: .leading, endPoint: .trailing)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: pub ? 0 : AppTheme.Radius.lg, style: .continuous)
                .strokeBorder(pub ? PublicationPalette.axis.opacity(0.55) : Color.primary.opacity(0.07), lineWidth: pub ? 0.75 : 1)
        )
    }

    private func pillItem(label: String, val: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .themedSecondary()
            Text(val)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .frame(minWidth: 0, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }
}

/// Subtle press feedback for clickable dashboard cards.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
