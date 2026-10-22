import Foundation
import Metal
import AppKit

/// Central registry providing a verified, model-adaptive hardware and system capability inventory.
public final class CapabilityRegistry: Sendable {
    private let profileService: DeviceProfileService
    private let cpuProvider: CPUProvider
    private let memoryProvider: MemoryProvider
    private let gpuProvider: GPUProvider
    private let storageProvider: StorageProvider
    private let batteryProvider: BatteryProvider
    private let networkProvider: NetworkProvider

    public init(
        profileService: DeviceProfileService = DeviceProfileService(),
        cpuProvider: CPUProvider = CPUProvider(),
        memoryProvider: MemoryProvider = MemoryProvider(),
        gpuProvider: GPUProvider = GPUProvider(),
        storageProvider: StorageProvider = StorageProvider(),
        batteryProvider: BatteryProvider = BatteryProvider(),
        networkProvider: NetworkProvider = NetworkProvider()
    ) {
        self.profileService = profileService
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.gpuProvider = gpuProvider
        self.storageProvider = storageProvider
        self.batteryProvider = batteryProvider
        self.networkProvider = networkProvider
    }

    /// Evaluates and returns the complete, truthful capability inventory across all categories.
    public func inspectAllCapabilities() -> [CapabilityRecord] {
        var records: [CapabilityRecord] = []
        let profile = profileService.buildProfile()

        // 1. Compute / CPU
        records.append(CapabilityRecord(
            id: "cpu.model",
            category: .compute,
            displayName: "Processor Family",
            valueString: profile.cpuName,
            status: .available,
            source: "sysctl(machdep.cpu.brand_string)",
            confidence: .exact
        ))
        records.append(CapabilityRecord(
            id: "cpu.logical_cores",
            category: .compute,
            displayName: "Logical CPU Cores",
            valueString: "\(profile.logicalCores) cores",
            status: .available,
            source: "ProcessInfo.activeProcessorCount",
            confidence: .exact
        ))
        records.append(CapabilityRecord(
            id: "cpu.physical_cores",
            category: .compute,
            displayName: "Physical CPU Cores",
            valueString: "\(profile.physicalCores) cores",
            status: .available,
            source: "sysctl(hw.physicalcpu)",
            confidence: .exact
        ))
        let cpuSample = cpuProvider.sample()
        if let cpuMetrics = cpuSample.value {
            records.append(CapabilityRecord(
                id: "cpu.utilization",
                category: .compute,
                displayName: "Current CPU Load",
                valueString: String(format: "%.1f%%", cpuMetrics.totalUsagePercent),
                unit: "%",
                status: .available,
                source: "host_statistics(HOST_CPU_LOAD_INFO)",
                confidence: .derived
            ))
        }

        // 2. GPU / Graphics (Live telemetry via IOKit IOAccelerator & Metal)
        let gpuSample = gpuProvider.sample()
        if let gpu = gpuSample.value {
            records.append(CapabilityRecord(
                id: "gpu.devices",
                category: .gpu,
                displayName: "Graphics Processor",
                valueString: gpu.deviceName,
                status: .available,
                source: "Metal (MTLCopyAllDevices)",
                confidence: .exact
            ))
            records.append(CapabilityRecord(
                id: "gpu.utilization",
                category: .gpu,
                displayName: "GPU Utilization",
                valueString: String(format: "%.1f%%", gpu.utilizationPercent),
                unit: "%",
                status: .available,
                source: "IOKit IOAccelerator (PerformanceStatistics)",
                confidence: .exact
            ))
            records.append(CapabilityRecord(
                id: "gpu.renderer_util",
                category: .gpu,
                displayName: "Renderer Load",
                valueString: String(format: "%.1f%%", gpu.rendererUtilizationPercent),
                unit: "%",
                status: .available,
                source: "IOKit IOAccelerator",
                confidence: .exact
            ))
            records.append(CapabilityRecord(
                id: "gpu.tiler_util",
                category: .gpu,
                displayName: "Tiler Load",
                valueString: String(format: "%.1f%%", gpu.tilerUtilizationPercent),
                unit: "%",
                status: .available,
                source: "IOKit IOAccelerator",
                confidence: .exact
            ))
            records.append(CapabilityRecord(
                id: "gpu.memory_allocated",
                category: .gpu,
                displayName: "GPU System Memory In Use",
                valueString: gpu.formattedInUseMemory,
                status: .available,
                source: "IOKit / Metal (currentAllocatedSize)",
                confidence: .exact
            ))
        }

        // 3. Memory
        records.append(CapabilityRecord(
            id: "memory.installed",
            category: .memory,
            displayName: "Total Physical Memory",
            valueString: profile.formattedMemory,
            status: .available,
            source: "ProcessInfo.physicalMemory",
            confidence: .exact
        ))
        let memSample = memoryProvider.sample()
        if let mem = memSample.value {
            records.append(CapabilityRecord(
                id: "memory.used",
                category: .memory,
                displayName: "Memory Used",
                valueString: "\(mem.formattedUsed) (\(String(format: "%.1f%%", mem.usagePercentage)))",
                status: .available,
                source: "Mach VM Statistics (active + wired + compressed)",
                confidence: .derived
            ))
            records.append(CapabilityRecord(
                id: "memory.pressure",
                category: .memory,
                displayName: "Memory Pressure",
                valueString: mem.pressureLevel,
                status: .available,
                source: "sysctl(kern.memorystatus_vm_pressure_level)",
                confidence: .exact
            ))
        }

        // 4. Displays
        records.append(CapabilityRecord(
            id: "display.count",
            category: .displays,
            displayName: "Connected Displays",
            valueString: "\(profile.displayCount) display(s)",
            status: .available,
            source: "AppKit.NSScreen",
            confidence: .exact
        ))
        for (idx, screen) in NSScreen.screens.enumerated() {
            let res = screen.frame
            let scale = screen.backingScaleFactor
            records.append(CapabilityRecord(
                id: "display.\(idx)",
                category: .displays,
                displayName: "Display #\(idx + 1) Resolution",
                valueString: "\(Int(res.width)) × \(Int(res.height)) @ \(Int(scale))x",
                status: .available,
                source: "NSScreen.frame",
                confidence: .exact
            ))
        }

        // 5. Battery & Power
        let batterySample = batteryProvider.sample()
        if let bat = batterySample.value {
            records.append(CapabilityRecord(
                id: "battery.charge",
                category: .battery,
                displayName: "Battery Charge",
                valueString: "\(bat.chargePercent)% (\(bat.isCharging ? "Charging" : "Discharging"))",
                status: .available,
                source: "IOKit Power Sources",
                confidence: .exact
            ))
            records.append(CapabilityRecord(
                id: "battery.power_source",
                category: .battery,
                displayName: "Power Source",
                valueString: bat.powerSource,
                status: .available,
                source: "IOKit Power Sources",
                confidence: .exact
            ))
        } else {
            records.append(CapabilityRecord(
                id: "battery.presence",
                category: .battery,
                displayName: "Internal Battery",
                valueString: nil,
                status: batterySample.status,
                source: "IOKit Power Sources",
                explanation: batterySample.reason ?? "Desktop Mac configuration without internal battery.",
                confidence: .exact
            ))
        }

        // 6. Storage
        let storageSample = storageProvider.sample()
        if let volumes = storageSample.value {
            records.append(CapabilityRecord(
                id: "storage.volumes",
                category: .storage,
                displayName: "Mounted Volumes",
                valueString: "\(volumes.count) volume(s)",
                status: .available,
                source: "FileManager.mountedVolumeURLs",
                confidence: .exact
            ))
            for vol in volumes {
                records.append(CapabilityRecord(
                    id: "storage.vol.\(vol.name)",
                    category: .storage,
                    displayName: "Volume: \(vol.name) (\(vol.fileSystemType))",
                    valueString: "\(vol.formattedAvailable) free of \(vol.formattedTotal)",
                    status: .available,
                    source: "URLResourceKey.volumeAvailableCapacityKey",
                    confidence: .exact
                ))
            }
        }

        // 7. Network
        let netSample = networkProvider.sample()
        if let net = netSample.value {
            records.append(CapabilityRecord(
                id: "network.primary",
                category: .network,
                displayName: "Primary Interface",
                valueString: net.primaryInterfaceName,
                status: .available,
                source: "getifaddrs",
                confidence: .exact
            ))
            records.append(CapabilityRecord(
                id: "network.active_count",
                category: .network,
                displayName: "Active Interfaces",
                valueString: "\(net.interfaces.filter { $0.isUp }.count) active",
                status: .available,
                source: "getifaddrs",
                confidence: .exact
            ))
        }

        // 8. Thermal & Cooling
        let thermalState = ProcessInfo.processInfo.thermalState
        let thermalString: String
        switch thermalState {
        case .nominal: thermalString = "Nominal (Cool)"
        case .fair: thermalString = "Fair (Normal)"
        case .serious: thermalString = "Serious (Elevated)"
        case .critical: thermalString = "Critical (Throttling)"
        @unknown default: thermalString = "Normal"
        }
        records.append(CapabilityRecord(
            id: "thermal.state",
            category: .thermal,
            displayName: "System Thermal State",
            valueString: thermalString,
            status: .available,
            source: "ProcessInfo.thermalState",
            confidence: .exact
        ))

        return records
    }
}
