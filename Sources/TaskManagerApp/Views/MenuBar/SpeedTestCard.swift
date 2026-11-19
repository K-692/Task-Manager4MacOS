import SwiftUI

/// Internet speed test panel shown inside the menu bar popover.
struct SpeedTestCard: View {
    @ObservedObject var speedTest: SpeedTestService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                Text("INTERNET SPEED")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(.secondary)
                Spacer()
                if let last = speedTest.lastRun, !speedTest.phase.isRunning {
                    Text(last, style: .time)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            if speedTest.phase.isRunning {
                runningView
            } else {
                resultsView
            }

            actionButton
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    private var runningView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(speedTest.phase == .latency ? "—" : String(format: "%.1f", speedTest.liveMbps))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(phaseColor)
                Text("Mbps")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(speedTest.phase.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            ProgressView(value: speedTest.progress)
                .progressViewStyle(.linear)
                .tint(phaseColor)
            metricsGrid
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        if case .failed(let message) = speedTest.phase {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(.rose)
                .fixedSize(horizontal: false, vertical: true)
        } else if speedTest.downloadMbps == nil {
            Text("Measure your download, upload and latency. The test takes about 15 seconds and uses Cloudflare's speed test servers.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            metricsGrid
        }
    }

    private var metricsGrid: some View {
        HStack(spacing: 6) {
            metric(title: "Download", icon: "arrow.down.circle.fill", value: speedTest.downloadMbps.map { format($0) }, unit: "Mbps", tint: .cyan)
            metric(title: "Upload", icon: "arrow.up.circle.fill", value: speedTest.uploadMbps.map { format($0) }, unit: "Mbps", tint: .indigo)
            metric(title: "Ping", icon: "timer", value: speedTest.pingMs.map { String(format: "%.0f", $0) }, unit: "ms", tint: .emerald)
            metric(title: "Jitter", icon: "waveform.path", value: speedTest.jitterMs.map { String(format: "%.0f", $0) }, unit: "ms", tint: .amber)
        }
    }

    private func metric(title: String, icon: String, value: String?, unit: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 8))
                Text(title).font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(tint)
            Text(value ?? "—")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.opacity(0.08)))
    }

    private var actionButton: some View {
        Button {
            if speedTest.phase.isRunning {
                speedTest.cancel()
            } else {
                speedTest.start()
            }
        } label: {
            Label(
                speedTest.phase.isRunning ? "Stop" : (speedTest.downloadMbps == nil ? "Run Speed Test" : "Run Again"),
                systemImage: speedTest.phase.isRunning ? "stop.fill" : "play.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(speedTest.phase.isRunning ? .rose : .orange)
        .controlSize(.small)
    }

    private var phaseColor: Color {
        switch speedTest.phase {
        case .upload: return .indigo
        case .latency: return .emerald
        default: return .cyan
        }
    }

    private func format(_ mbps: Double) -> String {
        mbps >= 100 ? String(format: "%.0f", mbps) : String(format: "%.1f", mbps)
    }
}
