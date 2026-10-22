import SwiftUI
import TaskManagerCore

/// Processes view: Windows Task Manager style process monitor with CPU, Memory, Architecture, and "End Task" capability.
public struct ProcessesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator
    @State private var filterQuery: String = ""
    @State private var sortKey: String = "memory" // default: "memory", "cpu", "name", "pid"
    @State private var selectedPID: Int32? = nil
    @State private var showTerminationAlert: Bool = false
    @State private var terminationErrorMessage: String? = nil

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let allProcesses = sampling.latestProcesses?.value ?? []
        let filtered = allProcesses.filter { proc in
            if filterQuery.isEmpty { return true }
            return proc.name.localizedCaseInsensitiveContains(filterQuery) ||
                   (proc.bundleIdentifier?.localizedCaseInsensitiveContains(filterQuery) ?? false) ||
                   "\(proc.pid)".contains(filterQuery)
        }.sorted { p1, p2 in
            switch sortKey {
            case "name":
                return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
            case "pid":
                return p1.pid < p2.pid
            case "memory":
                let m1 = p1.residentMemoryBytes ?? 0
                let m2 = p2.residentMemoryBytes ?? 0
                return m1 > m2
            default: // "cpu"
                return p1.cpuPercent > p2.cpuPercent
            }
        }

        VStack(spacing: 0) {
            // Header Bar
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Processes")
                        .font(.system(size: 24, weight: .bold))
                    Text("\(allProcesses.count) processes running • \(allProcesses.filter { $0.isActive }.count) active applications")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // End Task Action Button (Windows Task Manager style)
                Button(action: {
                    if let pid = selectedPID {
                        terminateSelected(pid: pid, force: false)
                    }
                }) {
                    Label("End Task", systemImage: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.rose)
                .disabled(selectedPID == nil)

                Button(action: {
                    sampling.refreshAll()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.sm)

            // Search & Sort Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter by name, bundle ID, or PID...", text: $filterQuery)
                        .textFieldStyle(.plain)

                    if !filterQuery.isEmpty {
                        Button(action: { filterQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Picker("Sort by", selection: $sortKey) {
                    Text("CPU Usage %").tag("cpu")
                    Text("Memory Footprint").tag("memory")
                    Text("Application Name").tag("name")
                    Text("Process ID (PID)").tag("pid")
                }
                .pickerStyle(.menu)
                .frame(width: 170)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.sm)

            Divider()

            // Process Table Header
            HStack {
                Text("Process Name")
                    .font(.caption.bold())
                    .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
                Text("PID")
                    .font(.caption.bold())
                    .frame(width: 65, alignment: .trailing)
                Text("CPU")
                    .font(.caption.bold())
                    .frame(width: 80, alignment: .trailing)
                Text("Memory")
                    .font(.caption.bold())
                    .frame(width: 100, alignment: .trailing)
                Text("Architecture")
                    .font(.caption.bold())
                    .frame(width: 110, alignment: .center)
                Text("Status")
                    .font(.caption.bold())
                    .frame(width: 90, alignment: .trailing)
            }
            .padding(.horizontal, AppTheme.Spacing.md + 8)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Process Rows List
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filtered) { proc in
                        let isSelected = proc.pid == selectedPID
                        HStack {
                            // Process Name & Icon
                            HStack(spacing: 8) {
                                Image(systemName: proc.isActive ? "app.fill" : "app")
                                    .foregroundColor(proc.isActive ? .emerald : .indigo)
                                    .font(.system(size: 13))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(proc.name)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                        .lineLimit(1)
                                    if let bundle = proc.bundleIdentifier {
                                        Text(bundle)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)

                            // PID
                            Text("\(proc.pid)")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .frame(width: 65, alignment: .trailing)

                            // CPU %
                            Text(proc.formattedCPU)
                                .font(.caption.monospaced())
                                .bold()
                                .foregroundColor(proc.cpuPercent > 10.0 ? .amber : .primary)
                                .frame(width: 80, alignment: .trailing)

                            // Memory
                            Text(proc.formattedMemory)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .trailing)

                            // Architecture
                            Text(proc.architecture)
                                .font(.system(size: 11))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(proc.architecture.contains("Apple") ? Color.purple.opacity(0.12) : Color.blue.opacity(0.12))
                                .foregroundColor(proc.architecture.contains("Apple") ? .purple : .blue)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .frame(width: 110, alignment: .center)

                            // Status
                            Text(proc.isActive ? "Frontmost" : (proc.isHidden ? "Hidden" : "Background"))
                                .font(.caption)
                                .foregroundColor(proc.isActive ? .emerald : .secondary)
                                .frame(width: 90, alignment: .trailing)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md + 8)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPID = proc.pid
                        }
                        .contextMenu {
                            Button("End Task") {
                                terminateSelected(pid: proc.pid, force: false)
                            }
                            Button("Force Kill (SIGKILL)") {
                                terminateSelected(pid: proc.pid, force: true)
                            }
                            Divider()
                            Button("Copy PID") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("\(proc.pid)", forType: .string)
                            }
                            Button("Copy Process Name") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(proc.name, forType: .string)
                            }
                        }

                        Divider()
                            .padding(.leading, AppTheme.Spacing.md + 24)
                    }
                }
            }
        }
    }

    private func terminateSelected(pid: Int32, force: Bool) {
        let success = env.terminateProcess(pid: pid, force: force)
        if !success {
            terminationErrorMessage = "Could not terminate process with PID \(pid)."
        } else {
            selectedPID = nil
        }
    }
}
