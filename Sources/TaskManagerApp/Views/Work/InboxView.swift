import SwiftUI
import TaskManagerCore

/// Inbox view: fast capture and triage area for unsorted work.
public struct InboxView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var newTaskTitle: String = ""
    @State private var newTaskNotes: String = ""
    @State private var selectedPriority: TaskPriority = .normal
    @State private var selectedProjectId: UUID? = nil

    public init() {}

    public var body: some View {
        let inboxTasks = env.tasks.filter { $0.status == .inbox && !$0.isCompleted }

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inbox")
                        .font(.system(size: 26, weight: .bold))
                    Text("Capture ideas, incoming requests, and triage them into projects.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Quick Capture Card
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("What's on your mind? (Press Return)", text: $newTaskTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .medium))
                            .onSubmit {
                                submitTask()
                            }

                        TextField("Optional notes or context", text: $newTaskNotes)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Divider()

                        HStack {
                            Picker("Priority", selection: $selectedPriority) {
                                ForEach(TaskPriority.allCases, id: \.self) { prio in
                                    Text(prio.displayName).tag(prio)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 90)

                            Picker("Project", selection: $selectedProjectId) {
                                Text("No Project").tag(UUID?.none)
                                ForEach(env.projects) { proj in
                                    Text(proj.name).tag(UUID?.some(proj.id))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 130)

                            Spacer()

                            Button("Add to Inbox") {
                                submitTask()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.Colors.primaryAccent)
                            .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Inbox Task List
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unprocessed Items (\(inboxTasks.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    if inboxTasks.isEmpty {
                        CardView {
                            EmptyStateView(
                                icon: "tray",
                                title: "Inbox Zero",
                                message: "All incoming thoughts and tasks have been triaged. Capture a new item anytime!"
                            )
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    } else {
                        CardView {
                            VStack(spacing: 2) {
                                ForEach(inboxTasks) { task in
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
                                            up.status = .todo
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

    private func submitTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        env.addTask(
            title: title,
            notes: newTaskNotes.isEmpty ? nil : newTaskNotes,
            priority: selectedPriority,
            projectId: selectedProjectId
        )
        newTaskTitle = ""
        newTaskNotes = ""
        selectedPriority = .normal
        selectedProjectId = nil
    }
}
