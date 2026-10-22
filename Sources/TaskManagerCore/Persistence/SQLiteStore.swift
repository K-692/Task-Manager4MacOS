import Foundation
import SQLite3

public enum SQLiteError: Error, LocalizedError {
    case openDatabase(String)
    case prepareStatement(String)
    case step(String)
    case bind(String)
    case migrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openDatabase(let msg): return "Failed to open SQLite database: \(msg)"
        case .prepareStatement(let msg): return "Failed to prepare SQLite statement: \(msg)"
        case .step(let msg): return "Failed to execute SQLite step: \(msg)"
        case .bind(let msg): return "Failed to bind parameter: \(msg)"
        case .migrationFailed(let msg): return "SQLite migration failed: \(msg)"
        }
    }
}

/// A lightweight, thread-safe SQLite connection wrapper using Apple's native libsqlite3.
public final class SQLiteStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSRecursiveLock()
    public let databaseURL: URL?

    public init(databaseURL: URL? = nil) throws {
        self.databaseURL = databaseURL
        let path = databaseURL?.path ?? ":memory:"

        if let dbURL = databaseURL {
            let directory = dbURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &dbPointer, flags, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(dbPointer))
            sqlite3_close(dbPointer)
            throw SQLiteError.openDatabase(errmsg)
        }
        self.db = dbPointer

        // Enable Foreign Keys & WAL mode for performance and safety
        try execute(sql: "PRAGMA foreign_keys = ON;")
        if databaseURL != nil {
            try execute(sql: "PRAGMA journal_mode = WAL;")
        }
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    public func execute(sql: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var errmsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errmsg) != SQLITE_OK {
            let message = errmsg != nil ? String(cString: errmsg!) : "Unknown error"
            sqlite3_free(errmsg)
            throw SQLiteError.step(message)
        }
    }

    public func transaction<T>(_ block: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }

        try executeRaw(sql: "BEGIN TRANSACTION;")
        do {
            let result = try block()
            try executeRaw(sql: "COMMIT;")
            return result
        } catch {
            try executeRaw(sql: "ROLLBACK;")
            throw error
        }
    }

    private func executeRaw(sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errmsg) != SQLITE_OK {
            let message = errmsg != nil ? String(cString: errmsg!) : "Unknown error"
            sqlite3_free(errmsg)
            throw SQLiteError.step(message)
        }
    }

    public func query<T>(
        sql: String,
        bindings: [Any?] = [],
        transform: (OpaquePointer) throws -> T
    ) throws -> [T] {
        lock.lock()
        defer { lock.unlock() }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.prepareStatement(errmsg)
        }
        defer { sqlite3_finalize(statement) }

        try bindParameters(statement: statement!, bindings: bindings)

        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let item = try transform(statement!)
            results.append(item)
        }
        return results
    }

    public func executeUpdate(sql: String, bindings: [Any?] = []) throws {
        lock.lock()
        defer { lock.unlock() }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.prepareStatement(errmsg)
        }
        defer { sqlite3_finalize(statement) }

        try bindParameters(statement: statement!, bindings: bindings)

        let stepResult = sqlite3_step(statement)
        if stepResult != SQLITE_DONE && stepResult != SQLITE_ROW {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.step(errmsg)
        }
    }

    private func bindParameters(statement: OpaquePointer, bindings: [Any?]) throws {
        for (index, value) in bindings.enumerated() {
            let idx = Int32(index + 1)
            guard let val = value else {
                sqlite3_bind_null(statement, idx)
                continue
            }

            if let stringVal = val as? String {
                sqlite3_bind_text(statement, idx, (stringVal as NSString).utf8String, -1, nil)
            } else if let intVal = val as? Int {
                sqlite3_bind_int64(statement, idx, Int64(intVal))
            } else if let int64Val = val as? Int64 {
                sqlite3_bind_int64(statement, idx, int64Val)
            } else if let doubleVal = val as? Double {
                sqlite3_bind_double(statement, idx, doubleVal)
            } else if let boolVal = val as? Bool {
                sqlite3_bind_int(statement, idx, boolVal ? 1 : 0)
            } else if let dateVal = val as? Date {
                sqlite3_bind_double(statement, idx, dateVal.timeIntervalSince1970)
            } else if let uuidVal = val as? UUID {
                sqlite3_bind_text(statement, idx, (uuidVal.uuidString as NSString).utf8String, -1, nil)
            } else {
                throw SQLiteError.bind("Unsupported binding type at index \(index): \(type(of: val))")
            }
        }
    }

    // Helper Column Readers
    public static func text(at column: Int32, statement: OpaquePointer) -> String? {
        guard let cString = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: cString)
    }

    public static func int(at column: Int32, statement: OpaquePointer) -> Int? {
        if sqlite3_column_type(statement, column) == SQLITE_NULL { return nil }
        return Int(sqlite3_column_int64(statement, column))
    }

    public static func double(at column: Int32, statement: OpaquePointer) -> Double? {
        if sqlite3_column_type(statement, column) == SQLITE_NULL { return nil }
        return sqlite3_column_double(statement, column)
    }

    public static func date(at column: Int32, statement: OpaquePointer) -> Date? {
        guard let interval = double(at: column, statement: statement) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    public static func uuid(at column: Int32, statement: OpaquePointer) -> UUID? {
        guard let str = text(at: column, statement: statement) else { return nil }
        return UUID(uuidString: str)
    }
}
