import SwiftUI
import TaskManagerCore

/// Settings view: user preferences, appearance, notifications, backup, and privacy.
public struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedTab: String = "general"
    @State private var notificationStatus: String = "Checking..."
    @State private var exportMessage: String? = nil
    @State private var isResetConfirmationPresented: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 26, weight: .bold))
                    Text("Configure Task Manager, customize appearance, manage backups and privacy.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Tab Switcher
                HStack(spacing: 8) {
                    tabButton(id: "general", label: "General", icon: "gearshape")
                    tabButton(id: "appearance", label: "Appearance", icon: "paintpalette")
                    tabButton(id: "notifications", label: "Notifications", icon: "bell")
                    tabButton(id: "privacy", label: "Data & Privacy", icon: "lock.shield")
                    tabButton(id: "about", label: "About", icon: "info.circle")
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Tab Content
                Group {
                    switch selectedTab {
                    case "general":
                        generalSettings()
                    case "appearance":
                        appearanceSettings()
                    case "notifications":
                        notificationSettings()
                    case "privacy":
                        privacySettings()
                    case "about":
                        aboutSettings()
                    default:
                        generalSettings()
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .onAppear {
            checkNotifications()
        }
    }

    private func tabButton(id: String, label: String, icon: String) -> some View {
        let isSel = selectedTab == id
        return Button(action: { selectedTab = id }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(label)
                    .font(.system(size: 12, weight: isSel ? .semibold : .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSel ? AppTheme.Colors.primaryAccent.opacity(0.15) : Color.primary.opacity(0.04))
            .foregroundColor(isSel ? AppTheme.Colors.primaryAccent : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func generalSettings() -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Application Behavior").font(.headline)

                Toggle(isOn: $env.keepInMenuBar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep in Menu Bar")
                            .font(.system(size: 13, weight: .medium))
                        Text("Closing the main window leaves quick capture available in the menu bar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: env.keepInMenuBar) { val in
                    try? env.settingsRepo.setBool(key: "keep_in_menu_bar", value: val)
                }

                Divider()

                Toggle(isOn: $env.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login (Opt-in)")
                            .font(.system(size: 13, weight: .medium))
                        Text("Starts quietly in the menu bar when your Mac turns on via SMAppService.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: env.launchAtLogin) { val in
                    try? env.loginItemService.setLaunchAtLogin(enabled: val)
                }
            }
        }
    }

    private func appearanceSettings() -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Theme & Visual Style").font(.headline)

                Picker("Appearance Mode", selection: $env.appearanceMode) {
                    Text("Match System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                .onChange(of: env.appearanceMode) { val in
                    try? env.settingsRepo.set(key: "appearance", value: val)
                }

                Text("Task Manager honors macOS system materials, accent colors, and typography.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func notificationSettings() -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Notifications & Reminders").font(.headline)

                HStack {
                    Text("Current Permission Status:")
                        .font(.system(size: 13))
                    Spacer()
                    Text(notificationStatus)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }

                Button("Request Notification Authorization") {
                    Task {
                        _ = try? await env.notificationService.requestAuthorization()
                        checkNotifications()
                    }
                }
                .buttonStyle(.bordered)

                Text("Reminders are delivered strictly on-device through Apple UserNotifications without any remote push servers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func privacySettings() -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Backup & Export").font(.headline)

                    HStack(spacing: 12) {
                        Button("Export All (JSON)") {
                            if let data = try? env.importExportService.exportJSON() {
                                saveFile(data: data, defaultName: "TaskManager_Backup.json")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.primaryAccent)

                        Button("Export Tasks (CSV)") {
                            if let csv = try? env.importExportService.exportCSV(), let data = csv.data(using: .utf8) {
                                saveFile(data: data, defaultName: "Tasks.csv")
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    if let msg = exportMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.emerald)
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Data Storage & Reset").font(.headline)

                    Text("All task data and telemetry rollups are stored locally in an embedded SQLite database. No analytics or metrics are uploaded.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Button("Clear Metric History") {
                        try? env.rollupRepo.clearAll()
                        exportMessage = "Metric history cleared."
                    }
                    .buttonStyle(.bordered)

                    Button("Reset All Tasks & Database", role: .destructive) {
                        isResetConfirmationPresented = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.rose)
                }
            }
        }
        .confirmationDialog("Reset Database?", isPresented: $isResetConfirmationPresented, titleVisibility: .visible) {
            Button("Reset Everything", role: .destructive) {
                try? env.store.executeUpdate(sql: "DELETE FROM tasks;")
                try? env.store.executeUpdate(sql: "DELETE FROM projects;")
                try? env.store.executeUpdate(sql: "DELETE FROM tags;")
                env.reloadAll()
                exportMessage = "Database reset successfully."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently erase all your tasks, projects, and tags. This action cannot be undone.")
        }
    }

    private func aboutSettings() -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Task Manager for macOS").font(.headline)
                Text("Version 1.0 (Build 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("A polished, lightweight, privacy-first task manager with an advanced local Mac system-information dashboard and native macOS widgets.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                Text("License: MIT License")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("100% Offline • Local-First SQLite • Zero Cloud Tracking • Apple Silicon & Intel Universal")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
    }

    private func checkNotifications() {
        Task {
            let status = await env.notificationService.checkAuthorizationStatus()
            await MainActor.run {
                switch status {
                case .authorized: notificationStatus = "Authorized"
                case .denied: notificationStatus = "Denied in System Settings"
                case .notDetermined: notificationStatus = "Not Requested"
                case .provisional: notificationStatus = "Provisional"
                default: notificationStatus = "Unknown"
                }
            }
        }
    }

    private func saveFile(data: Data, defaultName: String) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = defaultName
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                try? data.write(to: url)
                exportMessage = "Successfully exported to \(url.lastPathComponent)"
            }
        }
    }
}
