import SwiftUI
import TaskManagerCore

/// Main application layout with Windows Task Manager style sidebar and detail content.
public struct MainLayoutView: View {
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        ZStack {
            NavigationSplitView {
                sidebarView
                    .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
            } detail: {
                detailView
                    .frame(minWidth: 700, minHeight: 520)
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

    private var sidebarView: some View {
        List(selection: $env.selectedDestination) {
            // App Branding Header
            Section {
                HStack(spacing: 10) {
                    appLogoImage
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Task Manager")
                            .font(.system(size: 15, weight: .bold))
                        Text(env.deviceProfile.cpuName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
            }

            // Software & Processes Section
            Section("Software") {
                NavigationLink(value: AppDestination.processes) {
                    Label {
                        HStack {
                            Text("Processes")
                            Spacer()
                            if let count = env.samplingCoordinator.latestProcesses?.value?.count {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.primary.opacity(0.08))
                                    .foregroundColor(.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "square.stack.3d.up.fill").foregroundColor(.indigo)
                    }
                }

                NavigationLink(value: AppDestination.startupApps) {
                    Label("Startup Apps", systemImage: "bolt.fill").foregroundColor(.amber)
                }
            }

            // Hardware & Performance Section
            Section("Performance & Hardware") {
                NavigationLink(value: AppDestination.performance(.cpu)) {
                    Label {
                        HStack {
                            Text("CPU")
                            Spacer()
                            if let cpu = env.samplingCoordinator.latestCPU?.value {
                                Text(String(format: "%.0f%%", cpu.totalUsagePercent))
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.indigo)
                            }
                        }
                    } icon: {
                        Image(systemName: "cpu").foregroundColor(.indigo)
                    }
                }

                NavigationLink(value: AppDestination.performance(.memory)) {
                    Label {
                        HStack {
                            Text("Memory")
                            Spacer()
                            if let mem = env.samplingCoordinator.latestMemory?.value {
                                Text(String(format: "%.0f%%", mem.usagePercentage))
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.blue)
                            }
                        }
                    } icon: {
                        Image(systemName: "memorychip").foregroundColor(.blue)
                    }
                }

                NavigationLink(value: AppDestination.performance(.gpu)) {
                    Label {
                        HStack {
                            Text("GPU")
                            Spacer()
                            if let gpu = env.samplingCoordinator.latestGPU?.value {
                                Text(String(format: "%.0f%%", gpu.utilizationPercent))
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.purple)
                            }
                        }
                    } icon: {
                        Image(systemName: "display.trianglebadge.exclamationmark").foregroundColor(.purple)
                    }
                }

                NavigationLink(value: AppDestination.performance(.disk)) {
                    Label("Disk", systemImage: "internaldrive").foregroundColor(.emerald)
                }

                NavigationLink(value: AppDestination.performance(.network)) {
                    Label("Network", systemImage: "network").foregroundColor(.cyan)
                }

                NavigationLink(value: AppDestination.hardware) {
                    Label("Hardware & Specs", systemImage: "slider.horizontal.3").foregroundColor(.secondary)
                }
            }

            // System Section
            Section("System") {
                NavigationLink(value: AppDestination.settings) {
                    Label("Settings", systemImage: "gearshape").foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button(action: { env.isCommandPalettePresented = true }) {
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

    @ViewBuilder
    private var detailView: some View {
        switch env.selectedDestination {
        case .processes:
            ProcessesView(sampling: env.samplingCoordinator)
        case .performance(let subtab):
            PerformanceView(sampling: env.samplingCoordinator)
                .onAppear {
                    env.selectedPerformanceSubtab = subtab
                }
        case .appHistory:
            ProcessesView(sampling: env.samplingCoordinator)
        case .startupApps:
            StartupAppsView()
        case .hardware:
            HardwareCapabilitiesView()
        case .settings:
            SettingsView()
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
