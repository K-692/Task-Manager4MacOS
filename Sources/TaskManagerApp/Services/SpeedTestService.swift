import Foundation
import SwiftUI

/// User-initiated internet speed test (latency, download, upload).
///
/// Uses Cloudflare's public speed-test endpoints (the same ones behind
/// speed.cloudflare.com). Nothing runs unless the user presses "Run Speed Test",
/// and no personal data is sent — only throw-away test payloads.
@MainActor
public final class SpeedTestService: ObservableObject {
    public enum Phase: Equatable {
        case idle
        case latency
        case download
        case upload
        case finished
        case failed(String)

        public var title: String {
            switch self {
            case .idle: return "Ready"
            case .latency: return "Measuring latency…"
            case .download: return "Testing download…"
            case .upload: return "Testing upload…"
            case .finished: return "Complete"
            case .failed: return "Test failed"
            }
        }

        public var isRunning: Bool {
            switch self {
            case .latency, .download, .upload: return true
            default: return false
            }
        }
    }

    @Published public private(set) var phase: Phase = .idle
    /// Live throughput of the running download/upload phase, in Mbps.
    @Published public private(set) var liveMbps: Double = 0
    /// 0…1 progress of the whole test.
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var pingMs: Double?
    @Published public private(set) var jitterMs: Double?
    @Published public private(set) var downloadMbps: Double?
    @Published public private(set) var uploadMbps: Double?
    @Published public private(set) var lastRun: Date?

    private var task: Task<Void, Never>?

    private static let baseURL = "https://speed.cloudflare.com"
    private static let downloadDuration: TimeInterval = 7
    private static let uploadDuration: TimeInterval = 6
    private static let parallelStreams = 4

    public init() {}

    public func start() {
        guard !phase.isRunning else { return }
        task?.cancel()
        pingMs = nil
        jitterMs = nil
        downloadMbps = nil
        uploadMbps = nil
        liveMbps = 0
        progress = 0
        task = Task { [weak self] in
            await self?.run()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        if phase.isRunning {
            phase = .idle
            liveMbps = 0
            progress = 0
        }
    }

    // MARK: - Test pipeline

    private func run() async {
        do {
            phase = .latency
            let (ping, jitter) = try await measureLatency()
            pingMs = ping
            jitterMs = jitter
            progress = 0.1
            try Task.checkCancellation()

            phase = .download
            downloadMbps = try await measureThroughput(upload: false, duration: Self.downloadDuration, progressRange: 0.1...0.6)
            try Task.checkCancellation()

            phase = .upload
            uploadMbps = try await measureThroughput(upload: true, duration: Self.uploadDuration, progressRange: 0.6...1.0)

            liveMbps = 0
            progress = 1
            lastRun = Date()
            phase = .finished
        } catch is CancellationError {
            // cancel() already reset the state.
        } catch {
            liveMbps = 0
            phase = .failed(Self.describe(error))
        }
    }

    private func measureLatency() async throws -> (Double, Double) {
        let session = URLSession(configuration: Self.configuration())
        defer { session.invalidateAndCancel() }
        var samples: [Double] = []
        for i in 0..<8 {
            try Task.checkCancellation()
            var request = URLRequest(url: URL(string: "\(Self.baseURL)/__down?bytes=0&r=\(i)-\(UUID().uuidString.prefix(6))")!)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let start = DispatchTime.now().uptimeNanoseconds
            let (_, response) = try await session.data(for: request)
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            // The first request includes TLS/DNS setup; skip it.
            if i > 0 { samples.append(elapsed) }
        }
        let sorted = samples.sorted()
        let median = sorted[sorted.count / 2]
        var diffs: [Double] = []
        for i in 1..<samples.count { diffs.append(abs(samples[i] - samples[i - 1])) }
        let jitter = diffs.reduce(0, +) / Double(max(1, diffs.count))
        return (median, jitter)
    }

    /// Runs several parallel streams for `duration` seconds and returns the average Mbps,
    /// ignoring the first second of TCP ramp-up.
    private func measureThroughput(upload: Bool, duration: TimeInterval, progressRange: ClosedRange<Double>) async throws -> Double {
        let counter = ByteCounter()
        let deadline = Date().addingTimeInterval(duration)
        let runner = TransferRunner(
            upload: upload,
            payload: upload ? Self.randomPayload(bytes: 1_048_576) : Data(),
            baseURL: Self.baseURL,
            deadline: deadline,
            counter: counter
        )
        let session = URLSession(configuration: Self.configuration(), delegate: runner, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        runner.start(session: session, streams: Self.parallelStreams)

        // Sample the byte counter while the transfers run.
        let start = Date()
        var lastBytes: Int64 = 0
        var lastTime = start
        var rampBytes: Int64?
        var rampTime: Date?
        var smoothed: Double = 0
        while Date() < deadline {
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                session.invalidateAndCancel()
                throw error
            }
            let now = Date()
            let bytes = counter.value
            let interval = now.timeIntervalSince(lastTime)
            if interval > 0 {
                let instant = Double(bytes - lastBytes) * 8 / interval / 1_000_000
                // Uploads are credited in whole chunks, so smooth them more.
                let weight = upload ? 0.15 : 0.3
                smoothed = smoothed == 0 ? instant : smoothed * (1 - weight) + instant * weight
                liveMbps = smoothed
            }
            lastBytes = bytes
            lastTime = now
            if rampBytes == nil && now.timeIntervalSince(start) >= 1 {
                rampBytes = bytes
                rampTime = now
            }
            let fraction = min(1, now.timeIntervalSince(start) / duration)
            progress = progressRange.lowerBound + (progressRange.upperBound - progressRange.lowerBound) * fraction
        }

        session.invalidateAndCancel()

        let totalBytes = counter.value
        guard totalBytes > 0 else { throw URLError(.notConnectedToInternet) }
        let fromBytes = rampBytes ?? 0
        let fromTime = rampTime ?? start
        let seconds = max(0.5, Date().timeIntervalSince(fromTime))
        return Double(totalBytes - fromBytes) * 8 / seconds / 1_000_000
    }

    // MARK: - Helpers

    private static func configuration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 15
        config.httpMaximumConnectionsPerHost = parallelStreams
        return config
    }

