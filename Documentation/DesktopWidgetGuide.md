# Creating a Native macOS Desktop Widget (WidgetKit Extension)

This guide provides the complete architectural pattern and production-ready Swift code to build a **macOS Desktop Widget** for **Task Manager for macOS** using Apple's **WidgetKit** and **App Groups**.

---

## 1. Overview & Architecture

Starting with **macOS 14 Sonoma**, users can place interactive widgets directly onto their Mac Desktop. A macOS Widget is implemented as an embedded **App Extension** (`.appex`) inside the main application bundle:

```text
Task Manager.app/
└── Contents/
    ├── MacOS/
    │   └── TaskManager                 (Main App Process)
    └── PlugIns/
        └── TaskManagerWidget.appex      (WidgetKit Process)
```

Because macOS sandboxes the Widget Extension and the Main App into separate processes, they communicate efficiently via an **App Group** (`group.com.k692.TaskManager`) using a shared `UserDefaults` suite or a shared file container.

```text
┌────────────────────────────────┐         ┌────────────────────────────────┐
│       Task Manager App         │         │      macOS Desktop Widget      │
│  (SamplingCoordinator 1s Tick) │         │     (WidgetKit Timeline)       │
└───────────────┬────────────────┘         └────────────────┬───────────────┘
                │ Writes Latest Snapshot                    │ Reads Snapshot
                ▼                                           ▼
┌───────────────────────────────────────────────────────────────────────────┐
│           Shared App Group Container (group.com.k692.TaskManager)         │
│               UserDefaults / Shared TelemetrySnapshot.json                │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Shared Data Model (`TelemetrySnapshot.swift`)

Create a shared Swift structure that represents the instantaneous hardware state. Place this file in a shared target or compile it into both targets:

```swift
import Foundation

public struct TelemetrySnapshot: Codable, Sendable {
    public let timestamp: Date
    public let cpuPercent: Double
    public let gpuPercent: Double
    public let memoryPercent: Double
    public let diskPercent: Double
    public let netInBytesPerSec: Double
    public let netOutBytesPerSec: Double
    public let cpuHistory: [Double]
    public let gpuHistory: [Double]

    public init(
        timestamp: Date = Date(),
        cpuPercent: Double,
        gpuPercent: Double,
        memoryPercent: Double,
        diskPercent: Double,
        netInBytesPerSec: Double,
        netOutBytesPerSec: Double,
        cpuHistory: [Double],
        gpuHistory: [Double]
    ) {
        self.timestamp = timestamp
        self.cpuPercent = cpuPercent
        self.gpuPercent = gpuPercent
        self.memoryPercent = memoryPercent
        self.diskPercent = diskPercent
        self.netInBytesPerSec = netInBytesPerSec
        self.netOutBytesPerSec = netOutBytesPerSec
        self.cpuHistory = cpuHistory
        self.gpuHistory = gpuHistory
    }

    // Static helper to write snapshot from Main App
    public static func save(_ snapshot: TelemetrySnapshot) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.k692.TaskManager"),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults.set(data, forKey: "latest_telemetry_snapshot")
    }

    // Static helper to read snapshot in Widget
    public static func load() -> TelemetrySnapshot {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.k692.TaskManager"),
              let data = sharedDefaults.data(forKey: "latest_telemetry_snapshot"),
              let snapshot = try? JSONDecoder().decode(TelemetrySnapshot.self, from: data) else {
            return TelemetrySnapshot(
                cpuPercent: 12.0,
                gpuPercent: 5.0,
                memoryPercent: 55.0,
                diskPercent: 42.0,
                netInBytesPerSec: 1024 * 45,
                netOutBytesPerSec: 1024 * 12,
                cpuHistory: [8, 10, 12, 14, 11, 12],
                gpuHistory: [3, 4, 6, 5, 4, 5]
            )
        }
        return snapshot
    }
}
```

---

## 3. Widget Timeline Provider (`TelemetryTimelineProvider.swift`)

The timeline provider supplies data entries to WidgetKit:

```swift
import WidgetKit
import SwiftUI

public struct TelemetryEntry: TimelineEntry {
    public let date: Date
    public let snapshot: TelemetrySnapshot

