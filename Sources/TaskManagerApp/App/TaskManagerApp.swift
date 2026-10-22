import SwiftUI
import TaskManagerCore

@main
struct TaskManagerApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup("Task Manager") {
            MainLayoutView()
                .environmentObject(env)
                .frame(minWidth: 950, minHeight: 620)
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

                Button("Refresh Now") {
                    env.samplingCoordinator.refreshAll()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        // Native Menu Bar Utility
        MenuBarExtra("Task Manager", systemImage: "cpu") {
            MenuBarContentView()
                .environmentObject(env)
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
