import Foundation
import SwiftUI
import Combine
import TaskManagerCore

/// Observable global environment holding repositories, services, and reactive app state.
@MainActor
public final class AppEnvironment: ObservableObject {
    public let store: SQLiteStore
    public let taskRepo: TaskRepository
    public let projectRepo: ProjectRepository
    public let tagRepo: TagRepository
    public let rollupRepo: MetricRollupRepository
    public let settingsRepo: SettingsRepository
    public let samplingCoordinator: SamplingCoordinator
    public let deviceProfileService: DeviceProfileService
    public let capabilityRegistry: CapabilityRegistry
    public let notificationService: NotificationService
    public let importExportService: ImportExportService
    public let widgetSnapshotStore: WidgetSnapshotStore
    public let loginItemService: LoginItemService

    // Reactive State
    @Published public var tasks: [TaskItem] = []
    @Published public var projects: [Project] = []
    @Published public var tags: [Tag] = []
    @Published public var deviceProfile: DeviceProfile
    @Published public var capabilities: [CapabilityRecord] = []
    @Published public var appearanceMode: String = "system" // "system", "light", "dark"
    @Published public var keepInMenuBar: Bool = true
    @Published public var launchAtLogin: Bool = false
    @Published public var selectedDestination: AppDestination = .today
    @Published public var isQuickCapturePresented: Bool = false
    @Published public var isCommandPalettePresented: Bool = false
    @Published public var searchQuery: String = ""

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

            let tRepo = TaskRepository(store: dbStore)
            let pRepo = ProjectRepository(store: dbStore)
            let gRepo = TagRepository(store: dbStore)
            let rRepo = MetricRollupRepository(store: dbStore)
            let sRepo = SettingsRepository(store: dbStore)

            self.taskRepo = tRepo
            self.projectRepo = pRepo
            self.tagRepo = gRepo
            self.rollupRepo = rRepo
            self.settingsRepo = sRepo

            let profService = DeviceProfileService()
            self.deviceProfileService = profService
            self.deviceProfile = profService.buildProfile()

            self.capabilityRegistry = CapabilityRegistry(profileService: profService)
            self.samplingCoordinator = SamplingCoordinator(rollupRepository: rRepo)
            self.notificationService = NotificationService()
            self.importExportService = ImportExportService(taskRepo: tRepo, projectRepo: pRepo, tagRepo: gRepo, store: dbStore)
            self.widgetSnapshotStore = WidgetSnapshotStore()
            self.loginItemService = LoginItemService()

            // Load saved settings
            self.appearanceMode = sRepo.getString(key: "appearance", default: "system")
            self.keepInMenuBar = sRepo.getBool(key: "keep_in_menu_bar", default: true)
            self.launchAtLogin = loginItemService.isEnabled

            // Seed initial data if fresh database
            seedSampleDataIfNeeded()

