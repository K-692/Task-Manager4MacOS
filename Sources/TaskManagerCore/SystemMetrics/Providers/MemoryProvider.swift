import Foundation
import Darwin

/// Snapshot of host VM memory usage and memory pressure.
public struct MemoryMetrics: Codable, Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64
    public let activeBytes: UInt64
    public let inactiveBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let pressureLevel: String // "Normal", "Warning", "Critical", "Unknown"

    public init(
        totalBytes: UInt64,
        usedBytes: UInt64,
        freeBytes: UInt64,
        activeBytes: UInt64,
        inactiveBytes: UInt64,
        wiredBytes: UInt64,
        compressedBytes: UInt64,
        pressureLevel: String
    ) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.pressureLevel = pressureLevel
    }

    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }

    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory)
    }

    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory)
    }
}

/// Provider for Memory metrics using Mach VM statistics and system pressure.
public final class MemoryProvider: Sendable {
    public let totalPhysicalMemory: UInt64

    public init() {
        self.totalPhysicalMemory = ProcessInfo.processInfo.physicalMemory
    }

    public func sample() -> MetricSample<MemoryMetrics> {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MetricSample(
                value: nil,
                unit: "Bytes",
                source: "host_statistics64(HOST_VM_INFO64)",
                confidence: .exact,
                status: .probeFailed(code: "\(result)", userSafeMessage: "Unable to read Mach VM statistics"),
                reason: "Kernel call failed with code \(result)"
            )
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let free = UInt64(vmStats.free_count) * pageSize

        // According to SAS: "RAM used" is defined as active + wired + compressed
        let used = min(totalPhysicalMemory, active + wired + compressed)

        // Memory pressure check via sysctl
        var pressureVal: Int32 = 0
        var size = MemoryLayout<Int32>.size
        var pressureString = "Normal"
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureVal, &size, nil, 0) == 0 {
            switch pressureVal {
            case 1: pressureString = "Normal"
            case 2: pressureString = "Warning"
            case 4: pressureString = "Critical"
            default: pressureString = "Normal"
            }
        }

        let metrics = MemoryMetrics(
            totalBytes: totalPhysicalMemory,
            usedBytes: used,
            freeBytes: free,
            activeBytes: active,
            inactiveBytes: inactive,
            wiredBytes: wired,
            compressedBytes: compressed,
            pressureLevel: pressureString
        )

        return MetricSample(
            value: metrics,
            unit: "Bytes",
            source: "host_statistics64(HOST_VM_INFO64)",
            confidence: .derived,
            status: .available,
            reason: "Used memory computed as active + wired + compressed pages"
        )
    }
}
