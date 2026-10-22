import Foundation

/// Data confidence level according to the Task Manager SAS specification.
public enum DataConfidence: String, Codable, Sendable {
    case exact
    case derived
    case partial
}

/// Explicit hardware and system metric capability status.
/// Never substitute zero or guess when an API is unsupported or restricted.
public enum CapabilityStatus: Codable, Hashable, Sendable {
    case available
    case notPresent
    case unsupportedByOS
    case notExposedBySupportedAPI
    case restricted(reason: String)
    case permissionRequired(permission: String)
    case temporarilyUnavailable(reason: String)
    case probeFailed(code: String, userSafeMessage: String)

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    public var label: String {
        switch self {
        case .available:
            return "Available"
        case .notPresent:
            return "Not Present"
        case .unsupportedByOS:
            return "Unsupported by macOS"
        case .notExposedBySupportedAPI:
            return "Not Exposed by Apple API"
        case .restricted(let reason):
            return "Restricted (\(reason))"
        case .permissionRequired(let permission):
            return "Permission Required: \(permission)"
        case .temporarilyUnavailable(let reason):
            return "Temporarily Unavailable (\(reason))"
        case .probeFailed(_, let msg):
            return "Probe Failed (\(msg))"
        }
    }
}

/// Structured metric sample guaranteeing provenance, confidence, and timestamp.
public struct MetricSample<T: Codable & Sendable>: Codable, Sendable {
    public let value: T?
    public let unit: String
    public let observedAt: Date
    public let source: String
    public let confidence: DataConfidence
    public let status: CapabilityStatus
    public let reason: String?

    public init(
        value: T?,
        unit: String,
        observedAt: Date = Date(),
        source: String,
        confidence: DataConfidence = .exact,
        status: CapabilityStatus = .available,
        reason: String? = nil
    ) {
        self.value = value
        self.unit = unit
        self.observedAt = observedAt
        self.source = source
        self.confidence = confidence
        self.status = status
        self.reason = reason
    }
}

/// Hardware category grouping for system diagnostics and hardware inventory.
public enum HardwareCategory: String, Codable, CaseIterable, Sendable {
    case compute = "compute"
    case gpu = "gpu"
    case memory = "memory"
    case displays = "displays"
    case battery = "battery"
    case storage = "storage"
    case network = "network"
    case attachedDevices = "attached_devices"
    case thermal = "thermal"
    case peripherals = "peripherals"

    public var displayName: String {
        switch self {
        case .compute: return "CPU & Compute"
        case .gpu: return "GPU & Graphics"
        case .memory: return "System Memory"
        case .displays: return "Displays"
        case .battery: return "Battery & Power"
        case .storage: return "Storage & Volumes"
        case .network: return "Network Interfaces"
        case .attachedDevices: return "Attached Devices"
        case .thermal: return "Thermal & Cooling"
        case .peripherals: return "Peripherals & Audio"
        }
    }

    public var systemImage: String {
        switch self {
        case .compute: return "cpu"
        case .gpu: return "display.trianglebadge.exclamationmark"
        case .memory: return "memorychip"
        case .displays: return "display"
        case .battery: return "battery.100"
        case .storage: return "internaldrive"
        case .network: return "network"
        case .attachedDevices: return "cable.connector"
        case .thermal: return "thermometer.medium"
        case .peripherals: return "hifispeaker"
        }
    }
}

/// General capability record used in the Hardware & Capabilities page.
public struct CapabilityRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let category: HardwareCategory
    public let displayName: String
    public let valueString: String?
    public let unit: String?
    public let status: CapabilityStatus
    public let source: String
    public let observedAt: Date?
    public let refreshedAt: Date
    public let explanation: String?
    public let confidence: DataConfidence

    public init(
        id: String,
        category: HardwareCategory,
        displayName: String,
        valueString: String?,
        unit: String? = nil,
        status: CapabilityStatus,
        source: String,
        observedAt: Date? = Date(),
        refreshedAt: Date = Date(),
        explanation: String? = nil,
        confidence: DataConfidence = .exact
    ) {
        self.id = id
        self.category = category
        self.displayName = displayName
        self.valueString = valueString
        self.unit = unit
        self.status = status
        self.source = source
        self.observedAt = observedAt
        self.refreshedAt = refreshedAt
        self.explanation = explanation
        self.confidence = confidence
    }
}
