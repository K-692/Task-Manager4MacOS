import SwiftUI
import TaskManagerCore

/// Network view: live throughput graph and per-interface statistics.
public struct NetworkView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let net = sampling.latestNetwork?.value
        let interfaces = net?.interfaces ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Network Interfaces")
                            .font(.system(size: 26, weight: .bold))
                        Text("Real-time network transfer rates, packet counters, and interface status.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: sampling.latestNetwork?.status ?? .available)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Live Throughput Chart
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Throughput (KB/s)")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Primary: \(net?.primaryInterfaceName ?? "en0") • Inbound: \(formatRate(net?.totalBytesInPerSecond ?? 0)) • Outbound: \(formatRate(net?.totalBytesOutPerSecond ?? 0))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        NetworkThroughputChart(
                            inboundPoints: sampling.networkInHistory.values.isEmpty ? [0, 0] : sampling.networkInHistory.values,
                            outboundPoints: sampling.networkOutHistory.values.isEmpty ? [0, 0] : sampling.networkOutHistory.values
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Interfaces Table
                VStack(alignment: .leading, spacing: 6) {
                    Text("Detected Interfaces (\(interfaces.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    CardView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Interface").font(.caption.bold()).frame(width: 100, alignment: .leading)
                                Text("State").font(.caption.bold()).frame(width: 80, alignment: .leading)
                                Text("Download Rate").font(.caption.bold()).frame(width: 120, alignment: .leading)
                                Text("Upload Rate").font(.caption.bold()).frame(width: 120, alignment: .leading)
                                Spacer()
                                Text("Total In/Out").font(.caption.bold()).frame(width: 140, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            .foregroundColor(.secondary)

                            Divider()

                            ForEach(interfaces) { iface in
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: iface.name.hasPrefix("en") ? "wifi" : "network")
                                            .foregroundColor(.indigo)
                                        Text(iface.name)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .frame(width: 100, alignment: .leading)

                                    Text(iface.isUp ? "Active" : "Down")
                                        .font(.caption)
                                        .foregroundColor(iface.isUp ? .emerald : .secondary)
                                        .frame(width: 80, alignment: .leading)

                                    Text(iface.formattedInboundRate)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.emerald)
                                        .frame(width: 120, alignment: .leading)

                                    Text(iface.formattedOutboundRate)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.blue)
                                        .frame(width: 120, alignment: .leading)

                                    Spacer()

                                    Text("\(formatBytes(iface.totalBytesIn)) / \(formatBytes(iface.totalBytesOut))")
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                        .frame(width: 140, alignment: .trailing)
                                }
                                .padding(.vertical, 6)

                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
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

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
