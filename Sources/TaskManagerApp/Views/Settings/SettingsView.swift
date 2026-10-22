import SwiftUI
import TaskManagerCore

/// Settings view: tight, technical, unified single-tab configuration panel
/// with menu bar widget customization, telemetry rates, and system specs.
public struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var updateSpeed: Double = 1.0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Header (compact clearance inside safe area)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold))
                    Text("Runtime preferences, menu bar widget customization, and telemetry cadences.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                // 1. Menu Bar Widget Customization & Background
                CardView(padding: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("macOS Menu Bar Widget & Background")
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            Text("Real-Time")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.emerald.opacity(0.12))
                                .foregroundColor(.emerald)
                                .clipShape(Capsule())
                        }

                        // Component Selection Toggles (CPU / GPU / Memory / Disk / Network)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Menu Bar Display Components")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 6) {
                                menuBarToggleChip(
                                    title: "CPU",
                                    icon: "cpu",
                                    color: .indigo,
                                    isOn: $env.menuBarShowCPU,
                                    currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestCPU?.value?.totalUsagePercent ?? 0)
                                )

                                menuBarToggleChip(
                                    title: "GPU",
                                    icon: "display.trianglebadge.exclamationmark",
                                    color: .purple,
                                    isOn: $env.menuBarShowGPU,
                                    currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestGPU?.value?.utilizationPercent ?? 0)
                                )

                                menuBarToggleChip(
                                    title: "Memory",
                                    icon: "memorychip",
                                    color: .blue,
                                    isOn: $env.menuBarShowMemory,
                                    currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestMemory?.value?.usagePercentage ?? 0)
                                )

                                menuBarToggleChip(
                                    title: "Disk",
                                    icon: "internaldrive",
                                    color: .emerald,
                                    isOn: $env.menuBarShowDisk,
                                    currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestStorage?.value?.first?.usagePercentage ?? 0)
                                )

                                menuBarToggleChip(
                                    title: "Network",
                                    icon: "network",
                                    color: .cyan,
                                    isOn: $env.menuBarShowNetwork,
                                    currentVal: formatCompactRate((env.samplingCoordinator.latestNetwork?.value?.totalBytesInPerSecond ?? 0) + (env.samplingCoordinator.latestNetwork?.value?.totalBytesOutPerSecond ?? 0))
                                )
                            }

                            // Live Menu Bar Preview Ribbon
                            HStack(spacing: 6) {
                                Text("Live Menu Bar Preview:")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 5) {
                                    let hasAny = env.menuBarShowCPU || env.menuBarShowGPU || env.menuBarShowMemory || env.menuBarShowDisk || env.menuBarShowNetwork

                                    if env.menuBarShowCPU || !hasAny {
                                        previewItem(icon: "cpu", val: "\(Int(env.samplingCoordinator.latestCPU?.value?.totalUsagePercent ?? 0))%", color: .indigo)
                                    }
                                    if env.menuBarShowGPU {
                                        previewItem(icon: "display.trianglebadge.exclamationmark", val: "\(Int(env.samplingCoordinator.latestGPU?.value?.utilizationPercent ?? 0))%", color: .purple)
                                    }
                                    if env.menuBarShowMemory {
                                        previewItem(icon: "memorychip", val: "\(Int(env.samplingCoordinator.latestMemory?.value?.usagePercentage ?? 0))%", color: .blue)
                                    }
                                    if env.menuBarShowDisk {
                                        previewItem(icon: "internaldrive", val: "\(Int(env.samplingCoordinator.latestStorage?.value?.first?.usagePercentage ?? 0))%", color: .emerald)
                                    }
                                    if env.menuBarShowNetwork {
                                        previewItem(icon: "network", val: formatCompactRate((env.samplingCoordinator.latestNetwork?.value?.totalBytesInPerSecond ?? 0) + (env.samplingCoordinator.latestNetwork?.value?.totalBytesOutPerSecond ?? 0)), color: .cyan)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                                Spacer()

                                Button("Reset Default") {
                                    env.menuBarShowCPU = true
                                    env.menuBarShowGPU = true
                                    env.menuBarShowMemory = false
                                    env.menuBarShowDisk = false
                                    env.menuBarShowNetwork = false
                                }
                                .font(.system(size: 9))
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        }

                        Divider()

                        // Behavior Toggles (Tight)
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Keep in Menu Bar")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Closing the main window leaves live metrics active in the macOS menu bar.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $env.keepInMenuBar)
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    .labelsHidden()
                                    .onChange(of: env.keepInMenuBar) { val in
                                        try? env.settingsRepo.setBool(key: "keep_in_menu_bar", value: val)
                                    }
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Launch at Login (SMAppService)")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Start Task Manager automatically on macOS boot without background daemons.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $env.launchAtLogin)
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    .labelsHidden()
                                    .onChange(of: env.launchAtLogin) { val in
                                        try? env.loginItemService.setLaunchAtLogin(enabled: val)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)

                // 2. Telemetry Refresh Rate
                CardView(padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Telemetry & Sampling Engine")
                            .font(.system(size: 13, weight: .bold))

                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Telemetry Update Frequency")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Sampling rate for CPU, GPU, Memory, Disk, and Network rate monitors.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("Update Speed", selection: $updateSpeed) {
                                Text("0.5s (Fast)").tag(0.5)
                                Text("1.0s (Normal)").tag(1.0)
                                Text("3.0s (Eco)").tag(3.0)
                                Text("Pause").tag(0.0)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 300)
                            .onChange(of: updateSpeed) { newVal in
                                env.samplingCoordinator.samplingInterval = newVal
                            }
                        }

                        Divider()

                        HStack(spacing: 6) {
                            Image(systemName: "memorychip")
                                .foregroundColor(.indigo)
                                .font(.system(size: 11))
                            Text("Telemetry is retained strictly in volatile 60-sample in-memory ring buffers with zero disk writes.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 18)

                // 3. Theme & Appearance
                CardView(padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visual Theme")
                            .font(.system(size: 13, weight: .bold))

                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Visual Theme Mode")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Choose between dark mode, light mode, or system appearance.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("Theme", selection: $env.appearanceMode) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 300)
                            .onChange(of: env.appearanceMode) { val in
                                try? env.settingsRepo.set(key: "appearance", value: val)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)

                // 4. About & System Specs (Tightened)
                CardView(padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            appLogoImage
                                .frame(width: 34, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Task Manager for macOS")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Version 1.0 (Build 1) • Native Swift & Metal Engine")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("100% Offline")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.emerald.opacity(0.12))
                                .foregroundColor(.emerald)
                                .clipShape(Capsule())
                        }

                        Divider()

                        // Aligned Technical Specifications Grid (Tight)
                        VStack(spacing: 5) {
                            specRow(label: "Device Model", value: env.deviceProfile.marketingName)
                            specRow(label: "Processor", value: "\(env.deviceProfile.cpuName) (\(env.deviceProfile.physicalCores) Cores • \(env.deviceProfile.logicalCores) Threads)")
                            specRow(label: "Graphics (GPU)", value: env.deviceProfile.gpuNames.first ?? "Apple Silicon GPU (Metal 3)")
                            specRow(label: "Architecture", value: "\(env.deviceProfile.architecture) (Unified Memory)")
                            specRow(label: "Installed RAM", value: env.deviceProfile.formattedMemory)
                            specRow(label: "Operating System", value: "macOS \(env.deviceProfile.osVersion) (\(env.deviceProfile.osBuild))")
                            specRow(label: "Software License", value: "MIT Open Source License")
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            updateSpeed = env.samplingCoordinator.samplingInterval
        }
    }

    private func menuBarToggleChip(
        title: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>,
        currentVal: String
    ) -> some View {
        Button(action: {
            isOn.wrappedValue.toggle()
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isOn.wrappedValue ? color : .secondary)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 10, weight: .bold))
                    Text(currentVal)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 9))
                    .foregroundColor(isOn.wrappedValue ? color : .secondary.opacity(0.4))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(isOn.wrappedValue ? color.opacity(0.12) : Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isOn.wrappedValue ? color.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func previewItem(icon: String, val: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(val)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
        }
    }

    private func formatCompactRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1fM", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0fK", bytesPerSec / 1024)
        } else {
            return "0K"
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
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
