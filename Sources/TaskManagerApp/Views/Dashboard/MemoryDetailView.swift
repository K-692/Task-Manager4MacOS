import SwiftUI
import TaskManagerCore

/// Dedicated in-depth Mach Virtual Memory and memory pressure inspector.
public struct MemoryDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sampling: SamplingCoordinator

    public init(sampling: SamplingCoordinator) {
        self.sampling = sampling
    }

    public var body: some View {
        let mem = sampling.latestMemory?.value
        let processes = (sampling.latestProcesses?.value ?? []).sorted { ($0.residentMemoryBytes ?? 0) > ($1.residentMemoryBytes ?? 0) }
        let topMemProcesses = Array(processes.prefix(6))

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: "memorychip")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Memory — Mach Virtual Memory & Pressure")
                                .font(.system(size: 22, weight: .bold))
                        }
                        Text("\(mem?.formattedUsed ?? "—") used of \(mem?.formattedTotal ?? env.deviceProfile.formattedMemory) (\(mem?.formattedFree ?? "—") available)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f%%", mem?.usagePercentage ?? 0.0))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                        Text("MEMORY FOOTPRINT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // 60-Second Real-Time Memory Utilization Chart
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("60-Second Memory Load History")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("100%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        MemoryTimeSeriesChart(
                            dataPoints: sampling.memoryHistory.values.isEmpty ? [0, 0] : sampling.memoryHistory.values
                        )

                        HStack {
                            Text("60s ago")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("0s (Live)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Stacked Mach Memory Breakdown Bar
                if let m = mem {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Physical Memory Composition")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                pressureBadge(m.pressureLevel)
                            }

                            // Stacked Bar
                            GeometryReader { geo in
                                let total = Double(m.totalBytes > 0 ? m.totalBytes : 1)
                                let wiredW = CGFloat(Double(m.wiredBytes) / total) * geo.size.width
                                let activeW = CGFloat(Double(m.activeBytes) / total) * geo.size.width
                                let compressedW = CGFloat(Double(m.compressedBytes) / total) * geo.size.width
                                let freeW = max(0, geo.size.width - wiredW - activeW - compressedW)

                                HStack(spacing: 2) {
                                    Rectangle().fill(Color.purple).frame(width: max(2, wiredW))
                                    Rectangle().fill(Color.blue).frame(width: max(2, activeW))
                                    Rectangle().fill(Color.amber).frame(width: max(2, compressedW))
                                    Rectangle().fill(Color.emerald).frame(width: max(2, freeW))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .frame(height: 14)

                            // Legend
                            HStack(spacing: 16) {
                                legendItem(color: .purple, label: "Wired", val: m.formattedWired)
                                legendItem(color: .blue, label: "Active", val: m.formattedActive)
                                legendItem(color: .amber, label: "Compressed", val: m.formattedCompressed)
                                legendItem(color: .emerald, label: "Free", val: m.formattedFree)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Mach VM Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mach VM Paging & Pressure")
                                .font(.system(size: 13, weight: .semibold))

                            VStack(spacing: 8) {
                                specRow(label: "Memory Pressure", value: mem?.pressureLevel.capitalized ?? "Normal")
                                specRow(label: "Mach Page Size", value: "16 KB (Apple Silicon VM)")
                                specRow(label: "Active Memory", value: mem?.formattedActive ?? "—")
                                specRow(label: "Wired (Pinned)", value: mem?.formattedWired ?? "—")
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Memory Pools & Allocation")
                                .font(.system(size: 13, weight: .semibold))

                            VStack(spacing: 8) {
                                specRow(label: "Total Physical RAM", value: mem?.formattedTotal ?? env.deviceProfile.formattedMemory)
                                specRow(label: "Compressed RAM", value: mem?.formattedCompressed ?? "—")
                                specRow(label: "Inactive / Cached", value: mem?.formattedInactive ?? "—")
                                specRow(label: "Available Free", value: mem?.formattedFree ?? "—")
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Top Memory Consuming Processes
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Top Memory Consumers (Resident Footprint)")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("Real-Time Sample")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 6) {
                            HStack {
                                Text("PID")
                                    .frame(width: 50, alignment: .leading)
                                Text("Process Name")
                                    .frame(minWidth: 150, alignment: .leading)
                                Spacer()
                                Text("Architecture")
                                    .frame(width: 90, alignment: .trailing)
                                Text("RAM Footprint")
                                    .frame(width: 90, alignment: .trailing)
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                            Divider()

                            ForEach(topMemProcesses) { proc in
                                HStack {
                                    Text("\(proc.pid)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 50, alignment: .leading)

                                    HStack(spacing: 6) {
                                        Image(systemName: proc.isActive ? "app.fill" : "gearshape.2")
                                            .font(.system(size: 10))
                                            .foregroundColor(proc.isActive ? .blue : .secondary)
                                        Text(proc.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .frame(minWidth: 150, alignment: .leading)

                                    Spacer()

                                    Text(proc.architecture)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(width: 90, alignment: .trailing)

                                    Text(proc.formattedMemory)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .frame(width: 90, alignment: .trailing)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func pressureBadge(_ status: String) -> some View {
        let color: Color = status.lowercased() == "critical" ? .rose : (status.lowercased() == "warn" ? .amber : .emerald)
        return Text(status.uppercased())
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func legendItem(color: Color, label: String, val: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label):")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(val)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}
