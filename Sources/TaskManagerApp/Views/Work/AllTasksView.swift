import SwiftUI
import TaskManagerCore

/// Master task table with filtering, search, sorting, and bulk actions.
public struct AllTasksView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var searchFilter: String = ""
    @State private var priorityFilter: TaskPriority? = nil
    @State private var projectFilter: UUID? = nil
    @State private var statusFilter: String = "open" // "open", "completed", "all"
    @State private var sortOption: String = "priority" // "priority", "due", "title", "created"

    public init() {}

    public var body: some View {
        let filteredTasks = env.tasks.filter { task in
            if !searchFilter.isEmpty {
                let matchTitle = task.title.localizedCaseInsensitiveContains(searchFilter)
                let matchNotes = task.notes?.localizedCaseInsensitiveContains(searchFilter) ?? false
                if !matchTitle && !matchNotes { return false }
            }
            if let prio = priorityFilter, task.priority != prio {
                return false
            }
            if let projId = projectFilter, task.projectId != projId {
                return false
            }
            if statusFilter == "open" && task.isCompleted {
                return false
            }
            if statusFilter == "completed" && !task.isCompleted {
                return false
            }
            return true
        }.sorted { t1, t2 in
            switch sortOption {
            case "priority":
                if t1.priority != t2.priority { return t1.priority > t2.priority }
                return t1.createdAt > t2.createdAt
            case "due":
                if let d1 = t1.dueAt, let d2 = t2.dueAt { return d1 < d2 }
                if t1.dueAt != nil { return true }
                if t2.dueAt != nil { return false }
                return t1.createdAt > t2.createdAt
            case "title":
                return t1.title.localizedCaseInsensitiveCompare(t2.title) == .orderedAscending
            default:
                return t1.createdAt > t2.createdAt
            }
        }

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("All Tasks")
                        .font(.system(size: 26, weight: .bold))
                    Text("Search, filter, and organize all your work in one place.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Filter & Sort Bar
                CardView {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search tasks...", text: $searchFilter)
                                .textFieldStyle(.plain)
                            if !searchFilter.isEmpty {
                                Button(action: { searchFilter = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()

                        HStack {
                            Picker("Status", selection: $statusFilter) {
                                Text("Open").tag("open")
                                Text("Completed").tag("completed")
                                Text("All").tag("all")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)

                            Picker("Priority", selection: $priorityFilter) {
                                Text("All Priorities").tag(TaskPriority?.none)
                                ForEach(TaskPriority.allCases, id: \.self) { p in
                                    Text(p.displayName).tag(TaskPriority?.some(p))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 120)

                            Picker("Project", selection: $projectFilter) {
                                Text("All Projects").tag(UUID?.none)
                                ForEach(env.projects) { proj in
                                    Text(proj.name).tag(UUID?.some(proj.id))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 130)

                            Spacer()

                            Picker("Sort", selection: $sortOption) {
                                Text("Priority").tag("priority")
                                Text("Due Date").tag("due")
                                Text("Title").tag("title")
                                Text("Created").tag("created")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 110)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Task List
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tasks (\(filteredTasks.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    if filteredTasks.isEmpty {
                        CardView {
                            EmptyStateView(
                                icon: "checklist",
                                title: "No Matching Tasks",
                                message: "Try clearing filters or search terms to see your tasks."
                            )
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    } else {
                        CardView {
                            VStack(spacing: 2) {
                                ForEach(filteredTasks) { task in
                                    TaskRowView(
                                        task: task,
                                        onToggle: { env.toggleTaskCompletion(task) },
                                        onDelete: { env.deleteTask(id: task.id) },
                                        onUpdateTitle: { newTitle in
                                            var up = task
                                            up.title = newTitle
                                            env.updateTask(up)
                                        },
                                        onDeferToTomorrow: {
                                            var up = task
                                            up.dueAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                                            env.updateTask(up)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                }
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }
}
