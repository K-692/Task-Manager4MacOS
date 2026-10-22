import SwiftUI
import TaskManagerCore

/// Tags view: tag filtering and task organization.
public struct TagsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedTag: Tag? = nil
    @State private var isAddTagPresented: Bool = false
    @State private var newTagName: String = ""
    @State private var newTagColor: String = "blue"

    public init() {}

    public var body: some View {
        let activeTag = selectedTag ?? env.tags.first
        let tasksWithTag = env.tasks.filter { task in
            guard let tag = activeTag else { return false }
            return task.tags.contains(where: { $0.id == tag.id }) && !task.isCompleted
        }

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags")
                            .font(.system(size: 26, weight: .bold))
                        Text("Organize and filter tasks across projects with reusable tags.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("New Tag") {
                        isAddTagPresented = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Tag Pills Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(env.tags) { tag in
                            let isSelected = activeTag?.id == tag.id
                            Button(action: { selectedTag = tag }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.projectColor(for: tag.colorToken))
                                        .frame(width: 8, height: 8)
                                    Text(tag.name)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSelected ? Color.projectColor(for: tag.colorToken).opacity(0.2) : Color.primary.opacity(0.05))
                                .foregroundColor(isSelected ? Color.projectColor(for: tag.colorToken) : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }

                // Tagged Tasks List
                VStack(alignment: .leading, spacing: 6) {
                    if let tag = activeTag {
                        Text("Tasks tagged with \"\(tag.name)\" (\(tasksWithTag.count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, AppTheme.Spacing.md)

                        if tasksWithTag.isEmpty {
                            CardView {
                                EmptyStateView(
                                    icon: "tag",
                                    title: "No Tasks with this Tag",
                                    message: "Attach this tag to tasks to see them collected here."
                                )
                            }
                            .padding(.horizontal, AppTheme.Spacing.md)
                        } else {
                            CardView {
                                VStack(spacing: 2) {
                                    ForEach(tasksWithTag) { task in
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
                    } else {
                        CardView {
                            EmptyStateView(
                                icon: "tag",
                                title: "No Tags Created",
                                message: "Create a tag to categorize tasks across multiple projects.",
                                actionTitle: "Create Tag",
                                action: { isAddTagPresented = true }
                            )
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                }
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .sheet(isPresented: $isAddTagPresented) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("New Tag")
                    .font(.headline)

                TextField("Tag name", text: $newTagName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Color:")
                        .font(.subheadline)
                    ForEach(["blue", "emerald", "amber", "rose", "purple", "indigo", "teal"], id: \.self) { color in
                        Circle()
                            .fill(Color.projectColor(for: color))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(Color.primary, lineWidth: newTagColor == color ? 2 : 0)
                            )
                            .onTapGesture {
                                newTagColor = color
                            }
                    }
                }

                HStack {
                    Spacer()
                    Button("Cancel") { isAddTagPresented = false }
                    Button("Create") {
                        env.addTag(name: newTagName, colorToken: newTagColor)
                        newTagName = ""
                        isAddTagPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.primaryAccent)
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 8)
            }
            .padding()
            .frame(width: 320)
        }
    }
}
