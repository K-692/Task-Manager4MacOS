import Foundation

/// Core domain entity representing a Task.
public struct TaskItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var notes: String?
    public var status: TaskStatus
    public var priority: TaskPriority
    public let createdAt: Date
    public var updatedAt: Date
    public var startAt: Date?
    public var dueAt: Date?
    public var completedAt: Date?
    public var projectId: UUID?
    public var sectionId: UUID?
    public var sortOrder: Double
    public var estimateMinutes: Int?
    public var recurrenceRule: String?
    public var parentTaskId: UUID?
    public var deletedAt: Date?
    public var tags: [Tag]

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        status: TaskStatus = .todo,
        priority: TaskPriority = .normal,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        startAt: Date? = nil,
        dueAt: Date? = nil,
        completedAt: Date? = nil,
        projectId: UUID? = nil,
        sectionId: UUID? = nil,
        sortOrder: Double = 0.0,
        estimateMinutes: Int? = nil,
        recurrenceRule: String? = nil,
        parentTaskId: UUID? = nil,
        deletedAt: Date? = nil,
        tags: [Tag] = []
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startAt = startAt
        self.dueAt = dueAt
        self.completedAt = completedAt
        self.projectId = projectId
        self.sectionId = sectionId
        self.sortOrder = sortOrder
        self.estimateMinutes = estimateMinutes
        self.recurrenceRule = recurrenceRule
        self.parentTaskId = parentTaskId
        self.deletedAt = deletedAt
        self.tags = tags
    }

    public var isCompleted: Bool {
        status == .completed
    }

    public var isOverdue: Bool {
        guard let due = dueAt, !isCompleted else { return false }
        return due < Date()
    }

    public var isToday: Bool {
        guard let due = dueAt else { return false }
        return Calendar.current.isDateInToday(due)
    }

    public var isUpcoming: Bool {
        guard let due = dueAt, !isCompleted else { return false }
        return due > Date()
    }
}

/// Filter criteria for querying and smart listing tasks.
public struct TaskFilter: Sendable {
    public var statuses: Set<TaskStatus>?
    public var priorities: Set<TaskPriority>?
    public var projectId: UUID?
    public var tagId: UUID?
    public var isDueToday: Bool?
    public var isOverdue: Bool?
    public var isUpcoming: Bool?
    public var searchQuery: String?
    public var includeDeleted: Bool

    public init(
        statuses: Set<TaskStatus>? = nil,
        priorities: Set<TaskPriority>? = nil,
        projectId: UUID? = nil,
        tagId: UUID? = nil,
        isDueToday: Bool? = nil,
        isOverdue: Bool? = nil,
        isUpcoming: Bool? = nil,
        searchQuery: String? = nil,
        includeDeleted: Bool = false
    ) {
        self.statuses = statuses
        self.priorities = priorities
        self.projectId = projectId
        self.tagId = tagId
        self.isDueToday = isDueToday
        self.isOverdue = isOverdue
        self.isUpcoming = isUpcoming
        self.searchQuery = searchQuery
        self.includeDeleted = includeDeleted
    }

    public static let today = TaskFilter(
        statuses: [.todo, .inProgress, .inbox],
        isDueToday: true,
        includeDeleted: false
    )

    public static let inbox = TaskFilter(
        statuses: [.inbox],
        includeDeleted: false
    )

    public static let upcoming = TaskFilter(
        statuses: [.todo, .inProgress],
        isUpcoming: true,
        includeDeleted: false
    )

    public static let all = TaskFilter(
        statuses: [.inbox, .todo, .inProgress],
        includeDeleted: false
    )

    public static let completed = TaskFilter(
        statuses: [.completed],
        includeDeleted: false
    )
}
