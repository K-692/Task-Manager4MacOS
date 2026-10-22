import Foundation

/// Runtime representation of the host Mac hardware and system facts.
public struct DeviceProfile: Codable, Sendable {
    public let deviceProfileId: UUID
    public let modelIdentifier: String
    public let marketingName: String
    public let osVersion: String
    public let osBuild: String
    public let architecture: String
    public let cpuName: String
    public let logicalCores: Int
    public let physicalCores: Int
    public let totalMemoryBytes: UInt64
    public let uptimeSeconds: TimeInterval
    public let bootTime: Date
    public let gpuNames: [String]
    public let displayCount: Int
    public let isAppleSilicon: Bool
    public let isLaptop: Bool

    public init(
        deviceProfileId: UUID = UUID(),
        modelIdentifier: String,
        marketingName: String,
        osVersion: String,
        osBuild: String,
        architecture: String,
        cpuName: String,
        logicalCores: Int,
        physicalCores: Int,
        totalMemoryBytes: UInt64,
        uptimeSeconds: TimeInterval,
        bootTime: Date,
        gpuNames: [String],
        displayCount: Int,
        isAppleSilicon: Bool,
        isLaptop: Bool
    ) {
        self.deviceProfileId = deviceProfileId
        self.modelIdentifier = modelIdentifier
        self.marketingName = marketingName
        self.osVersion = osVersion
        self.osBuild = osBuild
        self.architecture = architecture
        self.cpuName = cpuName
        self.logicalCores = logicalCores
        self.physicalCores = physicalCores
        self.totalMemoryBytes = totalMemoryBytes
        self.uptimeSeconds = uptimeSeconds
        self.bootTime = bootTime
        self.gpuNames = gpuNames
        self.displayCount = displayCount
        self.isAppleSilicon = isAppleSilicon
        self.isLaptop = isLaptop
    }

    public var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalMemoryBytes), countStyle: .memory)
    }

    public var formattedUptime: String {
        let hours = Int(uptimeSeconds) / 3600
        let minutes = (Int(uptimeSeconds) % 3600) / 60
        let days = hours / 24
        if days > 0 {
            return "\(days)d \(hours % 24)h \(minutes)m"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}
