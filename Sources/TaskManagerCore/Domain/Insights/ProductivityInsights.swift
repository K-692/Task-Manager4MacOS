import Foundation

/// Activity count for a single calendar day (for GitHub-style heatmap).
public struct HeatmapDay: Identifiable, Codable, Hashable, Sendable {
    public var id: String { dateString }
    public let dateString: String // YYYY-MM-DD
    public let date: Date
    public let count: Int
    public let weekday: Int // 1 = Sun, 7 = Sat

    public init(date: Date, count: Int, calendar: Calendar = .current) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateString = formatter.string(from: date)
        self.date = calendar.startOfDay(for: date)
        self.count = count
        self.weekday = calendar.component(.weekday, from: date)
    }
}

/// Completion trend count for a specific period.
public struct TrendPoint: Identifiable, Codable, Hashable, Sendable {
    public var id: String { label }
    public let label: String
    public let count: Int
    public let date: Date

    public init(label: String, count: Int, date: Date) {
        self.label = label
        self.count = count
        self.date = date
    }
}

/// Calculated productivity metrics derived from local task data.
public struct ProductivityInsights: Codable, Sendable {
    public let totalCompleted: Int
    public let completedThisWeek: Int
    public let completedThisMonth: Int
    public let completionRate: Double // 0.0 - 1.0
    public let overdueCount: Int
    public let openCount: Int
    public let priorityCounts: [TaskPriority: Int]
    public let weeklyTrend: [TrendPoint]
    public let heatmapDays: [HeatmapDay]

    public init(
        totalCompleted: Int,
        completedThisWeek: Int,
        completedThisMonth: Int,
        completionRate: Double,
        overdueCount: Int,
        openCount: Int,
        priorityCounts: [TaskPriority: Int],
        weeklyTrend: [TrendPoint],
        heatmapDays: [HeatmapDay]
    ) {
        self.totalCompleted = totalCompleted
        self.completedThisWeek = completedThisWeek
        self.completedThisMonth = completedThisMonth
        self.completionRate = completionRate
        self.overdueCount = overdueCount
        self.openCount = openCount
        self.priorityCounts = priorityCounts
        self.weeklyTrend = weeklyTrend
        self.heatmapDays = heatmapDays
    }
}
