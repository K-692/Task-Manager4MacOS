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
                WindowRouter.shared.environment?.setMainWindowVisible(false)
                // Give AppKit a moment to finish closing, then drop the Dock icon
                // if no other main window remains.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    MainActor.assumeIsolated {
                        let stillOpen = NSApp.windows.contains { $0 !== closing && WindowRouter.isMainWindow($0) && $0.isVisible }
                        // Without a menu bar icon the Dock icon is the only way back, so keep it.
                        let env = WindowRouter.shared.environment
                        let hideDock = (env?.hideDockIconWhenClosed ?? true) && (env?.showMenuBarIcon ?? true)
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
                if WindowRouter.isMainWindow(window) {
                    WindowRouter.shared.environment?.setMainWindowVisible(true)
                }
            }
        })
        // Pause the window's live UI while it is minimised, hidden or fully covered.
        observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                guard WindowRouter.isMainWindow(window) else { return }
                WindowRouter.shared.environment?.setMainWindowVisible(window.isVisible && window.occlusionState.contains(.visible))
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
    /// Menu bar visibility lives in UserDefaults: SwiftUI's MenuBarExtra(isInserted:)
    /// only tracks an @AppStorage-backed binding reliably.
    @AppStorage(AppEnvironment.menuBarVisibleDefaultsKey) private var showMenuBarIcon = true

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
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarContentView(sampling: env.samplingCoordinator)
                .environmentObject(env)
                .liveProcesses(env.samplingCoordinator)
                .preferredColorScheme(standardColorScheme)
                .background(WindowOpenerInstaller())
        } label: {
            MenuBarStatusLabel(env: env, sampling: env.samplingCoordinator, rotation: env.rotation)
        }
        .menuBarExtraStyle(.window)
    }

    private var colorScheme: ColorScheme? {
        // The publication theme is always light (white paper).
        if env.visualTheme.isPublication { return .light }
        switch env.appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    /// The menu bar popup keeps the standard look regardless of the publication theme.
    private var standardColorScheme: ColorScheme? {
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
    @ObservedObject var rotation: MenuBarRotation

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
        // Only the icon is shaded green → red by usage (Network: by throughput); the
        // value keeps the normal menu bar text colour (white on a dark menu bar).
        let dark = env.menuBarIsDark
        let usage: (Double, UsageScale) = {
            switch metric {
            case .cpu: return (sampling.latestCPU?.value?.totalUsagePercent ?? 0, .percent)
            case .gpu: return (sampling.latestGPU?.value?.utilizationPercent ?? 0, .percent)
            case .memory: return (sampling.latestMemory?.value?.usagePercentage ?? 0, .percent)
            case .disk: return (sampling.latestStorage?.value?.first?.usagePercentage ?? 0, .percent)
            case .network: return (netIn + netOut, .network)
            }
        }()
        let iconColor = NSColor(UsageColor.menuBarColor(usage.0, scale: usage.1, darkMenuBar: dark))

        Image(nsImage: Self.label(icon: metric.icon, value: value, iconColor: iconColor, darkMenuBar: dark))
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

    /// Last rendered label, reused while nothing visible changed.
    @MainActor private static var cache: (key: String, image: NSImage)?

    /// Draws the label directly with AppKit (much cheaper than rendering a SwiftUI view
    /// every second). Icon + value are centred in a constant-width slot so the status
    /// item never changes size.
    @MainActor
    private static func label(icon: String, value: String, iconColor: NSColor, darkMenuBar: Bool) -> NSImage {
        let rgb = iconColor.usingColorSpace(.sRGB) ?? iconColor
        let key = "\(icon)|\(value)|\(darkMenuBar)|\(Int(rgb.redComponent * 255)),\(Int(rgb.greenComponent * 255)),\(Int(rgb.blueComponent * 255))"
        if let cache, cache.key == key { return cache.image }

        let textColor: NSColor = darkMenuBar ? .white : .black
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [iconColor]))
        let symbol = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        let attrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: textColor]
        let textSize = (value as NSString).size(withAttributes: attrs)

        let image = NSImage(size: NSSize(width: slotWidth, height: height), flipped: false) { rect in
            let contentWidth = iconWidth + spacing + textSize.width
            var x = (rect.width - contentWidth) / 2
            if let symbol {
                let s = symbol.size
                let scale = min(1, iconWidth / max(s.width, 1), height / max(s.height, 1))
                let w = s.width * scale, h = s.height * scale
                symbol.draw(in: NSRect(x: x + (iconWidth - w) / 2, y: (rect.height - h) / 2, width: w, height: h))
            }
            x += iconWidth + spacing
            (value as NSString).draw(at: NSPoint(x: x, y: (rect.height - textSize.height) / 2), withAttributes: attrs)
            return true
        }
        image.isTemplate = false
        cache = (key, image)
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
