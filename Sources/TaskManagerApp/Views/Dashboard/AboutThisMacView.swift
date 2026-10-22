import SwiftUI
import TaskManagerCore

/// About This Mac view: verified hardware and operating system facts.
public struct AboutThisMacView: View {
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        let profile = env.deviceProfile

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("About This Mac")
                        .font(.system(size: 26, weight: .bold))
                    Text("Verified hardware specifications and system facts for this machine.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Mac Identity Banner
                CardView {
                    HStack(spacing: AppTheme.Spacing.lg) {
                        Image(systemName: profile.isLaptop ? "laptopcomputer" : "desktopcomputer")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.Colors.primaryAccent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.marketingName)
                                .font(.title2.bold())
                            Text("Model Identifier: \(profile.modelIdentifier)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Architecture: \(profile.architecture)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Detailed Specs Grid
                CardView {
                    VStack(spacing: 12) {
                        specRow(title: "macOS Version", value: "\(profile.osVersion) (Build \(profile.osBuild))")
                        Divider()
                        specRow(title: "Processor / SoC", value: profile.cpuName)
                        Divider()
                        specRow(title: "CPU Topology", value: "\(profile.logicalCores) logical cores (\(profile.physicalCores) physical cores)")
                        Divider()
                        specRow(title: "System Memory", value: "\(profile.formattedMemory) Unified Memory")
                        Divider()
                        specRow(title: "Graphics Hardware", value: profile.gpuNames.joined(separator: ", "))
                        Divider()
                        specRow(title: "Displays", value: "\(profile.displayCount) connected display(s)")
                        Divider()
                        specRow(title: "System Uptime", value: profile.formattedUptime)
                        Divider()
                        specRow(title: "Boot Timestamp", value: formatBootTime(profile.bootTime))
                        Divider()
                        specRow(title: "Device Profile ID", value: profile.deviceProfileId.uuidString)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }

    private func specRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 180, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatBootTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}
