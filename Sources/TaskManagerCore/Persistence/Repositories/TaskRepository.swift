import Foundation
import SQLite3

/// Repository handling all Task persistence, queries, smart lists, and relations.
public final class TaskRepository: @unchecked Sendable {
    private let store: SQLiteStore

    public init(store: SQLiteStore) {
        self.store = store
    }

    public func fetchTasks(filter: TaskFilter = TaskFilter()) throws -> [TaskItem] {
        var conditions: [String] = []
        var bindings: [Any?] = []

        if !filter.includeDeleted {
            conditions.append("t.deleted_at IS NULL")
        }

        if let statuses = filter.statuses, !statuses.isEmpty {
            let placeholders = statuses.map { _ in "?" }.joined(separator: ",")
            conditions.append("t.status IN (\(placeholders))")
            for status in statuses {
                bindings.append(status.rawValue)
            }
        }

        if let priorities = filter.priorities, !priorities.isEmpty {
            let placeholders = priorities.map { _ in "?" }.joined(separator: ",")
            conditions.append("t.priority IN (\(placeholders))")
            for priority in priorities {
                bindings.append(priority.rawValue)
            }
        }

        if let projectId = filter.projectId {
            conditions.append("t.project_id = ?")
            bindings.append(projectId)
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date()).timeIntervalSince1970
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!.timeIntervalSince1970

        if filter.isDueToday == true {
            conditions.append("((t.due_at >= ? AND t.due_at < ?) OR (t.due_at < ? AND t.status != 'completed'))")
            bindings.append(startOfToday)
            bindings.append(endOfToday)
            bindings.append(startOfToday)
        }

        if filter.isOverdue == true {
            conditions.append("t.due_at < ? AND t.status != 'completed'")
            bindings.append(startOfToday)
        }

        if filter.isUpcoming == true {
            conditions.append("t.due_at >= ? AND t.status != 'completed'")
            bindings.append(startOfToday)
        }

        if let query = filter.searchQuery, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            conditions.append("(t.title LIKE ? OR t.notes LIKE ?)")
            let wildcard = "%\(query)%"
            bindings.append(wildcard)
            bindings.append(wildcard)
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let sql = """
        SELECT t.id, t.title, t.notes, t.status, t.priority, t.created_at, t.updated_at,
               t.start_at, t.due_at, t.completed_at, t.project_id, t.section_id,
               t.sort_order, t.estimate_minutes, t.recurrence_rule, t.parent_task_id, t.deleted_at
        FROM tasks t
        \(whereClause)
        ORDER BY t.sort_order ASC, t.created_at DESC;
        """

        let tasks = try store.query(sql: sql, bindings: bindings) { stmt in
            mapTask(statement: stmt)
        }

        // Attach tags to tasks
        var resultTasks: [TaskItem] = []
        for var task in tasks {
            task.tags = try fetchTags(for: task.id)
            resultTasks.append(task)
        }
        return resultTasks
    }

    public func fetchTask(id: UUID) throws -> TaskItem? {
        let sql = """
        SELECT t.id, t.title, t.notes, t.status, t.priority, t.created_at, t.updated_at,
               t.start_at, t.due_at, t.completed_at, t.project_id, t.section_id,
               t.sort_order, t.estimate_minutes, t.recurrence_rule, t.parent_task_id, t.deleted_at
        FROM tasks t
        WHERE t.id = ?;
        """
        let tasks = try store.query(sql: sql, bindings: [id]) { stmt in
            mapTask(statement: stmt)
        }
        guard var task = tasks.first else { return nil }
        task.tags = try fetchTags(for: task.id)
        return task
    }

