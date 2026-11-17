import SwiftUI
import Metal
import TaskManagerCore

/// Dedicated in-depth GPU telemetry, graphics pipeline, and Metal inspector.
public struct GPUDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator
    @Environment(\.layoutClass) private var layoutClass

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let gpu = sampling.latestGPU?.value
        let deviceName = gpu?.deviceName ?? env.deviceProfile.gpuNames.first ?? "Apple Silicon GPU"

        DetailPage {
            DetailHeader(
                icon: "cube.transparent",
                tint: .purple,
                title: "Graphics",
                subtitle: "\(deviceName) • Metal 3 • Unified Memory",
                metric: String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0),
                metricLabel: "Device utilization"
            )

            SectionCard("GPU Load History", icon: "waveform.path.ecg", tint: .purple, accessory: {
                PillTag("60s", tint: .purple)
            }) {
                GPUTimeSeriesChart(
                    dataPoints: sampling.gpuHistory.values.isEmpty ? [0, 0] : sampling.gpuHistory.values
                )
                .frame(height: layoutClass == .compact ? 140 : 200)
                ChartTimeAxis(tint: .purple)
            }

            AdaptiveGrid(minimum: 300) {
                SectionCard("Graphics Engines", icon: "square.stack.3d.up", tint: .purple) {
                    VStack(spacing: 8) {
                        UsageBarRow(label: "Device", value: gpu?.utilizationPercent ?? 0, tint: .purple)
                        UsageBarRow(label: "Renderer", value: gpu?.rendererUtilizationPercent ?? 0, tint: .indigo)
                        UsageBarRow(label: "Tiler", value: gpu?.tilerUtilizationPercent ?? 0, tint: .cyan)
                    }
                }

                SectionCard("VRAM & Memory Pool", icon: "memorychip", tint: .purple) {
                    VStack(spacing: 8) {
                        SpecRow("VRAM in Use", gpu?.formattedInUseMemory ?? "0 MB")
                        SpecRow("Allocated VRAM", gpu?.formattedAllocatedMemory ?? "0 MB")
                        SpecRow("Memory Type", "Unified System Memory")
                        SpecRow("Shared Pool", env.deviceProfile.formattedMemory)
                    }
                }
            }

            SectionCard("Metal Features", icon: "sparkles", tint: .purple) {
                VStack(spacing: 8) {
                    SpecRow("Primary Metal Device", deviceName)
                    SpecRow("Unified Memory", "Zero-copy CPU/GPU sharing")
                    SpecRow("Hardware Ray Tracing", "Supported (Apple Silicon)")
                    SpecRow("Mesh Shaders", "Supported (Metal 3)")
                    SpecRow("Argument Buffers", "Tier 2")
                    SpecRow("Texture Compression", "ASTC, BC")
                }
            }
        }
    }
}
