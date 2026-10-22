import Foundation

/// Defines standard recurrence frequencies supported by Task Manager.
public enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case weekdays = "WEEKDAYS"

    public var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .weekdays: return "Every Weekday (Mon-Fri)"
        }
    }
}

/// Represents a structured recurrence rule.
public struct RecurrenceRule: Codable, Hashable, Sendable {
    public var frequency: RecurrenceFrequency
    public var interval: Int
    public var endDate: Date?

    public init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        endDate: Date? = nil
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.endDate = endDate
    }

    /// Serializes to a standard recurrence string (e.g., "FREQ=DAILY;INTERVAL=1").
    public var ruleString: String {
        var str = "FREQ=\(frequency.rawValue);INTERVAL=\(interval)"
        if let endDate = endDate {
            let formatter = ISO8601DateFormatter()
            str += ";UNTIL=\(formatter.string(from: endDate))"
        }
        return str
    }

    /// Parses a serialized recurrence string.
    public static func parse(_ string: String) -> RecurrenceRule? {
        let parts = string.components(separatedBy: ";")
        var freq: RecurrenceFrequency?
        var interval = 1
        var until: Date?

        for part in parts {
            let keyValue = part.components(separatedBy: "=")
            guard keyValue.count == 2 else { continue }
            let key = keyValue[0].uppercased()
            let val = keyValue[1]

            switch key {
            case "FREQ":
                freq = RecurrenceFrequency(rawValue: val.uppercased())
            case "INTERVAL":
                interval = Int(val) ?? 1
            case "UNTIL":
                until = ISO8601DateFormatter().date(from: val)
            default:
                break
            }
        }

        guard let frequency = freq else { return nil }
        return RecurrenceRule(frequency: frequency, interval: interval, endDate: until)
    }
}

/// Engine to calculate next occurrences for recurring tasks.
public struct RecurrenceEngine {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Calculates the next due date based on the rule and reference date.
    /// To prevent recurrence storms, if the reference date is in the past,
    /// it advances from the current date or reference date to the next valid upcoming occurrence.
    public func nextDueDate(for rule: RecurrenceRule, after baseDate: Date, from now: Date = Date()) -> Date? {
        var next = baseDate

        repeat {
            guard let advanced = advanceOnce(from: next, rule: rule) else { return nil }
            next = advanced
            if let until = rule.endDate, next > until {
                return nil
            }
        } while next <= baseDate || (next < now && calendar.isDateInToday(next) == false && next < calendar.startOfDay(for: now))

        return next
    }

    private func advanceOnce(from date: Date, rule: RecurrenceRule) -> Date? {
        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: rule.interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: rule.interval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: rule.interval, to: date)
        case .weekdays:
            var current = date
            for _ in 0..<rule.interval {
                repeat {
                    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: current) else { return nil }
                    current = tomorrow
                } while calendar.isDateInWeekend(current)
            }
            return current
        }
    }
}
