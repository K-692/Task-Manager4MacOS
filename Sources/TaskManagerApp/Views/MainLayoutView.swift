import SwiftUI
import TaskManagerCore

/// Main application layout with Windows Task Manager style sidebar, real-time sparklines, and unified dashboard.
public struct MainLayoutView: View {
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarContentView(
                    sampling: env.samplingCoordinator,
                    deviceProfile: env.deviceProfile,
                    selectedDestination: $env.selectedDestination,
                    onOpenCommandPalette: { env.isCommandPalettePresented = true }
                )
                .navigationSplitViewColumnWidth(min: 260, ideal: 275, max: 320)
            } detail: {
                detailView
                    .frame(minWidth: 720, minHeight: 540)
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
        .animation(.easeOut(duration: 0.15), value: env.isCommandPalettePresented)
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
                    appLogoImage
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
                        .frame(width: 72, alignment: .leading)

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
                            Image(systemName: "display.trianglebadge.exclamationmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.purple)
                                .frame(width: 14)
                            Text("GPU")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(width: 72, alignment: .leading)

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
                        .frame(width: 72, alignment: .leading)

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
                            Text("Disk")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(width: 72, alignment: .leading)

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
                        .frame(width: 72, alignment: .leading)

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
                    Text("Search & Actions (⌘K)")
                        .font(.caption)
                    Spacer()
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

    @ViewBuilder
    private var appLogoImage: some View {
        if let url = Bundle.module.url(forResource: "icon", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "cpu.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.indigo)
        }
    }
}
