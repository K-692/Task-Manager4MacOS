import SwiftUI
import TaskManagerCore

/// Main application layout with resizable sidebar and content detail area.
public struct MainLayoutView: View {
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        ZStack {
            NavigationSplitView {
                sidebarView
                    .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
            } detail: {
                detailView
                    .frame(minWidth: 650, minHeight: 500)
            }

            // Command Palette Modal Overlay
            if env.isCommandPalettePresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        env.isCommandPalettePresented = false
                    }

                CommandPaletteView(isPresented: $env.isCommandPalettePresented)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.15), value: env.isCommandPalettePresented)
    }

    private var sidebarView: some View {
        List(selection: $env.selectedDestination) {
            // Work Section
            Section("Work") {
                NavigationLink(value: AppDestination.today) {
                    Label {
                        HStack {
                            Text("Today")
                            Spacer()
                            let count = env.tasks.filter { $0.isToday && !$0.isCompleted }.count
                            if count > 0 {
                                countBadge("\(count)", color: .amber)
                            }
                        }
                    } icon: {
                        Image(systemName: "sun.max.fill").foregroundColor(.amber)
                    }
                }

                NavigationLink(value: AppDestination.inbox) {
                    Label {
                        HStack {
                            Text("Inbox")
                            Spacer()
                            let count = env.tasks.filter { $0.status == .inbox && !$0.isCompleted }.count
                            if count > 0 {
                                countBadge("\(count)", color: .blue)
                            }
                        }
                    } icon: {
                        Image(systemName: "tray.fill").foregroundColor(.blue)
                    }
                }

                NavigationLink(value: AppDestination.upcoming) {
                    Label {
                        HStack {
                            Text("Upcoming")
                            Spacer()
                            let count = env.tasks.filter { $0.isUpcoming && !$0.isCompleted }.count
                            if count > 0 {
                                countBadge("\(count)", color: .purple)
                            }
                        }
                    } icon: {
                        Image(systemName: "calendar").foregroundColor(.purple)
                    }
                }

                NavigationLink(value: AppDestination.allTasks) {
                    Label("All Tasks", systemImage: "checklist")
                }

                NavigationLink(value: AppDestination.projects) {
                    Label("Projects", systemImage: "folder.fill").foregroundColor(.indigo)
                }

                NavigationLink(value: AppDestination.tags) {
                    Label("Tags", systemImage: "tag.fill").foregroundColor(.emerald)
                }

                NavigationLink(value: AppDestination.completed) {
                    Label("Completed", systemImage: "checkmark.circle.fill").foregroundColor(.emerald)
                }
            }

            // Insights Section
            Section("Insights") {
                NavigationLink(value: AppDestination.productivity) {
                    Label("Productivity", systemImage: "chart.bar.fill").foregroundColor(.indigo)
                }
            }

            // This Mac Section
            Section("This Mac") {
                NavigationLink(value: AppDestination.macOverview) {
                    Label("Overview", systemImage: "laptopcomputer").foregroundColor(.indigo)
                }

                NavigationLink(value: AppDestination.performance) {
                    Label("Performance", systemImage: "cpu").foregroundColor(.blue)
                }

                NavigationLink(value: AppDestination.storage) {
                    Label("Storage", systemImage: "internaldrive.fill").foregroundColor(.purple)
                }

                NavigationLink(value: AppDestination.battery) {
                    Label("Battery & Power", systemImage: "battery.100").foregroundColor(.emerald)
                }

                NavigationLink(value: AppDestination.network) {
                    Label("Network", systemImage: "network").foregroundColor(.cyan)
                }

                NavigationLink(value: AppDestination.processes) {
                    Label("Processes", systemImage: "square.stack.3d.up.fill").foregroundColor(.slate)
                }

                NavigationLink(value: AppDestination.hardwareCapabilities) {
                    Label("Hardware & Capabilities", systemImage: "slider.horizontal.3").foregroundColor(.amber)
                }

                NavigationLink(value: AppDestination.aboutThisMac) {
                    Label("About This Mac", systemImage: "info.circle").foregroundColor(.secondary)
                }
            }

            // System Section
            Section("System") {
                NavigationLink(value: AppDestination.settings) {
                    Label("Settings", systemImage: "gearshape").foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            // Quick Command Palette trigger button at bottom of sidebar
            Button(action: { env.isCommandPalettePresented = true }) {
                HStack {
                    Image(systemName: "command")
                        .font(.system(size: 11, weight: .bold))
                    Text("Search & Actions (⌘K)")
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch env.selectedDestination {
        case .today:
            TodayView()
        case .inbox:
            InboxView()
        case .upcoming:
            UpcomingView()
        case .allTasks:
            AllTasksView()
        case .projects, .project:
            ProjectsView()
        case .tags, .tag:
            TagsView()
        case .completed:
            CompletedView()
        case .productivity:
            ProductivityView()
        case .macOverview:
            MacOverviewView(sampling: env.samplingCoordinator)
        case .performance:
            PerformanceView(sampling: env.samplingCoordinator)
        case .storage:
            StorageView(sampling: env.samplingCoordinator)
        case .battery:
            BatteryView(sampling: env.samplingCoordinator)
        case .network:
            NetworkView(sampling: env.samplingCoordinator)
        case .processes:
            ProcessesView(sampling: env.samplingCoordinator)
        case .hardwareCapabilities:
            HardwareCapabilitiesView()
        case .aboutThisMac:
            AboutThisMacView()
        case .settings:
            SettingsView()
        }
    }

    private func countBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
