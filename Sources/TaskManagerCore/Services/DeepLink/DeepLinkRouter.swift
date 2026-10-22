import Foundation

/// Navigation destinations supported across the Task Manager application.
public enum AppDestination: Hashable, Codable, Sendable {
    // Work
    case today
    case inbox
    case upcoming
    case allTasks
    case projects
    case project(id: UUID)
    case tags
    case tag(id: UUID)
    case completed

    // Insights
    case productivity

    // This Mac
    case macOverview
    case performance
    case storage
    case battery
    case network
    case processes
    case hardwareCapabilities
    case aboutThisMac

    // System
    case settings
}

/// Router parsing and resolving deep links into app navigation destinations.
public struct DeepLinkRouter {
    public init() {}

    public static func destination(from url: URL) -> (destination: AppDestination, openCapture: Bool)? {
        guard url.scheme?.lowercased() == "taskmanager" else { return nil }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch host {
        case "today":
            return (.today, false)
        case "inbox":
            return (.inbox, false)
        case "upcoming":
            return (.upcoming, false)
        case "all":
            return (.allTasks, false)
        case "capture":
            return (.inbox, true)
        case "productivity":
            return (.productivity, false)
        case "project":
            if let uuid = UUID(uuidString: path) {
                return (.project(id: uuid), false)
            }
            return (.projects, false)
        case "dashboard":
            switch path.lowercased() {
            case "performance": return (.performance, false)
            case "storage": return (.storage, false)
            case "battery": return (.battery, false)
            case "network": return (.network, false)
            case "processes": return (.processes, false)
            case "hardware": return (.hardwareCapabilities, false)
            case "about": return (.aboutThisMac, false)
            default: return (.macOverview, false)
            }
        case "settings":
            return (.settings, false)
        default:
            return (.today, false)
        }
    }
}
