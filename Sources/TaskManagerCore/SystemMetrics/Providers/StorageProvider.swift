import Foundation

/// Snapshot of an individual mounted volume.
public struct VolumeInfo: Identifiable, Codable, Sendable {
    public var id: String { mountPath }
    public let name: String
    public let mountPath: String
    public let totalBytes: UInt64
    public let availableBytes: UInt64
    public let fileSystemType: String
    public let isRemovable: Bool
    public let isRoot: Bool

    public init(
        name: String,
        mountPath: String,
        totalBytes: UInt64,
        availableBytes: UInt64,
        fileSystemType: String,
        isRemovable: Bool,
        isRoot: Bool
    ) {
        self.name = name
        self.mountPath = mountPath
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.fileSystemType = fileSystemType
        self.isRemovable = isRemovable
        self.isRoot = isRoot
    }

    public var usedBytes: UInt64 {
        totalBytes > availableBytes ? totalBytes - availableBytes : 0
    }

    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }

    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }

    public var formattedAvailable: String {
        ByteCountFormatter.string(fromByteCount: Int64(availableBytes), countStyle: .file)
    }

    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .file)
    }
}

/// Provider for Storage metrics using FileManager.
public final class StorageProvider: Sendable {
    public init() {}

    public func sample() -> MetricSample<[VolumeInfo]> {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeLocalizedFormatDescriptionKey,
            .volumeIsRootFileSystemKey
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return MetricSample(
                value: nil,
                unit: "Volumes",
                source: "FileManager.mountedVolumeURLs",
                confidence: .exact,
                status: .probeFailed(code: "STORAGE_ERR", userSafeMessage: "Unable to enumerate mounted volumes"),
                reason: "FileManager returned nil for mounted volumes"
            )
        }

        var volumes: [VolumeInfo] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let name = values.volumeName ?? url.lastPathComponent
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let available = UInt64(values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0))
            let format = values.volumeLocalizedFormatDescription ?? "APFS"
            let removable = values.volumeIsRemovable ?? false
            let isRoot = values.volumeIsRootFileSystem ?? (url.path == "/")

            guard total > 0 else { continue }

            volumes.append(VolumeInfo(
                name: name,
                mountPath: url.path,
                totalBytes: total,
                availableBytes: available,
                fileSystemType: format,
                isRemovable: removable,
                isRoot: isRoot
            ))
        }

        // Sort so root volume is first
        volumes.sort { $0.isRoot && !$1.isRoot }

        return MetricSample(
            value: volumes,
            unit: "Volumes",
            source: "FileManager.resourceValues(URLResourceKey)",
            confidence: .exact,
            status: .available
        )
    }
}
