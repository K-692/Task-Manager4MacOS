import SwiftUI
import TaskManagerCore

/// Main application layout with Windows Task Manager style sidebar, real-time sparklines, and unified dashboard.
public struct MainLayoutView: View {
    @EnvironmentObject private var env: AppEnvironment

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sidebarAutoCollapsed = false

    /// Below this window width the sidebar collapses automatically so the
    /// content keeps a usable width; it comes back when the window grows.
    private let collapseWidth: CGFloat = 680

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            content
                .onAppear { adaptSidebar(to: geo.size.width) }
                .onChange(of: geo.size.width) { adaptSidebar(to: $0) }
        }
    }

    private func adaptSidebar(to width: CGFloat) {
        if width < collapseWidth {
            if columnVisibility != .detailOnly {
                columnVisibility = .detailOnly
                sidebarAutoCollapsed = true
            }
        } else if width >= collapseWidth + 20, sidebarAutoCollapsed {
            columnVisibility = .all
            sidebarAutoCollapsed = false
        }
    }

    private var content: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarContentView(
                    sampling: env.samplingCoordinator,
                    deviceProfile: env.deviceProfile,
                    selectedDestination: $env.selectedDestination,
                    onOpenCommandPalette: { env.isCommandPalettePresented = true }
                )
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            } detail: {
                ResponsiveContainer {
                    detailView
                        .id(env.selectedDestination)
                        .transition(.opacity)
                }
                .frame(minWidth: 300, minHeight: 360)
                .background(DetailBackground())
            }

            // Command Palette Modal Overlay (Cmd+K)
            if env.isCommandPalettePresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        env.isCommandPalettePresented = false
                    }

                CommandPaletteView(isPresented: $env.isCommandPalettePresented)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .environment(\.visualTheme, env.visualTheme)
        .environment(\.sampleInterval, env.samplingCoordinator.samplingInterval)
        .animation(.easeOut(duration: 0.15), value: env.isCommandPalettePresented)
        .animation(.easeInOut(duration: 0.15), value: env.selectedDestination)
    }

    @ViewBuilder
    private var detailView: some View {
        switch env.selectedDestination {
        case .dashboard:
            PerformanceView(sampling: env.samplingCoordinator)
        case .cpu:
            CPUDetailView(sampling: env.samplingCoordinator)
        case .gpu:
            GPUDetailView(sampling: env.samplingCoordinator)
        case .memory:
            MemoryDetailView(sampling: env.samplingCoordinator)
        case .disk:
            StorageView(sampling: env.samplingCoordinator)
        case .network:
            NetworkView(sampling: env.samplingCoordinator)
        case .processes:
            ProcessesView(sampling: env.samplingCoordinator)
        case .startupApps:
            StartupAppsView()
        case .settings:
            SettingsView()
        }
    }
}

/// Standalone reactive sidebar view observing SamplingCoordinator directly for 60fps telemetry.
private struct SidebarContentView: View {
    @ObservedObject var sampling: SamplingCoordinator
    let deviceProfile: DeviceProfile
    @Binding var selectedDestination: AppDestination
    let onOpenCommandPalette: () -> Void

