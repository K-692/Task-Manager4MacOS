import SwiftUI
import TaskManagerCore

/// Storage view: mounted volumes, filesystem formats, and capacity gauges.
public struct StorageView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let volumes = sampling.latestStorage?.value ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Storage & Volumes")
                            .font(.system(size: 26, weight: .bold))
                        Text("Inspect mounted drives, free capacity, and filesystem formats without intrusive whole-disk scans.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: sampling.latestStorage?.status ?? .available)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                if volumes.isEmpty {
                    CardView {
                        EmptyStateView(
                            icon: "internaldrive",
                            title: "No Volumes Detected",
                            message: "Unable to inspect mounted storage volumes."
                        )
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                } else {
                    ForEach(volumes) { vol in
                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: vol.isRoot ? "internaldrive.fill" : (vol.isRemovable ? "externaldrive.fill" : "internaldrive"))
                                        .font(.title2)
                                        .foregroundColor(vol.isRoot ? .purple : .blue)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(vol.name)
                                                .font(.headline)
                                            if vol.isRoot {
                                                Text("Startup Disk")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple.opacity(0.12))
                                                    .foregroundColor(.purple)
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
                                                    colors: [.purple, .indigo],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geo.size.width * CGFloat(vol.usagePercentage / 100.0))
                                    }
                                }
                                .frame(height: 10)
                                .padding(.top, 4)

                                HStack {
                                    Text("\(vol.formattedUsed) used (\(String(format: "%.1f%%", vol.usagePercentage)))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Safe URLResourceKey probe")
                                        .font(.caption2)
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                }
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }
}
