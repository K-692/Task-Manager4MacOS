import SwiftUI
import TaskManagerCore

/// Settings view: responsive, scrollable configuration panel.
public struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var updateSpeed: Double = 1.0

    public init() {}

    public var body: some View {
        DetailPage {
            DetailHeader(
                icon: "gearshape.fill",
                tint: .slate,
                title: "Settings",
                subtitle: "Menu bar widget, background behavior, telemetry cadence and appearance."
            )

            // 1. Menu Bar Widget
            SectionCard("Menu Bar Widget", icon: "menubar.rectangle", tint: .indigo, accessory: {
                PillTag("ALWAYS ON", tint: .emerald)
            }) {
                settingRow(
                    title: "Rotate metrics every 2 seconds",
                    detail: "Cycle CPU → GPU → Memory → Storage → Network in the menu bar. Turn off to always show the metric selected below."
                ) {
                    Toggle("", isOn: $env.rotateMenuBarMetrics)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                Divider()

                Text(env.rotateMenuBarMetrics
                     ? "Rotation starts from the metric selected below."
                     : "Choose the metric shown next to the Task Manager icon in the macOS menu bar.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                    menuBarRadioChip(metric: .cpu, color: .indigo,
                                     currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestCPU?.value?.totalUsagePercent ?? 0))
                    menuBarRadioChip(metric: .gpu, color: .purple,
                                     currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestGPU?.value?.utilizationPercent ?? 0))
                    menuBarRadioChip(metric: .memory, color: .blue,
                                     currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestMemory?.value?.usagePercentage ?? 0))
                    menuBarRadioChip(metric: .disk, color: .emerald,
                                     currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestStorage?.value?.first?.usagePercentage ?? 0))
                    menuBarRadioChip(metric: .network, color: .cyan,
                                     currentVal: formatCompactRate((env.samplingCoordinator.latestNetwork?.value?.totalBytesInPerSecond ?? 0) + (env.samplingCoordinator.latestNetwork?.value?.totalBytesOutPerSecond ?? 0)))
                }

                HStack(spacing: 8) {
                    Text("Preview")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: env.displayedMenuBarMetric.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(valueForMetric(env.displayedMenuBarMetric))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                    Spacer(minLength: 0)
                }
            }

            // 2. Background behavior
            SectionCard("Background & Startup", icon: "power", tint: .emerald) {
                VStack(spacing: 12) {
                    settingRow(
                        title: "Stay running in the menu bar",
                        detail: "Closing the window never quits Task Manager. It keeps monitoring from the menu bar until you choose Quit (⌘Q)."
                    ) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.emerald)
                            .help("Always enabled")
                    }

                    Divider()

                    settingRow(
                        title: "Hide Dock icon when window is closed",
                        detail: "Run as a pure menu bar utility while the main window is closed."
                    ) {
                        Toggle("", isOn: $env.hideDockIconWhenClosed)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }

                    Divider()

                    settingRow(
                        title: "Launch at login",
                        detail: "Start Task Manager automatically so the menu bar widget is always available."
                    ) {
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

            // 3. Telemetry cadence + 4. Theme side by side when there is room
            AdaptiveGrid(minimum: 320) {
                SectionCard("Sample Rate", icon: "timer", tint: .amber, accessory: {
                    Text(formattedInterval(updateSpeed))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }) {
                    Text("Refresh rate for CPU, GPU, memory, disk and network monitors.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 2) {
                        cadenceButton(label: "0.5s", tag: "Fast", interval: 0.5)
                        cadenceButton(label: "1s", tag: "Normal", interval: 1.0)
                        cadenceButton(label: "3s", tag: "Eco", interval: 3.0)
                        cadenceButton(label: "Pause", tag: "", interval: 0.0)
                    }
                    .padding(2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }

                SectionCard("Appearance", icon: "paintpalette", tint: .purple) {
                    Text("Match macOS or force light or dark mode.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 2) {
                        themeButton(label: "System", icon: "circle.lefthalf.filled", mode: "system")
                        themeButton(label: "Light", icon: "sun.max.fill", mode: "light")
                        themeButton(label: "Dark", icon: "moon.fill", mode: "dark")
                    }
                    .padding(2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }

            // 5. About
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        AppLogoView()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Task Manager for macOS")
                                .font(.system(size: 13, weight: .bold))
                            Text("Version \(appVersion) • Native Swift • MIT License")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 4)
                        PillTag("NO TELEMETRY", tint: .emerald)
                    }

                    Divider()

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)], alignment: .leading, spacing: 6) {
                        SpecRow("Device Model", env.deviceProfile.marketingName)
                        SpecRow("Architecture", env.deviceProfile.architecture)
                        SpecRow("Processor", "\(env.deviceProfile.cpuName) (\(env.deviceProfile.physicalCores)C)")
                        SpecRow("Installed RAM", env.deviceProfile.formattedMemory)
                        SpecRow("Graphics", env.deviceProfile.gpuNames.first ?? "Apple Silicon GPU")
                        SpecRow("macOS", env.deviceProfile.osVersion.replacingOccurrences(of: "Version ", with: ""))
                    }
                }
            }

            HStack {
                Spacer()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit Task Manager", systemImage: "power")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .onAppear {
            updateSpeed = env.samplingCoordinator.samplingInterval
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3"
        return "\(short) (\(build))"
    }

    private func settingRow<Accessory: View>(title: String, detail: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            accessory()
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
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                if !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .indigo : .secondary.opacity(0.7))
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isSelected ? Color.primary.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
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
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.primary.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
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

}
