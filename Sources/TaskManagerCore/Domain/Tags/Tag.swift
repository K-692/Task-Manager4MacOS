import Foundation

/// Represents a tag that can be attached to tasks.
public struct Tag: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var colorToken: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        colorToken: String = "blue",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.colorToken = colorToken
        self.createdAt = createdAt
    }
}
