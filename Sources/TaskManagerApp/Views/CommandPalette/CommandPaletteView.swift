import SwiftUI
import TaskManagerCore

/// Command palette floating overlay for keyboard-first navigation and process search (Cmd+K).
public struct CommandPaletteView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Binding public var isPresented: Bool
    @State private var query: String = ""
    @FocusState private var isFieldFocused: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        let processes = env.samplingCoordinator.latestProcesses?.value ?? []
        let matchingProcesses = processes.filter {
            !query.isEmpty && (
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false) ||
                "\($0.pid)".contains(query)
            )
        }

        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                TextField("Type a command or search processes (e.g. Safari, GPU, CPU)...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
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
                        // Navigation Shortcuts
                        Text("Navigation")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 8)

                        navRow(title: "Processes", icon: "square.stack.3d.up.fill", destination: .processes)
                        navRow(title: "Performance — CPU", icon: "cpu", destination: .performance(.cpu))
                        navRow(title: "Performance — Memory", icon: "memorychip", destination: .performance(.memory))
                        navRow(title: "Performance — GPU", icon: "display.trianglebadge.exclamationmark", destination: .performance(.gpu))
                        navRow(title: "Performance — Disk", icon: "internaldrive", destination: .performance(.disk))
                        navRow(title: "Performance — Network", icon: "network", destination: .performance(.network))
                        navRow(title: "Startup Apps", icon: "bolt.fill", destination: .startupApps)
                        navRow(title: "Hardware Specifications", icon: "slider.horizontal.3", destination: .hardware)
                        navRow(title: "Settings", icon: "gearshape", destination: .settings)
                    } else {
                        // Process Search Results
                        if matchingProcesses.isEmpty {
                            Text("No processes found matching \"\(query)\".")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(14)
                        } else {
                            Text("Processes (\(matchingProcesses.count))")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.top, 8)

                            ForEach(matchingProcesses.prefix(10)) { proc in
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: "app.fill")
                                            .foregroundColor(.indigo)
                                            .font(.system(size: 13))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(proc.name)
                                                .font(.system(size: 13, weight: .medium))
                                            Text("PID: \(proc.pid) • \(proc.formattedMemory) • \(proc.architecture)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()

                                    Button("End Task") {
                                        _ = env.terminateProcess(pid: proc.pid)
                                        isPresented = false
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .foregroundColor(.rose)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 520)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(AppTheme.Colors.subtleBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        .onAppear {
            isFieldFocused = true
        }
    }

    private func navRow(title: String, icon: String, destination: AppDestination) -> some View {
        Button(action: {
            env.selectedDestination = destination
            if case .performance(let subtab) = destination {
                env.selectedPerformanceSubtab = subtab
            }
            isPresented = false
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.indigo)
                    .frame(width: 22)
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
