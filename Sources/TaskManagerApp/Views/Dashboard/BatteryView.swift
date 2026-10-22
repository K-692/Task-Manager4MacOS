import SwiftUI
import TaskManagerCore

/// Battery & Power view: charge state, power source, and cycle count with truthful desktop fallback.
public struct BatteryView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let batterySample = sampling.latestBattery
        let battery = batterySample?.value

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Battery & Power")
                            .font(.system(size: 26, weight: .bold))
                        Text("Real-time battery level, power source, and health telemetry via IOKit.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: batterySample?.status ?? .notPresent)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                if let bat = battery {
                    // Battery Level Main Card
                    CardView {
                        HStack(spacing: AppTheme.Spacing.lg) {
                            ZStack {
                                Circle()
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 10)
                                Circle()
                                    .trim(from: 0, to: CGFloat(Double(bat.chargePercent) / 100.0))
                                    .stroke(
                                        bat.chargePercent > 20 ? Color.emerald : Color.rose,
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))

                                VStack(spacing: 2) {
                                    Text("\(bat.chargePercent)%")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                    Image(systemName: bat.isCharging ? "bolt.fill" : "battery.100")
                                        .foregroundColor(bat.isCharging ? .amber : .secondary)
                                }
                            }
                            .frame(width: 90, height: 90)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(bat.isCharging ? "Charging" : "Discharging")
                                    .font(.title3.bold())
                                    .foregroundColor(bat.isCharging ? .amber : .primary)

                                Text("Current Power Source: \(bat.powerSource)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let time = bat.timeRemainingMinutes {
                                    Text("\(time / 60)h \(time % 60)m remaining")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    // Battery Health & Diagnostics
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
                        CardView {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cycle Count")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(bat.cycleCount != nil ? "\(bat.cycleCount!)" : "Not exposed by OS")
                                    .font(.title3.bold())
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Condition")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(bat.condition ?? "Normal")
                                    .font(.title3.bold())
                                    .foregroundColor(.emerald)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                } else {
                    CardView {
                        EmptyStateView(
                            icon: "powerplug.fill",
                            title: "No Internal Battery",
                            message: batterySample?.reason ?? "This Mac is running a desktop configuration (Mac mini, Mac Studio, iMac, or Mac Pro) connected directly to AC power.",
                            actionTitle: nil,
                            action: nil
                        )
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }
}
