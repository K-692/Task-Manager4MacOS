import SwiftUI
import TaskManagerCore

/// Projects view: projects management, color coding, progress tracking, and tasks.
public struct ProjectsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedProjectId: UUID? = nil
    @State private var isAddProjectPresented: Bool = false
    @State private var newProjectName: String = ""
    @State private var newProjectDesc: String = ""
    @State private var newProjectColor: String = "indigo"

    public init() {}

    public var body: some View {
        let activeProjects = env.projects.filter { !$0.isArchived }

        HStack(spacing: 0) {
            // Project Sidebar
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack {
                    Text("Projects")
                        .font(.title2.bold())
                    Spacer()
                    Button(action: { isAddProjectPresented = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Create new project")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                List(activeProjects, selection: $selectedProjectId) { project in
                    let projTasks = env.tasks.filter { $0.projectId == project.id && !$0.isCompleted }
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.projectColor(for: project.colorToken))
                            .frame(width: 8, height: 8)
                        Text(project.name)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        if !projTasks.isEmpty {
                            Text("\(projTasks.count)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(project.id)
                }
                .listStyle(.sidebar)
            }
            .frame(width: 220)

            Divider()

            // Project Detail
            Group {
                if let projId = selectedProjectId ?? activeProjects.first?.id,
                   let project = env.projects.first(where: { $0.id == projId }) {
                    projectDetailView(project)
                } else {
                    EmptyStateView(
                        icon: "folder",
                        title: "No Project Selected",
                        message: "Select a project from the sidebar or create a new one to organize your work.",
                        actionTitle: "New Project",
                        action: { isAddProjectPresented = true }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $isAddProjectPresented) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("New Project")
                    .font(.headline)

                TextField("Project name", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)

                TextField("Description (optional)", text: $newProjectDesc)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Color:")
                        .font(.subheadline)
                    ForEach(["indigo", "blue", "emerald", "amber", "rose", "purple", "teal"], id: \.self) { color in
                        Circle()
                            .fill(Color.projectColor(for: color))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: newProjectColor == color ? 2 : 0)
                            )
                            .onTapGesture {
                                newProjectColor = color
                            }
                    }
                }

                HStack {
                    Spacer()
                    Button("Cancel") {
                        isAddProjectPresented = false
                    }
                    Button("Create") {
                        env.addProject(name: newProjectName, description: newProjectDesc.isEmpty ? nil : newProjectDesc, colorToken: newProjectColor)
                        newProjectName = ""
                        newProjectDesc = ""
                        isAddProjectPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.primaryAccent)
                    .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 8)
            }
            .padding()
            .frame(width: 360)
        }
    }

    private func projectDetailView(_ project: Project) -> some View {
        let tasks = env.tasks.filter { $0.projectId == project.id }
        let openTasks = tasks.filter { !$0.isCompleted }
        let completedTasks = tasks.filter { $0.isCompleted }
        let progress = tasks.isEmpty ? 0.0 : Double(completedTasks.count) / Double(tasks.count)

        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Project Header Card
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color.projectColor(for: project.colorToken))
                                .frame(width: 12, height: 12)
                            Text(project.name)
                                .font(.title2.bold())
                            Spacer()
                            Text("\(completedTasks.count)/\(tasks.count) completed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if let desc = project.description, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.08))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.projectColor(for: project.colorToken))
                                    .frame(width: geo.size.width * CGFloat(progress))
                            }
                        }
                        .frame(height: 6)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Tasks
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tasks (\(openTasks.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    if openTasks.isEmpty {
                        CardView {
                            EmptyStateView(
                                icon: "checkmark.circle",
                                title: "All Caught Up",
                                message: "No active tasks in this project."
                            )
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    } else {
                        CardView {
                            VStack(spacing: 2) {
                                ForEach(openTasks) { task in
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
