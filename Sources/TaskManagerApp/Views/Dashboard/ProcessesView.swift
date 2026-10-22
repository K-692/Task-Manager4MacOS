import SwiftUI
import TaskManagerCore

/// Processes view: sortable and searchable running application inventory.
public struct ProcessesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator
    @State private var filterQuery: String = ""
    @State private var sortKey: String = "memory" // "memory", "name", "pid"

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let allProcesses = sampling.latestProcesses?.value ?? []
        let filtered = allProcesses.filter { proc in
            if filterQuery.isEmpty { return true }
            return proc.name.localizedCaseInsensitiveContains(filterQuery) ||
                   (proc.bundleIdentifier?.localizedCaseInsensitiveContains(filterQuery) ?? false)
        }.sorted { p1, p2 in
            switch sortKey {
            case "name":
                return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
            case "pid":
                return p1.pid < p2.pid
            default:
                let m1 = p1.residentMemoryBytes ?? 0
                let m2 = p2.residentMemoryBytes ?? 0
                return m1 > m2
            }
        }

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Running Applications")
                            .font(.system(size: 26, weight: .bold))
                        Text("Zero-privilege inventory of user-visible applications and inspectable memory.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        sampling.refreshAll()
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Search & Filter Bar
                CardView {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search applications by name or bundle ID...", text: $filterQuery)
                            .textFieldStyle(.plain)

                        if !filterQuery.isEmpty {
                            Button(action: { filterQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Picker("Sort By", selection: $sortKey) {
                            Text("Memory Footprint").tag("memory")
                            Text("Application Name").tag("name")
                            Text("Process ID (PID)").tag("pid")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Process Table
                CardView {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Application").font(.caption.bold()).frame(width: 220, alignment: .leading)
                            Text("Bundle Identifier").font(.caption.bold()).frame(width: 200, alignment: .leading)
                            Text("PID").font(.caption.bold()).frame(width: 70, alignment: .leading)
                            Text("Memory").font(.caption.bold()).frame(width: 100, alignment: .leading)
                            Spacer()
                            Text("Status").font(.caption.bold()).frame(width: 90, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                        .foregroundColor(.secondary)

                        Divider()

                        ForEach(filtered) { proc in
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "app.fill")
                                        .foregroundColor(proc.isActive ? .emerald : .indigo)
                                    Text(proc.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                }
                                .frame(width: 220, alignment: .leading)

                                Text(proc.bundleIdentifier ?? "—")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 200, alignment: .leading)

                                Text("\(proc.pid)")
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .leading)

                                Text(proc.formattedMemory)
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .leading)

                                Spacer()

                                Text(proc.isActive ? "Frontmost" : (proc.isHidden ? "Hidden" : "Background"))
                                    .font(.caption)
                                    .foregroundColor(proc.isActive ? .emerald : .secondary)
                                    .frame(width: 90, alignment: .trailing)
                            }
                            .padding(.vertical, 6)

                            Divider()
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }
}
