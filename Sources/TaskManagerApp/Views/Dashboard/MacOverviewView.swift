import SwiftUI
import TaskManagerCore

/// Mac Overview: high-level device status and quick performance sparklines.
public struct MacOverviewView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let profile = env.deviceProfile
        let cpu = sampling.latestCPU?.value
        let mem = sampling.latestMemory?.value
        let storage = sampling.latestStorage?.value?.first
        let battery = sampling.latestBattery?.value
        let net = sampling.latestNetwork?.value

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // System Identity Banner
                CardView {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: profile.isLaptop ? "laptopcomputer" : "desktopcomputer")
                            .font(.system(size: 38))
                            .foregroundColor(AppTheme.Colors.primaryAccent)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.marketingName)
                                .font(.title3.bold())
                            Text("\(profile.modelIdentifier) • \(profile.architecture) • \(profile.osVersion) (Build \(profile.osBuild))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Uptime: \(profile.formattedUptime)")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            Text("\(profile.logicalCores) Cores • \(profile.formattedMemory) Unified RAM")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Metric Cards Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
                    // CPU Card
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("CPU Load", systemImage: "cpu")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                StatusBadge(status: sampling.latestCPU?.status ?? .available)
                            }

                            Text(String(format: "%.1f%%", cpu?.totalUsagePercent ?? 0.0))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.indigo)

                            SparklineCanvas(
                                dataPoints: sampling.cpuHistory.values.isEmpty ? [0, 0] : sampling.cpuHistory.values,
                                lineColor: .indigo
                            )

                            Text("\(profile.logicalCores) logical cores • \(String(format: "%.1f%%", cpu?.userPercent ?? 0)) user / \(String(format: "%.1f%%", cpu?.systemPercent ?? 0)) sys")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Memory Card
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Memory", systemImage: "memorychip")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(mem?.pressureLevel ?? "Normal")
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.emerald.opacity(0.15))
                                    .foregroundColor(.emerald)
                                    .clipShape(Capsule())
                            }

                            Text("\(mem?.formattedUsed ?? "0 GB") / \(profile.formattedMemory)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)

                            SparklineCanvas(
                                dataPoints: sampling.memoryHistory.values.isEmpty ? [0, 0] : sampling.memoryHistory.values,
                                lineColor: .blue
                            )

                            Text("Pressure: \(mem?.pressureLevel ?? "Normal") • Active + Wired + Compressed")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Storage Card
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Primary Volume", systemImage: "internaldrive")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                StatusBadge(status: sampling.latestStorage?.status ?? .available)
                            }

                            Text("\(storage?.formattedAvailable ?? "0 GB") Free")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)

                            // Storage Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.primary.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.purple)
                                        .frame(width: geo.size.width * CGFloat((storage?.usagePercentage ?? 0) / 100.0))
                                }
                            }
                            .frame(height: 8)
                            .padding(.top, 10)

                            Text("\(storage?.name ?? "Macintosh HD") (\(storage?.fileSystemType ?? "APFS")) of \(storage?.formattedTotal ?? "")")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Battery & Power Card
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Battery & Power", systemImage: "battery.100")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                StatusBadge(status: sampling.latestBattery?.status ?? .notPresent)
                            }

                            if let bat = battery {
                                Text("\(bat.chargePercent)%")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(bat.chargePercent > 20 ? .emerald : .rose)

                                Text("\(bat.powerSource) • \(bat.isCharging ? "Charging" : "On Battery")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let cycle = bat.cycleCount {
                                    Text("Cycle count: \(cycle) • Health: \(bat.condition ?? "Normal")")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("No Internal Battery")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Text(sampling.latestBattery?.reason ?? "Desktop Mac configuration without internal battery.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Network Card
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Network", systemImage: "network")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(net?.primaryInterfaceName ?? "en0")
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                            }

                            Text(formatRate(net?.totalBytesInPerSecond ?? 0))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.emerald)

                            SparklineCanvas(
                                dataPoints: sampling.networkInHistory.values.isEmpty ? [0, 0] : sampling.networkInHistory.values,
                                lineColor: .emerald
                            )

                            Text("Down: \(formatRate(net?.totalBytesInPerSecond ?? 0)) • Up: \(formatRate(net?.totalBytesOutPerSecond ?? 0))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Running Processes Card
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Processes", systemImage: "square.stack.3d.up")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(sampling.latestProcesses?.value?.count ?? 0) Active")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("\(sampling.latestProcesses?.value?.count ?? 0) Apps")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("Active: \(sampling.latestProcesses?.value?.first?.name ?? "Finder")")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Zero-privilege NSWorkspace application inventory")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .onAppear {
            sampling.isDashboardActive = true
        }
        .onDisappear {
            sampling.isDashboardActive = false
        }
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024)
        } else {
            return String(format: "%.0f B/s", bytesPerSec)
        }
    }
}
