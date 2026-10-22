import SwiftUI
import TaskManagerCore

/// Reusable task row displaying title, priority, due date, tags, project, and actions.
public struct TaskRowView: View {
    public let task: TaskItem
    public let onToggle: () -> Void
    public let onDelete: () -> Void
    public let onUpdateTitle: (String) -> Void
    public let onDeferToTomorrow: () -> Void

    @State private var editedTitle: String = ""
    @State private var isHovered: Bool = false

    public init(
        task: TaskItem,
        onToggle: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onUpdateTitle: @escaping (String) -> Void,
        onDeferToTomorrow: @escaping () -> Void
    ) {
        self.task = task
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onUpdateTitle = onUpdateTitle
        self.onDeferToTomorrow = onDeferToTomorrow
        self._editedTitle = State(initialValue: task.title)
    }

    public var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(task.isCompleted ? .emerald : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Inline Title Field
            VStack(alignment: .leading, spacing: 2) {
                InlineEditField(text: $editedTitle, placeholder: "Task title") {
                    if !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onUpdateTitle(editedTitle)
                    }
                }
                .font(.system(size: 13, weight: task.isCompleted ? .regular : .medium))
                .strikethrough(task.isCompleted, color: .secondary)
                .foregroundColor(task.isCompleted ? .secondary : .primary)

                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Badges
            HStack(spacing: 6) {
                // Due date badge
                if let due = task.dueAt {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(formatDueDate(due))
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(dueDateColor(due).opacity(0.12))
                    .foregroundColor(dueDateColor(due))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                // Priority Badge
                PriorityBadge(priority: task.priority)

                // Tags
                ForEach(task.tags.prefix(2)) { tag in
                    Text(tag.name)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.projectColor(for: tag.colorToken).opacity(0.12))
                        .foregroundColor(Color.projectColor(for: tag.colorToken))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }

            // Quick hover actions
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onDeferToTomorrow) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Defer to tomorrow")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.rose.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete task")
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(task.isCompleted ? "Reopen Task" : "Mark as Completed") {
                onToggle()
            }
            Button("Defer to Tomorrow") {
                onDeferToTomorrow()
            }
            Divider()
            Button("Delete Task", role: .destructive) {
                onDelete()
            }
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Overdue"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        if task.isCompleted { return .slate }
        if task.isOverdue { return .rose }
        if task.isToday { return .amber }
        return .blue
    }
}
