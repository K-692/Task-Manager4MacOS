import Foundation
import SwiftUI
import Combine
import TaskManagerCore

/// Supported components for the single-icon macOS menu bar widget.
public enum MenuBarMetric: String, CaseIterable, Codable {
    case cpu = "cpu"
    case gpu = "gpu"
    case memory = "memory"
    case disk = "disk"
    case network = "network"

    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "Memory"
        case .disk: return "Storage"
        case .network: return "Network"
        }
    }

    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "cube.transparent"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        }
    }
}

/// Observable global environment holding system services, settings, and performance state.
@MainActor
public final class AppEnvironment: ObservableObject {
    public let store: SQLiteStore
    public let settingsRepo: SettingsRepository
    public let rollupRepo: MetricRollupRepository
    public let samplingCoordinator: SamplingCoordinator
    public let deviceProfileService: DeviceProfileService
    public let capabilityRegistry: CapabilityRegistry
    public let loginItemService: LoginItemService

    // Reactive State
    @Published public var deviceProfile: DeviceProfile
    @Published public var capabilities: [CapabilityRecord] = []
    @Published public var selectedDestination: AppDestination = .dashboard
    @Published public var appearanceMode: String = "system"
    /// Standard (colorful) or Publication (paper-ready) look.
    @Published public var visualTheme: VisualTheme = .standard {
        didSet { try? settingsRepo.set(key: "visual_theme", value: visualTheme.rawValue) }
    }
    /// The menu bar widget is always on; this controls whether the Dock icon
    /// disappears while the main window is closed.
    @Published public var hideDockIconWhenClosed: Bool = true {
        didSet {
            try? settingsRepo.setBool(key: "hide_dock_when_closed", value: hideDockIconWhenClosed)
        }
    }
    @Published public var launchAtLogin: Bool = false

    /// When on, the menu bar item cycles CPU → GPU → Memory → Storage → Network every 2 seconds.
    @Published public var rotateMenuBarMetrics: Bool = true {
        didSet {
            try? settingsRepo.setBool(key: "menubar_rotate", value: rotateMenuBarMetrics)
            restartRotation()
        }
    }
    /// The metric currently shown by the rotation.
    @Published public private(set) var rotatingMetric: MenuBarMetric = .cpu
    /// Seconds between rotation steps.
    public static let menuBarRotationInterval: TimeInterval = 2.0

    /// The metric the menu bar label should display right now.
    public var displayedMenuBarMetric: MenuBarMetric {
        rotateMenuBarMetrics ? rotatingMetric : selectedMenuBarMetric
    }

    /// User-initiated internet speed test shown in the menu bar popover.
    public let speedTest = SpeedTestService()

    private var rotationTimer: Timer?
    @Published public var searchQuery: String = ""
    @Published public var selectedProcessPID: Int32? = nil
    @Published public var isCommandPalettePresented: Bool = false

    // Menu Bar Display Customization (Single-Selection: only one component active on macOS menu bar)
    @Published public var selectedMenuBarMetric: MenuBarMetric = .cpu {
        didSet {
            try? settingsRepo.set(key: "menubar_selected_metric", value: selectedMenuBarMetric.rawValue)
            if rotateMenuBarMetrics { restartRotation() }
        }
    }

    // Backwards-compatible accessors
    public var menuBarShowCPU: Bool {
        get { selectedMenuBarMetric == .cpu }
        set { if newValue { selectedMenuBarMetric = .cpu } }
    }
    public var menuBarShowGPU: Bool {
        get { selectedMenuBarMetric == .gpu }
        set { if newValue { selectedMenuBarMetric = .gpu } }
    }
    public var menuBarShowMemory: Bool {
        get { selectedMenuBarMetric == .memory }
        set { if newValue { selectedMenuBarMetric = .memory } }
    }
    public var menuBarShowDisk: Bool {
        get { selectedMenuBarMetric == .disk }
        set { if newValue { selectedMenuBarMetric = .disk } }
    }
    public var menuBarShowNetwork: Bool {
        get { selectedMenuBarMetric == .network }
        set { if newValue { selectedMenuBarMetric = .network } }
    }

    private var cancellables = Set<AnyCancellable>()

    public init(databaseURL: URL? = nil) {
        do {
            let dbStore: SQLiteStore
            if let customURL = databaseURL {
                dbStore = try SQLiteStore(databaseURL: customURL)
            } else {
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let appDir = appSupport.appendingPathComponent("TaskManager", isDirectory: true)
                try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
                let dbURL = appDir.appendingPathComponent("taskmanager.sqlite")
                dbStore = try SQLiteStore(databaseURL: dbURL)
            }
            self.store = dbStore

            // Run migrations
            let migrator = MigrationManager(store: dbStore)
            try migrator.migrate()

            let rRepo = MetricRollupRepository(store: dbStore)
            let sRepo = SettingsRepository(store: dbStore)

            self.rollupRepo = rRepo
            self.settingsRepo = sRepo

            let profService = DeviceProfileService()
            self.deviceProfileService = profService
            self.deviceProfile = profService.buildProfile()

            self.capabilityRegistry = CapabilityRegistry(profileService: profService)
            let coordinator = SamplingCoordinator(rollupRepository: rRepo)
            self.samplingCoordinator = coordinator
            self.loginItemService = LoginItemService()

            // Forward telemetry sampling ticks to notify all views observing env
            coordinator.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)

            // Load saved settings
            self.appearanceMode = sRepo.getString(key: "appearance", default: "system")
            self.visualTheme = VisualTheme(rawValue: sRepo.getString(key: "visual_theme", default: "standard")) ?? .standard
            self.hideDockIconWhenClosed = sRepo.getBool(key: "hide_dock_when_closed", default: true)
            self.rotateMenuBarMetrics = sRepo.getBool(key: "menubar_rotate", default: true)

            // First launch: register as a login item so the menu bar widget is
            // available after every restart. Users can switch it off in Settings.
            if !sRepo.getBool(key: "did_initial_login_item_setup", default: false) {
                try? loginItemService.setLaunchAtLogin(enabled: true)
                try? sRepo.setBool(key: "did_initial_login_item_setup", value: true)
            }
            self.launchAtLogin = loginItemService.isEnabled
            let savedMetric = sRepo.getString(key: "menubar_selected_metric", default: "cpu")
            self.selectedMenuBarMetric = MenuBarMetric(rawValue: savedMetric) ?? .cpu

            reloadCapabilities()
            restartRotation()
        } catch {
            fatalError("Failed to initialize TaskManager AppEnvironment: \(error)")
        }
    }

    private func restartRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        guard rotateMenuBarMetrics else { return }
        rotatingMetric = selectedMenuBarMetric
        let timer = Timer(timeInterval: Self.menuBarRotationInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let all = MenuBarMetric.allCases
                let idx = all.firstIndex(of: self.rotatingMetric) ?? 0
                self.rotatingMetric = all[(idx + 1) % all.count]
            }
        }
        // .common mode keeps the rotation running while menus are open or the user scrolls.
        RunLoop.main.add(timer, forMode: .common)
        rotationTimer = timer
    }

    public func reloadCapabilities() {
        self.capabilities = capabilityRegistry.inspectAllCapabilities()
        self.deviceProfile = deviceProfileService.buildProfile()
    }

    /// Terminates a process ("End Task" feature like Windows Task Manager).
    public func terminateProcess(pid: Int32, force: Bool = false) -> Bool {
        let success = samplingCoordinator.processProvider.terminateProcess(pid: pid, force: force)
        samplingCoordinator.tick()
        return success
    }
}
