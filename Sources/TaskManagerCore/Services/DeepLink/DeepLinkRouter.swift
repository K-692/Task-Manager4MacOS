import Foundation

/// Navigation destinations matching the native Task Manager tabs.
public enum AppDestination: Hashable, Codable, Sendable {
    case processes
    case performance(PerformanceSubtab = .cpu)
    case appHistory
    case startupApps
    case hardware
    case settings
}

public enum PerformanceSubtab: String, Hashable, Codable, CaseIterable, Sendable {
    case cpu = "CPU"
    case memory = "Memory"
    case gpu = "GPU"
    case disk = "Disk"
    case network = "Network"

    public var systemImage: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .gpu: return "display.trianglebadge.exclamationmark"
        case .disk: return "internaldrive"
        case .network: return "network"
        }
    }
}

/// Router parsing and resolving deep links into app navigation destinations.
public struct DeepLinkRouter {
    public init() {}

    public static func destination(from url: URL) -> AppDestination? {
        guard url.scheme?.lowercased() == "taskmanager" else { return nil }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()

        switch host {
        case "processes":
            return .processes
        case "performance":
            switch path {
            case "gpu": return .performance(.gpu)
            case "memory": return .performance(.memory)
            case "disk": return .performance(.disk)
            case "network": return .performance(.network)
            default: return .performance(.cpu)
            }
        case "history":
            return .appHistory
        case "startup":
            return .startupApps
        case "hardware":
            return .hardware
        case "settings":
            return .settings
        default:
            return .processes
        }
    }
}
