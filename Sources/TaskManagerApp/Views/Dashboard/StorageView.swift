import SwiftUI
import TaskManagerCore

/// Dedicated in-depth Storage & Volumes inspector with live activity history.
public struct StorageView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator
    @Environment(\.layoutClass) private var layoutClass

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let volumes = sampling.latestStorage?.value ?? []
        let primaryDisk = volumes.first

        DetailPage {
            DetailHeader(
                icon: "internaldrive",
                tint: .emerald,
                title: "Storage",
                subtitle: "\(primaryDisk?.name ?? "Startup Disk") • \(primaryDisk?.formattedAvailable ?? "—") available of \(primaryDisk?.formattedTotal ?? "—")",
                metric: String(format: "%.0f%%", primaryDisk?.usagePercentage ?? 0.0),
                metricLabel: "Capacity used"
            )

            SectionCard("Primary Volume History", icon: "waveform.path.ecg", tint: .emerald, accessory: {
                PillTag("60s", tint: .emerald)
            }) {
                DiskTimeSeriesChart(
                    dataPoints: sampling.diskHistory.values.isEmpty ? [0, 0] : sampling.diskHistory.values
                )
                .frame(height: layoutClass == .compact ? 120 : 170)
                ChartTimeAxis(tint: .emerald)
            }

            Text("Mounted Volumes (\(volumes.count))")
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 4)

            if volumes.isEmpty {
                CardView {
                    EmptyStateView(
                        icon: "internaldrive",
                        title: "No Volumes Detected",
                        message: "Unable to inspect mounted storage volumes."
                    )
                }
            } else {
                AdaptiveGrid(minimum: 320) {
                    ForEach(volumes) { vol in
                        volumeCard(vol)
                    }
                }
            }

            SectionCard("Filesystem", icon: "folder", tint: .emerald) {
                VStack(spacing: 8) {
                    SpecRow("Primary Filesystem", primaryDisk?.fileSystemType ?? "APFS")
                    SpecRow("Startup Mount Point", primaryDisk?.mountPath ?? "/")
                    SpecRow("Hardware Interface", "Apple Fabric NVMe SSD")
                    SpecRow("Encryption", "FileVault (AES-XTS)")
                }
            }
        }
    }

    private func volumeCard(_ vol: VolumeInfo) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    IconBadge(
                        systemName: vol.isRoot ? "internaldrive.fill" : (vol.isRemovable ? "externaldrive.fill" : "internaldrive"),
                        tint: vol.isRoot ? .emerald : .blue,
                        size: 30
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(vol.name)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if vol.isRoot { PillTag("Startup", tint: .emerald) }
                            if vol.isRemovable { PillTag("External", tint: .blue) }
                        }
                        Text(vol.mountPath)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(vol.formattedAvailable) free")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text("of \(vol.formattedTotal)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .fixedSize()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [.emerald, .teal], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(min(1.0, max(0.0, vol.usagePercentage / 100.0))))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(vol.formattedUsed) used (\(String(format: "%.1f%%", vol.usagePercentage)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(vol.fileSystemType)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
