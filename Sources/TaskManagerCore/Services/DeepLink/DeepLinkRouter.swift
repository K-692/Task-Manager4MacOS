import Foundation

/// Navigation destinations matching the native Task Manager tabs.
public enum AppDestination: Hashable, Codable, Sendable {
    case dashboard
    case processes
    case startupApps
    case settings
}

/// Router parsing and resolving deep links into app navigation destinations.
public struct DeepLinkRouter {
    public init() {}

    public static func destination(from url: URL) -> AppDestination? {
        guard url.scheme?.lowercased() == "taskmanager" else { return nil }

        let host = url.host?.lowercased() ?? ""

        switch host {
        case "dashboard", "performance", "hardware":
            return .dashboard
        case "processes":
            return .processes
        case "startup":
            return .startupApps
        case "settings":
            return .settings
        default:
            return .dashboard
        }
    }
}
