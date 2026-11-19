import Foundation
import Combine

/// Drives the menu bar metric rotation on a strict 2-second cadence.
///
/// - Lives in its own small ObservableObject, so a rotation step only redraws the
///   menu bar item, not the whole app window.
/// - The shown metric is derived from the time elapsed since rotation started
///   (`elapsed / interval`), so a late timer tick can never shift the schedule.
/// - A strict `DispatchSourceTimer` with zero leeway fires on each 2-second boundary.
@MainActor
public final class MenuBarRotation: ObservableObject {
    public static let interval: TimeInterval = 2.0

    @Published public private(set) var current: MenuBarMetric = .cpu

    private var timer: DispatchSourceTimer?
    private var anchor: TimeInterval = 0
    private var startIndex = 0

    public init() {}

    public func start(from metric: MenuBarMetric) {
        stop()
        let all = MenuBarMetric.allCases
        startIndex = all.firstIndex(of: metric) ?? 0
        anchor = ProcessInfo.processInfo.systemUptime
        current = metric

        let source = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        source.schedule(deadline: .now() + Self.interval, repeating: Self.interval, leeway: .milliseconds(0))
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.tick() }
        }
        source.resume()
        timer = source
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let all = MenuBarMetric.allCases
        let elapsed = ProcessInfo.processInfo.systemUptime - anchor
        // Round to the nearest step so a tick a few ms early or late lands on the right metric.
        let steps = Int((elapsed / Self.interval).rounded())
        let next = all[(startIndex + steps) % all.count]
        if next != current { current = next }
    }
}
