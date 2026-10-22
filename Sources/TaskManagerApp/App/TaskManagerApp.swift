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

        // Native Menu Bar Utility updating live every 1s
        MenuBarExtra {
            MenuBarContentView(sampling: env.samplingCoordinator)
                .environmentObject(env)
        } label: {
            MenuBarStatusLabel(sampling: env.samplingCoordinator)
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

/// Reactive status bar label displaying real-time CPU% and GPU% directly on the Mac top menu bar.
private struct MenuBarStatusLabel: View {
    @ObservedObject var sampling: SamplingCoordinator

    var body: some View {
        let cpu = Int(sampling.latestCPU?.value?.totalUsagePercent ?? 0.0)
        let gpu = Int(sampling.latestGPU?.value?.utilizationPercent ?? 0.0)

        HStack(spacing: 3) {
            Image(systemName: "cpu")
            Text("\(cpu)%")
                .monospacedDigit()
            Text("•")
                .foregroundColor(.secondary)
            Image(systemName: "display.trianglebadge.exclamationmark")
            Text("\(gpu)%")
                .monospacedDigit()
        }
    }
}
