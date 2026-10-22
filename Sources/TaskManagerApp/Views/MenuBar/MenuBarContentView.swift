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
        let battery = sampling.latestBattery?.value

        VStack(alignment: .leading, spacing: 12) {
            // Header with App Name and Quick Status
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.indigo)
                    Text("Task Manager")
                        .font(.headline)
                }
                Spacer()
                Text(env.deviceProfile.marketingName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Divider()

            // Hardware Telemetry Rows (Strict Order: CPU -> GPU -> Memory -> Disk -> Network)
            VStack(spacing: 8) {
                // 1. CPU Row
                HStack {
                    Label("CPU", systemImage: "cpu")
                        .font(.caption)
                        .foregroundColor(.indigo)
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    Text(String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0))
                        .font(.caption.monospaced())
                        .bold()
                }

                // 2. GPU Row (Immediately after CPU)
                HStack {
                    Label("GPU", systemImage: "display.trianglebadge.exclamationmark")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    Text(String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0))
                        .font(.caption.monospaced())
                        .bold()
                }

                // 3. Memory Row
                HStack {
                    Label("Memory", systemImage: "memorychip")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    Text("\(mem?.formattedUsed ?? "0 GB") (\(String(format: "%.0f%%", mem?.usagePercentage ?? 0.0)))")
                        .font(.caption.monospaced())
                }

                // 4. Disk Row
                if let disk = sampling.latestStorage?.value?.first {
                    HStack {
                        Label("Disk", systemImage: "internaldrive")
                            .font(.caption)
                            .foregroundColor(.emerald)
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text("\(disk.formattedAvailable) free (\(String(format: "%.0f%%", disk.usagePercentage)))")
                            .font(.caption.monospaced())
                    }
                }

                // 5. Network Row
                if let n = net {
                    HStack {
                        Label("Network", systemImage: "network")
                            .font(.caption)
                            .foregroundColor(.cyan)
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text("↓ \(n.formattedInPerSecond)  ↑ \(n.formattedOutPerSecond)")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                }

                // Battery Row (if present)
                if let bat = battery {
                    HStack {
                        Label("Battery", systemImage: bat.isCharging ? "battery.100.bolt" : "battery.100")
                            .font(.caption)
                            .foregroundColor(bat.chargePercent > 20 ? .emerald : .rose)
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text("\(bat.chargePercent)% \(bat.isCharging ? "(Charging)" : "")")
                            .font(.caption.monospaced())
                    }
                }
            }

            Divider()

            // Actions
            HStack {
                Button("Open Task Manager") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.rose)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}
