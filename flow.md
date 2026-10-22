# Task Manager for macOS — Implementation Architecture & Research Journey

**Document Purpose:** Living architecture specification, research paper reference, and end-to-end technical implementation log for the **Task Manager for macOS** desktop platform.  
**Version:** 2.0.0  
**Target Platform:** macOS 13.0+ (Ventura, Sonoma, Sequoia)  
**Binary Architecture:** Universal (`arm64` Apple Silicon + `x86_64` Intel)  
**License:** MIT License  

---

## 1. Executive Summary & Research Motivation

Desktop operating systems rely fundamentally on performance management utilities to inspect runtime processes, diagnose hardware resource saturation, and terminate unresponsive software. On Microsoft Windows, the native **Windows Task Manager** has set a decades-long standard for centralized software and hardware diagnostics.

On macOS, users have historically been fragmented between:
1. **Activity Monitor:** A functional but aging system utility lacking unified multi-engine GPU time-series graphs, modern UI paradigms, or startup item management.
2. **Third-Party Telemetry Utilities:** Applications that often require intrusive kernel extensions, root background daemons, closed-source subscription models, or heavy Electron/web runtimes that themselves consume significant system resources (200MB–600MB RAM).

### The Research Question
Can an independent, zero-dependency, open-source macOS desktop application achieve complete parity with the **Windows Task Manager** model by:
- Operating strictly within user-space privilege boundaries (zero root daemons or private kernel extensions),
- Delivering live, empirical **GPU engine visualization** (Device, Renderer, Tiler, and VRAM) alongside multi-core CPU, Mach VM memory, storage, and network telemetry,
- Providing instantaneous **"End Task"** process control with graceful and forced termination pipelines,
- Maintaining a featherlight runtime profile (< 0.4% CPU idle, ~25MB memory footprint), and
- Operating 100% offline with zero remote telemetry or account registration?

This document formalizes the architecture, implementation journey, and technical mechanisms that accomplish this goal.

---

## 2. High-Level System Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       SwiftUI Native Presentation                           │
│   • Software (Processes Table, Per-Process CPU/Memory, End Task Control)    │
│   • Performance (CPU, Memory, GPU, Disk, Network 60s Live Time-Series)      │
│   • Startup Apps (SMAppService Login Items & Launch Services)               │
│   • Hardware & Specs (Empirical Hardware Discovery & Capability Matrix)     │
│   • System (Sampling Frequency, Theme Settings, MenuBarExtra Status)        │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ State & Action Dispatch
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                   AppEnvironment (Observable Central State)                 │
│         Reactive State • Sampling Coordinator • Navigation Router           │
└──────────────────────────┬─────────────────────────────┬────────────────────┘
                           │                             │
