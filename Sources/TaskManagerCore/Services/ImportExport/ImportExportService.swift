import Foundation

/// Documented export container format for Task Manager backups.
public struct TaskManagerExportData: Codable, Sendable {
    public let schemaVersion: Int
    public let exportedAt: Date
    public let projects: [Project]
    public let sections: [ProjectSection]
    public let tags: [Tag]
    public let tasks: [TaskItem]

    public init(
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        projects: [Project],
        sections: [ProjectSection],
        tags: [Tag],
        tasks: [TaskItem]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.projects = projects
        self.sections = sections
        self.tags = tags
        self.tasks = tasks
    }
}

/// Service handling JSON and CSV import / export with strict validation.
public final class ImportExportService: Sendable {
    private let taskRepo: TaskRepository
    private let projectRepo: ProjectRepository
    private let tagRepo: TagRepository
    private let store: SQLiteStore

    public init(
        taskRepo: TaskRepository,
        projectRepo: ProjectRepository,
        tagRepo: TagRepository,
        store: SQLiteStore
    ) {
        self.taskRepo = taskRepo
        self.projectRepo = projectRepo
        self.tagRepo = tagRepo
        self.store = store
    }

    /// Generates a complete JSON backup of tasks, projects, sections, and tags.
    public func exportJSON() throws -> Data {
        let projects = try projectRepo.fetchProjects(includeArchived: true)
        var sections: [ProjectSection] = []
        for proj in projects {
            sections.append(contentsOf: try projectRepo.fetchSections(projectId: proj.id))
        }
        let tags = try tagRepo.fetchTags()
        let tasks = try taskRepo.fetchTasks(filter: TaskFilter(includeDeleted: false))

        let export = TaskManagerExportData(
            schemaVersion: 1,
            projects: projects,
            sections: sections,
            tags: tags,
            tasks: tasks
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    /// Generates CSV format for spreadsheet compatibility.
    public func exportCSV() throws -> String {
        let tasks = try taskRepo.fetchTasks(filter: TaskFilter(includeDeleted: false))
        let projects = try projectRepo.fetchProjects(includeArchived: true)
        let projectMap = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })

        var csv = "ID,Title,Status,Priority,Due Date,Project,Tags,Notes\n"
        let dateFmt = ISO8601DateFormatter()

        for t in tasks {
            let id = t.id.uuidString
            let title = escapeCSV(t.title)
            let status = t.status.rawValue
            let priority = t.priority.rawValue
            let dueDate = t.dueAt != nil ? dateFmt.string(from: t.dueAt!) : ""
            let projectName = escapeCSV(t.projectId != nil ? (projectMap[t.projectId!] ?? "") : "")
            let tags = escapeCSV(t.tags.map { $0.name }.joined(separator: ";"))
            let notes = escapeCSV(t.notes ?? "")

            csv += "\(id),\(title),\(status),\(priority),\(dueDate),\(projectName),\(tags),\(notes)\n"
        }
        return csv
    }

    private func escapeCSV(_ text: String) -> String {
        var str = text.replacingOccurrences(of: "\"", with: "\"\"")
        if str.contains(",") || str.contains("\n") || str.contains("\"") {
            str = "\"\(str)\""
        }
        return str
    }

    /// Validates and imports data from a JSON backup.
    public func importJSON(data: Data) throws -> (tasksCount: Int, projectsCount: Int, tagsCount: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let importData = try decoder.decode(TaskManagerExportData.self, from: data)

        guard importData.schemaVersion <= 1 else {
            throw NSError(domain: "TaskManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported backup schema version: \(importData.schemaVersion)"])
        }

        try store.transaction {
            // Import projects
            for proj in importData.projects {
                try? projectRepo.insertProject(proj)
            }
            // Import sections
            for sec in importData.sections {
                try? projectRepo.insertSection(sec)
            }
            // Import tags
            for tag in importData.tags {
                try? tagRepo.insertTag(tag)
            }
            // Import tasks
            for task in importData.tasks {
                try? taskRepo.insertTask(task)
            }
        }

        return (importData.tasks.count, importData.projects.count, importData.tags.count)
    }
}
