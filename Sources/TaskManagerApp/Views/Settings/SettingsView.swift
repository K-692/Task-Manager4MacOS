import SwiftUI
import TaskManagerCore

/// Settings view: user preferences, appearance, sampling rate, database storage, and about info.
public struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedTab: String = "general"
    @State private var statusMessage: String? = nil
    @State private var isResetConfirmationPresented: Bool = false
    @State private var updateSpeed: Double = 1.0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 26, weight: .bold))
                    Text("Configure Task Manager, customize telemetry sampling, and view app information.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Tab Switcher
                HStack(spacing: 8) {
                    tabButton(id: "general", label: "General", icon: "gearshape")
                    tabButton(id: "appearance", label: "Appearance", icon: "paintpalette")
                    tabButton(id: "privacy", label: "Storage & History", icon: "internaldrive")
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
            updateSpeed = env.samplingCoordinator.samplingInterval
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
                        Text("Closing the main window leaves live hardware telemetry available in the menu bar.")
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
                        Text("Launch at Login (SMAppService)")
                            .font(.system(size: 13, weight: .medium))
                        Text("Starts Task Manager automatically when your Mac boots.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: env.launchAtLogin) { val in
                    try? env.loginItemService.setLaunchAtLogin(enabled: val)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Telemetry Refresh Rate")
                        .font(.system(size: 13, weight: .medium))
                    Text("Controls how frequently CPU, Memory, GPU, and Network statistics are sampled.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Update Speed", selection: $updateSpeed) {
                        Text("High (0.5s)").tag(0.5)
                        Text("Normal (1.0s)").tag(1.0)
                        Text("Low (3.0s)").tag(3.0)
                        Text("Paused").tag(0.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                    .onChange(of: updateSpeed) { newVal in
                        env.samplingCoordinator.samplingInterval = newVal
                    }
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

    private func privacySettings() -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Data Storage & Metric History").font(.headline)

                    Text("All historical hardware telemetry rollups are stored locally in an embedded SQLite database. No analytics, processes, or metrics are uploaded to external servers.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Button("Clear Metric History") {
                        try? env.rollupRepo.clearAll()
                        statusMessage = "Metric history cleared."
                    }
                    .buttonStyle(.bordered)

                    if let msg = statusMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.emerald)
                    }
                }
            }
        }
    }

    private func aboutSettings() -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    appLogoImage
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Task Manager for macOS")
                            .font(.headline)
                        Text("Version 1.0 (Build 1) • Native Swift & AppKit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("A modern, zero-dependency, Windows Task Manager inspired software and hardware performance monitor for macOS.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Device: \(env.deviceProfile.marketingName)")
                        .font(.caption.monospaced())
                    Text("CPU: \(env.deviceProfile.cpuName) • \(env.deviceProfile.logicalCores) Cores")
                        .font(.caption.monospaced())
                    Text("Architecture: \(env.deviceProfile.architecture) • Memory: \(env.deviceProfile.formattedMemory)")
                        .font(.caption.monospaced())
                    Text("GPU: \(env.deviceProfile.gpuNames.first ?? "Integrated GPU")")
                        .font(.caption.monospaced())
                    Text("OS: macOS \(env.deviceProfile.osVersion) (\(env.deviceProfile.osBuild))")
                        .font(.caption.monospaced())
                }
                .foregroundColor(.secondary)

                Divider()

                Text("License: MIT License • 100% Offline • Zero Remote Telemetry")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
    }

    @ViewBuilder
    private var appLogoImage: some View {
        if let url = Bundle.module.url(forResource: "icon", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "cpu.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.indigo)
        }
    }
}
