import Foundation
import IOKit.ps

/// Snapshot of battery state and power source.
public struct BatteryMetrics: Codable, Sendable {
    public let chargePercent: Int
    public let isCharging: Bool
    public let powerSource: String // "AC Power", "Battery Power"
    public let cycleCount: Int?
    public let condition: String? // "Normal", "Service Recommended", etc.
    public let timeRemainingMinutes: Int?

    public init(
        chargePercent: Int,
        isCharging: Bool,
        powerSource: String,
        cycleCount: Int? = nil,
        condition: String? = nil,
        timeRemainingMinutes: Int? = nil
    ) {
        self.chargePercent = chargePercent
        self.isCharging = isCharging
        self.powerSource = powerSource
        self.cycleCount = cycleCount
        self.condition = condition
        self.timeRemainingMinutes = timeRemainingMinutes
    }
}

/// Provider for battery and power metrics using IOKit power-source interfaces.
public final class BatteryProvider: Sendable {
    public init() {}

    public func sample() -> MetricSample<BatteryMetrics> {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return MetricSample(
                value: nil,
                unit: "%",
                source: "IOPSCopyPowerSourcesInfo",
                confidence: .exact,
                status: .notPresent,
                reason: "No internal battery present (Desktop Mac)"
            )
        }

        guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef], !list.isEmpty else {
            return MetricSample(
                value: nil,
                unit: "%",
                source: "IOPSCopyPowerSourcesList",
                confidence: .exact,
                status: .notPresent,
                reason: "No internal battery present (Desktop Mac)"
            )
        }

        for powerSource in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, powerSource)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            guard let isInternal = desc[kIOPSTypeKey as String] as? String, isInternal == (kIOPSInternalType as String) else {
                continue
            }

            let curCap = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let isCharging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
            let pSource = desc[kIOPSPowerSourceStateKey as String] as? String ?? "AC Power"
            let powerSourceState = (pSource == (kIOPSACPowerValue as String)) ? "AC Power" : "Battery Power"

            let percent = maxCap > 0 ? Int((Double(curCap) / Double(maxCap)) * 100.0) : curCap
            let cycleCount = desc["Cycle Count"] as? Int
            let condition = desc["Battery Health"] as? String ?? "Normal"
            let timeRemaining = desc[kIOPSTimeToEmptyKey as String] as? Int

            let metrics = BatteryMetrics(
                chargePercent: percent,
                isCharging: isCharging,
                powerSource: powerSourceState,
                cycleCount: cycleCount,
                condition: condition,
                timeRemainingMinutes: (timeRemaining != nil && timeRemaining! > 0) ? timeRemaining : nil
            )

            return MetricSample(
                value: metrics,
                unit: "%",
                source: "IOKit.ps (IOPSGetPowerSourceDescription)",
                confidence: .exact,
                status: .available
            )
        }

        // If no internal battery was matched
        return MetricSample(
            value: nil,
            unit: "%",
            source: "IOPSGetPowerSourceDescription",
            confidence: .exact,
            status: .notPresent,
            reason: "No internal battery detected on this Mac"
        )
    }
}