    private static func randomPayload(bytes: Int) -> Data {
        var data = Data(count: bytes)
        data.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            arc4random_buf(base, bytes)
        }
        return data
    }

    private static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost: return "No internet connection."
            case .timedOut: return "The server took too long to respond."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed: return "Could not reach the speed test server."
            default: break
            }
        }
        return error.localizedDescription
    }
}

/// Thread-safe running total of transferred bytes.
final class ByteCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var total: Int64 = 0

    func add(_ bytes: Int64) {
        lock.lock()
        total += bytes
        lock.unlock()
    }

    var value: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return total
    }
}

/// Keeps a fixed number of download or upload transfers in flight until the
/// deadline and counts bytes as they arrive (download) or leave (upload).
final class TransferRunner: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let upload: Bool
    private let payload: Data
    private let baseURL: String
    private let deadline: Date
    private let counter: ByteCounter
    private weak var session: URLSession?

    init(upload: Bool, payload: Data, baseURL: String, deadline: Date, counter: ByteCounter) {
        self.upload = upload
        self.payload = payload
        self.baseURL = baseURL
        self.deadline = deadline
        self.counter = counter
    }

    func start(session: URLSession, streams: Int) {
        self.session = session
        for _ in 0..<streams { launch() }
    }

    private func launch() {
        guard let session, Date() < deadline else { return }
        let tag = UUID().uuidString.prefix(8)
        let task: URLSessionTask
        if upload {
            var request = URLRequest(url: URL(string: "\(baseURL)/__up?r=\(tag)")!)
            request.httpMethod = "POST"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            task = session.uploadTask(with: request, from: payload)
        } else {
            var request = URLRequest(url: URL(string: "\(baseURL)/__down?bytes=50000000&r=\(tag)")!)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            task = session.dataTask(with: request)
        }
        task.resume()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if !upload { counter.add(Int64(data.count)) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if (error as? URLError)?.code == .cancelled { return }
        // Uploads are credited only once the server has acknowledged the whole
        // payload; per-chunk send progress just reflects the local socket buffer.
        if upload, error == nil, (task.response as? HTTPURLResponse)?.statusCode == 200 {
            counter.add(Int64(payload.count))
        }
        launch()
    }
}
