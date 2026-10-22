import SwiftUI
import TaskManagerCore

/// Today view: daily prioritized command center.
public struct TodayView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var quickTaskTitle: String = ""
    @State private var quickPriority: TaskPriority = .normal

    public init() {}

    public var body: some View {
        let calendar = Calendar.current
        let todayTasks = env.tasks.filter { $0.isToday && !$0.isCompleted }
        let overdueTasks = env.tasks.filter { $0.isOverdue }
        let completedToday = env.tasks.filter { $0.isCompleted && ($0.completedAt != nil && calendar.isDateInToday($0.completedAt!)) }
        let totalCount = todayTasks.count + overdueTasks.count + completedToday.count

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header with Progress Ring
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.system(size: 26, weight: .bold))
                        Text(currentDateFormatted)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    ProgressRingView(
                        completed: completedToday.count,
                        total: totalCount,
                        size: 58
                    )
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Inline Quick Capture Bar
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppTheme.Colors.primaryAccent)
                        .font(.system(size: 16))

                    TextField("Add a task to Today... (Press Return)", text: $quickTaskTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit {
                            submitQuickTask()
                        }

                    Picker("Priority", selection: $quickPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { prio in
                            Text(prio.displayName).tag(prio)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 90)

                    Button("Add") {
                        submitQuickTask()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.primaryAccent)
                    .disabled(quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                        .fill(AppTheme.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                        .stroke(AppTheme.Colors.subtleBorder, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.Spacing.md)

                // Overdue Section
                if !overdueTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Overdue (\(overdueTasks.count))", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.rose)

                            Spacer()

                            Button("Defer All to Today") {
                                for task in overdueTasks {
                                    var updated = task
                                    updated.dueAt = Date()
                                    env.updateTask(updated)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)

                        CardView {
                            VStack(spacing: 2) {
                                ForEach(overdueTasks) { task in
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

                // Scheduled For Today
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scheduled for Today (\(todayTasks.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    if todayTasks.isEmpty && overdueTasks.isEmpty {
                        CardView {
                            EmptyStateView(
                                icon: "sun.max",
                                title: "Clear for Today",
                                message: "You have no outstanding tasks due today. Enjoy your day or capture a new task above!"
                            )
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    } else {
                        CardView {
                            VStack(spacing: 2) {
                                ForEach(todayTasks) { task in
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

                // Completed Today
                if !completedToday.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Completed Today (\(completedToday.count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, AppTheme.Spacing.md)

                        CardView {
                            VStack(spacing: 2) {
                                ForEach(completedToday) { task in
                                    TaskRowView(
                                        task: task,
                                        onToggle: { env.toggleTaskCompletion(task) },
                                        onDelete: { env.deleteTask(id: task.id) },
                                        onUpdateTitle: { newTitle in
                                            var up = task
                                            up.title = newTitle
                                            env.updateTask(up)
                                        },
                                        onDeferToTomorrow: {}
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

    private func submitQuickTask() {
        let title = quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        env.addTask(title: title, priority: quickPriority, dueAt: Date())
        quickTaskTitle = ""
        quickPriority = .normal
    }

    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }
}
