import SwiftUI
import AppKit
import TaskManagerCore

/// Bridges AppKit lifecycle events to SwiftUI's `openWindow` action so the main
/// window can be re-created from the menu bar, the Dock, or a deep link.
@MainActor
final class WindowRouter {
    static let shared = WindowRouter()
    static let mainWindowID = "main"

    var openMainWindowAction: (() -> Void)?
    weak var environment: AppEnvironment?

    /// Shows the main window (re-creating it if it was closed) and brings the app forward.
    func showMainWindow() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        if let window = existingMainWindow() {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindowAction?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func existingMainWindow() -> NSWindow? {
        NSApp.windows.first { Self.isMainWindow($0) && $0.isVisible }
    }

    static func isMainWindow(_ window: NSWindow) -> Bool {
        // Menu bar extra popovers and system panels are NSPanels; the main dashboard is a regular window.
        guard !(window is NSPanel), window.canBecomeMain else { return false }
        return window.identifier?.rawValue.contains(mainWindowID) ?? true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep the process alive as a menu bar utility: never let macOS
        // auto-terminate it when no windows are open.
        ProcessInfo.processInfo.disableAutomaticTermination("Task Manager menu bar monitor")
        ProcessInfo.processInfo.disableSuddenTermination()

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let closing = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                guard WindowRouter.isMainWindow(closing) else { return }
                // Give AppKit a moment to finish closing, then drop the Dock icon
                // if no other main window remains.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    MainActor.assumeIsolated {
                        let stillOpen = NSApp.windows.contains { $0 !== closing && WindowRouter.isMainWindow($0) && $0.isVisible }
                        let hideDock = WindowRouter.shared.environment?.hideDockIconWhenClosed ?? true
                        if !stillOpen && hideDock {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
            }
        })
        observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                if WindowRouter.isMainWindow(window), NSApp.activationPolicy() != .regular {
                    NSApp.setActivationPolicy(.regular)
                }
            }
        })
    }

    /// Closing the last window must never quit the app — it lives on in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainActor.assumeIsolated {
                WindowRouter.shared.showMainWindow()
            }
        }
        return true
    }
}

@main
struct TaskManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        Window("Task Manager", id: WindowRouter.mainWindowID) {
            MainLayoutView()
                .environmentObject(env)
                .frame(minWidth: 460, idealWidth: 1180, minHeight: 420, idealHeight: 760)
                .preferredColorScheme(colorScheme)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .background(WindowOpenerInstaller())
                .onAppear { WindowRouter.shared.environment = env }
        }
        .defaultSize(width: 1180, height: 760)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Command Palette...") {
                    env.isCommandPalettePresented.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            CommandGroup(replacing: .appTermination) {
                Button("Quit Task Manager") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            CommandMenu("Go") {
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
        // Always-on menu bar utility. It is not optional: the app keeps running
        // here after the window is closed, until the user explicitly quits.
        MenuBarExtra {
            MenuBarContentView(sampling: env.samplingCoordinator)
                .environmentObject(env)
                .preferredColorScheme(colorScheme)
                .background(WindowOpenerInstaller())
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

/// Captures SwiftUI's `openWindow` action so AppKit code can re-open the main window.
struct WindowOpenerInstaller: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                let action = openWindow
                WindowRouter.shared.openMainWindowAction = {
                    action(id: WindowRouter.mainWindowID)
                }
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

        let metric = env.displayedMenuBarMetric
        let value: String = {
            switch metric {
            case .cpu: return "\(cpu)%"
            case .gpu: return "\(gpu)%"
            case .memory: return "\(mem)%"
            case .disk: return "\(disk)%"
            case .network: return netFormatted
            }
        }()

        // Rendered as a fixed-size template image: the status item keeps exactly the
        // same width whatever the metric or value, so neighbouring menu bar items
        // never shift while the metrics rotate.
        if let image = Self.renderLabel(icon: metric.icon, value: value) {
            Image(nsImage: image)
        } else {
            Image(systemName: metric.icon)
        }
    }

    private static let iconWidth: CGFloat = 16
    private static let spacing: CGFloat = 3
    private static let height: CGFloat = 18
    private static let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

    /// Width of the widest value the label can ever show, so the slot fits it exactly.
    private static let maxValueWidth: CGFloat = {
        let samples = ["100%", "88%", "99.9M", "999M", "999K", "0K"]
        let attrs: [NSAttributedString.Key: Any] = [.font: valueFont]
        return ceil(samples.map { ($0 as NSString).size(withAttributes: attrs).width }.max() ?? 36)
    }()

    /// Constant total width of the menu bar label.
    private static let slotWidth: CGFloat = iconWidth + spacing + maxValueWidth

    @MainActor
    private static func renderLabel(icon: String, value: String) -> NSImage? {
        // Icon + value hug each other and are centred in a constant-width slot,
        // so the item never changes size and the spacing is balanced on both sides.
        let content = HStack(spacing: spacing) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: iconWidth, height: height)
            Text(value)
                .font(Font(valueFont))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundColor(.black)
        .frame(width: slotWidth, height: height, alignment: .center)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.size = NSSize(width: slotWidth, height: height)
        // Template images are tinted by macOS to match the light/dark menu bar.
        image.isTemplate = true
        return image
    }

    private func formatCompactRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 100 * 1_048_576 {
            return String(format: "%.0fM", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1_048_576 {
            return String(format: "%.1fM", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0fK", bytesPerSec / 1024)
        } else {
            return "0K"
        }
    }
}
