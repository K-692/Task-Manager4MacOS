import SwiftUI
import TaskManagerCore

/// Compact menu-bar surface for quick capture, today summary, and app lifecycle control.
public struct MenuBarContentView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var quickTitle: String = ""

    public init() {}

    public var body: some View {
        let todayTasks = env.tasks.filter { $0.isToday && !$0.isCompleted }
        let cpu = env.samplingCoordinator.latestCPU?.value
        let mem = env.samplingCoordinator.latestMemory?.value
        let battery = env.samplingCoordinator.latestBattery?.value

        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Task Manager")
                    .font(.headline)
                Spacer()
                Text("\(todayTasks.count) due today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Quick capture
            HStack {
                TextField("Quick capture... (Return)", text: $quickTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        submitQuick()
                    }
                Button("Add") {
                    submitQuick()
                }
                .disabled(quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            // Today tasks list (top 3)
            if todayTasks.isEmpty {
                Text("No outstanding tasks for today.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(todayTasks.prefix(3)) { task in
                    HStack {
                        Button(action: { env.toggleTaskCompletion(task) }) {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text(task.title)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }

            Divider()

            // Compact System Status
            HStack(spacing: 12) {
                Label("\(String(format: "%.0f%%", cpu?.totalUsagePercent ?? 0)) CPU", systemImage: "cpu")
                    .font(.caption2)
                    .foregroundColor(.indigo)

                Label("\(mem?.formattedUsed ?? "0 GB") RAM", systemImage: "memorychip")
                    .font(.caption2)
                    .foregroundColor(.blue)

                if let bat = battery {
                    Label("\(bat.chargePercent)%", systemImage: "battery.100")
                        .font(.caption2)
                        .foregroundColor(bat.chargePercent > 20 ? .emerald : .rose)
                }
            }

            Divider()

            // Actions
            HStack {
                Button("Open Task Manager") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.rose)
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    private func submitQuick() {
        let title = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        env.addTask(title: title, dueAt: Date())
        quickTitle = ""
    }
}
