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
    @Environment(\.layoutClass) private var layoutClass
    @Environment(\.contentSize) private var contentSize

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

        let width = contentSize.width
        let showPID = width >= 520
        let showStatus = width >= 660
        let showArch = width >= 780
        let pad = layoutClass.pagePadding

        VStack(spacing: 0) {
            // Header Bar
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    processTitle(allProcesses)
                    Spacer(minLength: 12)
                    actionButtons
                }
                VStack(alignment: .leading, spacing: 10) {
                    processTitle(allProcesses)
                    actionButtons
                }
            }
            .padding(.horizontal, pad)
            .padding(.top, layoutClass == .compact ? 14 : 20)
            .padding(.bottom, AppTheme.Spacing.sm)

            // Search & Sort Bar
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    searchField.frame(minWidth: 220)
                    sortPicker
                }
                VStack(alignment: .leading, spacing: 8) {
                    searchField
                    sortPicker
                }
            }
            .padding(.horizontal, pad)
            .padding(.bottom, AppTheme.Spacing.sm)

            Divider()

            // Process Table Header
            HStack(spacing: 8) {
                headerButton("Process Name", key: "name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showPID {
                    headerButton("PID", key: "pid").frame(width: 60, alignment: .trailing)
                }
                headerButton("CPU", key: "cpu").frame(width: 64, alignment: .trailing)
                headerButton("Memory", key: "memory").frame(width: 84, alignment: .trailing)
                if showArch {
                    Text("Architecture").font(.caption.bold()).themedSecondary().frame(width: 104, alignment: .center)
                }
                if showStatus {
                    Text("Status").font(.caption.bold()).themedSecondary().frame(width: 84, alignment: .trailing)
                }
            }
            .padding(.horizontal, pad + 4)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.025))

            Divider()

            if filtered.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Matching Processes",
                    message: filterQuery.isEmpty ? "Collecting process list…" : "No process matches “\(filterQuery)”."
                )
            } else {
                // Process Rows List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { proc in
                            let isSelected = proc.pid == selectedPID
                            HStack(spacing: 8) {
                                // Process Name & Icon
                                HStack(spacing: 8) {
                                    Image(systemName: proc.isActive ? "app.fill" : "app")
                                        .foregroundColor(proc.isActive ? .emerald : .indigo)
                                        .font(.system(size: 13))

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(proc.name)
                                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        if let bundle = proc.bundleIdentifier {
                                            Text(bundle)
                                                .font(.system(size: 10))
                                                .themedSecondary()
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if showPID {
                                    Text("\(proc.pid)")
                                        .font(.caption.monospaced())
                                        .themedSecondary()
                                        .frame(width: 60, alignment: .trailing)
                                }

                                Text(proc.formattedCPU)
                                    .font(.caption.monospaced())
                                    .bold()
                                    .foregroundColor(proc.cpuPercent > 10.0 ? .amber : .primary)
                                    .lineLimit(1)
                                    .frame(width: 64, alignment: .trailing)

                                Text(proc.formattedMemory)
                                    .font(.caption.monospaced())
                                    .themedSecondary()
                                    .lineLimit(1)
                                    .frame(width: 84, alignment: .trailing)

                                if showArch {
                                    Text(proc.architecture)
                                        .font(.system(size: 10, weight: .medium))
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(proc.architecture.contains("Apple") ? Color.purple.opacity(0.12) : Color.blue.opacity(0.12))
                                        .foregroundColor(proc.architecture.contains("Apple") ? .purple : .blue)
                                        .clipShape(Capsule())
                                        .frame(width: 104, alignment: .center)
                                }

                                if showStatus {
                                    Text(proc.isActive ? "Frontmost" : (proc.isHidden ? "Hidden" : "Background"))
                                        .font(.caption)
                                        .foregroundColor(proc.isActive ? .emerald : .secondary)
                                        .lineLimit(1)
                                        .frame(width: 84, alignment: .trailing)
                                }
                            }
                            .padding(.horizontal, pad + 4)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                                    .padding(.horizontal, pad - 6)
                            )
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
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .alert("Unable to End Task", isPresented: Binding(
            get: { terminationErrorMessage != nil },
            set: { if !$0 { terminationErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(terminationErrorMessage ?? "")
        }
    }

    private func processTitle(_ all: [ProcessItem]) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemName: "square.stack.3d.up.fill", tint: .indigo, size: layoutClass == .compact ? 34 : 40)
            VStack(alignment: .leading, spacing: 3) {
                Text("Processes")
                    .font(.system(size: layoutClass == .compact ? 18 : 22, weight: .bold, design: .rounded))
                Text("\(all.count) running • \(all.filter { $0.isActive }.count) frontmost")
                    .font(.system(size: 12))
                    .themedSecondary()
                    .lineLimit(1)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
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
            .help("Refresh now")
        }
        .fixedSize()
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .themedSecondary()
            TextField("Filter by name, bundle ID, or PID…", text: $filterQuery)
                .textFieldStyle(.plain)

            if !filterQuery.isEmpty {
                Button(action: { filterQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .themedSecondary()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var sortPicker: some View {
        Picker("Sort by", selection: $sortKey) {
            Text("CPU Usage").tag("cpu")
            Text("Memory").tag("memory")
            Text("Name").tag("name")
            Text("PID").tag("pid")
        }
        .pickerStyle(.menu)
        .fixedSize()
    }

    private func headerButton(_ title: String, key: String) -> some View {
        Button(action: { sortKey = key }) {
            HStack(spacing: 3) {
                Text(title)
                if sortKey == key {
                    Image(systemName: key == "name" || key == "pid" ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .font(.caption.bold())
            .foregroundColor(sortKey == key ? .primary : .secondary)
            .lineLimit(1)
        }
        .buttonStyle(.plain)
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
