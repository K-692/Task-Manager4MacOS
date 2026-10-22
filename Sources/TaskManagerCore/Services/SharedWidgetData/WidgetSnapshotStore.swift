import Foundation

/// Compact task summary for widgets.
public struct WidgetTaskItem: Codable, Sendable {
    public let id: String
    public let title: String
    public let priority: String
    public let dueAt: Date?
    public let isOverdue: Bool

    public init(id: String, title: String, priority: String, dueAt: Date?, isOverdue: Bool) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueAt = dueAt
        self.isOverdue = isOverdue
    }
}

/// Versioned snapshot written for WidgetKit consumption without direct database access.
public struct WidgetSnapshot: Codable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let todayCount: Int
    public let overdueCount: Int
    public let completedTodayCount: Int
    public let topTasks: [WidgetTaskItem]
    public let batteryChargePercent: Int?
    public let isCharging: Bool?
    public let storageFreeBytes: UInt64?
    public let lastSampleTimestamp: Date?

    public init(
        schemaVersion: Int = 1,
        generatedAt: Date = Date(),
        todayCount: Int,
        overdueCount: Int,
        completedTodayCount: Int,
        topTasks: [WidgetTaskItem],
        batteryChargePercent: Int? = nil,
        isCharging: Bool? = nil,
        storageFreeBytes: UInt64? = nil,
        lastSampleTimestamp: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.todayCount = todayCount
        self.overdueCount = overdueCount
        self.completedTodayCount = completedTodayCount
        self.topTasks = topTasks
        self.batteryChargePercent = batteryChargePercent
        self.isCharging = isCharging
        self.storageFreeBytes = storageFreeBytes
        self.lastSampleTimestamp = lastSampleTimestamp
    }
}

/// Store responsible for atomically writing and reading widget snapshots.
public final class WidgetSnapshotStore: Sendable {
    private let snapshotURL: URL

    public init(containerURL: URL? = nil) {
        if let custom = containerURL {
            self.snapshotURL = custom.appendingPathComponent("widget_snapshot.json")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("TaskManager")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.snapshotURL = dir.appendingPathComponent("widget_snapshot.json")
        }
    }

    public func writeSnapshot(_ snapshot: WidgetSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        // Write atomically
        let tempURL = snapshotURL.deletingLastPathComponent().appendingPathComponent("temp_\(UUID().uuidString).json")
        try data.write(to: tempURL, options: .atomic)
        _ = try? FileManager.default.removeItem(at: snapshotURL)
        try FileManager.default.moveItem(at: tempURL, to: snapshotURL)
    }

    public func readSnapshot() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
