import SwiftUI
import TaskManagerCore

@main
struct TaskManagerApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup("Task Manager") {
            MainLayoutView()
                .environmentObject(env)
                .frame(minWidth: 960, minHeight: 640)
                .preferredColorScheme(colorScheme)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Command Palette...") {
                    env.isCommandPalettePresented.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Performance Dashboard") {
                    env.selectedDestination = .dashboard
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Processes") {
                    env.selectedDestination = .processes
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Startup Apps") {
                    env.selectedDestination = .startupApps
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Settings") {
                    env.selectedDestination = .settings
                }
                .keyboardShortcut("4", modifiers: .command)

                Divider()

                Button("CPU Telemetry") {
                    env.selectedDestination = .cpu
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("GPU Telemetry") {
                    env.selectedDestination = .gpu
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Memory Telemetry") {
                    env.selectedDestination = .memory
                }
                .keyboardShortcut("7", modifiers: .command)

                Button("Disk Telemetry") {
                    env.selectedDestination = .disk
                }
                .keyboardShortcut("8", modifiers: .command)

                Button("Network Telemetry") {
                    env.selectedDestination = .network
                }
                .keyboardShortcut("9", modifiers: .command)

                Divider()

                Button("Refresh Now") {
                    env.samplingCoordinator.refreshAll()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        // Native Menu Bar Utility updating live every 1s with user-customized components
        MenuBarExtra {
            MenuBarContentView(sampling: env.samplingCoordinator)
                .environmentObject(env)
        } label: {
            MenuBarStatusLabel(env: env, sampling: env.samplingCoordinator)
        }
        .menuBarExtraStyle(.window)
    }

    private var colorScheme: ColorScheme? {
        switch env.appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func handleDeepLink(_ url: URL) {
        if let dest = DeepLinkRouter.destination(from: url) {
            env.selectedDestination = dest
        }
    }
}

/// Reactive status bar label displaying user-customized real-time telemetry on the Mac top menu bar.
private struct MenuBarStatusLabel: View {
    @ObservedObject var env: AppEnvironment
    @ObservedObject var sampling: SamplingCoordinator

    var body: some View {
        let cpu = Int(sampling.latestCPU?.value?.totalUsagePercent ?? 0.0)
        let gpu = Int(sampling.latestGPU?.value?.utilizationPercent ?? 0.0)
        let mem = Int(sampling.latestMemory?.value?.usagePercentage ?? 0.0)
        let disk = Int(sampling.latestStorage?.value?.first?.usagePercentage ?? 0.0)
        let netIn = sampling.latestNetwork?.value?.totalBytesInPerSecond ?? 0.0
        let netOut = sampling.latestNetwork?.value?.totalBytesOutPerSecond ?? 0.0
        let netFormatted = formatCompactRate(netIn + netOut)

        let hasAny = env.menuBarShowCPU || env.menuBarShowGPU || env.menuBarShowMemory || env.menuBarShowDisk || env.menuBarShowNetwork

        HStack(spacing: 4) {
            if env.menuBarShowCPU || !hasAny {
                HStack(spacing: 2) {
                    Image(systemName: "cpu")
                    Text("\(cpu)%")
                        .monospacedDigit()
                }
            }

            if env.menuBarShowGPU {
                HStack(spacing: 2) {
                    Image(systemName: "display.trianglebadge.exclamationmark")
                    Text("\(gpu)%")
                        .monospacedDigit()
                }
            }

            if env.menuBarShowMemory {
                HStack(spacing: 2) {
                    Image(systemName: "memorychip")
                    Text("\(mem)%")
                        .monospacedDigit()
                }
            }

            if env.menuBarShowDisk {
                HStack(spacing: 2) {
                    Image(systemName: "internaldrive")
                    Text("\(disk)%")
                        .monospacedDigit()
                }
            }

            if env.menuBarShowNetwork {
                HStack(spacing: 2) {
                    Image(systemName: "network")
                    Text(netFormatted)
                        .monospacedDigit()
                }
            }
        }
    }

    private func formatCompactRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1fM", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0fK", bytesPerSec / 1024)
        } else {
            return "0K"
        }
    }
}
