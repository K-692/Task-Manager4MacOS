import Foundation
import SQLite3

/// Manages database migrations with version tracking and integrity guarantees.
public struct MigrationManager {
    private let store: SQLiteStore

    public init(store: SQLiteStore) {
        self.store = store
    }

    public func migrate() throws {
        try createMigrationsTableIfNeeded()
        let appliedVersions = try getAppliedVersions()

        if !appliedVersions.contains(1) {
            try applyMigrationV1()
        }
    }

    private func createMigrationsTableIfNeeded() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            applied_at REAL NOT NULL,
            description TEXT NOT NULL
        );
        """
        try store.execute(sql: sql)
    }

    private func getAppliedVersions() throws -> Set<Int> {
        let sql = "SELECT version FROM schema_migrations ORDER BY version ASC;"
        let versions = try store.query(sql: sql) { stmt in
            Int(sqlite3_column_int(stmt, 0))
        }
        return Set(versions)
    }

    private func applyMigrationV1() throws {
        try store.transaction {
            let v1Schema = """
            -- Settings table
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at REAL NOT NULL
            );

            -- Metric rollups table
            CREATE TABLE IF NOT EXISTS metric_rollups (
                id TEXT PRIMARY KEY,
                metric_key TEXT NOT NULL,
                observed_at REAL NOT NULL,
                bucket_seconds INTEGER NOT NULL,
                min_value REAL NOT NULL,
                max_value REAL NOT NULL,
                avg_value REAL NOT NULL,
                last_value REAL NOT NULL,
                unit TEXT NOT NULL,
                provider_quality TEXT NOT NULL,
                source TEXT NOT NULL
            );

            -- Performance Indexes
            CREATE INDEX IF NOT EXISTS idx_metric_rollups_key_time ON metric_rollups(metric_key, observed_at);
            """

            try store.execute(sql: v1Schema)

            let recordMigration = """
            INSERT INTO schema_migrations (version, applied_at, description)
            VALUES (1, \(Date().timeIntervalSince1970), 'Performance and settings baseline schema v1');
            """
            try store.execute(sql: recordMigration)
        }
    }
}
