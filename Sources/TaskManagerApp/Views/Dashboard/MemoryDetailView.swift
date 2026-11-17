import SwiftUI
import TaskManagerCore

/// Dedicated in-depth Mach Virtual Memory and memory pressure inspector.
public struct MemoryDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator
    @Environment(\.layoutClass) private var layoutClass

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let mem = sampling.latestMemory?.value
        let processes = (sampling.latestProcesses?.value ?? []).sorted { ($0.residentMemoryBytes ?? 0) > ($1.residentMemoryBytes ?? 0) }
        let topMemProcesses = Array(processes.prefix(6))

        DetailPage {
            DetailHeader(
                icon: "memorychip",
                tint: .blue,
                title: "Memory",
                subtitle: "\(mem?.formattedUsed ?? "—") used of \(mem?.formattedTotal ?? env.deviceProfile.formattedMemory) • \(mem?.formattedFree ?? "—") available",
                metric: String(format: "%.0f%%", mem?.usagePercentage ?? 0.0),
                metricLabel: "Memory in use"
            )

            SectionCard("Memory Load History", icon: "waveform.path.ecg", tint: .blue, accessory: {
                PillTag("60s", tint: .blue)
            }) {
                MemoryTimeSeriesChart(
                    dataPoints: sampling.memoryHistory.values.isEmpty ? [0, 0] : sampling.memoryHistory.values
                )
                .frame(height: layoutClass == .compact ? 140 : 200)
                ChartTimeAxis(tint: .blue)
            }

            if let m = mem {
                SectionCard("Physical Memory Composition", icon: "chart.bar.xaxis", tint: .blue, accessory: {
                    pressureBadge(m.pressureLevel)
                }) {
                    GeometryReader { geo in
                        let total = Double(m.totalBytes > 0 ? m.totalBytes : 1)
                        let usable = max(0, geo.size.width - 6)
                        let wiredW = CGFloat(Double(m.wiredBytes) / total) * usable
                        let activeW = CGFloat(Double(m.activeBytes) / total) * usable
                        let compressedW = CGFloat(Double(m.compressedBytes) / total) * usable
                        let freeW = max(0, usable - wiredW - activeW - compressedW)

                        HStack(spacing: 2) {
                            Rectangle().fill(Color.purple).frame(width: max(2, wiredW))
                            Rectangle().fill(Color.blue).frame(width: max(2, activeW))
                            Rectangle().fill(Color.amber).frame(width: max(2, compressedW))
                            Rectangle().fill(Color.emerald.opacity(0.7)).frame(width: max(2, freeW))
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 12)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .leading)], alignment: .leading, spacing: 6) {
                        legendItem(color: .purple, label: "Wired", val: m.formattedWired)
                        legendItem(color: .blue, label: "Active", val: m.formattedActive)
                        legendItem(color: .amber, label: "Compressed", val: m.formattedCompressed)
                        legendItem(color: .emerald, label: "Free", val: m.formattedFree)
                    }
                }
            }

            AdaptiveGrid(minimum: 300) {
                SectionCard("Paging & Pressure", icon: "gauge.medium", tint: .blue) {
                    VStack(spacing: 8) {
                        SpecRow("Memory Pressure", mem?.pressureLevel.capitalized ?? "Normal")
                        SpecRow("Page Size", "16 KB")
                        SpecRow("Active Memory", mem?.formattedActive ?? "—")
                        SpecRow("Wired (Pinned)", mem?.formattedWired ?? "—")
                    }
                }

                SectionCard("Pools & Allocation", icon: "square.stack", tint: .blue) {
                    VStack(spacing: 8) {
                        SpecRow("Total Physical RAM", mem?.formattedTotal ?? env.deviceProfile.formattedMemory)
                        SpecRow("Compressed", mem?.formattedCompressed ?? "—")
                        SpecRow("Inactive / Cached", mem?.formattedInactive ?? "—")
                        SpecRow("Available", mem?.formattedFree ?? "—")
                    }
                }
            }

            SectionCard("Top Memory Consumers", icon: "list.number", tint: .blue, accessory: {
                PillTag("LIVE", tint: .emerald)
            }) {
                TopProcessTable(
                    rows: topMemProcesses.map {
                        .init(id: $0.pid, name: $0.name, architecture: $0.architecture, isActive: $0.isActive, value: $0.formattedMemory)
                    },
                    valueTitle: "Memory",
                    tint: .blue
                )
            }
        }
    }

    private func pressureBadge(_ status: String) -> some View {
        let color: Color = status.lowercased() == "critical" ? .rose : (status.lowercased() == "warn" ? .amber : .emerald)
        return PillTag(status.uppercased(), tint: color)
    }

    private func legendItem(color: Color, label: String, val: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(val)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .lineLimit(1)
    }
}
