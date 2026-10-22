import SwiftUI
import TaskManagerCore

/// Settings view: compact, technical, non-scrollable configuration panel
/// fitting perfectly within the standard window viewport.
public struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var updateSpeed: Double = 1.0

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header (clean, compact clearance)
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(size: 18, weight: .bold))
                Text("Runtime preferences, macOS menu bar widget customization, and telemetry cadence.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            // 1. macOS Menu Bar Widget & Background
            CardView(padding: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("macOS Menu Bar Widget & Background")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Text("Single Active Icon")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.emerald.opacity(0.12))
                            .foregroundColor(.emerald)
                            .clipShape(Capsule())
                    }

                    // Single-Selection Radio Chips (CPU / GPU / Memory / Disk / Network)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Select the hardware component displayed on the macOS top menu bar (single selection):")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            menuBarRadioChip(
                                metric: .cpu,
                                color: .indigo,
                                currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestCPU?.value?.totalUsagePercent ?? 0)
                            )

                            menuBarRadioChip(
                                metric: .gpu,
                                color: .purple,
                                currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestGPU?.value?.utilizationPercent ?? 0)
                            )

                            menuBarRadioChip(
                                metric: .memory,
                                color: .blue,
                                currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestMemory?.value?.usagePercentage ?? 0)
                            )

                            menuBarRadioChip(
                                metric: .disk,
                                color: .emerald,
                                currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestStorage?.value?.first?.usagePercentage ?? 0)
                            )

                            menuBarRadioChip(
                                metric: .network,
                                color: .cyan,
                                currentVal: formatCompactRate((env.samplingCoordinator.latestNetwork?.value?.totalBytesInPerSecond ?? 0) + (env.samplingCoordinator.latestNetwork?.value?.totalBytesOutPerSecond ?? 0))
                            )
                        }

                        // Live Menu Bar Preview Ribbon
                        HStack(spacing: 6) {
                            Text("Menu Bar Preview:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Image(systemName: env.selectedMenuBarMetric.icon)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(colorForMetric(env.selectedMenuBarMetric))
                                Text(valueForMetric(env.selectedMenuBarMetric))
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                            Spacer()

                            Button("Reset to CPU") {
                                env.selectedMenuBarMetric = .cpu
                            }
                            .font(.system(size: 9))
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 1)
                    }

                    Divider()

                    // Behavior Toggles (Tight)
                    VStack(spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Keep in Menu Bar")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Closing the main window leaves live metrics active in the macOS menu bar.")
                                    .font(.system(size: 9))
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
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Launch at Login (SMAppService)")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Start Task Manager automatically on macOS boot without background daemons.")
                                    .font(.system(size: 9))
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

            // 2. Telemetry & Sample Rate
            CardView(padding: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Telemetry & Sample Rate")
                                .font(.system(size: 12, weight: .bold))
                            Text("Real-time refresh rate for CPU, GPU, Memory, Disk, and Network hardware monitors.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        // Custom unclipped segmented pill selector
                        HStack(spacing: 2) {
                            cadenceButton(label: "0.5s", tag: "Fast", interval: 0.5)
                            cadenceButton(label: "1.0s", tag: "Normal", interval: 1.0)
                            cadenceButton(label: "3.0s", tag: "Eco", interval: 3.0)
                            cadenceButton(label: "Pause", tag: "0.0s", interval: 0.0)
                        }
                        .padding(2)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Divider()

                    HStack(spacing: 6) {
                        Image(systemName: "memorychip")
                            .foregroundColor(.indigo)
                            .font(.system(size: 10))
                        Text("Telemetry is retained strictly in volatile 60-sample in-memory ring buffers with zero disk writes.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Active: \(formattedInterval(updateSpeed))")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 18)

            // 3. Visual Theme
            CardView(padding: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Visual Theme")
                            .font(.system(size: 12, weight: .bold))
                        Text("Choose between dark mode, light mode, or matching macOS system appearance.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        themeButton(label: "System", icon: "circle.lefthalf.filled", mode: "system")
                        themeButton(label: "Light", icon: "sun.max.fill", mode: "light")
                        themeButton(label: "Dark", icon: "moon.fill", mode: "dark")
                    }
                    .padding(2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 18)

            // 4. About & Technical Hardware Specs (Compact 2-Column Grid)
            CardView(padding: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        appLogoImage
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Task Manager for macOS")
                                .font(.system(size: 13, weight: .bold))
                            Text("Version 1.0 (Build 1) • Native Swift & Metal Engine • MIT License")
                                .font(.system(size: 9))
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

                    // Aligned Technical Specifications (2-Column Grid: 3 rows)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 4) {
                        specItem(label: "Device Model", value: env.deviceProfile.marketingName)
                        specItem(label: "Architecture", value: "\(env.deviceProfile.architecture) (Unified)")
                        specItem(label: "Processor", value: "\(env.deviceProfile.cpuName) (\(env.deviceProfile.physicalCores)C)")
                        specItem(label: "Installed RAM", value: env.deviceProfile.formattedMemory)
                        specItem(label: "Graphics (GPU)", value: env.deviceProfile.gpuNames.first ?? "Apple Silicon GPU (Metal 3)")
                        specItem(label: "Operating System", value: "macOS \(env.deviceProfile.osVersion) (\(env.deviceProfile.osBuild))")
                    }
                }
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            updateSpeed = env.samplingCoordinator.samplingInterval
        }
    }

    // MARK: - Menu Bar Radio Chip
    private func menuBarRadioChip(
        metric: MenuBarMetric,
        color: Color,
        currentVal: String
    ) -> some View {
        let isSelected = env.selectedMenuBarMetric == metric
        return Button(action: {
            env.selectedMenuBarMetric = metric
        }) {
            HStack(spacing: 5) {
                Image(systemName: metric.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? color : .secondary)

                VStack(alignment: .leading, spacing: 0) {
                    Text(metric.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    Text(currentVal)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(isSelected ? color : .secondary.opacity(0.8))
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "record.circle.fill" : "circle")
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? color : .secondary.opacity(0.35))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(isSelected ? color.opacity(0.12) : Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cadence Button
    private func cadenceButton(label: String, tag: String, interval: Double) -> some View {
        let isSelected = abs(updateSpeed - interval) < 0.05
        return Button(action: {
            updateSpeed = interval
            env.samplingCoordinator.samplingInterval = interval
        }) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                Text(tag)
                    .font(.system(size: 8))
                    .foregroundColor(isSelected ? .indigo : .secondary.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.primary.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Theme Button
    private func themeButton(label: String, icon: String, mode: String) -> some View {
        let isSelected = env.appearanceMode == mode
        return Button(action: {
            env.appearanceMode = mode
            try? env.settingsRepo.set(key: "appearance", value: mode)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .indigo : .secondary)
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isSelected ? Color.primary.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private func specItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func colorForMetric(_ metric: MenuBarMetric) -> Color {
        switch metric {
        case .cpu: return .indigo
        case .gpu: return .purple
        case .memory: return .blue
        case .disk: return .emerald
        case .network: return .cyan
        }
    }

    private func valueForMetric(_ metric: MenuBarMetric) -> String {
        switch metric {
        case .cpu:
            return "\(Int(env.samplingCoordinator.latestCPU?.value?.totalUsagePercent ?? 0))%"
        case .gpu:
            return "\(Int(env.samplingCoordinator.latestGPU?.value?.utilizationPercent ?? 0))%"
        case .memory:
            return "\(Int(env.samplingCoordinator.latestMemory?.value?.usagePercentage ?? 0))%"
        case .disk:
            return "\(Int(env.samplingCoordinator.latestStorage?.value?.first?.usagePercentage ?? 0))%"
        case .network:
            let rate = (env.samplingCoordinator.latestNetwork?.value?.totalBytesInPerSecond ?? 0) + (env.samplingCoordinator.latestNetwork?.value?.totalBytesOutPerSecond ?? 0)
            return formatCompactRate(rate)
        }
    }

    private func formattedInterval(_ interval: Double) -> String {
        if interval <= 0.05 {
            return "Paused"
        } else {
            return String(format: "%.1fs", interval)
        }
    }

    private func formatCompactRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1fM/s", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0fK/s", bytesPerSec / 1024)
        } else {
            return "0K/s"
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
