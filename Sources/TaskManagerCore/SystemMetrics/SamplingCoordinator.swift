import Foundation
import Combine

/// Ring buffer holding a fixed number of recent numeric samples for real-time charts.
public struct MetricRingBuffer: Sendable {
    public let capacity: Int
    private var elements: [Double] = []

    public init(capacity: Int = 60) {
        self.capacity = capacity
    }

    public mutating func append(_ value: Double) {
        elements.append(value)
        if elements.count > capacity {
            elements.removeFirst()
        }
    }

    public var values: [Double] {
        elements
    }

    public var count: Int {
        elements.count
    }

    public var latest: Double? {
        elements.last
    }
}

/// Central sampling coordinator that collects hardware telemetry according to UI lifecycle.
@MainActor
public final class SamplingCoordinator: ObservableObject {
    public let cpuProvider: CPUProvider
    public let memoryProvider: MemoryProvider
    public let gpuProvider: GPUProvider
    public let storageProvider: StorageProvider
    public let batteryProvider: BatteryProvider
    public let networkProvider: NetworkProvider
    public let processProvider: ProcessProvider
    public let rollupRepository: MetricRollupRepository?

    @Published public private(set) var latestCPU: MetricSample<CPUMetrics>?
    @Published public private(set) var latestMemory: MetricSample<MemoryMetrics>?
    @Published public private(set) var latestGPU: MetricSample<GPUMetrics>?
    @Published public private(set) var latestStorage: MetricSample<[VolumeInfo]>?
    @Published public private(set) var latestBattery: MetricSample<BatteryMetrics>?
    @Published public private(set) var latestNetwork: MetricSample<NetworkMetrics>?
    @Published public private(set) var latestProcesses: MetricSample<[ProcessItem]>?

    // Rolling ring buffers for live charts (last 60 samples)
    @Published public private(set) var cpuHistory = MetricRingBuffer(capacity: 60)
    @Published public private(set) var memoryHistory = MetricRingBuffer(capacity: 60)
    @Published public private(set) var gpuHistory = MetricRingBuffer(capacity: 60)
    @Published public private(set) var networkInHistory = MetricRingBuffer(capacity: 60)
    @Published public private(set) var networkOutHistory = MetricRingBuffer(capacity: 60)

    @Published public var isDashboardActive: Bool = false {
        didSet {
            // Speed up sampling when active, slow down when in background
            if isDashboardActive {
                startSampling(interval: 1.0)
            } else {
                startSampling(interval: 3.0)
            }
        }
    }

    @Published public var samplingInterval: TimeInterval = 1.0 {
        didSet {
            startSampling(interval: samplingInterval)
        }
    }

    private var samplingTimer: Timer?
    private var rollupCounter: Int = 0

    public init(
        cpuProvider: CPUProvider = CPUProvider(),
        memoryProvider: MemoryProvider = MemoryProvider(),
        gpuProvider: GPUProvider = GPUProvider(),
        storageProvider: StorageProvider = StorageProvider(),
        batteryProvider: BatteryProvider = BatteryProvider(),
        networkProvider: NetworkProvider = NetworkProvider(),
        processProvider: ProcessProvider = ProcessProvider(),
        rollupRepository: MetricRollupRepository? = nil
    ) {
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.gpuProvider = gpuProvider
        self.storageProvider = storageProvider
        self.batteryProvider = batteryProvider
        self.networkProvider = networkProvider
        self.processProvider = processProvider
        self.rollupRepository = rollupRepository

        // Initial sample
        refreshAll()
        startSampling(interval: samplingInterval)
    }

    public func startSampling(interval: TimeInterval = 1.0) {
        stopSampling()
        samplingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    public func stopSampling() {
        samplingTimer?.invalidate()
        samplingTimer = nil
    }

    public func tick() {
        // High frequency: CPU, Memory, GPU, Network, Processes
        let cpu = cpuProvider.sample()
        let mem = memoryProvider.sample()
        let gpu = gpuProvider.sample()
        let net = networkProvider.sample()
        let proc = processProvider.sample()

        latestCPU = cpu
        latestMemory = mem
        latestGPU = gpu
        latestNetwork = net
        latestProcesses = proc

        if let cpuVal = cpu.value {
            cpuHistory.append(cpuVal.totalUsagePercent)
        }
        if let memVal = mem.value {
            memoryHistory.append(memVal.usagePercentage)
        }
        if let gpuVal = gpu.value {
            gpuHistory.append(gpuVal.utilizationPercent)
        }
        if let netVal = net.value {
            networkInHistory.append(netVal.totalBytesInPerSecond)
            networkOutHistory.append(netVal.totalBytesOutPerSecond)
        }

        rollupCounter += 1

        // Lower frequency: Storage and Battery (every 5 ticks)
        if rollupCounter % 5 == 0 {
            latestStorage = storageProvider.sample()
            latestBattery = batteryProvider.sample()
        }

        // Rollup downsampling to SQLite if history repository is present
        if rollupCounter % 60 == 0, let repo = rollupRepository {
            saveRollup(repo: repo)
        }
    }

    public func refreshAll() {
        latestCPU = cpuProvider.sample()
        latestMemory = memoryProvider.sample()
        latestGPU = gpuProvider.sample()
        latestStorage = storageProvider.sample()
        latestBattery = batteryProvider.sample()
        latestNetwork = networkProvider.sample()
        latestProcesses = processProvider.sample()

        if let cpuVal = latestCPU?.value {
            cpuHistory.append(cpuVal.totalUsagePercent)
        }
        if let memVal = latestMemory?.value {
            memoryHistory.append(memVal.usagePercentage)
        }
        if let gpuVal = latestGPU?.value {
            gpuHistory.append(gpuVal.utilizationPercent)
        }
        if let netVal = latestNetwork?.value {
            networkInHistory.append(netVal.totalBytesInPerSecond)
            networkOutHistory.append(netVal.totalBytesOutPerSecond)
        }
    }

    private func saveRollup(repo: MetricRollupRepository) {
        if let cpu = latestCPU?.value {
            let rollup = MetricRollup(
                metricKey: "cpu.total",
                minValue: cpu.totalUsagePercent,
                maxValue: cpu.totalUsagePercent,
                avgValue: cpu.totalUsagePercent,
                lastValue: cpu.totalUsagePercent,
                unit: "%",
                source: "host_statistics"
            )
            try? repo.insertRollup(rollup)
        }
        if let mem = latestMemory?.value {
            let rollup = MetricRollup(
                metricKey: "memory.used_percent",
                minValue: mem.usagePercentage,
                maxValue: mem.usagePercentage,
                avgValue: mem.usagePercentage,
                lastValue: mem.usagePercentage,
                unit: "%",
                source: "mach_vm"
            )
            try? repo.insertRollup(rollup)
        }
        if let gpu = latestGPU?.value {
            let rollup = MetricRollup(
                metricKey: "gpu.utilization",
                minValue: gpu.utilizationPercent,
                maxValue: gpu.utilizationPercent,
                avgValue: gpu.utilizationPercent,
                lastValue: gpu.utilizationPercent,
                unit: "%",
                source: "IOAccelerator"
            )
            try? repo.insertRollup(rollup)
        }
    }
}
