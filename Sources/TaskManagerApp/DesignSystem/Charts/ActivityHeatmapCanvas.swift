import SwiftUI
import TaskManagerCore

/// Canvas-based GitHub-style activity heatmap rendering completed task frequency.
public struct ActivityHeatmapCanvas: View {
    public let days: [HeatmapDay]
    private let cellSize: CGFloat = 13
    private let cellSpacing: CGFloat = 3

    public init(days: [HeatmapDay]) {
        self.days = days
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Day-of-week labels
                VStack(spacing: cellSpacing) {
                    Text("").frame(height: cellSize)
                    Text("Mon").font(.system(size: 9)).foregroundColor(.secondary).frame(height: cellSize)
                    Text("").frame(height: cellSize)
                    Text("Wed").font(.system(size: 9)).foregroundColor(.secondary).frame(height: cellSize)
                    Text("").frame(height: cellSize)
                    Text("Fri").font(.system(size: 9)).foregroundColor(.secondary).frame(height: cellSize)
                    Text("").frame(height: cellSize)
                }

                // Grid of 12 columns (weeks) x 7 rows
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<weeksCount, id: \.self) { weekIdx in
                            VStack(spacing: cellSpacing) {
                                ForEach(1...7, id: \.self) { dayOfWeek in
                                    let day = dayFor(weekIndex: weekIdx, weekday: dayOfWeek)
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .fill(colorFor(count: day?.count ?? 0))
                                        .frame(width: cellSize, height: cellSize)
                                        .help(tooltipText(for: day))
                                }
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("Less").font(.system(size: 10)).foregroundColor(.secondary)
                RoundedRectangle(cornerRadius: 2).fill(colorFor(count: 0)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(colorFor(count: 1)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(colorFor(count: 3)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(colorFor(count: 6)).frame(width: 10, height: 10)
                Text("More").font(.system(size: 10)).foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var weeksCount: Int {
        max(1, (days.count + 6) / 7)
    }

    private func dayFor(weekIndex: Int, weekday: Int) -> HeatmapDay? {
        let idx = (weekIndex * 7) + (weekday - 1)
        guard idx >= 0 && idx < days.count else { return nil }
        return days[idx]
    }

    private func colorFor(count: Int) -> Color {
        if count == 0 {
            return Color.primary.opacity(0.06)
        } else if count <= 2 {
            return Color.emerald.opacity(0.35)
        } else if count <= 4 {
            return Color.emerald.opacity(0.65)
        } else {
            return Color.emerald
        }
    }

    private func tooltipText(for day: HeatmapDay?) -> String {
        guard let d = day else { return "No activity" }
        return "\(d.count) task(s) completed on \(d.dateString)"
    }
}
