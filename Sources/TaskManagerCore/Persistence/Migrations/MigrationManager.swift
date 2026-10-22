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
            -- Projects table
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                color_token TEXT NOT NULL DEFAULT 'indigo',
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                archived_at REAL,
                sort_order REAL NOT NULL DEFAULT 0.0
            );

            -- Project Sections table
            CREATE TABLE IF NOT EXISTS sections (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                name TEXT NOT NULL,
                sort_order REAL NOT NULL DEFAULT 0.0,
                FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
            );

            -- Tags table
            CREATE TABLE IF NOT EXISTS tags (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                color_token TEXT NOT NULL DEFAULT 'blue',
                created_at REAL NOT NULL
            );

            -- Tasks table
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                notes TEXT,
                status TEXT NOT NULL DEFAULT 'todo',
                priority TEXT NOT NULL DEFAULT 'normal',
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                start_at REAL,
                due_at REAL,
                completed_at REAL,
                project_id TEXT,
                section_id TEXT,
                sort_order REAL NOT NULL DEFAULT 0.0,
                estimate_minutes INTEGER,
                recurrence_rule TEXT,
                parent_task_id TEXT,
                deleted_at REAL,
                FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
                FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE SET NULL
            );

            -- Task Tags junction table
            CREATE TABLE IF NOT EXISTS task_tags (
                task_id TEXT NOT NULL,
                tag_id TEXT NOT NULL,
                PRIMARY KEY (task_id, tag_id),
                FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
                FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
            );

            -- Task Reminders table
            CREATE TABLE IF NOT EXISTS task_reminders (
                id TEXT PRIMARY KEY,
                task_id TEXT NOT NULL,
                fire_at REAL NOT NULL,
                kind TEXT NOT NULL DEFAULT 'due',
                enabled INTEGER NOT NULL DEFAULT 1,
                notification_identifier TEXT NOT NULL,
                FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
            );

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
            CREATE INDEX IF NOT EXISTS idx_tasks_due_at ON tasks(due_at);
            CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
            CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
            CREATE INDEX IF NOT EXISTS idx_tasks_sort_order ON tasks(sort_order);
            CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at ON tasks(deleted_at);
            CREATE INDEX IF NOT EXISTS idx_metric_rollups_key_time ON metric_rollups(metric_key, observed_at);
            """

            try store.execute(sql: v1Schema)

            let recordMigration = """
            INSERT INTO schema_migrations (version, applied_at, description)
            VALUES (1, \(Date().timeIntervalSince1970), 'Initial baseline schema v1');
            """
            try store.execute(sql: recordMigration)
        }
    }
}
