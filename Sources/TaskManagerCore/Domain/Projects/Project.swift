import Foundation

/// Represents a project containing tasks and optional sections.
public struct Project: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var colorToken: String
    public let createdAt: Date
    public var updatedAt: Date
    public var archivedAt: Date?
    public var sortOrder: Double

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        colorToken: String = "indigo",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        archivedAt: Date? = nil,
        sortOrder: Double = 0.0
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = description
        self.colorToken = colorToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.sortOrder = sortOrder
    }

    public var isArchived: Bool {
        archivedAt != nil
    }
}

/// Represents an ordered section within a project.
public struct ProjectSection: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let projectId: UUID
    public var name: String
    public var sortOrder: Double

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        name: String,
        sortOrder: Double = 0.0
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sortOrder = sortOrder
    }
}
