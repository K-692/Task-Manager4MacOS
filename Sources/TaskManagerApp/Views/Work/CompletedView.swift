import SwiftUI
import TaskManagerCore

/// Completed view: history of completed tasks with reopen and batch clearing options.
public struct CompletedView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var isClearConfirmationPresented: Bool = false

    public init() {}

    public var body: some View {
        let completedTasks = env.tasks.filter { $0.isCompleted }

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completed")
                            .font(.system(size: 26, weight: .bold))
                        Text("Review completed achievements and reopen tasks if needed.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !completedTasks.isEmpty {
                        Button("Clear Completed") {
                            isClearConfirmationPresented = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.rose)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Archive (\(completedTasks.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    if completedTasks.isEmpty {
                        CardView {
                            EmptyStateView(
                                icon: "checkmark.seal",
                                title: "No Completed Tasks Yet",
                                message: "Complete tasks to build up your productivity streak and track your progress here."
                            )
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    } else {
                        CardView {
                            VStack(spacing: 2) {
                                ForEach(completedTasks) { task in
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
        .confirmationDialog(
            "Clear Completed Tasks?",
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Completed Tasks", role: .destructive) {
                for task in completedTasks {
                    env.deleteTask(id: task.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all \(completedTasks.count) completed tasks from your database.")
        }
    }
}
