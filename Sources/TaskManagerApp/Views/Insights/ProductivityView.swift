import SwiftUI
import TaskManagerCore

/// Productivity insights view displaying trends, heatmaps, and priority distributions.
public struct ProductivityView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var insights: ProductivityInsights? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Productivity Insights")
                        .font(.system(size: 26, weight: .bold))
                    Text("Understand your work habits, completion trends, and priority distribution.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                if let ins = insights {
                    // Metric Summary Cards Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
                        CardView {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Completed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(ins.totalCompleted)")
                                    .font(.title2.bold())
                                    .foregroundColor(.emerald)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("This Week")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(ins.completedThisWeek)")
                                    .font(.title2.bold())
                                    .foregroundColor(.indigo)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("This Month")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(ins.completedThisMonth)")
                                    .font(.title2.bold())
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Completion Rate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(ins.completionRate * 100))%")
                                    .font(.title2.bold())
                                    .foregroundColor(ins.completionRate > 0.6 ? .emerald : .amber)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    // Activity Heatmap Card
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Completion Activity (Last 12 Weeks)")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Visualizes daily completed task volume over the past 84 days.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ActivityHeatmapCanvas(days: ins.heatmapDays)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    // Charts Row (Weekly Trend + Priority Distribution)
                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Weekly Completion Trend")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Completed tasks over the past 7 days.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                // Mini line/bar
                                HStack(alignment: .bottom, spacing: 8) {
                                    ForEach(ins.weeklyTrend) { pt in
                                        VStack(spacing: 4) {
                                            Text("\(pt.count)")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)

                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.indigo)
                                                .frame(height: max(6, CGFloat(pt.count) * 16))

                                            Text(pt.label)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .frame(height: 120)
                                .padding(.top, 8)
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Open Tasks by Priority")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Distribution of current pending work.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                PriorityDistributionChart(counts: ins.priorityCounts)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                } else {
                    CardView {
                        EmptyStateView(
                            icon: "chart.bar",
                            title: "Loading Insights...",
                            message: "Calculating local productivity analytics from your SQLite database."
                        )
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .onAppear {
            loadInsights()
        }
    }

    private func loadInsights() {
        do {
            self.insights = try env.taskRepo.fetchProductivityInsights()
        } catch {
            print("Failed to fetch insights: \(error)")
        }
    }
}
