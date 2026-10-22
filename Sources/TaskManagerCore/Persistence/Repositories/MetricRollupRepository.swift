import Foundation
import SQLite3

/// Structure representing a saved metric rollup point.
public struct MetricRollup: Identifiable, Codable, Sendable {
    public let id: String
    public let metricKey: String
    public let observedAt: Date
    public let bucketSeconds: Int
    public let minValue: Double
    public let maxValue: Double
    public let avgValue: Double
    public let lastValue: Double
    public let unit: String
    public let providerQuality: String
    public let source: String

    public init(
        id: String = UUID().uuidString,
        metricKey: String,
        observedAt: Date = Date(),
        bucketSeconds: Int = 60,
        minValue: Double,
        maxValue: Double,
        avgValue: Double,
        lastValue: Double,
        unit: String,
        providerQuality: String = "exact",
        source: String
    ) {
        self.id = id
        self.metricKey = metricKey
        self.observedAt = observedAt
        self.bucketSeconds = bucketSeconds
        self.minValue = minValue
        self.maxValue = maxValue
        self.avgValue = avgValue
        self.lastValue = lastValue
        self.unit = unit
        self.providerQuality = providerQuality
        self.source = source
    }
}

/// Repository for persisting and querying downsampled metric history.
public final class MetricRollupRepository: @unchecked Sendable {
    private let store: SQLiteStore

    public init(store: SQLiteStore) {
        self.store = store
    }

    public func insertRollup(_ rollup: MetricRollup) throws {
        let sql = """
        INSERT INTO metric_rollups (
            id, metric_key, observed_at, bucket_seconds,
            min_value, max_value, avg_value, last_value,
            unit, provider_quality, source
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        let bindings: [Any?] = [
            rollup.id,
            rollup.metricKey,
            rollup.observedAt,
            rollup.bucketSeconds,
            rollup.minValue,
            rollup.maxValue,
            rollup.avgValue,
            rollup.lastValue,
            rollup.unit,
            rollup.providerQuality,
            rollup.source
        ]
        try store.executeUpdate(sql: sql, bindings: bindings)
    }

    public func fetchRollups(metricKey: String, since: Date) throws -> [MetricRollup] {
        let sql = """
        SELECT id, metric_key, observed_at, bucket_seconds,
               min_value, max_value, avg_value, last_value,
               unit, provider_quality, source
        FROM metric_rollups
        WHERE metric_key = ? AND observed_at >= ?
        ORDER BY observed_at ASC;
        """
        return try store.query(sql: sql, bindings: [metricKey, since]) { stmt in
            MetricRollup(
                id: SQLiteStore.text(at: 0, statement: stmt) ?? UUID().uuidString,
                metricKey: SQLiteStore.text(at: 1, statement: stmt) ?? metricKey,
                observedAt: SQLiteStore.date(at: 2, statement: stmt) ?? Date(),
                bucketSeconds: SQLiteStore.int(at: 3, statement: stmt) ?? 60,
                minValue: SQLiteStore.double(at: 4, statement: stmt) ?? 0.0,
                maxValue: SQLiteStore.double(at: 5, statement: stmt) ?? 0.0,
                avgValue: SQLiteStore.double(at: 6, statement: stmt) ?? 0.0,
                lastValue: SQLiteStore.double(at: 7, statement: stmt) ?? 0.0,
                unit: SQLiteStore.text(at: 8, statement: stmt) ?? "",
                providerQuality: SQLiteStore.text(at: 9, statement: stmt) ?? "exact",
                source: SQLiteStore.text(at: 10, statement: stmt) ?? ""
            )
        }
    }

    public func purgeOldRollups(retentionDays: Int) throws {
        guard retentionDays > 0 else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        let sql = "DELETE FROM metric_rollups WHERE observed_at < ?;"
        try store.executeUpdate(sql: sql, bindings: [cutoff])
    }

    public func clearAll() throws {
        try store.executeUpdate(sql: "DELETE FROM metric_rollups;")
    }
}
