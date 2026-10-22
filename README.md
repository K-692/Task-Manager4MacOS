# Task Manager for macOS

<div align="center">

<img src="icon/icon.png" width="128" height="128" alt="Task Manager for macOS Logo" />

# Task Manager for macOS
### The Native Hardware & Software Performance Monitor for macOS

[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue?logo=apple&style=for-the-badge)](https://developer.apple.com/macos/)
[![Language](https://img.shields.io/badge/Swift-6.0%20%7C%205.9-orange?logo=swift&style=for-the-badge)](https://swift.org)
[![Architecture](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-purple?style=for-the-badge)](https://developer.apple.com/documentation/apple-silicon)
[![Graphics](https://img.shields.io/badge/GPU%20Telemetry-Metal%20%2B%20IOKit-indigo?logo=apple&style=for-the-badge)](https://developer.apple.com/metal/)
[![Storage](https://img.shields.io/badge/Storage-Embedded%20SQLite%20WAL-success?logo=sqlite&style=for-the-badge)](https://sqlite.org)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline%20%26%20Zero%20Telemetry-emerald?style=for-the-badge)](#privacy--offline-guarantee)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

<p align="center">
  <strong>A high-performance, featherlight, Windows Task Manager inspired software and hardware monitor for macOS. Live multi-engine GPU metrics, Mach CPU loads, memory pressure graphs, per-process telemetry with instant "End Task", and startup app control.</strong>
</p>

[Key Features](#-key-features) •
[GPU Monitoring](#-gpu-visualization--telemetry) •
[Architecture](#-architecture--design) •
[Installation & Build](#-installation--how-to-run) •
[Keyboard Shortcuts](#-keyboard-shortcuts) •
[Contributing](#-contributing)

</div>

---

## 📖 Overview

**Task Manager for macOS** brings the familiarity, precision, and power of the **Windows Task Manager** to the Mac ecosystem. It provides real-time, empirical hardware telemetry and granular software inspection without electron bloat, root daemons, or cloud analytics.

### Why Task Manager for macOS?
- **Zero Web Runtimes:** 100% native Swift, SwiftUI, AppKit, Metal, and Darwin Mach kernel APIs. No Electron, Node.js, Chromium, or web servers.
- **Featherlight Overhead:** Idles with `< 0.4%` CPU usage and `~25MB` memory footprint.
- **True GPU Visualization:** Real-time GPU load percentage, renderer utilization, tiler utilization, and allocated/in-use VRAM directly from Apple Silicon & discrete GPUs.
- **True "End Task" Process Control:** Instant graceful (`SIGTERM`) or forced (`SIGKILL`) termination of misbehaving applications.
- **Truthful Hardware Discovery:** Never reports fabricated metrics (e.g. 0°C or 0 RPM). Unsupported sensors are explicitly marked with typed capability statuses.
- **100% Offline & Local-First:** All rollups and settings persist strictly on your device in an embedded SQLite database (`taskmanager.sqlite`).

---

## ⚡ Key Features

```
┌────────────────────────────────────────────────────────────────────────┐
│  Task Manager (macOS)                                                  │
├───────────────┬────────────────────────────────────────────────────────┤
│ 🚀 Processes  │ Process Name         PID   CPU %   Memory  Arch   End  │
│ 📊 CPU        │ Safari              1420    4.2%   340 MB  Apple  [✕]  │
│ 🧠 Memory     │ Xcode               8912   12.8%   2.4 GB  Apple  [✕]  │
│ 🎮 GPU        │ WindowServer         280    6.1%   410 MB  Apple  [✕]  │
│ 💾 Disk       │ Terminal            4510    0.1%    45 MB  Apple  [✕]  │
│ 🌐 Network    ├────────────────────────────────────────────────────────┤
│ ⚡ Startup    │ [ 60-Second Real-Time Hardware Time-Series Charts ]    │
│ ⚙️ Settings   │ GPU: 14.2%  •  CPU: 8.5%  •  RAM: 18.2 GB / 36 GB      │
└───────────────┴────────────────────────────────────────────────────────┘
```

### 1. 🚀 Software & Process Management ("Processes" Tab)
- Real-time inventory of all running applications and processes with inspectable memory, PID, and architecture (`Apple Silicon` / `Intel 64-bit`).
- Live CPU % utilization per process calculated across Mach thread runtime differentials.
- Instant **"End Task"** action button and context menu with graceful (`NSRunningApplication.terminate`) and forced (`SIGKILL`) termination options.
- Instant search filter by application name, bundle identifier, or process PID.
- Multi-column sorting by CPU Usage %, Memory Footprint, Name, or Process ID.

### 2. 🎮 GPU Visualization & Telemetry ("Performance > GPU")
- **Live 60-Second Utilization Graph:** Interactive Swift Charts rendering continuous GPU engine activity.
- **Multi-Engine Breakdown:** Overall Device Utilization %, Renderer Core Utilization %, and Tiler Pipeline Utilization %.
- **VRAM / Unified Memory Tracking:** Real-time allocated system memory and active in-use VRAM.
- **Metal Hardware Profile:** Dynamic device identification via Apple Metal (`MTLCopyAllDevices`).

### 3. 📊 CPU & Processor Telemetry ("Performance > CPU")
- Host tick deltas derived directly from Mach kernel `HOST_CPU_LOAD_INFO`.
- Continuous 60-second utilization chart with user, system, and idle distributions.
- Core topology: physical cores vs. logical virtual cores and microarchitecture detection.

### 4. 🧠 Memory Architecture ("Performance > Memory")
- Full Mach VM page accounting: **Active**, **Wired**, **Compressed**, and **Free** memory.
- Dynamic color-coded stacked composition bar.
- Real-time kernel memory pressure alerts (`Normal`, `Warning`, `Critical`).

### 5. 💾 Storage Volumes ("Performance > Disk")
- Non-intrusive volume discovery using Apple `NSURLResourceKey` APIs.
- Volume mount paths, format types (APFS, Mac OS Extended, ExFAT), total capacity, used space, and free space.

### 6. 🌐 Network Throughput ("Performance > Network")
- Live inbound (Download) and outbound (Upload) throughput graphs via BSD `getifaddrs`.
- Primary active network interface detection and cumulative transferred byte counters.

### 7. ⚡ Startup Apps Management ("Startup Apps" Tab)
- Inspect and toggle background login items and launch services using Apple's modern `SMAppService` framework.
- Startup impact estimation and one-click access to system-level login item configurations.

### 8. 📌 Native Menu Bar Utility (`MenuBarExtra`)
- Always-available lightweight status panel showing live CPU %, Memory %, GPU %, Network rates, and Battery condition.
- One-click access to open the main Task Manager window or quit the app cleanly.

---

## 🎮 GPU Visualization & Telemetry

macOS does not provide a simple public sysctl for GPU load. **Task Manager for macOS** bridges this by reading the kernel's `IOAccelerator` performance counters combined with Apple Metal runtime introspection:

```swift
// Sample from Sources/TaskManagerCore/SystemMetrics/Providers/GPUProvider.swift
let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOAccelerator"))
if service != IO_OBJECT_NULL {
    var props: Unmanaged<CFMutableDictionary>?
    if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
       let dict = props?.takeRetainedValue() as? [String: Any],
       let stats = dict["PerformanceStatistics"] as? [String: Any] {
        let deviceUtil = (stats["Device Utilization %"] as? NSNumber)?.doubleValue ?? 0.0
        let rendererUtil = (stats["Renderer Utilization %"] as? NSNumber)?.doubleValue ?? 0.0
        let tilerUtil = (stats["Tiler Utilization %"] as? NSNumber)?.doubleValue ?? 0.0
        let allocMem = (stats["Alloc system memory"] as? NSNumber)?.uint64Value ?? 0
        let inUseMem = (stats["In use system memory"] as? NSNumber)?.uint64Value ?? 0
    }
    IOObjectRelease(service)
}
```

---

## 🏗 Architecture & Design

```text
Task-Manager/
├── icon/
│   └── icon.png                         # High-resolution application master icon
├── Sources/
│   ├── TaskManagerCore/                 # Core Telemetry & Domain Engine
│   │   ├── Domain/
│   │   │   ├── Hardware/                # DeviceProfile, HardwareCategory
│   │   │   └── Metrics/                 # MetricSample, CapabilityStatus, CapabilityRecord
│   │   ├── HardwareInventory/           # DeviceProfileService, CapabilityRegistry
│   │   ├── Persistence/                 # SQLiteStore (WAL), MetricRollupRepository, SettingsRepository
│   │   ├── Services/
│   │   │   ├── DeepLink/                # DeepLinkRouter (taskmanager://processes, performance, etc.)
│   │   │   └── LoginItem/               # LoginItemService (SMAppService)
│   │   └── SystemMetrics/
│   │       ├── SamplingCoordinator.swift# Central telemetry coordinator & ring buffers (60s history)
│   │       └── Providers/
│   │           ├── CPUProvider.swift    # Mach host_statistics64 (HOST_CPU_LOAD_INFO)
│   │           ├── MemoryProvider.swift # Mach vm_statistics64 & dispatch memory pressure
│   │           ├── GPUProvider.swift    # IOKit IOAccelerator + Apple Metal MTLCopyAllDevices
│   │           ├── StorageProvider.swift# FileManager volume attributes & APFS inspection
│   │           ├── NetworkProvider.swift# BSD getifaddrs delta throughput
│   │           ├── BatteryProvider.swift# IOKit IOPMPowerSource battery health & state
│   │           └── ProcessProvider.swift# libproc & NSWorkspace with SIGTERM/SIGKILL control
│   └── TaskManagerApp/                  # Native AppKit & SwiftUI Presentation Layer
│       ├── App/                         # TaskManagerApp, AppEnvironment
│       ├── DesignSystem/                # Theme tokens, Metric cards, Swift Charts views
│       ├── Resources/                   # Bundled App icon and assets
│       └── Views/
│           ├── MainLayoutView.swift     # Windows-style SplitView sidebar & header branding
│           ├── CommandPalette/          # Fast process search & tab switching (⌘K)
│           ├── Dashboard/
│           │   ├── ProcessesView.swift  # Process table, CPU/Memory columns, "End Task" button
│           │   ├── PerformanceView.swift# Subtabs: CPU, Memory, GPU, Disk, Network (60s charts)
│           │   ├── StartupAppsView.swift# Startup items management (SMAppService)
│           │   ├── HardwareCapabilitiesView.swift # Truthful hardware audit
│           │   └── ...
│           ├── MenuBar/                 # MenuBarContentView status popup
│           └── Settings/                # Telemetry frequency, dark/light theme, storage
└── Scripts/
    └── build-app.sh                     # Assembles release 'Task Manager.app' bundle with AppIcon.icns
```

---

## 💻 Installation & How to Run

### System Requirements
- macOS 13.0 (Ventura) or later (macOS 14 Sonoma and macOS 15 Sequoia fully supported)
- Xcode 15+ or Swift 5.9+ Command Line Tools
- Universal Binary: Runs natively on **Apple Silicon (M1/M2/M3/M4)** and **Intel x86_64** Macs

### Option 1: Run with SwiftPM directly
```bash
# Clone the repository
git clone https://github.com/K-692/Task-Manager4MacOS.git
cd Task-Manager4MacOS

# Build the project
swift build

# Run the Task Manager
swift run TaskManager
```

### Option 2: Build Native `.app` Bundle with Icon
```bash
# Execute the automated build & icon packaging script
./Scripts/build-app.sh

# Open the compiled application
open "dist/Task Manager.app"
```
The script automatically converts `icon/icon.png` into a native macOS `AppIcon.icns` bundle containing all required resolutions (16x16 to 1024x1024@2x) and links all SPM resources.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Destination / Action |
|:---|:---|
| <kbd>⌘</kbd> + <kbd>1</kbd> | Jump to **Processes** |
| <kbd>⌘</kbd> + <kbd>2</kbd> | Jump to **Performance** (CPU, Memory, GPU, Disk, Network) |
| <kbd>⌘</kbd> + <kbd>3</kbd> | Jump to **Startup Apps** |
| <kbd>⌘</kbd> + <kbd>4</kbd> | Jump to **Hardware & Specs** |
| <kbd>⌘</kbd> + <kbd>5</kbd> | Jump to **Settings** |
| <kbd>⌘</kbd> + <kbd>K</kbd> | Open **Command Palette** (Instant Process Search & End Task) |
| <kbd>⌘</kbd> + <kbd>R</kbd> | Force Telemetry Refresh |

---

## 🔒 Privacy & Offline Guarantee

- **100% Offline:** The app makes zero network connections.
- **No Background Telemetry:** No third-party tracking, crash reporting, or user telemetry is bundled.
- **Local Embedded Storage:** Downsampled telemetry rollups are stored strictly on-device in `~/Library/Application Support/TaskManager/taskmanager.sqlite`.

---

## 🤝 Contributing

Contributions, bug reports, and feature proposals are warmly welcomed!

1. **Fork** the repository: `https://github.com/K-692/Task-Manager4MacOS/fork`
2. **Create a Feature Branch**: `git checkout -b feature/NewMetricProvider`
3. **Commit your changes**: `git commit -m 'feat: add thermal pressure metric'`
4. **Push to the branch**: `git push origin feature/NewMetricProvider`
5. **Open a Pull Request** with a description of the changes and runtime verification on your Mac.

---

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.