    var body: some View {
        let cpu = sampling.latestCPU?.value
        let gpu = sampling.latestGPU?.value
        let mem = sampling.latestMemory?.value
        let net = sampling.latestNetwork?.value
        let disks = sampling.latestStorage?.value ?? []
        let primaryDisk = disks.first

        List(selection: $selectedDestination) {
            // App Branding Header
            Section {
                HStack(spacing: 10) {
                    AppLogoView()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Task Manager")
                            .font(.system(size: 14, weight: .bold))
                        Text(deviceProfile.cpuName)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 3)
            }

            // Navigation Section (Dashboard at Top)
            Section("Navigation") {
                NavigationLink(value: AppDestination.dashboard) {
                    Label {
                        HStack {
                            Text("Dashboard")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text("Live")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.emerald.opacity(0.15))
                                .foregroundColor(.emerald)
                                .clipShape(Capsule())
                        }
                    } icon: {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .foregroundColor(.indigo)
                    }
                }

                NavigationLink(value: AppDestination.processes) {
                    Label {
                        HStack {
                            Text("Processes")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            if let count = sampling.latestProcesses?.value?.count {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.primary.opacity(0.08))
                                    .foregroundColor(.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundColor(.indigo)
                    }
                }

                NavigationLink(value: AppDestination.startupApps) {
                    Label("Startup Apps", systemImage: "bolt.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.amber)
                }

                NavigationLink(value: AppDestination.settings) {
                    Label("Settings", systemImage: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            // Real-Time Hardware Telemetry in Order: CPU -> GPU -> Memory -> Disk -> Network
            Section("Live Hardware Telemetry") {
                // 1. CPU Row: CPU — [Graph] — %
                NavigationLink(value: AppDestination.cpu) {
                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "cpu")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.indigo)
                                .frame(width: 14)
                            Text("CPU")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(minWidth: 64, alignment: .leading)
                        .lineLimit(1)

                        Spacer()

                        SparklineView(
                            data: sampling.cpuHistory.values,
                            minVal: 0,
                            maxVal: 100,
                            tint: .indigo
                        )

                        Text(String(format: "%2.0f%%", cpu?.totalUsagePercent ?? 0.0))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }

                // 2. GPU Row: GPU — [Graph] — % (Immediately after CPU)
                NavigationLink(value: AppDestination.gpu) {
                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.purple)
                                .frame(width: 14)
                            Text("GPU")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(minWidth: 64, alignment: .leading)
                        .lineLimit(1)

                        Spacer()

                        SparklineView(
                            data: sampling.gpuHistory.values,
                            minVal: 0,
                            maxVal: 100,
                            tint: .purple
                        )

                        Text(String(format: "%2.0f%%", gpu?.utilizationPercent ?? 0.0))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }

                // 3. Memory Row: Memory — [Graph] — %
                NavigationLink(value: AppDestination.memory) {
                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "memorychip")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 14)
                            Text("Memory")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(minWidth: 64, alignment: .leading)
                        .lineLimit(1)

                        Spacer()

                        SparklineView(
                            data: sampling.memoryHistory.values,
                            minVal: 0,
                            maxVal: 100,
                            tint: .blue
                        )

                        Text(String(format: "%2.0f%%", mem?.usagePercentage ?? 0.0))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }

                // 4. Disk Row: Disk — [Graph] — %
                NavigationLink(value: AppDestination.disk) {
                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "internaldrive")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.emerald)
                                .frame(width: 14)
                            Text("Storage")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(minWidth: 64, alignment: .leading)
                        .lineLimit(1)

                        Spacer()

                        SparklineView(
                            data: sampling.diskHistory.values,
                            minVal: 0,
                            maxVal: 100,
                            tint: .emerald
                        )

                        Text(String(format: "%2.0f%%", primaryDisk?.usagePercentage ?? 0.0))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }

                // 5. Network Row: Network — [Graph] — Rate
                NavigationLink(value: AppDestination.network) {
                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "network")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cyan)
                                .frame(width: 14)
                            Text("Network")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(minWidth: 64, alignment: .leading)
                        .lineLimit(1)

                        Spacer()

                        let netHistory = sampling.networkTotalHistory.values
                        let maxNet = max(1024.0, netHistory.max() ?? 1024.0)

                        SparklineView(
                            data: netHistory,
                            minVal: 0,
                            maxVal: maxNet,
                            tint: .cyan
                        )

                        Text(formatCompactRate((net?.totalBytesInPerSecond ?? 0) + (net?.totalBytesOutPerSecond ?? 0)))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 44, alignment: .trailing)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button(action: onOpenCommandPalette) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                    Text("Search & Actions")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("⌘K")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private func formatCompactRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1fM", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0fK", bytesPerSec / 1024)
        } else {
            return String(format: "%.0fB", bytesPerSec)
        }
    }

}

/// Soft gradient backdrop behind detail pages.
private struct DetailBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.visualTheme) private var theme

    var body: some View {
        if theme.isPublication {
            Color.white.ignoresSafeArea()
        } else {
            gradient
        }
    }

    private var gradient: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.indigo.opacity(colorScheme == .dark ? 0.08 : 0.04),
                    Color.clear,
                    Color.cyan.opacity(colorScheme == .dark ? 0.05 : 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
