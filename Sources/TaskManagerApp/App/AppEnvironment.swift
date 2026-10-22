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
        case .disk: return "Disk"
        case .network: return "Network"
        }
    }

    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "display.trianglebadge.exclamationmark"
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
    @Published public var keepInMenuBar: Bool = true
    @Published public var launchAtLogin: Bool = false
    @Published public var searchQuery: String = ""
    @Published public var selectedProcessPID: Int32? = nil
    @Published public var isCommandPalettePresented: Bool = false

    // Menu Bar Display Customization (Single-Selection: only one component active on macOS menu bar)
    @Published public var selectedMenuBarMetric: MenuBarMetric = .cpu {
        didSet {
            try? settingsRepo.set(key: "menubar_selected_metric", value: selectedMenuBarMetric.rawValue)
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
            self.keepInMenuBar = sRepo.getBool(key: "keep_in_menu_bar", default: true)
            self.launchAtLogin = loginItemService.isEnabled
            let savedMetric = sRepo.getString(key: "menubar_selected_metric", default: "cpu")
            self.selectedMenuBarMetric = MenuBarMetric(rawValue: savedMetric) ?? .cpu

            reloadCapabilities()
        } catch {
            fatalError("Failed to initialize TaskManager AppEnvironment: \(error)")
        }
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
