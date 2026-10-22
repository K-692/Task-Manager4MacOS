import Foundation

/// Represents the status of a task in the Task Manager workflow.
public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case inbox = "inbox"
    case todo = "todo"
    case inProgress = "in_progress"
    case completed = "completed"
    case archived = "archived"

    public var displayName: String {
        switch self {
        case .inbox: return "Inbox"
        case .todo: return "To Do"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }

    public var systemImage: String {
        switch self {
        case .inbox: return "tray"
        case .todo: return "circle"
        case .inProgress: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox"
        }
    }
}

/// Represents the priority level of a task.
public enum TaskPriority: String, Codable, CaseIterable, Comparable, Sendable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"

    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    public var order: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        return lhs.order < rhs.order
    }
}