    public func insertTask(_ task: TaskItem) throws {
        let sql = """
        INSERT INTO tasks (
            id, title, notes, status, priority, created_at, updated_at,
            start_at, due_at, completed_at, project_id, section_id,
            sort_order, estimate_minutes, recurrence_rule, parent_task_id, deleted_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        let bindings: [Any?] = [
            task.id,
            task.title,
            task.notes,
            task.status.rawValue,
            task.priority.rawValue,
            task.createdAt,
            task.updatedAt,
            task.startAt,
            task.dueAt,
            task.completedAt,
            task.projectId,
            task.sectionId,
            task.sortOrder,
            task.estimateMinutes,
            task.recurrenceRule,
            task.parentTaskId,
            task.deletedAt
        ]
        try store.executeUpdate(sql: sql, bindings: bindings)

        for tag in task.tags {
            try attachTag(taskId: task.id, tagId: tag.id)
        }
    }

    public func updateTask(_ task: TaskItem) throws {
        let sql = """
        UPDATE tasks SET
            title = ?, notes = ?, status = ?, priority = ?, updated_at = ?,
            start_at = ?, due_at = ?, completed_at = ?, project_id = ?, section_id = ?,
            sort_order = ?, estimate_minutes = ?, recurrence_rule = ?, parent_task_id = ?, deleted_at = ?
        WHERE id = ?;
        """
        let bindings: [Any?] = [
            task.title,
            task.notes,
            task.status.rawValue,
            task.priority.rawValue,
            Date(),
            task.startAt,
            task.dueAt,
            task.completedAt,
            task.projectId,
            task.sectionId,
            task.sortOrder,
            task.estimateMinutes,
            task.recurrenceRule,
            task.parentTaskId,
            task.deletedAt,
            task.id
        ]
        try store.executeUpdate(sql: sql, bindings: bindings)

        // Sync tags
        try store.executeUpdate(sql: "DELETE FROM task_tags WHERE task_id = ?;", bindings: [task.id])
        for tag in task.tags {
            try attachTag(taskId: task.id, tagId: tag.id)
        }
    }

    public func deleteTask(id: UUID, hard: Bool = false) throws {
        if hard {
            try store.executeUpdate(sql: "DELETE FROM tasks WHERE id = ?;", bindings: [id])
        } else {
            let sql = "UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ?;"
            try store.executeUpdate(sql: sql, bindings: [Date(), Date(), id])
        }
    }

    public func restoreTask(id: UUID) throws {
        let sql = "UPDATE tasks SET deleted_at = NULL, updated_at = ? WHERE id = ?;"
        try store.executeUpdate(sql: sql, bindings: [Date(), id])
    }

    /// Marks a task completed, and generates next occurrence if recurring.
    public func completeTask(id: UUID) throws -> TaskItem? {
        guard var task = try fetchTask(id: id) else { return nil }
        task.status = .completed
        task.completedAt = Date()
        task.updatedAt = Date()
        try updateTask(task)

        // Check recurrence
        if let ruleStr = task.recurrenceRule,
           let rule = RecurrenceRule.parse(ruleStr),
           let due = task.dueAt {
            let engine = RecurrenceEngine()
            if let nextDue = engine.nextDueDate(for: rule, after: due) {
                let nextTask = TaskItem(
                    title: task.title,
                    notes: task.notes,
                    status: .todo,
                    priority: task.priority,
                    startAt: nil,
                    dueAt: nextDue,
                    projectId: task.projectId,
                    sectionId: task.sectionId,
                    estimateMinutes: task.estimateMinutes,
                    recurrenceRule: task.recurrenceRule,
                    parentTaskId: task.id,
                    tags: task.tags
                )
                try insertTask(nextTask)
            }
        }

        return task
    }

    public func reopenTask(id: UUID) throws {
        let sql = """
        UPDATE tasks SET status = 'todo', completed_at = NULL, updated_at = ?
        WHERE id = ?;
        """
        try store.executeUpdate(sql: sql, bindings: [Date(), id])
    }

    public func attachTag(taskId: UUID, tagId: UUID) throws {
        let sql = "INSERT OR IGNORE INTO task_tags (task_id, tag_id) VALUES (?, ?);"
        try store.executeUpdate(sql: sql, bindings: [taskId, tagId])
    }

    public func detachTag(taskId: UUID, tagId: UUID) throws {
        let sql = "DELETE FROM task_tags WHERE task_id = ? AND tag_id = ?;"
        try store.executeUpdate(sql: sql, bindings: [taskId, tagId])
    }

    public func reorderTasks(orderedIds: [UUID]) throws {
        try store.transaction {
            for (index, id) in orderedIds.enumerated() {
                let sql = "UPDATE tasks SET sort_order = ?, updated_at = ? WHERE id = ?;"
                try store.executeUpdate(sql: sql, bindings: [Double(index), Date(), id])
            }
        }
    }

    private func fetchTags(for taskId: UUID) throws -> [Tag] {
        let sql = """
        SELECT g.id, g.name, g.color_token, g.created_at
        FROM tags g
        JOIN task_tags tg ON g.id = tg.tag_id
        WHERE tg.task_id = ?
        ORDER BY g.name ASC;
        """
        return try store.query(sql: sql, bindings: [taskId]) { stmt in
            Tag(
                id: SQLiteStore.uuid(at: 0, statement: stmt) ?? UUID(),
                name: SQLiteStore.text(at: 1, statement: stmt) ?? "",
                colorToken: SQLiteStore.text(at: 2, statement: stmt) ?? "blue",
                createdAt: SQLiteStore.date(at: 3, statement: stmt) ?? Date()
            )
        }
    }

    private func mapTask(statement: OpaquePointer) -> TaskItem {
        let id = SQLiteStore.uuid(at: 0, statement: statement) ?? UUID()
        let title = SQLiteStore.text(at: 1, statement: statement) ?? ""
        let notes = SQLiteStore.text(at: 2, statement: statement)
        let statusRaw = SQLiteStore.text(at: 3, statement: statement) ?? "todo"
        let priorityRaw = SQLiteStore.text(at: 4, statement: statement) ?? "normal"
        let createdAt = SQLiteStore.date(at: 5, statement: statement) ?? Date()
        let updatedAt = SQLiteStore.date(at: 6, statement: statement) ?? Date()
        let startAt = SQLiteStore.date(at: 7, statement: statement)
        let dueAt = SQLiteStore.date(at: 8, statement: statement)
        let completedAt = SQLiteStore.date(at: 9, statement: statement)
        let projectId = SQLiteStore.uuid(at: 10, statement: statement)
        let sectionId = SQLiteStore.uuid(at: 11, statement: statement)
        let sortOrder = SQLiteStore.double(at: 12, statement: statement) ?? 0.0
        let estimateMinutes = SQLiteStore.int(at: 13, statement: statement)
        let recurrenceRule = SQLiteStore.text(at: 14, statement: statement)
        let parentTaskId = SQLiteStore.uuid(at: 15, statement: statement)
        let deletedAt = SQLiteStore.date(at: 16, statement: statement)

        return TaskItem(
            id: id,
            title: title,
            notes: notes,
            status: TaskStatus(rawValue: statusRaw) ?? .todo,
            priority: TaskPriority(rawValue: priorityRaw) ?? .normal,
            createdAt: createdAt,
            updatedAt: updatedAt,
            startAt: startAt,
            dueAt: dueAt,
            completedAt: completedAt,
            projectId: projectId,
            sectionId: sectionId,
            sortOrder: sortOrder,
            estimateMinutes: estimateMinutes,
            recurrenceRule: recurrenceRule,
            parentTaskId: parentTaskId,
            deletedAt: deletedAt,
            tags: []
        )
    }

    /// Calculates productivity insights based on local task history.
    public func fetchProductivityInsights() throws -> ProductivityInsights {
        let calendar = Calendar.current
        let now = Date()

        let allTasks = try fetchTasks(filter: TaskFilter(includeDeleted: false))
        let completedTasks = allTasks.filter { $0.isCompleted }
        let openTasks = allTasks.filter { !$0.isCompleted }

        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        let completedThisWeek = completedTasks.filter { task in
            guard let comp = task.completedAt else { return false }
            return comp >= startOfWeek
        }.count

        let completedThisMonth = completedTasks.filter { task in
            guard let comp = task.completedAt else { return false }
            return comp >= startOfMonth
        }.count

        let overdueCount = openTasks.filter { $0.isOverdue }.count
        let totalCount = allTasks.count
        let completionRate = totalCount > 0 ? Double(completedTasks.count) / Double(totalCount) : 0.0

        var priorityCounts: [TaskPriority: Int] = [:]
        for prio in TaskPriority.allCases {
            priorityCounts[prio] = openTasks.filter { $0.priority == prio }.count
        }

        // Weekly trend (last 7 days)
        var weeklyTrend: [TrendPoint] = []
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let count = completedTasks.filter { task in
                guard let comp = task.completedAt else { return false }
                return comp >= dayStart && comp < dayEnd
            }.count

            weeklyTrend.append(TrendPoint(label: dayFormatter.string(from: date), count: count, date: date))
        }

        // Heatmap (last 12 weeks / 84 days)
        var heatmapDays: [HeatmapDay] = []
        for dayOffset in (0..<84).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let count = completedTasks.filter { task in
                guard let comp = task.completedAt else { return false }
                return comp >= dayStart && comp < dayEnd
            }.count

            heatmapDays.append(HeatmapDay(date: date, count: count, calendar: calendar))
        }

        return ProductivityInsights(
            totalCompleted: completedTasks.count,
            completedThisWeek: completedThisWeek,
            completedThisMonth: completedThisMonth,
            completionRate: completionRate,
            overdueCount: overdueCount,
            openCount: openTasks.count,
            priorityCounts: priorityCounts,
            weeklyTrend: weeklyTrend,
            heatmapDays: heatmapDays
        )
    }
}
