import SwiftUI
import TaskManagerCore

/// Upcoming view: displays scheduled tasks across near-future dates.
public struct UpcomingView: View {
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        let upcomingTasks = env.tasks.filter { $0.isUpcoming && !$0.isCompleted }
        let grouped = Dictionary(grouping: upcomingTasks) { task -> String in
            guard let due = task.dueAt else { return "Later" }
            let cal = Calendar.current
            if cal.isDateInTomorrow(due) {
                return "Tomorrow"
            } else {
                let fmt = DateFormatter()
                fmt.dateFormat = "EEEE, MMM d"
                return fmt.string(from: due)
            }
        }
        let sortedKeys = grouped.keys.sorted { k1, k2 in
            if k1 == "Tomorrow" { return true }
            if k2 == "Tomorrow" { return false }
            return k1 < k2
        }

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upcoming")
                        .font(.system(size: 26, weight: .bold))
                    Text("Stay ahead of upcoming deadlines and schedule your upcoming work.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                if upcomingTasks.isEmpty {
                    CardView {
                        EmptyStateView(
                            icon: "calendar",
                            title: "No Upcoming Tasks",
                            message: "You have no future deadlines scheduled. Plan ahead by adding due dates to your tasks."
                        )
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                } else {
                    ForEach(sortedKeys, id: \.self) { key in
                        let tasks = grouped[key] ?? []
                        VStack(alignment: .leading, spacing: 6) {
                            Text(key)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, AppTheme.Spacing.md)

                            CardView {
                                VStack(spacing: 2) {
                                    ForEach(tasks) { task in
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
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }
}
