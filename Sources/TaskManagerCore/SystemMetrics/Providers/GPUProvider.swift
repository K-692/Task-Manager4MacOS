import Foundation
import Metal
import IOKit

/// Live snapshot of GPU utilization, memory usage, and hardware device specs.
public struct GPUMetrics: Codable, Sendable {
    public let deviceName: String
    public let utilizationPercent: Double
    public let rendererUtilizationPercent: Double
    public let tilerUtilizationPercent: Double
    public let allocatedMemoryBytes: UInt64
    public let inUseMemoryBytes: UInt64
    public let hasUnifiedMemory: Bool
    public let coreCount: Int?

    public init(
        deviceName: String,
        utilizationPercent: Double,
        rendererUtilizationPercent: Double = 0.0,
        tilerUtilizationPercent: Double = 0.0,
        allocatedMemoryBytes: UInt64 = 0,
        inUseMemoryBytes: UInt64 = 0,
        hasUnifiedMemory: Bool = true,
        coreCount: Int? = nil
    ) {
        self.deviceName = deviceName
        self.utilizationPercent = min(100.0, max(0.0, utilizationPercent))
        self.rendererUtilizationPercent = min(100.0, max(0.0, rendererUtilizationPercent))
        self.tilerUtilizationPercent = min(100.0, max(0.0, tilerUtilizationPercent))
        self.allocatedMemoryBytes = allocatedMemoryBytes
        self.inUseMemoryBytes = inUseMemoryBytes
        self.hasUnifiedMemory = hasUnifiedMemory
        self.coreCount = coreCount
    }

    public var formattedInUseMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(inUseMemoryBytes), countStyle: .memory)
    }

    public var formattedAllocatedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(allocatedMemoryBytes), countStyle: .memory)
    }
}

/// Provider for GPU telemetry using IOKit IOAccelerator and Apple Metal.
public final class GPUProvider: @unchecked Sendable {
    private let lock = NSLock()
    public let primaryDeviceName: String
    public let hasUnifiedMemory: Bool
    public let recommendedMaxWorkingSetSize: UInt64

    public init() {
        let metalDevices = MTLCopyAllDevices()
        if let primary = metalDevices.first {
            self.primaryDeviceName = primary.name
            self.hasUnifiedMemory = primary.hasUnifiedMemory
            self.recommendedMaxWorkingSetSize = primary.recommendedMaxWorkingSetSize
        } else {
            self.primaryDeviceName = "Apple Silicon GPU"
            self.hasUnifiedMemory = true
            self.recommendedMaxWorkingSetSize = 0
        }
    }

    /// Samples live GPU utilization and allocated memory.
    public func sample() -> MetricSample<GPUMetrics> {
        lock.lock()
        defer { lock.unlock() }

        var utilization = 0.0
        var rendererUtil = 0.0
        var tilerUtil = 0.0
        var allocMem: UInt64 = 0
        var inUseMem: UInt64 = 0

        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")

        if IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == kIOReturnSuccess {
            var entry = IOIteratorNext(iterator)
            while entry != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any] {
                    if let stats = dict["PerformanceStatistics"] as? [String: Any] {
                        if let deviceUtil = stats["Device Utilization %"] as? Double {
                            utilization = max(utilization, deviceUtil)
                        } else if let deviceUtil = stats["Device Utilization %"] as? Int {
                            utilization = max(utilization, Double(deviceUtil))
                        }

                        if let rendUtil = stats["Renderer Utilization %"] as? Double {
                            rendererUtil = max(rendererUtil, rendUtil)
                        } else if let rendUtil = stats["Renderer Utilization %"] as? Int {
                            rendererUtil = max(rendererUtil, Double(rendUtil))
                        }

                        if let tiler = stats["Tiler Utilization %"] as? Double {
                            tilerUtil = max(tilerUtil, tiler)
                        } else if let tiler = stats["Tiler Utilization %"] as? Int {
                            tilerUtil = max(tilerUtil, Double(tiler))
                        }

                        if let alloc = stats["Alloc system memory"] as? UInt64 {
                            allocMem = max(allocMem, alloc)
                        } else if let alloc = stats["Alloc system memory"] as? Int64 {
                            allocMem = max(allocMem, UInt64(max(0, alloc)))
                        }

                        if let inUse = stats["In use system memory"] as? UInt64 {
                            inUseMem = max(inUseMem, inUse)
                        } else if let inUse = stats["In use system memory"] as? Int64 {
                            inUseMem = max(inUseMem, UInt64(max(0, inUse)))
                        }
                    }
                }
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }

        // Metal fallback memory if IOKit didn't provide it
        if inUseMem == 0 {
            let devices = MTLCopyAllDevices()
            if let primary = devices.first {
                inUseMem = UInt64(primary.currentAllocatedSize)
            }
        }

        let metrics = GPUMetrics(
            deviceName: primaryDeviceName,
            utilizationPercent: utilization,
            rendererUtilizationPercent: rendererUtil,
            tilerUtilizationPercent: tilerUtil,
            allocatedMemoryBytes: allocMem,
            inUseMemoryBytes: inUseMem,
            hasUnifiedMemory: hasUnifiedMemory
        )

        return MetricSample(
            value: metrics,
            unit: "%",
            source: "IOKit IOAccelerator / Metal",
            confidence: .exact,
            status: .available
        )
    }
}