┌──────────────────────────▼──────────────┐   ┌──────────▼────────────────────┐
│         Hardware Discovery Layer        │   │     System Telemetry Layer    │
│  • DeviceProfileService (M1-M4 & Intel) │   │  • Mach Kernel Host Statistics│
│  • CapabilityRegistry (Truthful Audits) │   │  • Mach VM Page Accounting    │
│  • DeepLinkRouter (taskmanager://)      │   │  • IOKit IOAccelerator (GPU)  │
│  • LoginItemService (SMAppService)      │   │  • Apple Metal Device Bridge  │
│                                         │   │  • BSD getifaddrs Interface   │
│                                         │   │  • libproc & Process Control  │
└──────────────────────────┬──────────────┘   └──────────┬────────────────────┘
                           │                             │
┌──────────────────────────▼─────────────────────────────▼────────────────────┐
│                          Infrastructure & Persistence                       │
│  • SQLiteStore (Embedded C libsqlite3, WAL mode, foreign keys enabled)      │
│  • MetricRollupRepository (Downsampled Telemetry Time Series for SQLite)    │
│  • SettingsRepository (User Preferences & Sampling Rate Persistence)        │
│  • SMAppService (User-Controlled Launch at Login Registration)              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Empirical GPU Telemetry & Visualization Engine

Unlike CPU statistics (`host_statistics64`), macOS does not provide a public `sysctl` for live GPU utilization. To provide true Windows Task Manager style GPU visualization, the application combines **IOKit IOAccelerator service matching** with **Apple Metal runtime inspection**:

### Technical Mechanism:
1. **Hardware Detection:** Queries Apple Metal via `MTLCopyAllDevices()` to obtain the primary GPU device name, unified memory architecture flags (`hasUnifiedMemory`), and recommended working set constraints (`recommendedMaxWorkingSetSize`).
2. **IOKit IOAccelerator Extraction:** Opens `IOServiceMatching("IOAccelerator")` via `kIOMainPortDefault` and inspects the dynamic `PerformanceStatistics` dictionary published by the graphics kernel driver:
   - `Device Utilization %`: Total aggregated GPU load percentage.
   - `Renderer Utilization %`: Pixel and vertex shading pipeline utilization.
   - `Tiler Utilization %`: Tile-based deferred rendering (TBDR) pipeline utilization specific to Apple Silicon architecture.
   - `Alloc system memory`: Total memory allocated by the graphics subsystem.
   - `In use system memory`: Active resident memory bound to current rendering context.
3. **Ring Buffer Streaming:** Metric samples are piped directly into an in-memory `MetricRingBuffer(capacity: 60)` that updates every sampling tick (default 1.0s) and renders continuously into `GPUTimeSeriesChart` using Apple's declarative `Swift Charts` framework.

---

## 4. Process Inspection & "End Task" Control Pipeline

The application delivers parity with the Windows Task Manager "End Task" functionality through a multi-tiered process management engine:

```text
[User selects process in ProcessesView]
                  │
                  ▼
         [Clicks "End Task"]
                  │
         ┌────────┴────────┐
         │                 │
         ▼ (Standard)      ▼ (Force Kill Option)
NSRunningApplication.terminate()     kill(pid, SIGKILL)
         │                                   │
   [Graceful Exit]                   [Instant Termination]
         │                                   │
         └────────┬──────────────────────────┘
                  ▼
         SamplingCoordinator.tick()
                  ▼
     Processes table refreshes live
```

### Process Metrics Collection:
- **Per-Process CPU %:** Derived by computing thread CPU time differentials (`proc_pidinfo` with `PROC_PIDTHREADINFO` and `proc_taskinfo`) across successive sampling intervals:
  $$\text{CPU} \% = \frac{\Delta \text{User Time} + \Delta \text{System Time}}{\Delta \text{Wall Clock Time}} \times 100$$
- **Resident Memory:** Calculated directly via `proc_taskinfo.pti_resident_size`.
- **Architecture Detection:** Evaluates process binary slice architecture via `posix_spawnattr` or Mach-O inspection, distinguishing between native `Apple Silicon (arm64)` and translated `Intel 64-bit (x86_64)` processes.

---

## 5. Multi-Resource Performance Architecture

The **Performance** workspace implements a dedicated subtab architecture matching Windows Task Manager:

| Resource | Metrics Captured | Kernel Source API | Visualization Component |
|:---|:---|:---|:---|
| **CPU** | Total %, User %, System %, Cores, Architecture | Mach `host_statistics64(HOST_CPU_LOAD_INFO)` | `CPUTimeSeriesChart` |
| **Memory** | Active, Wired, Compressed, Free, Pressure Level | Mach `vm_statistics64`, `memorystatus_vm_pressure_level` | `MemoryTimeSeriesChart` + Stacked Bar |
| **GPU** | Utilization %, Renderer %, Tiler %, VRAM Alloc/In-Use | IOKit `IOAccelerator`, Apple Metal `MTLCopyAllDevices` | `GPUTimeSeriesChart` |
| **Disk** | Volume Mounts, Format (APFS), Total, Used, Free | Cocoa `NSURLResourceKey` filesystem volume keys | Disk Capacity Gauges |
| **Network**| Inbound (Download) B/s, Outbound (Upload) B/s, Totals | BSD `getifaddrs` socket delta counter | `NetworkThroughputChart` |

---

## 6. Startup Applications & Service Management

Configuring applications that run at login on macOS has historically been cumbersome due to legacy deprecated mechanisms (e.g. `LSSharedFileList`, AppleScript, and raw `LaunchAgents` plists).

Task Manager for macOS leverages Apple's modern **`ServiceManagement.SMAppService`** framework:
- Uses `SMAppService.mainApp.status` to determine registration state (`.enabled`, `.notRegistered`, etc.).
- Allows one-click opt-in registration (`try SMAppService.mainApp.register()`) or unregistration without root privilege escalation.
- Provides deep-link redirection to native macOS System Settings (`x-apple.systempreferences:com.apple.LoginItems-Settings.extension`) for third-party background launch agents.

---

## 7. Implementation Journey & Evolution

### Phase 1: Architectural Refocusing
- **User Instruction:** Eliminate daily task management (Inbox, Today, Projects, Tags, Recurrence, Insights) and transform the application strictly into a hardware and software performance monitor like Windows Task Manager.
- **Deletions:** Removed all task domain models (`TaskItem`, `Project`, `Tag`, `RecurrenceRule`), daily task views, task repositories, and test runners (`sas.md`, `Tests/`).
- **Persistence Pruning:** Simplified `MigrationManager` to focus exclusively on settings and metric telemetry rollups (`metric_rollups` and `settings` tables).

### Phase 2: Hardware & Software Telemetry Expansion
- **GPU Telemetry:** Developed `GPUProvider.swift` harnessing IOKit `IOAccelerator` performance counters and Metal device descriptors. Added `GPUTimeSeriesChart` to `ChartViews.swift`.
- **Process Management:** Enhanced `ProcessProvider.swift` with CPU usage differential algorithms, resident memory tracking, architecture classification, and `terminateProcess(pid:force:)` for "End Task".
- **Central Coordinator:** Updated `SamplingCoordinator.swift` with 60-sample ring buffers for CPU, Memory, GPU, Network In, and Network Out, coupled with periodic SQLite rollup persistence.

### Phase 3: Windows-Style UI Redesign
- **Navigation:** Updated `MainLayoutView.swift` to feature:
  - Header branding showcasing `icon/icon.png`.
  - Software tab: **Processes** (with live process count badge) and **Startup Apps**.
  - Hardware tab: **CPU**, **Memory**, **GPU**, **Disk**, **Network**, and **Hardware & Specs**.
- **Processes View:** Built a full-featured process manager with instant search, multi-column sorting, and an interactive "End Task" button.
- **Performance View:** Created a master-detail dashboard with resource selector cards on the left and dedicated 60-second live time-series charts on the right.
- **Menu Bar Utility:** Redesigned `MenuBarContentView.swift` as a lightweight hardware monitor showing live CPU %, Memory %, GPU %, Network throughput, and battery condition.

### Phase 4: Production Packaging & Asset Integration
- **Icon Bundling:** Updated `Scripts/build-app.sh` to convert `icon/icon.png` into a native macOS `AppIcon.icns` bundle (16x16 through 1024x1024@2x) and package a self-contained release `.app`.
- **SPM Resource Integration:** Configured `Package.swift` to bundle `icon.png` as a runtime module resource for in-app branding.
- **Verification:** Successfully compiled and built with zero errors via `swift build` and `./Scripts/build-app.sh`.

---

## 8. Final Repository Structure

```text
Task-Manager/
├── icon/
│   └── icon.png                         # High-resolution application master icon
├── dist/
│   └── Task Manager.app                 # Compiled native macOS application bundle
├── flow.md                              # This living research architecture document
├── README.md                            # Professional GitHub documentation with icon logo
├── Package.swift                        # SwiftPM manifest with bundled resources
├── Scripts/
│   └── build-app.sh                     # Automated release compilation and .icns generator
└── Sources/
    ├── TaskManagerCore/                 # Telemetry & Domain Engine
    │   ├── Domain/                      # Hardware & Metric types
    │   ├── HardwareInventory/           # DeviceProfileService, CapabilityRegistry
    │   ├── Persistence/                 # SQLiteStore, MetricRollupRepository, SettingsRepository
    │   ├── Services/                    # DeepLinkRouter, LoginItemService
    │   └── SystemMetrics/               # SamplingCoordinator & Hardware Providers
    └── TaskManagerApp/                  # Presentation Layer
        ├── App/                         # TaskManagerApp, AppEnvironment
        ├── DesignSystem/                # Theme, CardView, ChartViews (CPU, Memory, GPU, Net)
        ├── Resources/                   # icon.png resource bundle
        └── Views/                       # MainLayoutView, ProcessesView, PerformanceView, etc.
```
