import SwiftUI
import TaskManagerCore

/// Dedicated in-depth Network telemetry, throughput charts, and interfaces inspector.
public struct NetworkView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator
    @Environment(\.layoutClass) private var layoutClass

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let net = sampling.latestNetwork?.value
        let interfaces = net?.interfaces ?? []

        DetailPage {
            DetailHeader(
                icon: "network",
                tint: .cyan,
                title: "Network",
                subtitle: "Primary: \(net?.primaryInterfaceName ?? "en0") • ↓ \(net?.formattedTotalIn ?? "0 B") • ↑ \(net?.formattedTotalOut ?? "0 B")",
                metric: net?.formattedInPerSecond ?? "0 B/s",
                metricLabel: "Download"
            )

            SectionCard("Throughput History", icon: "waveform.path.ecg", tint: .cyan, accessory: {
                HStack(spacing: 10) {
                    legend(color: .cyan, text: "↓ \(net?.formattedInPerSecond ?? "0 B/s")")
                    legend(color: .indigo, text: "↑ \(net?.formattedOutPerSecond ?? "0 B/s")")
                }
            }) {
                NetworkThroughputChart(
                    inboundPoints: sampling.networkInHistory.values.isEmpty ? [0, 0] : sampling.networkInHistory.values,
                    outboundPoints: sampling.networkOutHistory.values.isEmpty ? [0, 0] : sampling.networkOutHistory.values
                )
                .frame(height: layoutClass == .compact ? 140 : 200)
                ChartTimeAxis(tint: .cyan)
            }

            SectionCard("Network Adapters (\(interfaces.count))", icon: "point.3.connected.trianglepath.dotted", tint: .cyan) {
                interfaceTable(interfaces)
            }

            SectionCard("Protocol Stack", icon: "square.3.layers.3d", tint: .cyan) {
                VStack(spacing: 8) {
                    SpecRow("Link Layer", "BSD Sockets (getifaddrs)")
                    SpecRow("Primary Port", net?.primaryInterfaceName ?? "en0")
                    SpecRow("Checksum Offload", "Hardware TCP/IP")
                    SpecRow("IPv4 & IPv6", "Dual stack active")
                }
            }
        }
    }

    @ViewBuilder
    private func interfaceTable(_ interfaces: [NetworkInterfaceInfo]) -> some View {
        let showStatus = layoutClass != .compact
        let showTotals = layoutClass == .wide

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Interface").frame(maxWidth: .infinity, alignment: .leading)
                if showStatus { Text("Status").frame(width: 64, alignment: .leading) }
                Text("Download").frame(width: 92, alignment: .trailing)
                Text("Upload").frame(width: 92, alignment: .trailing)
                if showTotals { Text("Session In / Out").frame(width: 170, alignment: .trailing) }
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary)
            .padding(.bottom, 6)

            Divider()

            ForEach(interfaces) { iface in
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: iface.name.hasPrefix("en0") ? "wifi" : (iface.name.hasPrefix("lo") ? "arrow.triangle.2.circlepath" : "network"))
                            .foregroundColor(.cyan)
                            .font(.system(size: 11))
                        Text(iface.name)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                        if !showStatus {
                            Circle().fill(iface.isUp ? Color.emerald : Color.secondary).frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if showStatus {
                        PillTag(iface.isUp ? "UP" : "DOWN", tint: iface.isUp ? .emerald : .secondary)
                            .frame(width: 64, alignment: .leading)
                    }

                    Text(iface.formattedInboundRate)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                        .lineLimit(1)
                        .frame(width: 92, alignment: .trailing)

                    Text(iface.formattedOutboundRate)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.indigo)
                        .lineLimit(1)
                        .frame(width: 92, alignment: .trailing)

                    if showTotals {
                        Text("\(formatBytes(iface.totalBytesIn)) / \(formatBytes(iface.totalBytesOut))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(width: 170, alignment: .trailing)
                    }
                }
                .padding(.vertical, 7)

                if iface.id != interfaces.last?.id {
                    Divider()
                }
            }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .fixedSize()
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
