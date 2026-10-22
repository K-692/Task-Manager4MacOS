# Task Manager for macOS

<div align="center">

<img src="icon/icon.png" width="128" height="128" alt="Task Manager for macOS Logo" />

# Task Manager for macOS
### The Native Hardware & Software Performance Monitor for macOS

[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue?logo=apple&style=for-the-badge)](https://developer.apple.com/macos/)
[![Language](https://img.shields.io/badge/Swift-6.0%20%7C%205.9-orange?logo=swift&style=for-the-badge)](https://swift.org)
[![Architecture](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-purple?style=for-the-badge)](https://developer.apple.com/documentation/apple-silicon)
[![Graphics](https://img.shields.io/badge/GPU%20Telemetry-Metal%20%2B%20IOKit-indigo?logo=apple&style=for-the-badge)](https://developer.apple.com/metal/)
[![Storage](https://img.shields.io/badge/Telemetry-100%25%20In--Memory%20(Zero%20Disk%20I%2FO)-success?style=for-the-badge)](#-ephemeral-in-memory-telemetry)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline%20%26%20Zero%20Telemetry-emerald?style=for-the-badge)](#-privacy--offline-guarantee)
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
- **Unified Technical Dashboard:** All Performance & Hardware metrics consolidated into a single, high-density landing page without nested sub-menus.
- **Live Sidebar Sparklines:** Real-time mini-graphs rendered directly in the sidebar navigation in strict order: **CPU $\rightarrow$ GPU $\rightarrow$ Memory $\rightarrow$ Disk $\rightarrow$ Network**.
- **True GPU Visualization:** Real-time GPU load percentage, renderer utilization, tiler utilization, and allocated/in-use VRAM directly from Apple Silicon & discrete GPUs.
- **Memory-First Process Sorting:** Processes default-sorted by physical memory footprint for instant leak detection, with instant "End Task" process control.
- **100% In-Memory Ephemeral Telemetry:** Zero disk I/O writes for metrics; live 60-second rolling ring buffers prevent SSD wear.
- **Single-Tab Technical Settings:** Aligned, organized configuration options in one clean view.

---

## ⚡ Key Features

```text
┌────────────────────────────────────────────────────────────────────────┐
│  Task Manager (macOS)                                                  │
├─────────────────────┬──────────────────────────────────────────────────┤
│ ⚡ Dashboard (Live) │ [ SYSTEM SUMMARY: Apple M2 Pro • 12 Cores • UMA ]│
│ 🚀 Processes (184)  ├──────────────────────────────────────────────────┤
│ ⚡ Startup Apps     │ CPU: 14.2%  [ ~~~~/\~~ ]  User 8.2% • System 6.0%│
│ ⚙️ Settings         │ GPU:  8.5%  [ ~~~~/~\~ ]  Renderer • Tiler • VRAM│
├─────────────────────┤ Memory: 54% [ ~~~~~~~~ ]  18.2 GB / 36 GB (Norm) │
│ LIVE TELEMETRY      │ Disk:   42% [ ======-- ]  Macintosh HD (APFS)    │
│ CPU     [~~/\~] 14% │ Net: 1.2M/s [ __/\____ ]  ↓ 1.2 MB/s  ↑ 45 KB/s  │
│ GPU     [~/\~~]  8% ├──────────────────────────────────────────────────┤
│ Memory  [~~~~~] 54% │ PROCESSES (Default: Memory Footprint)            │
│ Disk    [====-] 42% │ Xcode               8912   12.8%   2.4 GB  [End] │
│ Network [_/\__]1.2M │ Safari              1420    4.2%   340 MB  [End] │
└─────────────────────┴──────────────────────────────────────────────────┘
```

### 1. ⚡ Unified Performance & Hardware Dashboard (Landing Page)
- **Consolidated Single-View Telemetry:** All hardware metrics (CPU, GPU, Memory, Disk, Network, Platform Specs) displayed in one comprehensive, technical dashboard without nested sub-menus.
- **Thermal & Health Ticker:** Live thermal throttling status (`Nominal`, `Fair`, `Serious`, `Critical`), system uptime counter, and active process count.
- **System Specifications Matrix:** Transparent hardware disclosure of Mac model, chip architecture, physical/logical core topology, installed RAM, GPU model, and Darwin kernel build.

### 2. 📊 Live Sidebar Sparklines (Real-Time Mini Graphs)
- Hardware-accelerated mini sparkline graphs stream live in the leftmost navigation sidebar in strict order:
  1. **CPU** — Live utilization % + Sparkline graph
  2. **GPU** — Live GPU load % + Sparkline graph (immediately after CPU!)
  3. **Memory** — Live RAM usage % + Sparkline graph
  4. **Disk** — Live storage used % + Progress gauge
  5. **Network** — Live download throughput + Sparkline graph
- Clicking any sidebar telemetry row navigates instantly to the Dashboard.

### 3. 🚀 Software & Process Management ("Processes" Tab)
- Real-time inventory of all running applications and processes with inspectable memory, PID, and architecture (`Apple Silicon` / `Intel 64-bit`).
- **Memory-First Default Sort:** Automatically sorted by resident memory footprint descending to immediately identify high-memory applications.
- Live CPU % utilization per process calculated across Mach thread runtime differentials.
- Instant **"End Task"** action button and context menu with graceful (`NSRunningApplication.terminate`) and forced (`SIGKILL`) termination options.
- Instant search filter by application name, bundle identifier, or process PID.

### 4. 🎮 GPU Visualization & Telemetry (Apple Metal + IOKit)
- **Live 60-Second Utilization Graph:** Continuous GPU engine load time-series rendered via Swift Charts.
- **Multi-Engine Breakdown:** Overall Device Utilization %, Renderer Core Utilization %, and Tiler Pipeline Utilization %.
- **VRAM / Unified Memory Tracking:** Real-time allocated system memory and active in-use VRAM.
- **Metal Hardware Profile:** Dynamic device identification via Apple Metal (`MTLCopyAllDevices`).

### 5. 🧠 Mach Virtual Memory Architecture
- Full Mach VM page accounting: **Active**, **Wired**, **Compressed**, and **Free** memory.
- Dynamic color-coded stacked composition bar.
- Real-time kernel memory pressure alerts (`Normal`, `Warning`, `Critical`).

### 6. ⚡ Startup Apps Management ("Startup Apps" Tab)
- Inspect and toggle background login items and launch services using Apple's modern `SMAppService` framework.
- Startup impact estimation and one-click access to system-level login item configurations.

### 7. ⚙️ Single-Tab Technical Settings Panel
- All application options organized in a single, aligned technical view:
  - Application & Menu Bar lifecycle behavior (Keep in Menu Bar, Launch at Login).
  - Telemetry sampling frequency picker (High 0.5s, Normal 1.0s, Low 3.0s, Paused).
  - Appearance mode selector (Match System, Light, Dark).
  - Full system hardware specification readout.

### 8. 📌 Native Menu Bar Utility (`MenuBarExtra`)
- Always-available lightweight status panel showing live CPU %, GPU %, Memory %, Disk available, Network rates, and Battery condition.

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
│   │   ├── Domain/                      # Hardware & Metric types
│   │   ├── HardwareInventory/           # DeviceProfileService, CapabilityRegistry
│   │   ├── Persistence/                 # SQLiteStore (WAL), SettingsRepository
│   │   ├── Services/                    # DeepLinkRouter, LoginItemService (SMAppService)
│   │   └── SystemMetrics/
│   │       ├── SamplingCoordinator.swift# Central telemetry coordinator & 60s ring buffers
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
│       ├── DesignSystem/                # Theme tokens, SparklineView, Swift Charts
│       ├── Resources/                   # Bundled App icon and assets
│       └── Views/
│           ├── MainLayoutView.swift     # Sidebar with live sparklines & unified router
│           ├── CommandPalette/          # Fast process search & tab switching (⌘K)
│           ├── Dashboard/
│           │   ├── PerformanceView.swift# Unified Performance & Hardware Dashboard
│           │   ├── ProcessesView.swift  # Process table, memory-first sort, "End Task"
│           │   ├── StartupAppsView.swift# Startup items management (SMAppService)
│           │   └── ...
│           ├── MenuBar/                 # MenuBarContentView status popup
│           └── Settings/                # Single-tab aligned technical settings view
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
| <kbd>⌘</kbd> + <kbd>1</kbd> | Jump to **Performance Dashboard** |
| <kbd>⌘</kbd> + <kbd>2</kbd> | Jump to **Processes** |
| <kbd>⌘</kbd> + <kbd>3</kbd> | Jump to **Startup Apps** |
| <kbd>⌘</kbd> + <kbd>4</kbd> | Jump to **Settings** |
| <kbd>⌘</kbd> + <kbd>K</kbd> | Open **Command Palette** (Instant Process Search & End Task) |
| <kbd>⌘</kbd> + <kbd>R</kbd> | Force Telemetry Refresh |

---

## 🔒 Privacy & Ephemeral Telemetry

- **100% In-Memory Telemetry:** Telemetry metrics are retained strictly in 60-sample in-memory ring buffers. No long-term metric rollups are written to disk.
- **100% Offline:** The app makes zero external network connections.
- **Zero Third-Party SDKs:** No analytics, trackers, or crash reporting libraries are bundled.

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
