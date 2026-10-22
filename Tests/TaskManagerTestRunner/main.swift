import Foundation
import TaskManagerCore

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
    if actual != expected {
        print("❌ Assertion Failed at \(file):\(line) — Expected '\(expected)', got '\(actual)'. \(message)")
        exit(1)
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if !condition {
        print("❌ Assertion Failed at \(file):\(line) — Condition is false. \(message)")
        exit(1)
    }
}

func assertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if condition {
        print("❌ Assertion Failed at \(file):\(line) — Condition is true. \(message)")
        exit(1)
    }
}

print("==================================================")
print("  Task Manager for macOS — Test Suite Runner")
print("==================================================")

// 1. Task Domain Tests
print("\n👉 [1/5] Running TaskDomainTests...")
do {
    let task = TaskItem(title: "Write documentation", notes: "Document SAS architecture", priority: .high)
    assertEqual(task.title, "Write documentation")
    assertEqual(task.notes, "Document SAS architecture")
    assertEqual(task.priority, .high)
    assertEqual(task.status, .todo)
    assertFalse(task.isCompleted)
    assertFalse(task.isOverdue)

    assertTrue(TaskPriority.low < TaskPriority.normal)
    assertTrue(TaskPriority.normal < TaskPriority.high)
    assertTrue(TaskPriority.high < TaskPriority.urgent)

    let calendar = Calendar.current
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

    let overdueTask = TaskItem(title: "Overdue", dueAt: yesterday)
    assertTrue(overdueTask.isOverdue)
    assertFalse(overdueTask.isUpcoming)

    let upcomingTask = TaskItem(title: "Upcoming", dueAt: tomorrow)
    assertTrue(upcomingTask.isUpcoming)
    assertFalse(upcomingTask.isOverdue)

    print("   ✅ TaskDomainTests passed successfully.")
}

// 2. Recurrence Engine Tests
print("\n👉 [2/5] Running RecurrenceEngineTests...")
do {
    let rule = RecurrenceRule(frequency: .weekly, interval: 2)
    assertEqual(rule.ruleString, "FREQ=WEEKLY;INTERVAL=2")

    let parsed = RecurrenceRule.parse("FREQ=WEEKLY;INTERVAL=2")
    assertTrue(parsed != nil)
    assertEqual(parsed?.frequency, .weekly)
    assertEqual(parsed?.interval, 2)

    let engine = RecurrenceEngine()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let dailyRule = RecurrenceRule(frequency: .daily, interval: 1)

    let next = engine.nextDueDate(for: dailyRule, after: today, from: today)
    assertTrue(next != nil)
    let expected = calendar.date(byAdding: .day, value: 1, to: today)
    assertEqual(next, expected)

    // Storm prevention check
    let threeWeeksAgo = calendar.date(byAdding: .day, value: -21, to: Date())!
    let stormProtectedNext = engine.nextDueDate(for: dailyRule, after: threeWeeksAgo, from: Date())
    assertTrue(stormProtectedNext != nil)
    assertTrue(stormProtectedNext! >= calendar.startOfDay(for: Date()))

    print("   ✅ RecurrenceEngineTests passed successfully.")
}

// 3. SQLite Store & Repositories Tests
print("\n👉 [3/5] Running SQLiteStore & RepositoryTests...")
do {
    let store = try SQLiteStore(databaseURL: nil)
    let migrator = MigrationManager(store: store)
    try migrator.migrate()

    let taskRepo = TaskRepository(store: store)
    let projectRepo = ProjectRepository(store: store)
    let tagRepo = TagRepository(store: store)
    let rollupRepo = MetricRollupRepository(store: store)

    // Task CRUD
    let task = TaskItem(title: "Test Task", notes: "Test notes", priority: .high)
    try taskRepo.insertTask(task)

    let fetched = try taskRepo.fetchTask(id: task.id)
    assertTrue(fetched != nil)
    assertEqual(fetched?.title, "Test Task")
    assertEqual(fetched?.priority, .high)

    var updated = fetched!
    updated.title = "Updated Title"
    try taskRepo.updateTask(updated)

    let reFetched = try taskRepo.fetchTask(id: task.id)
    assertEqual(reFetched?.title, "Updated Title")

    // Project & Section
    let project = Project(name: "Engineering", colorToken: "indigo")
    try projectRepo.insertProject(project)

    let section = ProjectSection(projectId: project.id, name: "Backlog")
    try projectRepo.insertSection(section)

    let sections = try projectRepo.fetchSections(projectId: project.id)
    assertEqual(sections.count, 1)
    assertEqual(sections.first?.name, "Backlog")

    // Tag association
    let tag = Tag(name: "Swift", colorToken: "orange")
    try tagRepo.insertTag(tag)

    let taskWithTag = TaskItem(title: "Tagged Task", projectId: project.id, tags: [tag])
    try taskRepo.insertTask(taskWithTag)

    let fetchedTagged = try taskRepo.fetchTask(id: taskWithTag.id)
    assertEqual(fetchedTagged?.tags.count, 1)
    assertEqual(fetchedTagged?.tags.first?.name, "Swift")

    // Metric Rollup
    let rollup = MetricRollup(
        metricKey: "cpu.load",
        minValue: 10.0,
        maxValue: 40.0,
        avgValue: 25.0,
        lastValue: 30.0,
        unit: "%",
        source: "host_statistics"
    )
    try rollupRepo.insertRollup(rollup)

    let rollups = try rollupRepo.fetchRollups(metricKey: "cpu.load", since: Date().addingTimeInterval(-3600))
    assertEqual(rollups.count, 1)
    assertEqual(rollups.first?.avgValue, 25.0)

    print("   ✅ SQLiteStore & RepositoryTests passed successfully.")
} catch {
    print("❌ SQLiteStore test failed with error: \(error)")
    exit(1)
}

