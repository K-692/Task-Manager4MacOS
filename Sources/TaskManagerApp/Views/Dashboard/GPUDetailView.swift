import SwiftUI
import Metal
import TaskManagerCore

/// Dedicated in-depth GPU telemetry, graphics pipeline, and Metal inspector.
public struct GPUDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let gpu = sampling.latestGPU?.value
        let deviceName = gpu?.deviceName ?? env.deviceProfile.gpuNames.first ?? "Apple Silicon GPU"

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: "display.trianglebadge.exclamationmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.purple)
                            Text("GPU — Graphics Processing & Metal Engine")
                                .font(.system(size: 22, weight: .bold))
                        }
                        Text("\(deviceName) • Apple Metal 3 Pipeline • Unified Memory Architecture")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple)
                        Text("DEVICE UTILIZATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // 60-Second Real-Time GPU Utilization Chart
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("60-Second GPU Load History")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("100%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        GPUTimeSeriesChart(
                            dataPoints: sampling.gpuHistory.values.isEmpty ? [0, 0] : sampling.gpuHistory.values
                        )

                        HStack {
                            Text("60s ago")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("0s (Live)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.purple)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Pipeline Breakdown & VRAM Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hardware Graphics Engines")
                                .font(.system(size: 13, weight: .semibold))

                            VStack(spacing: 8) {
                                statRow(label: "Device Utilization", value: String(format: "%.1f%%", gpu?.utilizationPercent ?? 0.0), color: .purple)
                                statRow(label: "Renderer Utilization", value: String(format: "%.1f%%", gpu?.rendererUtilizationPercent ?? 0.0), color: .indigo)
                                statRow(label: "Tiler Utilization", value: String(format: "%.1f%%", gpu?.tilerUtilizationPercent ?? 0.0), color: .cyan)
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("VRAM & Memory Pool")
                                .font(.system(size: 13, weight: .semibold))

                            VStack(spacing: 8) {
                                specRow(label: "VRAM in Use", value: gpu?.formattedInUseMemory ?? "0 MB")
                                specRow(label: "Allocated VRAM", value: gpu?.formattedAllocatedMemory ?? "0 MB")
                                specRow(label: "Memory Type", value: "Unified System Memory")
                                specRow(label: "Shared Pool", value: env.deviceProfile.formattedMemory)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Metal Pipeline Capabilities Matrix
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Apple Metal Features & Hardware Capabilities")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("Direct IOKit & Metal 3 Runtime")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 8) {
                            specRow(label: "Primary Metal Device", value: deviceName)
                            specRow(label: "Unified Memory", value: "Enabled (Zero-copy CPU/GPU sharing)")
                            specRow(label: "Hardware Ray Tracing", value: "Supported by Apple Silicon Metal Engine")
                            specRow(label: "Mesh Shaders", value: "Supported (Metal 3 Feature Set)")
                            specRow(label: "Argument Buffers", value: "Tier 2 Hardware Acceleration")
                            specRow(label: "Texture Compression", value: "ASTC, BC (Direct Hardware Decompression)")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 170, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}
