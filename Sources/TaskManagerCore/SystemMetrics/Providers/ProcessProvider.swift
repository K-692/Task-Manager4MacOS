import Foundation
import AppKit
import Darwin
import Darwin.libproc

/// Snapshot of a running process or application.
public struct ProcessItem: Identifiable, Codable, Sendable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let bundleIdentifier: String?
    public let isActive: Bool
    public let isHidden: Bool
    public let cpuPercent: Double
    public let residentMemoryBytes: UInt64?
    public let launchDate: Date?
    public let architecture: String

    public init(
        pid: Int32,
        name: String,
        bundleIdentifier: String? = nil,
        isActive: Bool = false,
        isHidden: Bool = false,
        cpuPercent: Double = 0.0,
        residentMemoryBytes: UInt64? = nil,
        launchDate: Date? = nil,
        architecture: String = "Apple Silicon"
    ) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isActive = isActive
        self.isHidden = isHidden
        self.cpuPercent = max(0.0, cpuPercent)
        self.residentMemoryBytes = residentMemoryBytes
        self.launchDate = launchDate
        self.architecture = architecture
    }

    public var formattedMemory: String {
        guard let mem = residentMemoryBytes, mem > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(mem), countStyle: .memory)
    }

    public var formattedCPU: String {
        if cpuPercent > 0.05 {
            return String(format: "%.1f%%", cpuPercent)
        } else {
            return "< 0.1%"
        }
    }
}

/// Provider for inspecting and managing running processes and applications.
public final class ProcessProvider: @unchecked Sendable {
    private struct PreviousCPU {
        let totalTime: UInt64
        let timestamp: Date
    }

    private var previousCPUs: [Int32: PreviousCPU] = [:]
    private let lock = NSLock()

    public init() {}

    public func sample() -> MetricSample<[ProcessItem]> {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
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
            var cpuUsage = 0.0

            var taskInfo = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            if proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size) == size {
                residentMemory = UInt64(taskInfo.pti_resident_size)

                let totalTime = taskInfo.pti_total_user + taskInfo.pti_total_system
                if let prev = previousCPUs[pid] {
                    let dt = now.timeIntervalSince(prev.timestamp)
                    if dt > 0.1 && totalTime >= prev.totalTime {
                        let deltaNs = Double(totalTime - prev.totalTime)
                        // pti times are in nanoseconds
                        let cpuFrac = (deltaNs / 1_000_000_000.0) / dt
                        cpuUsage = min(100.0, cpuFrac * 100.0)
                    }
                }
                previousCPUs[pid] = PreviousCPU(totalTime: totalTime, timestamp: now)
            }

            #if arch(arm64)
            let arch = "Apple"
            #else
            let arch = "Intel"
            #endif

            processList.append(ProcessItem(
                pid: pid,
                name: name,
                bundleIdentifier: bundleId,
                isActive: isActive,
                isHidden: isHidden,
                cpuPercent: cpuUsage,
                residentMemoryBytes: residentMemory,
                launchDate: launchDate,
                architecture: arch
            ))
        }

        // Clean up dead PIDs from previousCPUs
        let currentPIDs = Set(processList.map { $0.pid })
        previousCPUs = previousCPUs.filter { currentPIDs.contains($0.key) }

        // Sort by memory usage descending by default
        processList.sort {
            if $0.isActive != $1.isActive {
                return $0.isActive && !$1.isActive
            }
            let m0 = $0.residentMemoryBytes ?? 0
            let m1 = $1.residentMemoryBytes ?? 0
            return m0 > m1
        }

        return MetricSample(
            value: processList,
            unit: "Processes",
            source: "NSWorkspace / libproc",
            confidence: .exact,
            status: .available
        )
    }

    /// Terminates a process (Windows Task Manager "End Task" functionality).
    public func terminateProcess(pid: Int32, force: Bool = false) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid) {
            if force {
                return app.forceTerminate()
            } else {
                let success = app.terminate()
                if !success {
                    return app.forceTerminate()
                }
                return true
            }
        } else {
            let sig = force ? SIGKILL : SIGTERM
            return kill(pid, sig) == 0
        }
    }
}
