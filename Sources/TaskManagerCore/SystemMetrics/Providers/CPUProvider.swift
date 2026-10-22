import Foundation
import Darwin

/// Snapshot of CPU utilization and core topology.
public struct CPUMetrics: Codable, Sendable {
    public let totalUsagePercent: Double
    public let userPercent: Double
    public let systemPercent: Double
    public let idlePercent: Double
    public let logicalCores: Int
    public let physicalCores: Int

    public init(
        totalUsagePercent: Double,
        userPercent: Double,
        systemPercent: Double,
        idlePercent: Double,
        logicalCores: Int,
        physicalCores: Int
    ) {
        self.totalUsagePercent = min(100.0, max(0.0, totalUsagePercent))
        self.userPercent = min(100.0, max(0.0, userPercent))
        self.systemPercent = min(100.0, max(0.0, systemPercent))
        self.idlePercent = min(100.0, max(0.0, idlePercent))
        self.logicalCores = logicalCores
        self.physicalCores = physicalCores
    }
}

/// Provider for CPU metrics using Mach host statistics and sysctl.
public final class CPUProvider: @unchecked Sendable {
    private var previousCPULoad: host_cpu_load_info?
    private let lock = NSLock()

    public let logicalCores: Int
    public let physicalCores: Int

    public init() {
        var logical: Int32 = 0
        var sizeLogical = MemoryLayout<Int32>.size
        if sysctlbyname("hw.logicalcpu", &logical, &sizeLogical, nil, 0) != 0 {
            logical = Int32(ProcessInfo.processInfo.activeProcessorCount)
        }
        self.logicalCores = max(1, Int(logical))

        var physical: Int32 = 0
        var sizePhysical = MemoryLayout<Int32>.size
        if sysctlbyname("hw.physicalcpu", &physical, &sizePhysical, nil, 0) != 0 {
            physical = logical
        }
        self.physicalCores = max(1, Int(physical))
    }

    /// Samples current CPU utilization by calculating delta ticks from previous sample.
    public func sample() -> MetricSample<CPUMetrics> {
        lock.lock()
        defer { lock.unlock() }

        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MetricSample(
                value: nil,
                unit: "%",
                source: "host_statistics(HOST_CPU_LOAD_INFO)",
                confidence: .exact,
                status: .probeFailed(code: "\(result)", userSafeMessage: "Unable to read Mach host CPU load"),
                reason: "Kernel call failed with code \(result)"
            )
        }

        guard let prev = previousCPULoad else {
            previousCPULoad = cpuLoad
            let initial = CPUMetrics(
                totalUsagePercent: 0.0,
                userPercent: 0.0,
                systemPercent: 0.0,
                idlePercent: 100.0,
                logicalCores: logicalCores,
                physicalCores: physicalCores
            )
            return MetricSample(
                value: initial,
                unit: "%",
                source: "host_statistics(HOST_CPU_LOAD_INFO)",
                confidence: .derived,
                status: .available,
                reason: "Baseline sample initialized"
            )
        }

        previousCPULoad = cpuLoad

        let userDelta = Double(cpuLoad.cpu_ticks.0 - prev.cpu_ticks.0)
        let systemDelta = Double(cpuLoad.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDelta = Double(cpuLoad.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDelta = Double(cpuLoad.cpu_ticks.3 - prev.cpu_ticks.3)

        let totalTicks = userDelta + systemDelta + idleDelta + niceDelta
        guard totalTicks > 0 else {
            return MetricSample(
                value: CPUMetrics(totalUsagePercent: 0, userPercent: 0, systemPercent: 0, idlePercent: 100, logicalCores: logicalCores, physicalCores: physicalCores),
                unit: "%",
                source: "host_statistics(HOST_CPU_LOAD_INFO)",
                confidence: .derived,
                status: .available
            )
        }

        let userPercent = (userDelta / totalTicks) * 100.0
        let systemPercent = (systemDelta / totalTicks) * 100.0
        let nicePercent = (niceDelta / totalTicks) * 100.0
        let idlePercent = (idleDelta / totalTicks) * 100.0
        let totalUsage = userPercent + systemPercent + nicePercent

        let metrics = CPUMetrics(
            totalUsagePercent: totalUsage,
            userPercent: userPercent,
            systemPercent: systemPercent,
            idlePercent: idlePercent,
            logicalCores: logicalCores,
            physicalCores: physicalCores
        )

        return MetricSample(
            value: metrics,
            unit: "%",
            source: "host_statistics(HOST_CPU_LOAD_INFO)",
            confidence: .derived,
            status: .available
        )
    }
}
