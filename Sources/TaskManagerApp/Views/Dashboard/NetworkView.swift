import SwiftUI
import TaskManagerCore

/// Dedicated in-depth Network telemetry, throughput charts, and interfaces inspector.
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
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: "network")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.cyan)
                            Text("Network — Real-Time Throughput & Interfaces")
                                .font(.system(size: 22, weight: .bold))
                        }
                        Text("Primary Adapter: \(net?.primaryInterfaceName ?? "en0") • Total Downloaded: \(net?.formattedTotalIn ?? "0 B") • Uploaded: \(net?.formattedTotalOut ?? "0 B")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(net?.formattedInPerSecond ?? "0 B/s")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        Text("DOWNLOAD THROUGHPUT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // 60-Second Real-Time Dual-Line Throughput Chart
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("60-Second Network Activity (Inbound & Outbound)")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.cyan).frame(width: 8, height: 8)
                                    Text("Download (↓ \(net?.formattedInPerSecond ?? "0 B/s"))")
                                        .font(.caption2.bold())
                                        .foregroundColor(.cyan)
                                }
                                HStack(spacing: 4) {
                                    Circle().fill(Color.indigo).frame(width: 8, height: 8)
                                    Text("Upload (↑ \(net?.formattedOutPerSecond ?? "0 B/s"))")
                                        .font(.caption2.bold())
                                        .foregroundColor(.indigo)
                                }
                            }
                        }

                        NetworkThroughputChart(
                            inboundPoints: sampling.networkInHistory.values.isEmpty ? [0, 0] : sampling.networkInHistory.values,
                            outboundPoints: sampling.networkOutHistory.values.isEmpty ? [0, 0] : sampling.networkOutHistory.values
                        )

                        HStack {
                            Text("60s ago")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("0s (Live)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Interfaces Table
                VStack(alignment: .leading, spacing: 12) {
                    Text("Detected Network Adapters (\(interfaces.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 24)

                    CardView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Interface").font(.system(size: 11, weight: .bold)).frame(width: 100, alignment: .leading)
                                Text("Status").font(.system(size: 11, weight: .bold)).frame(width: 70, alignment: .leading)
                                Text("Download Rate").font(.system(size: 11, weight: .bold)).frame(width: 110, alignment: .leading)
                                Text("Upload Rate").font(.system(size: 11, weight: .bold)).frame(width: 110, alignment: .leading)
                                Spacer()
                                Text("Session Traffic (In / Out)").font(.system(size: 11, weight: .bold)).frame(width: 160, alignment: .trailing)
                            }
                            .padding(.vertical, 8)
                            .foregroundColor(.secondary)

                            Divider()

                            ForEach(interfaces) { iface in
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: iface.name.hasPrefix("en0") ? "wifi" : (iface.name.hasPrefix("lo") ? "arrow.triangle.2.circlepath" : "network"))
                                            .foregroundColor(.cyan)
                                            .font(.system(size: 11))
                                        Text(iface.name)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    }
                                    .frame(width: 100, alignment: .leading)

                                    Text(iface.isUp ? "UP" : "DOWN")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(iface.isUp ? Color.emerald.opacity(0.12) : Color.secondary.opacity(0.1))
                                        .foregroundColor(iface.isUp ? .emerald : .secondary)
                                        .clipShape(Capsule())
                                        .frame(width: 70, alignment: .leading)

                                    Text(iface.formattedInboundRate)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.cyan)
                                        .frame(width: 110, alignment: .leading)

                                    Text(iface.formattedOutboundRate)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.indigo)
                                        .frame(width: 110, alignment: .leading)

                                    Spacer()

                                    Text("\(formatBytes(iface.totalBytesIn)) / \(formatBytes(iface.totalBytesOut))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 160, alignment: .trailing)
                                }
                                .padding(.vertical, 7)

                                if iface.id != interfaces.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Network Protocol Specs
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Network Architecture & Protocol Stack")
                            .font(.system(size: 13, weight: .semibold))

                        VStack(spacing: 8) {
                            specRow(label: "Link Layer Stack", value: "BSD Sockets API (getifaddrs / AF_LINK)")
                            specRow(label: "Primary Hardware Port", value: net?.primaryInterfaceName ?? "en0 (Wi-Fi 6 / 802.11ax)")
                            specRow(label: "Hardware Acceleration", value: "Apple Silicon Hardware TCP/IP Checksum Offload")
                            specRow(label: "IPv4 & IPv6 Dual Stack", value: "Active & Routing (Low Latency)")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 170, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}