            // Initial reload
            reloadAll()
        } catch {
            fatalError("Failed to initialize TaskManager AppEnvironment: \(error)")
        }
    }

    public func reloadAll() {
        do {
            self.tasks = try taskRepo.fetchTasks(filter: TaskFilter(includeDeleted: false))
            self.projects = try projectRepo.fetchProjects(includeArchived: false)
            self.tags = try tagRepo.fetchTags()
            self.capabilities = capabilityRegistry.inspectAllCapabilities()
            self.deviceProfile = deviceProfileService.buildProfile()
            updateWidgetSnapshot()
        } catch {
            print("Failed to reload data: \(error)")
        }
    }

    public func addTask(title: String, notes: String? = nil, priority: TaskPriority = .normal, dueAt: Date? = nil, projectId: UUID? = nil, tags: [Tag] = [], recurrence: String? = nil) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let status: TaskStatus = (dueAt != nil) ? .todo : .inbox
        let task = TaskItem(
            title: title,
            notes: notes,
            status: status,
            priority: priority,
            dueAt: dueAt,
            projectId: projectId,
            recurrenceRule: recurrence,
            tags: tags
        )
        do {
            try taskRepo.insertTask(task)
            reloadAll()
        } catch {
            print("Error adding task: \(error)")
        }
    }

    public func toggleTaskCompletion(_ task: TaskItem) {
        do {
            if task.isCompleted {
                try taskRepo.reopenTask(id: task.id)
            } else {
                _ = try taskRepo.completeTask(id: task.id)
            }
            reloadAll()
        } catch {
            print("Error toggling task completion: \(error)")
        }
    }

    public func deleteTask(id: UUID) {
        do {
            try taskRepo.deleteTask(id: id, hard: false)
            reloadAll()
        } catch {
            print("Error deleting task: \(error)")
        }
    }

    public func updateTask(_ task: TaskItem) {
        do {
            try taskRepo.updateTask(task)
            reloadAll()
        } catch {
            print("Error updating task: \(error)")
        }
    }

    public func addProject(name: String, description: String? = nil, colorToken: String = "indigo") {
        let proj = Project(name: name, description: description, colorToken: colorToken)
        do {
            try projectRepo.insertProject(proj)
            reloadAll()
        } catch {
            print("Error adding project: \(error)")
        }
    }

    public func addTag(name: String, colorToken: String = "blue") {
        let tag = Tag(name: name, colorToken: colorToken)
        do {
            try tagRepo.insertTag(tag)
            reloadAll()
        } catch {
            print("Error adding tag: \(error)")
        }
    }

    public func updateWidgetSnapshot() {
        let calendar = Calendar.current
        let todayTasks = tasks.filter { $0.isToday && !$0.isCompleted }
        let overdueTasks = tasks.filter { $0.isOverdue }
        let completedToday = tasks.filter { $0.isCompleted && ($0.completedAt != nil && calendar.isDateInToday($0.completedAt!)) }

        let topWidgets = todayTasks.prefix(5).map {
            WidgetTaskItem(
                id: $0.id.uuidString,
                title: $0.title,
                priority: $0.priority.displayName,
                dueAt: $0.dueAt,
                isOverdue: $0.isOverdue
            )
        }

        let battery = samplingCoordinator.latestBattery?.value
        let storage = samplingCoordinator.latestStorage?.value?.first

        let snapshot = WidgetSnapshot(
            schemaVersion: 1,
            generatedAt: Date(),
            todayCount: todayTasks.count,
            overdueCount: overdueTasks.count,
            completedTodayCount: completedToday.count,
            topTasks: Array(topWidgets),
            batteryChargePercent: battery?.chargePercent,
            isCharging: battery?.isCharging,
            storageFreeBytes: storage?.availableBytes,
            lastSampleTimestamp: Date()
        )
        try? widgetSnapshotStore.writeSnapshot(snapshot)
    }

    private func seedSampleDataIfNeeded() {
        do {
            let existingProjects = try projectRepo.fetchProjects(includeArchived: true)
            guard existingProjects.isEmpty else { return }

            let workProj = Project(name: "Work & Engineering", description: "Architecture, coding, and code reviews", colorToken: "indigo")
            let personalProj = Project(name: "Personal", description: "Health, home, and finances", colorToken: "emerald")
            try projectRepo.insertProject(workProj)
            try projectRepo.insertProject(personalProj)

            let urgentTag = Tag(name: "Urgent", colorToken: "rose")
            let macTag = Tag(name: "macOS", colorToken: "blue")
            let reviewTag = Tag(name: "Review", colorToken: "amber")
            try tagRepo.insertTag(urgentTag)
            try tagRepo.insertTag(macTag)
            try tagRepo.insertTag(reviewTag)

            let calendar = Calendar.current
            let now = Date()
            let todayEvening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)

            let sample1 = TaskItem(
                title: "Review Task Manager SAS specification",
                notes: "Verify architecture requirements, runtime capability states, and native widgets",
                status: .completed,
                priority: .high,
                completedAt: calendar.date(byAdding: .hour, value: -2, to: now),
                projectId: workProj.id,
                tags: [macTag, reviewTag]
            )

            let sample2 = TaskItem(
                title: "Inspect Mac hardware capability inventory",
                notes: "Check CPU logical cores, Metal GPUs, battery state and thermal pressure",
                status: .todo,
                priority: .urgent,
                dueAt: todayEvening,
                projectId: workProj.id,
                tags: [urgentTag, macTag]
            )

            let sample3 = TaskItem(
                title: "Organize project priorities & upcoming milestones",
                notes: "Review active sprints and organize task list sections",
                status: .todo,
                priority: .normal,
                dueAt: tomorrow,
                projectId: workProj.id,
                tags: [reviewTag]
            )

            let sample4 = TaskItem(
                title: "Set up daily backup routine",
                notes: "Verify local SQLite backups and JSON export function",
                status: .inbox,
                priority: .low,
                projectId: personalProj.id,
                tags: []
            )

            try taskRepo.insertTask(sample1)
            try taskRepo.insertTask(sample2)
            try taskRepo.insertTask(sample3)
            try taskRepo.insertTask(sample4)
        } catch {
            print("Failed to seed initial data: \(error)")
        }
    }
}