    public init(date: Date = Date(), snapshot: TelemetrySnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct TelemetryTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> TelemetryEntry {
        TelemetryEntry(date: Date(), snapshot: TelemetrySnapshot.load())
    }

    public func getSnapshot(in context: Context, completion: @escaping (TelemetryEntry) -> Void) {
        let entry = TelemetryEntry(date: Date(), snapshot: TelemetrySnapshot.load())
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<TelemetryEntry>) -> Void) {
        let entry = TelemetryEntry(date: Date(), snapshot: TelemetrySnapshot.load())
        
        // Refresh every 15-30 seconds (or immediately when app notifies via WidgetCenter)
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
```

---

## 4. Widget Views for Different Desktop Sizes (`WidgetViews.swift`)

WidgetKit supports `.systemSmall`, `.systemMedium`, and `.systemLarge`:

```swift
import SwiftUI
import WidgetKit

public struct TaskManagerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TelemetryTimelineProvider.Entry

    public var body: some View {
        switch family {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        default:
            largeWidgetView
        }
    }

    // Small Desktop Widget (CPU & GPU Focus)
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.indigo)
                    .font(.system(size: 13, weight: .bold))
                Text("Task Manager")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text(String(format: "%.0f%%", entry.snapshot.cpuPercent))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.indigo)
            }

            Divider()

            HStack {
                Label("GPU", systemImage: "display.trianglebadge.exclamationmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple)
                Spacer()
                Text(String(format: "%.0f%%", entry.snapshot.gpuPercent))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
            }

            HStack {
                Label("RAM", systemImage: "memorychip")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                Spacer()
                Text(String(format: "%.0f%%", entry.snapshot.memoryPercent))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .widgetURL(URL(string: "taskmanager://dashboard"))
    }

    // Medium Desktop Widget (Dual CPU + GPU Side-by-Side)
    private var mediumWidgetView: some View {
        HStack(spacing: 12) {
            // Left: CPU Panel
            Link(destination: URL(string: "taskmanager://cpu")!) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.indigo)
                        Text("CPU")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Text(String(format: "%.0f%%", entry.snapshot.cpuPercent))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.indigo)
                    }
                    Text("Apple Silicon Multi-Core")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.indigo.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Right: GPU Panel
            Link(destination: URL(string: "taskmanager://gpu")!) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "display.trianglebadge.exclamationmark")
                            .foregroundColor(.purple)
                        Text("GPU")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Text(String(format: "%.0f%%", entry.snapshot.gpuPercent))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple)
                    }
                    Text("Metal 3 Graphics Pipeline")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.purple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
    }

    // Large Desktop Widget (Full Hardware Command Center)
    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .foregroundColor(.indigo)
                    Text("Task Manager Dashboard")
                        .font(.system(size: 13, weight: .bold))
                }
                Spacer()
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.emerald)
            }

            Divider()

            // 5 Telemetry Rows
            telemetryRow(name: "CPU", icon: "cpu", val: String(format: "%.0f%%", entry.snapshot.cpuPercent), color: .indigo, url: "taskmanager://cpu")
            telemetryRow(name: "GPU", icon: "display.trianglebadge.exclamationmark", val: String(format: "%.0f%%", entry.snapshot.gpuPercent), color: .purple, url: "taskmanager://gpu")
            telemetryRow(name: "Memory", icon: "memorychip", val: String(format: "%.0f%%", entry.snapshot.memoryPercent), color: .blue, url: "taskmanager://memory")
            telemetryRow(name: "Disk", icon: "internaldrive", val: String(format: "%.0f%%", entry.snapshot.diskPercent), color: .emerald, url: "taskmanager://disk")
            telemetryRow(name: "Network", icon: "network", val: String(format: "%.1f KB/s", entry.snapshot.netInBytesPerSec / 1024.0), color: .cyan, url: "taskmanager://network")
        }
        .padding(14)
        .widgetURL(URL(string: "taskmanager://dashboard"))
    }

    private func telemetryRow(name: String, icon: String, val: String, color: Color, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 16)
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(val)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
    }
}
```

---

## 5. Main Widget Definition (`TaskManagerWidget.swift`)

Declare the widget bundle:

```swift
import WidgetKit
import SwiftUI

@main
struct TaskManagerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskManagerDesktopWidget()
    }
}

struct TaskManagerDesktopWidget: Widget {
    let kind: String = "TaskManagerDesktopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TelemetryTimelineProvider()) { entry in
            TaskManagerWidgetEntryView(entry: entry)
                .containerBackground(Color(nsColor: .windowBackgroundColor), for: .widget)
        }
        .configurationDisplayName("Hardware Telemetry")
        .description("Real-time CPU, GPU, Memory, Disk, and Network telemetry on your Desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

---

## 6. Broadcasting from Main App (`SamplingCoordinator.swift`)

In the main app's `tick()` method inside `SamplingCoordinator.swift`, periodically broadcast the snapshot:

```swift
// Inside SamplingCoordinator.swift -> tick()
let snapshot = TelemetrySnapshot(
    cpuPercent: latestCPU?.value?.totalUsagePercent ?? 0.0,
    gpuPercent: latestGPU?.value?.utilizationPercent ?? 0.0,
    memoryPercent: latestMemory?.value?.usagePercentage ?? 0.0,
    diskPercent: latestStorage?.value?.first?.usagePercentage ?? 0.0,
    netInBytesPerSec: latestNetwork?.value?.totalBytesInPerSecond ?? 0.0,
    netOutBytesPerSec: latestNetwork?.value?.totalBytesOutPerSecond ?? 0.0,
    cpuHistory: cpuHistory.values,
    gpuHistory: gpuHistory.values
)

TelemetrySnapshot.save(snapshot)

// Notify WidgetKit to reload desktop widgets
#if canImport(WidgetKit)
import WidgetKit
WidgetCenter.shared.reloadAllTimelines()
#endif
```

---

## 7. Adding the Extension to Xcode & Building

1. In Xcode: **File** $\rightarrow$ **New** $\rightarrow$ **Target...** $\rightarrow$ Select **Widget Extension**.
2. Product Name: `TaskManagerWidget`.
3. Check **Include Configuration Intent** (optional) and click **Finish**.
4. In **Signing & Capabilities**:
   - Add **App Groups** capability to both `TaskManager` and `TaskManagerWidgetExtension`.
   - Enter group identifier: `group.com.k692.TaskManager`.
5. Run the application. On macOS Sonoma or Sequoia:
   - Right-click anywhere on your Desktop $\rightarrow$ Click **Edit Widgets...**
   - Search for **Task Manager**.
   - Drag the Small, Medium, or Large widget directly onto your Desktop!
