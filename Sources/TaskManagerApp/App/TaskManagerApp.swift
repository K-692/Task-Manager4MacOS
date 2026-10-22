import SwiftUI
import TaskManagerCore

@main
struct TaskManagerApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup("Task Manager") {
            MainLayoutView()
                .environmentObject(env)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(colorScheme)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    env.selectedDestination = .inbox
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Command Palette...") {
                    env.isCommandPalettePresented.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            CommandMenu("Navigate") {
                Button("Today") {
                    env.selectedDestination = .today
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Inbox") {
                    env.selectedDestination = .inbox
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Upcoming") {
                    env.selectedDestination = .upcoming
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("All Tasks") {
                    env.selectedDestination = .allTasks
                }
                .keyboardShortcut("4", modifiers: .command)

                Divider()

                Button("Mac Overview") {
                    env.selectedDestination = .macOverview
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Performance Monitor") {
                    env.selectedDestination = .performance
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Hardware & Capabilities") {
                    env.selectedDestination = .hardwareCapabilities
                }
                .keyboardShortcut("7", modifiers: .command)
            }
        }

        // Always-available MenuBarExtra
        MenuBarExtra("Task Manager", systemImage: "checkmark.circle.fill") {
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
        if let route = DeepLinkRouter.destination(from: url) {
            env.selectedDestination = route.destination
            if route.openCapture {
                env.isCommandPalettePresented = true
            }
        }
    }
}
