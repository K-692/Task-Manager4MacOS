import Foundation
import Darwin

/// Snapshot of an individual network interface.
public struct NetworkInterfaceInfo: Identifiable, Codable, Sendable {
    public var id: String { name }
    public let name: String
    public let isUp: Bool
    public let totalBytesIn: UInt64
    public let totalBytesOut: UInt64
    public let bytesInPerSecond: Double
    public let bytesOutPerSecond: Double

    public init(
        name: String,
        isUp: Bool,
        totalBytesIn: UInt64,
        totalBytesOut: UInt64,
        bytesInPerSecond: Double,
        bytesOutPerSecond: Double
    ) {
        self.name = name
        self.isUp = isUp
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
    }

    public var formattedInboundRate: String {
        formatRate(bytesInPerSecond)
    }

    public var formattedOutboundRate: String {
        formatRate(bytesOutPerSecond)
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024)
        } else {
            return String(format: "%.0f B/s", bytesPerSec)
        }
    }
}

/// Aggregated network metrics across active interfaces.
public struct NetworkMetrics: Codable, Sendable {
    public let primaryInterfaceName: String
    public let totalBytesInPerSecond: Double
    public let totalBytesOutPerSecond: Double
    public let interfaces: [NetworkInterfaceInfo]

    public init(
        primaryInterfaceName: String,
        totalBytesInPerSecond: Double,
        totalBytesOutPerSecond: Double,
        interfaces: [NetworkInterfaceInfo]
    ) {
        self.primaryInterfaceName = primaryInterfaceName
        self.totalBytesInPerSecond = totalBytesInPerSecond
        self.totalBytesOutPerSecond = totalBytesOutPerSecond
        self.interfaces = interfaces
    }

    public var formattedInPerSecond: String {
        formatRate(totalBytesInPerSecond)
    }

    public var formattedOutPerSecond: String {
        formatRate(totalBytesOutPerSecond)
    }

    public var formattedTotalIn: String {
        let total = interfaces.reduce(0) { $0 + $1.totalBytesIn }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    public var formattedTotalOut: String {
        let total = interfaces.reduce(0) { $0 + $1.totalBytesOut }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024)
        } else {
            return String(format: "%.0f B/s", bytesPerSec)
        }
    }
}

/// Provider for network interfaces and throughput using getifaddrs.
public final class NetworkProvider: @unchecked Sendable {
    private struct PreviousSnapshot {
        let bytesIn: UInt64
        let bytesOut: UInt64
        let timestamp: Date
    }

    private var previousSnapshots: [String: PreviousSnapshot] = [:]
    private let lock = NSLock()

    public init() {}

    public func sample() -> MetricSample<NetworkMetrics> {
        lock.lock()
        defer { lock.unlock() }

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return MetricSample(
                value: nil,
                unit: "B/s",
                source: "getifaddrs",
                confidence: .exact,
                status: .probeFailed(code: "NET_ERR", userSafeMessage: "Unable to inspect network interfaces"),
                reason: "getifaddrs failed"
            )
        }
        defer { freeifaddrs(ifaddr) }

        let now = Date()
        var interfaceMap: [String: (bytesIn: UInt64, bytesOut: UInt64, isUp: Bool)] = [:]

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if !isLoopback && current.pointee.ifa_addr != nil {
                let family = current.pointee.ifa_addr.pointee.sa_family
                if family == AF_LINK {
                    let name = String(cString: current.pointee.ifa_name)
                    if let data = current.pointee.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self)
                        let bytesIn = UInt64(networkData.pointee.ifi_ibytes)
                        let bytesOut = UInt64(networkData.pointee.ifi_obytes)
                        interfaceMap[name] = (bytesIn, bytesOut, isUp)
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }

        var interfaces: [NetworkInterfaceInfo] = []
        var totalInRate = 0.0
        var totalOutRate = 0.0

        for (name, data) in interfaceMap.sorted(by: { $0.key < $1.key }) {
            var inRate = 0.0
            var outRate = 0.0

            if let prev = previousSnapshots[name] {
                let dt = now.timeIntervalSince(prev.timestamp)
                if dt > 0.05 {
                    if data.bytesIn >= prev.bytesIn {
                        inRate = Double(data.bytesIn - prev.bytesIn) / dt
                    }
                    if data.bytesOut >= prev.bytesOut {
                        outRate = Double(data.bytesOut - prev.bytesOut) / dt
                    }
                }
            }

            previousSnapshots[name] = PreviousSnapshot(
                bytesIn: data.bytesIn,
                bytesOut: data.bytesOut,
                timestamp: now
            )

            if data.isUp {
                totalInRate += inRate
                totalOutRate += outRate
            }

            interfaces.append(NetworkInterfaceInfo(
                name: name,
                isUp: data.isUp,
                totalBytesIn: data.bytesIn,
                totalBytesOut: data.bytesOut,
                bytesInPerSecond: inRate,
                bytesOutPerSecond: outRate
            ))
        }

        // Identify primary interface (e.g. en0 or first active with traffic)
        let primary = interfaces.first(where: { $0.isUp && $0.name.hasPrefix("en") })?.name ?? interfaces.first?.name ?? "en0"

        let metrics = NetworkMetrics(
            primaryInterfaceName: primary,
            totalBytesInPerSecond: totalInRate,
            totalBytesOutPerSecond: totalOutRate,
            interfaces: interfaces
        )

        return MetricSample(
            value: metrics,
            unit: "B/s",
            source: "getifaddrs / if_data",
            confidence: .derived,
            status: .available
        )
    }
}
