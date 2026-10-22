import Foundation
import UserNotifications

/// Service for managing local macOS notifications and task reminders.
public final class NotificationService: Sendable {
    public init() {}

    /// Checks current notification authorization status.
    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Requests notification permissions only when triggered by user intent.
    public func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Schedules a local notification reminder for a task.
    public func scheduleReminder(taskId: UUID, title: String, notes: String?, fireAt: Date) async throws -> String {
        let center = UNUserNotificationCenter.current()
        let identifier = "task-reminder-\(taskId.uuidString)"

        let content = UNMutableNotificationContent()
        content.title = title
        if let notes = notes, !notes.isEmpty {
            content.body = notes
        } else {
            content.body = "Reminder for this task"
        }
        content.sound = .default
        content.userInfo = ["taskId": taskId.uuidString]

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
        return identifier
    }

    /// Cancels a scheduled reminder.
    public func cancelReminder(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
