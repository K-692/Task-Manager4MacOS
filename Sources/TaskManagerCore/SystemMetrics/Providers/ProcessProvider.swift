import Foundation
import AppKit
import Darwin
import Darwin.libproc

/// Snapshot of a running application.
public struct ProcessItem: Identifiable, Codable, Sendable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let bundleIdentifier: String?
    public let isActive: Bool
    public let isHidden: Bool
    public let launchDate: Date?
    public let residentMemoryBytes: UInt64?

    public init(
        pid: Int32,
        name: String,
        bundleIdentifier: String? = nil,
        isActive: Bool = false,
        isHidden: Bool = false,
        launchDate: Date? = nil,
        residentMemoryBytes: UInt64? = nil
    ) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isActive = isActive
        self.isHidden = isHidden
        self.launchDate = launchDate
        self.residentMemoryBytes = residentMemoryBytes
    }

    public var formattedMemory: String {
        guard let mem = residentMemoryBytes, mem > 0 else { return "Unavailable" }
        return ByteCountFormatter.string(fromByteCount: Int64(mem), countStyle: .memory)
    }
}

/// Provider for user-visible running applications using NSWorkspace and libproc.
public final class ProcessProvider: Sendable {
    public init() {}

    public func sample() -> MetricSample<[ProcessItem]> {
        let runningApps = NSWorkspace.shared.runningApplications
        var processList: [ProcessItem] = []

        for app in runningApps {
            let pid = app.processIdentifier
            guard pid > 0 else { continue }

            let name = app.localizedName ?? "Process (\(pid))"
            let bundleId = app.bundleIdentifier
            let isActive = app.isActive
            let isHidden = app.isHidden
            let launchDate = app.launchDate

            var residentMemory: UInt64? = nil
            var taskInfo = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            if proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size) == size {
                residentMemory = UInt64(taskInfo.pti_resident_size)
            }

            processList.append(ProcessItem(
                pid: pid,
                name: name,
                bundleIdentifier: bundleId,
                isActive: isActive,
                isHidden: isHidden,
                launchDate: launchDate,
                residentMemoryBytes: residentMemory
            ))
        }

        // Sort: active first, then descending by memory footprint, then by name
        processList.sort {
            if $0.isActive != $1.isActive {
                return $0.isActive && !$1.isActive
            }
            if let m0 = $0.residentMemoryBytes, let m1 = $1.residentMemoryBytes {
                return m0 > m1
            }
            return $0.name < $1.name
        }

        return MetricSample(
            value: processList,
            unit: "Processes",
            source: "NSWorkspace.runningApplications / libproc",
            confidence: .exact,
            status: .available,
            reason: "Enumerates user-visible applications and inspectable memory"
        )
    }
}
