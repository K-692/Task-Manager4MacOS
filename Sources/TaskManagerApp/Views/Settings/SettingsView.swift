import SwiftUI
import TaskManagerCore

/// Settings view: clean, unified single-tab settings panel with aligned technical controls.
public struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var updateSpeed: Double = 1.0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold))
                    Text("Configure Task Manager runtime behavior, appearance, and telemetry rates.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.md)

                // 1. Behavior & Menu Bar
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Application & Background Behavior")
                            .font(.system(size: 14, weight: .semibold))

                        VStack(spacing: 12) {
                            // Row: Keep in Menu Bar
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Keep in Menu Bar")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("Closing the main window leaves live hardware metrics active in the macOS menu bar.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $env.keepInMenuBar)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .onChange(of: env.keepInMenuBar) { val in
                                        try? env.settingsRepo.setBool(key: "keep_in_menu_bar", value: val)
                                    }
                            }

                            Divider()

                            // Row: Launch at Login
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Launch at Login (SMAppService)")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("Start Task Manager automatically when your Mac boots up without background daemons.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $env.launchAtLogin)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .onChange(of: env.launchAtLogin) { val in
                                        try? env.loginItemService.setLaunchAtLogin(enabled: val)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // 2. Telemetry Refresh Rate
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Telemetry & Sampling")
                            .font(.system(size: 14, weight: .semibold))

                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Telemetry Update Frequency")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Sampling rate for CPU, GPU, Memory, and Network rate monitors.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("Update Speed", selection: $updateSpeed) {
                                Text("High (0.5s)").tag(0.5)
                                Text("Normal (1.0s)").tag(1.0)
                                Text("Low (3.0s)").tag(3.0)
                                Text("Paused").tag(0.0)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 300)
                            .onChange(of: updateSpeed) { newVal in
                                env.samplingCoordinator.samplingInterval = newVal
                            }
                        }

                        Divider()

                        HStack(spacing: 8) {
                            Image(systemName: "memorychip")
                                .foregroundColor(.indigo)
                                .font(.system(size: 13))
                            Text("Performance metrics are retained strictly in an ephemeral 60-sample in-memory ring buffer with zero disk writes.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // 3. Theme & Appearance
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Appearance")
                            .font(.system(size: 14, weight: .semibold))

                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Visual Theme Mode")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Choose between dark mode, light mode, or matching macOS system appearance.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("Theme", selection: $env.appearanceMode) {
                                Text("Match System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 280)
                            .onChange(of: env.appearanceMode) { val in
                                try? env.settingsRepo.set(key: "appearance", value: val)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // 4. About & System Specs
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            appLogoImage
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Task Manager for macOS")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Version 1.0 (Build 1) • Native Swift & Metal Engine")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("100% Offline")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.emerald.opacity(0.12))
                                .foregroundColor(.emerald)
                                .clipShape(Capsule())
                        }

                        Divider()

                        // Aligned Technical Specifications Grid
                        VStack(spacing: 8) {
                            specRow(label: "Device Model", value: env.deviceProfile.marketingName)
                            specRow(label: "Processor", value: "\(env.deviceProfile.cpuName) (\(env.deviceProfile.physicalCores) P/E Cores • \(env.deviceProfile.logicalCores) Threads)")
                            specRow(label: "Architecture", value: "\(env.deviceProfile.architecture) (Unified Memory)")
                            specRow(label: "Installed RAM", value: env.deviceProfile.formattedMemory)
                            specRow(label: "Graphics (GPU)", value: env.deviceProfile.gpuNames.first ?? "Apple Silicon GPU")
                            specRow(label: "Operating System", value: "macOS \(env.deviceProfile.osVersion) (\(env.deviceProfile.osBuild))")
                            specRow(label: "Software License", value: "MIT Open Source License")
                        }
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

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer()
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
