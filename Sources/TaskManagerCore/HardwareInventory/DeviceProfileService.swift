import Foundation
import Metal
import AppKit

/// Service responsible for discovering host Mac hardware profile and specifications.
public final class DeviceProfileService: Sendable {
    public init() {}

    public func buildProfile() -> DeviceProfile {
        let modelIdentifier = readSysctlString("hw.model") ?? "Mac"
        let marketingName = resolveMarketingName(modelIdentifier: modelIdentifier)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let osBuild = readSysctlString("kern.osversion") ?? "Unknown"

        #if arch(arm64)
        let architecture = "Apple Silicon (arm64)"
        let isAppleSilicon = true
        #elseif arch(x86_64)
        let architecture = "Intel (x86_64)"
        let isAppleSilicon = false
        #else
        let architecture = "Unknown"
        let isAppleSilicon = false
        #endif

        let cpuBrand = readSysctlString("machdep.cpu.brand_string") ?? (isAppleSilicon ? "Apple Silicon" : "Intel Core Processor")
        let logicalCores = ProcessInfo.processInfo.activeProcessorCount
        var physicalCores = logicalCores
        var physCores32: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.physicalcpu", &physCores32, &size, nil, 0) == 0 {
            physicalCores = Int(physCores32)
        }

        let memory = ProcessInfo.processInfo.physicalMemory
        let uptime = ProcessInfo.processInfo.systemUptime
        let bootTime = Date().addingTimeInterval(-uptime)

        // Enumerate GPU devices safely using Metal
        let metalDevices = MTLCopyAllDevices()
        let gpuNames = metalDevices.map { $0.name }

        // Displays
        let displayCount = NSScreen.screens.count

        let isLaptop = modelIdentifier.lowercased().contains("book") ||
                       marketingName.lowercased().contains("book")

        return DeviceProfile(
            modelIdentifier: modelIdentifier,
            marketingName: marketingName,
            osVersion: osVersion,
            osBuild: osBuild,
            architecture: architecture,
            cpuName: cpuBrand,
            logicalCores: logicalCores,
            physicalCores: physicalCores,
            totalMemoryBytes: memory,
            uptimeSeconds: uptime,
            bootTime: bootTime,
            gpuNames: gpuNames.isEmpty ? ["Integrated GPU"] : gpuNames,
            displayCount: max(1, displayCount),
            isAppleSilicon: isAppleSilicon,
            isLaptop: isLaptop
        )
    }

    private func readSysctlString(_ name: String) -> String? {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveMarketingName(modelIdentifier: String) -> String {
        // Known model identifier translation table (Apple Silicon and Intel)
        let mapping: [String: String] = [
            // M4 Family
            "Mac16,1": "MacBook Pro (14-inch, M4, 2024)",
            "Mac16,6": "MacBook Pro (14-inch, M4 Pro, 2024)",
            "Mac16,7": "MacBook Pro (16-inch, M4 Pro, 2024)",
            "Mac16,8": "MacBook Pro (16-inch, M4 Max, 2024)",
            "Mac16,10": "Mac mini (M4, 2024)",
            "Mac16,11": "Mac mini (M4 Pro, 2024)",
            "Mac16,15": "iMac (24-inch, M4, 2024)",

            // M3 Family
            "Mac15,3": "MacBook Pro (14-inch, M3, Nov 2023)",
            "Mac15,6": "MacBook Pro (14-inch, M3 Pro, Nov 2023)",
            "Mac15,7": "MacBook Pro (16-inch, M3 Pro, Nov 2023)",
            "Mac15,8": "MacBook Pro (16-inch, M3 Max, Nov 2023)",
            "Mac15,12": "MacBook Air (13-inch, M3, 2024)",
            "Mac15,13": "MacBook Air (15-inch, M3, 2024)",
            "Mac15,4": "iMac (24-inch, M3, 2023)",

            // M2 Family
            "Mac14,2": "MacBook Air (13-inch, M2, 2022)",
            "Mac14,7": "MacBook Pro (13-inch, M2, 2022)",
            "Mac14,9": "MacBook Pro (14-inch, M2 Pro, 2023)",
            "Mac14,10": "MacBook Pro (16-inch, M2 Pro, 2023)",
            "Mac14,15": "MacBook Air (15-inch, M2, 2023)",
            "Mac14,3": "Mac mini (M2, 2023)",
            "Mac14,12": "Mac mini (M2 Pro, 2023)",
            "Mac14,13": "Mac Studio (M2 Max, 2023)",
            "Mac14,14": "Mac Studio (M2 Ultra, 2023)",

            // M1 Family
            "MacBookAir10,1": "MacBook Air (M1, 2020)",
            "MacBookPro17,1": "MacBook Pro (13-inch, M1, 2020)",
            "MacBookPro18,1": "MacBook Pro (16-inch, M1 Pro, 2021)",
            "MacBookPro18,2": "MacBook Pro (16-inch, M1 Max, 2021)",
            "MacBookPro18,3": "MacBook Pro (14-inch, M1 Pro, 2021)",
            "MacBookPro18,4": "MacBook Pro (14-inch, M1 Max, 2021)",
            "Macmini9,1": "Mac mini (M1, 2020)",
            "iMac21,1": "iMac (24-inch, M1, 2021)",
            "Mac13,1": "Mac Studio (M1 Max, 2022)",
            "Mac13,2": "Mac Studio (M1 Ultra, 2022)",

            // Virtual Machines
            "VirtualMac2,1": "Apple Silicon Virtual Machine"
        ]

        if let name = mapping[modelIdentifier] {
            return name
        }

        if modelIdentifier.hasPrefix("MacBookAir") {
            return "MacBook Air (\(modelIdentifier))"
        } else if modelIdentifier.hasPrefix("MacBookPro") {
            return "MacBook Pro (\(modelIdentifier))"
        } else if modelIdentifier.hasPrefix("Macmini") {
            return "Mac mini (\(modelIdentifier))"
        } else if modelIdentifier.hasPrefix("iMac") {
            return "iMac (\(modelIdentifier))"
        } else if modelIdentifier.hasPrefix("MacPro") {
            return "Mac Pro (\(modelIdentifier))"
        }

        return "Apple Mac (\(modelIdentifier))"
    }
}
