import Foundation
import SQLite3

/// Repository managing projects and their ordered sections.
public final class ProjectRepository: @unchecked Sendable {
    private let store: SQLiteStore

    public init(store: SQLiteStore) {
        self.store = store
    }

    public func fetchProjects(includeArchived: Bool = false) throws -> [Project] {
        let condition = includeArchived ? "" : "WHERE archived_at IS NULL"
        let sql = """
        SELECT id, name, description, color_token, created_at, updated_at, archived_at, sort_order
        FROM projects
        \(condition)
        ORDER BY sort_order ASC, created_at ASC;
        """
        return try store.query(sql: sql) { stmt in
            Project(
                id: SQLiteStore.uuid(at: 0, statement: stmt) ?? UUID(),
                name: SQLiteStore.text(at: 1, statement: stmt) ?? "",
                description: SQLiteStore.text(at: 2, statement: stmt),
                colorToken: SQLiteStore.text(at: 3, statement: stmt) ?? "indigo",
                createdAt: SQLiteStore.date(at: 4, statement: stmt) ?? Date(),
                updatedAt: SQLiteStore.date(at: 5, statement: stmt) ?? Date(),
                archivedAt: SQLiteStore.date(at: 6, statement: stmt),
                sortOrder: SQLiteStore.double(at: 7, statement: stmt) ?? 0.0
            )
        }
    }

    public func insertProject(_ project: Project) throws {
        let sql = """
        INSERT INTO projects (
            id, name, description, color_token, created_at, updated_at, archived_at, sort_order
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        let bindings: [Any?] = [
            project.id,
            project.name,
            project.description,
            project.colorToken,
            project.createdAt,
            project.updatedAt,
            project.archivedAt,
            project.sortOrder
        ]
        try store.executeUpdate(sql: sql, bindings: bindings)
    }

    public func updateProject(_ project: Project) throws {
        let sql = """
        UPDATE projects SET
            name = ?, description = ?, color_token = ?, updated_at = ?,
            archived_at = ?, sort_order = ?
        WHERE id = ?;
        """
        let bindings: [Any?] = [
            project.name,
            project.description,
            project.colorToken,
            Date(),
            project.archivedAt,
            project.sortOrder,
            project.id
        ]
        try store.executeUpdate(sql: sql, bindings: bindings)
    }

    public func archiveProject(id: UUID) throws {
        let sql = "UPDATE projects SET archived_at = ?, updated_at = ? WHERE id = ?;"
        try store.executeUpdate(sql: sql, bindings: [Date(), Date(), id])
    }

    public func unarchiveProject(id: UUID) throws {
        let sql = "UPDATE projects SET archived_at = NULL, updated_at = ? WHERE id = ?;"
        try store.executeUpdate(sql: sql, bindings: [Date(), id])
    }

    public func deleteProject(id: UUID) throws {
        // According to SAS: Project deletion reassigns tasks to nil (via foreign key ON DELETE SET NULL), does not silently delete them!
        try store.executeUpdate(sql: "DELETE FROM projects WHERE id = ?;", bindings: [id])
    }

    // Sections
    public func fetchSections(projectId: UUID) throws -> [ProjectSection] {
        let sql = """
        SELECT id, project_id, name, sort_order
        FROM sections
        WHERE project_id = ?
        ORDER BY sort_order ASC;
        """
        return try store.query(sql: sql, bindings: [projectId]) { stmt in
            ProjectSection(
                id: SQLiteStore.uuid(at: 0, statement: stmt) ?? UUID(),
                projectId: SQLiteStore.uuid(at: 1, statement: stmt) ?? projectId,
                name: SQLiteStore.text(at: 2, statement: stmt) ?? "",
                sortOrder: SQLiteStore.double(at: 3, statement: stmt) ?? 0.0
            )
        }
    }

    public func insertSection(_ section: ProjectSection) throws {
        let sql = "INSERT INTO sections (id, project_id, name, sort_order) VALUES (?, ?, ?, ?);"
        try store.executeUpdate(sql: sql, bindings: [section.id, section.projectId, section.name, section.sortOrder])
    }

    public func deleteSection(id: UUID) throws {
        try store.executeUpdate(sql: "DELETE FROM sections WHERE id = ?;", bindings: [id])
    }
}
