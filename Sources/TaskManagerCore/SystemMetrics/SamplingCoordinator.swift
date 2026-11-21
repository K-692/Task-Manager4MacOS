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

    public private(set) var latestCPU: MetricSample<CPUMetrics>?
    public private(set) var latestMemory: MetricSample<MemoryMetrics>?
    public private(set) var latestGPU: MetricSample<GPUMetrics>?
    public private(set) var latestStorage: MetricSample<[VolumeInfo]>?
    public private(set) var latestBattery: MetricSample<BatteryMetrics>?
    public private(set) var latestNetwork: MetricSample<NetworkMetrics>?
    public private(set) var latestProcesses: MetricSample<[ProcessItem]>?

    // Rolling ring buffers for live charts (last 60 samples)
    public private(set) var cpuHistory = MetricRingBuffer(capacity: 60)
    public private(set) var gpuHistory = MetricRingBuffer(capacity: 60)
    public private(set) var memoryHistory = MetricRingBuffer(capacity: 60)
    public private(set) var diskHistory = MetricRingBuffer(capacity: 60)
    public private(set) var networkInHistory = MetricRingBuffer(capacity: 60)
    public private(set) var networkOutHistory = MetricRingBuffer(capacity: 60)
    public private(set) var networkTotalHistory = MetricRingBuffer(capacity: 60)

    @Published public var isDashboardActive: Bool = true

    @Published public var samplingInterval: TimeInterval = 1.0 {
        didSet {
            if samplingInterval > 0 {
                startSampling(interval: samplingInterval)
            } else {
                stopSampling()
            }
        }
    }

    private var samplingTimer: Timer?
    private var rollupCounter: Int = 0

    // MARK: Lightweight sampling
    //
    // Scanning every process is the most expensive sample, so it only runs every tick
    // while something on screen shows live process data (Processes, CPU/Memory detail,
    // menu bar popup). Otherwise it runs every 5th tick (window open, for counts) or
    // every 15th tick (menu bar only). Storage and battery change slowly and are
    // sampled every 5th (30th with the window closed) / 10th tick.
    private var liveProcessDemand = 0
    /// Set by the app while the main window is on screen.
    public var isWindowVisible = true

    /// Call when a view that shows live process data appears.
    public func beginLiveProcesses() {
        liveProcessDemand += 1
        if liveProcessDemand == 1 {
            objectWillChange.send()
            latestProcesses = processProvider.sample()
        }
    }

    /// Call when that view disappears.
    public func endLiveProcesses() {
        liveProcessDemand = max(0, liveProcessDemand - 1)
    }

    private var processEvery: Int {
        if liveProcessDemand > 0 { return 1 }
        return isWindowVisible ? 5 : 15
    }

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

        // Pre-fill ring buffers with baseline readings so charts render smoothly from t=0
        seedInitialHistory()

        startSampling(interval: samplingInterval)
    }

    private func seedInitialHistory() {
        objectWillChange.send()
        let cpuVal = latestCPU?.value?.totalUsagePercent ?? 0.0
        let gpuVal = latestGPU?.value?.utilizationPercent ?? 0.0
        let memVal = latestMemory?.value?.usagePercentage ?? 50.0
        let diskVal = latestStorage?.value?.first?.usagePercentage ?? 50.0

        for _ in 0..<60 {
            cpuHistory.append(cpuVal)
            gpuHistory.append(gpuVal)
            memoryHistory.append(memVal)
            diskHistory.append(diskVal)
            networkInHistory.append(0.0)
            networkOutHistory.append(0.0)
            networkTotalHistory.append(0.0)
        }
    }

    public func startSampling(interval: TimeInterval = 1.0) {
        stopSampling()
        guard interval > 0 else { return }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        samplingTimer = timer
    }

    public func stopSampling() {
        samplingTimer?.invalidate()
        samplingTimer = nil
    }

    public func tick() {
        rollupCounter += 1

        // One change notification per tick (instead of one per property).
        objectWillChange.send()

        let cpu = cpuProvider.sample()
        let mem = memoryProvider.sample()
        let gpu = gpuProvider.sample()
        let net = networkProvider.sample()
        latestCPU = cpu
        latestMemory = mem
        latestGPU = gpu
        latestNetwork = net

        if rollupCounter % processEvery == 0 {
            latestProcesses = processProvider.sample()
        }
        // Disk usage changes slowly: every 5 s with the window open, every 30 s otherwise.
        if rollupCounter % (isWindowVisible ? 5 : 30) == 0 || latestStorage == nil {
            latestStorage = storageProvider.sample()
        }
        if rollupCounter % 10 == 0 {
            latestBattery = batteryProvider.sample()
        }

        if let cpuVal = cpu.value {
            cpuHistory.append(cpuVal.totalUsagePercent)
        }
        if let gpuVal = gpu.value {
            gpuHistory.append(gpuVal.utilizationPercent)
        }
        if let memVal = mem.value {
            memoryHistory.append(memVal.usagePercentage)
        }
        if let diskVal = latestStorage?.value?.first?.usagePercentage {
            diskHistory.append(diskVal)
        }
        if let netVal = net.value {
            networkInHistory.append(netVal.totalBytesInPerSecond)
            networkOutHistory.append(netVal.totalBytesOutPerSecond)
            networkTotalHistory.append(netVal.totalBytesInPerSecond + netVal.totalBytesOutPerSecond)
        }
    }

    public func refreshAll() {
        objectWillChange.send()
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
        if let gpuVal = latestGPU?.value {
            gpuHistory.append(gpuVal.utilizationPercent)
        }
        if let memVal = latestMemory?.value {
            memoryHistory.append(memVal.usagePercentage)
        }
        if let diskVal = latestStorage?.value?.first?.usagePercentage {
            diskHistory.append(diskVal)
        }
        if let netVal = latestNetwork?.value {
            networkInHistory.append(netVal.totalBytesInPerSecond)
            networkOutHistory.append(netVal.totalBytesOutPerSecond)
            networkTotalHistory.append(netVal.totalBytesInPerSecond + netVal.totalBytesOutPerSecond)
        }
    }
}
