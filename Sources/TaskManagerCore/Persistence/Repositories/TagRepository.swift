import Foundation
import SQLite3

/// Repository managing tags.
public final class TagRepository: @unchecked Sendable {
    private let store: SQLiteStore

    public init(store: SQLiteStore) {
        self.store = store
    }

    public func fetchTags() throws -> [Tag] {
        let sql = "SELECT id, name, color_token, created_at FROM tags ORDER BY name ASC;"
        return try store.query(sql: sql) { stmt in
            Tag(
                id: SQLiteStore.uuid(at: 0, statement: stmt) ?? UUID(),
                name: SQLiteStore.text(at: 1, statement: stmt) ?? "",
                colorToken: SQLiteStore.text(at: 2, statement: stmt) ?? "blue",
                createdAt: SQLiteStore.date(at: 3, statement: stmt) ?? Date()
            )
        }
    }

    public func insertTag(_ tag: Tag) throws {
        let sql = "INSERT OR IGNORE INTO tags (id, name, color_token, created_at) VALUES (?, ?, ?, ?);"
        try store.executeUpdate(sql: sql, bindings: [tag.id, tag.name, tag.colorToken, tag.createdAt])
    }

    public func updateTag(_ tag: Tag) throws {
        let sql = "UPDATE tags SET name = ?, color_token = ? WHERE id = ?;"
        try store.executeUpdate(sql: sql, bindings: [tag.name, tag.colorToken, tag.id])
    }

    public func deleteTag(id: UUID) throws {
        try store.executeUpdate(sql: "DELETE FROM tags WHERE id = ?;", bindings: [id])
    }
}
