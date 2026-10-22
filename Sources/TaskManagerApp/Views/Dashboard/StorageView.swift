import SwiftUI
import TaskManagerCore

/// Dedicated in-depth Storage & Volumes inspector with live activity history.
public struct StorageView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let volumes = sampling.latestStorage?.value ?? []
        let primaryDisk = volumes.first

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: "internaldrive")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.emerald)
                            Text("Disk — Storage & Mounted Volumes")
                                .font(.system(size: 22, weight: .bold))
                        }
                        Text("\(primaryDisk?.name ?? "Startup Disk") • \(primaryDisk?.formattedAvailable ?? "—") available of \(primaryDisk?.formattedTotal ?? "—")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f%%", primaryDisk?.usagePercentage ?? 0.0))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.emerald)
                        Text("DISK CAPACITY USED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // 60-Second Real-Time Disk Usage History
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("60-Second Primary Volume Space History")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("100%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        DiskTimeSeriesChart(
                            dataPoints: sampling.diskHistory.values.isEmpty ? [0, 0] : sampling.diskHistory.values
                        )

                        HStack {
                            Text("60s ago")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("0s (Live)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.emerald)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Mounted Volumes List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mounted Volumes (\(volumes.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 24)

                    if volumes.isEmpty {
                        CardView {
                            EmptyStateView(
                                icon: "internaldrive",
                                title: "No Volumes Detected",
                                message: "Unable to inspect mounted storage volumes."
                            )
                        }
                        .padding(.horizontal, 24)
                    } else {
                        ForEach(volumes) { vol in
                            CardView {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: vol.isRoot ? "internaldrive.fill" : (vol.isRemovable ? "externaldrive.fill" : "internaldrive"))
                                            .font(.title2)
                                            .foregroundColor(vol.isRoot ? .emerald : .blue)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(vol.name)
                                                    .font(.headline)
                                                if vol.isRoot {
                                                    Text("Startup Disk")
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.emerald.opacity(0.12))
                                                        .foregroundColor(.emerald)
                                                        .clipShape(Capsule())
                                                }
                                                if vol.isRemovable {
                                                    Text("External")
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.blue.opacity(0.12))
                                                        .foregroundColor(.blue)
                                                        .clipShape(Capsule())
                                                }
                                            }

                                            Text("\(vol.mountPath) • Format: \(vol.fileSystemType)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(vol.formattedAvailable) free")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Text("of \(vol.formattedTotal)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    // Capacity Bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.primary.opacity(0.08))

                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.emerald, .teal],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: geo.size.width * CGFloat(min(1.0, max(0.0, vol.usagePercentage / 100.0))))
                                        }
                                    }
                                    .frame(height: 10)
                                    .padding(.top, 4)

                                    HStack {
                                        Text("\(vol.formattedUsed) used (\(String(format: "%.1f%%", vol.usagePercentage)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(vol.fileSystemType)
                                            .font(.caption2.monospaced())
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }

                // Storage Filesystem Specs
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filesystem Architecture & Storage Specs")
                            .font(.system(size: 13, weight: .semibold))

                        VStack(spacing: 8) {
                            specRow(label: "Primary Filesystem", value: primaryDisk?.fileSystemType ?? "APFS")
                            specRow(label: "Startup Mount Point", value: primaryDisk?.mountPath ?? "/")
                            specRow(label: "Hardware Interface", value: "Apple Fabric NVMe SSD (PCIe Gen 4)")
                            specRow(label: "Encryption", value: "FileVault 2 Hardware AES-XTS (Encrypted)")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 160, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}
