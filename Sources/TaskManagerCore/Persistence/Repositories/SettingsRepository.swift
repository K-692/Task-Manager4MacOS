import Foundation
import SQLite3

/// Repository managing typed application settings.
public final class SettingsRepository: @unchecked Sendable {
    private let store: SQLiteStore

    public init(store: SQLiteStore) {
        self.store = store
    }

    public func get(key: String) throws -> String? {
        let sql = "SELECT value FROM settings WHERE key = ?;"
        let results = try store.query(sql: sql, bindings: [key]) { stmt in
            SQLiteStore.text(at: 0, statement: stmt)
        }
        return results.first ?? nil
    }

    public func set(key: String, value: String) throws {
        let sql = """
        INSERT INTO settings (key, value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;
        """
        try store.executeUpdate(sql: sql, bindings: [key, value, Date()])
    }

    public func getBool(key: String, default defaultValue: Bool = false) -> Bool {
        do {
            guard let val = try get(key: key) else { return defaultValue }
            return val == "true" || val == "1"
        } catch {
            return defaultValue
        }
    }

    public func setBool(key: String, value: Bool) throws {
        try set(key: key, value: value ? "true" : "false")
    }

    public func getInt(key: String, default defaultValue: Int = 0) -> Int {
        do {
            guard let val = try get(key: key), let intVal = Int(val) else { return defaultValue }
            return intVal
        } catch {
            return defaultValue
        }
    }

    public func setInt(key: String, value: Int) throws {
        try set(key: key, value: String(value))
    }

    public func getString(key: String, default defaultValue: String = "") -> String {
        do {
            return try get(key: key) ?? defaultValue
        } catch {
            return defaultValue
        }
    }

    public func resetAll() throws {
        try store.executeUpdate(sql: "DELETE FROM settings;")
    }
}
