import SwiftUI
import TaskManagerCore

/// Command palette floating overlay for keyboard-first navigation and task search (Cmd+K).
public struct CommandPaletteView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Binding public var isPresented: Bool
    @State private var query: String = ""
    @FocusState private var isFieldFocused: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        let matchingTasks = env.tasks.filter {
            !query.isEmpty && $0.title.localizedCaseInsensitiveContains(query)
        }

        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                TextField("Type a command or search tasks...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($isFieldFocused)

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("ESC") {
                    isPresented = false
                }
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(14)

            Divider()

            // Suggestions / Results
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if query.isEmpty {
                        // Quick Navigation Section
                        Text("Navigation")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 8)

                        navRow(title: "Today", icon: "sun.max", destination: .today)
                        navRow(title: "Inbox", icon: "tray", destination: .inbox)
                        navRow(title: "Upcoming", icon: "calendar", destination: .upcoming)
                        navRow(title: "All Tasks", icon: "checklist", destination: .allTasks)
                        navRow(title: "Projects", icon: "folder", destination: .projects)
                        navRow(title: "Productivity Insights", icon: "chart.bar", destination: .productivity)
                        navRow(title: "Mac Overview", icon: "laptopcomputer", destination: .macOverview)
                        navRow(title: "Performance Monitor", icon: "cpu", destination: .performance)
                        navRow(title: "Hardware & Capabilities", icon: "slider.horizontal.3", destination: .hardwareCapabilities)
                        navRow(title: "Settings", icon: "gearshape", destination: .settings)
                    } else {
                        // Task Search Results
                        if matchingTasks.isEmpty {
                            Text("No tasks found matching \"\(query)\". Press Return to create as a new task.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(14)

                            Button(action: {
                                env.addTask(title: query)
                                isPresented = false
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AppTheme.Colors.primaryAccent)
                                    Text("Create Task \"\(query)\"")
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("Tasks")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.top, 8)

                            ForEach(matchingTasks.prefix(8)) { task in
                                Button(action: {
                                    env.selectedDestination = .allTasks
                                    isPresented = false
                                }) {
                                    HStack {
                                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(task.isCompleted ? .emerald : .secondary)
                                        Text(task.title)
                                            .font(.system(size: 13))
                                        Spacer()
                                        PriorityBadge(priority: task.priority)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)
        }
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(AppTheme.Colors.subtleBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            isFieldFocused = true
        }
    }

    private func navRow(title: String, icon: String, destination: AppDestination) -> some View {
        Button(action: {
            env.selectedDestination = destination
            isPresented = false
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.indigo)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                Image(systemName: "return")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