// 4. Device Profile & Truthful Capability Registry Tests
print("\n👉 [4/5] Running DeviceProfile & CapabilityRegistryTests...")
do {
    let service = DeviceProfileService()
    let profile = service.buildProfile()

    assertFalse(profile.modelIdentifier.isEmpty)
    assertFalse(profile.marketingName.isEmpty)
    assertFalse(profile.cpuName.isEmpty)
    assertTrue(profile.logicalCores > 0)
    assertTrue(profile.physicalCores > 0)
    assertTrue(profile.totalMemoryBytes > 0)
    assertTrue(profile.displayCount > 0)
    assertFalse(profile.gpuNames.isEmpty)

    let registry = CapabilityRegistry(profileService: service)
    let records = registry.inspectAllCapabilities()
    assertFalse(records.isEmpty)

    // Verify SAS Truthful Capability mandates:
    // Fan RPM must be explicitly notExposedBySupportedAPI, NEVER 0!
    guard let fan = records.first(where: { $0.id == "thermal.fan_rpm" }) else {
        print("❌ Missing thermal.fan_rpm")
        exit(1)
    }
    assertEqual(fan.status, .notExposedBySupportedAPI)
    assertTrue(fan.valueString == nil)
    assertTrue(fan.explanation != nil)

    // GPU load must be explicitly notExposedBySupportedAPI
    guard let gpu = records.first(where: { $0.id == "gpu.utilization" }) else {
        print("❌ Missing gpu.utilization")
        exit(1)
    }
    assertEqual(gpu.status, .notExposedBySupportedAPI)
    assertTrue(gpu.valueString == nil)

    // Neural Engine telemetry must be notExposedBySupportedAPI
    guard let ane = records.first(where: { $0.id == "neural.telemetry" }) else {
        print("❌ Missing neural.telemetry")
        exit(1)
    }
    assertEqual(ane.status, .notExposedBySupportedAPI)

    print("   ✅ DeviceProfile & CapabilityRegistryTests passed successfully.")
}

// 5. Import / Export & Widget Snapshot Tests
print("\n👉 [5/5] Running ImportExport & WidgetSnapshotTests...")
do {
    let store = try SQLiteStore(databaseURL: nil)
    try MigrationManager(store: store).migrate()

    let taskRepo = TaskRepository(store: store)
    let projectRepo = ProjectRepository(store: store)
    let tagRepo = TagRepository(store: store)
    let service = ImportExportService(taskRepo: taskRepo, projectRepo: projectRepo, tagRepo: tagRepo, store: store)

    let project = Project(name: "Export Project", colorToken: "blue")
    try projectRepo.insertProject(project)

    let task = TaskItem(title: "Export Task", priority: .urgent, projectId: project.id)
    try taskRepo.insertTask(task)

    let exportedData = try service.exportJSON()
    assertTrue(exportedData.count > 0)

    let csv = try service.exportCSV()
    assertTrue(csv.contains("Export Task"))
    assertTrue(csv.contains("urgent"))

    let importStore = try SQLiteStore(databaseURL: nil)
    try MigrationManager(store: importStore).migrate()
    let importTaskRepo = TaskRepository(store: importStore)
    let importProjectRepo = ProjectRepository(store: importStore)
    let importTagRepo = TagRepository(store: importStore)
    let importService = ImportExportService(taskRepo: importTaskRepo, projectRepo: importProjectRepo, tagRepo: importTagRepo, store: importStore)

    let counts = try importService.importJSON(data: exportedData)
    assertEqual(counts.projectsCount, 1)
    assertEqual(counts.tasksCount, 1)

    let importedTasks = try importTaskRepo.fetchTasks()
    assertEqual(importedTasks.first?.title, "Export Task")
    assertEqual(importedTasks.first?.priority, .urgent)

    // Widget Snapshot test
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let snapshotStore = WidgetSnapshotStore(containerURL: tempDir)
    let snapshot = WidgetSnapshot(
        schemaVersion: 1,
        todayCount: 3,
        overdueCount: 1,
        completedTodayCount: 4,
        topTasks: [
            WidgetTaskItem(id: "1", title: "Task 1", priority: "High", dueAt: Date(), isOverdue: false)
        ],
        batteryChargePercent: 95,
        isCharging: true
    )

    try snapshotStore.writeSnapshot(snapshot)
    let read = snapshotStore.readSnapshot()
    assertTrue(read != nil)
    assertEqual(read?.todayCount, 3)
    assertEqual(read?.overdueCount, 1)
    assertEqual(read?.batteryChargePercent, 95)

    print("   ✅ ImportExport & WidgetSnapshotTests passed successfully.")
} catch {
    print("❌ ImportExport test failed with error: \(error)")
    exit(1)
}

print("\n==================================================")
print("🎉 ALL TEST SUITES PASSED (5/5) WITH ZERO FAILURES!")
print("==================================================")
