import SwiftUI
import TaskManagerCore

/// Compact menu-bar surface for instant hardware & process monitoring.
public struct MenuBarContentView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let cpu = sampling.latestCPU?.value
        let mem = sampling.latestMemory?.value
        let gpu = sampling.latestGPU?.value
        let net = sampling.latestNetwork?.value
        let disk = sampling.latestStorage?.value?.first
        let battery = sampling.latestBattery?.value
        let topProcesses = Array((sampling.latestProcesses?.value ?? []).sorted { $0.cpuPercent > $1.cpuPercent }.prefix(3))
        let netHistory = sampling.networkTotalHistory.values

        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                AppLogoView()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Task Manager")
                        .font(.system(size: 13, weight: .bold))
                    Text(env.deviceProfile.marketingName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                PillTag(env.rotateMenuBarMetrics ? "ROTATING" : "LIVE", tint: .emerald)
            }

            // Metric rows
            VStack(spacing: 6) {
                metricRow(icon: "cpu", title: "CPU", tint: .indigo,
                          value: String(format: "%.0f%%", cpu?.totalUsagePercent ?? 0),
                          history: sampling.cpuHistory.values, maxVal: 100,
                          destination: .cpu)
                metricRow(icon: "cube.transparent", title: "GPU", tint: .purple,
                          value: String(format: "%.0f%%", gpu?.utilizationPercent ?? 0),
                          history: sampling.gpuHistory.values, maxVal: 100,
                          destination: .gpu)
                metricRow(icon: "memorychip", title: "Memory", tint: .blue,
                          value: String(format: "%.0f%%", mem?.usagePercentage ?? 0),
                          detail: mem?.formattedUsed,
                          history: sampling.memoryHistory.values, maxVal: 100,
                          destination: .memory)
                metricRow(icon: "internaldrive", title: "Storage", tint: .emerald,
                          value: String(format: "%.0f%%", disk?.usagePercentage ?? 0),
                          detail: disk.map { "\($0.formattedAvailable) free" },
                          history: sampling.diskHistory.values, maxVal: 100,
                          destination: .disk)
                metricRow(icon: "network", title: "Network", tint: .cyan,
                          value: net?.formattedInPerSecond ?? "0 B/s",
                          detail: net.map { "↑ \($0.formattedOutPerSecond)" },
                          history: netHistory, maxVal: max(1024, netHistory.max() ?? 1024),
                          destination: .network)

                if let bat = battery {
                    HStack(spacing: 8) {
                        Image(systemName: bat.isCharging ? "battery.100.bolt" : "battery.75")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(bat.chargePercent > 20 ? .emerald : .rose)
                            .frame(width: 18)
                        Text("Battery")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(bat.chargePercent)%\(bat.isCharging ? " • Charging" : "")")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }

            if !topProcesses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOP PROCESSES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundColor(.secondary)
                    ForEach(topProcesses) { proc in
                        HStack {
                            Text(proc.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(String(format: "%.1f%%", proc.cpuPercent))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.indigo)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
            }

            SpeedTestCard(speedTest: env.speedTest)

            Divider()

            // Actions
            HStack(spacing: 8) {
                Button {
                    open(.dashboard)
                } label: {
                    Label("Open Dashboard", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button {
                    open(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .help("Settings")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.bordered)
                .tint(.rose)
                .help("Quit Task Manager (⌘Q)")
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 310)
    }

    private func open(_ destination: AppDestination) {
        env.selectedDestination = destination
        WindowRouter.shared.showMainWindow()
    }

    private func metricRow(
        icon: String,
        title: String,
        tint: Color,
        value: String,
        valueColor: Color = .primary,
        detail: String? = nil,
        history: [Double],
        maxVal: Double,
        destination: AppDestination
    ) -> some View {
        Button {
            open(destination)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                SparklineView(data: history, minVal: 0, maxVal: maxVal, tint: tint)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(valueColor)
                    .lineLimit(1)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
