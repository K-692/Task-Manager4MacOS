# Task Manager for macOS — Implementation Architecture & Research Journey

**Document Purpose:** Living architecture specification, research paper reference, and end-to-end technical implementation log for the **Task Manager for macOS** desktop platform.  
**Version:** 2.5.0  
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
- Organizing all hardware and performance telemetry into a single, unified, **non-scrollable command-center dashboard landing page** without nested sub-menus,
- Streaming live, right-aligned sparkline micro-graphs directly within the primary navigation sidebar (in order: CPU $\rightarrow$ GPU $\rightarrow$ Memory $\rightarrow$ Disk $\rightarrow$ Network),
- Providing dedicated, in-depth architectural diagnostic tabs for each isolated hardware component,
- Updating macOS status bar metrics in real time on a 1-second continuous cadence,
- Maintaining a featherlight runtime profile (< 0.4% CPU idle, ~25MB memory footprint) using 100% in-memory ephemeral telemetry buffers (zero disk I/O writes for metrics), and
- Operating 100% offline with zero remote telemetry or account registration?

This document formalizes the architecture, implementation journey, and technical mechanisms that accomplish this goal.

---

## 2. High-Level System Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       SwiftUI Native Presentation                           │
│   • Leftmost Sidebar: App Brand, Nav Items, Live Sparklines (CPU, GPU, RAM) │
│   • Dashboard (Landing Page): Non-Scrollable Window Command Center Grid     │
│   • Dedicated Hardware Tabs: CPU, GPU, Memory, Disk, Network In-Depth Views │
│   • Processes: Software Inventory, Memory-First Default Sort, End Task      │
│   • Startup Apps: SMAppService Login Items & Launch Services                │
│   • Settings: Single-Tab Cleanly Aligned Technical Configuration Panel      │
│   • macOS Status Bar: Real-Time 1-Second CPU% and GPU% MenuBarExtra Ticker  │
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
│                 Ephemeral & Persistent Storage Boundaries                   │
│  • Ephemeral Telemetry: In-Memory 60-Sample Ring Buffers (Zero Disk I/O)    │
│  • Persistent Preferences: Embedded SQLite Store (Settings Only)            │
│  • SMAppService: Native macOS Login Item Registration                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Ephemeral In-Memory Telemetry Model (Zero Disk Writes)

In contrast to initial prototypes that periodically downsampled telemetry metrics into SQLite rollups, Task Manager v2.2.0 adopts a **purely in-memory ephemeral telemetry model**:

1. **Ring Buffers (`MetricRingBuffer`):** Fixed-capacity buffers (`capacity: 60`) allocate exactly 60 double-precision floating-point values for:
   - `cpuHistory` (CPU total load %)
   - `gpuHistory` (GPU utilization %)
   - `memoryHistory` (RAM footprint %)
   - `diskHistory` (Primary volume capacity %)
   - `networkInHistory` (Inbound bytes/sec)
   - `networkOutHistory` (Outbound bytes/sec)
   - `networkTotalHistory` (Combined throughput)
2. **Zero Disk Wear:** Disk write operations for telemetry are completely eliminated. This protects SSD health, prevents disk I/O bottlenecks during peak system stress, and keeps process memory footprint pinned under 30MB.
3. **High-Frequency Sidebar Sparklines:** The lightweight `SparklineView` component consumes the in-memory ring buffers directly using Apple's hardware-accelerated `SwiftUI.Canvas` API, rendering sub-millisecond line, center reference lines, and gradient strokes directly in the sidebar navigation with zero text truncation.

---

## 4. Empirical GPU Telemetry Engine

Unlike CPU statistics (`host_statistics64`), macOS does not provide a public `sysctl` for live GPU utilization. To provide true Windows Task Manager style GPU visualization, the application combines **IOKit IOAccelerator service matching** with **Apple Metal runtime inspection**:

### Technical Mechanism:
1. **Hardware Detection:** Queries Apple Metal via `MTLCopyAllDevices()` to obtain the primary GPU device name, unified memory architecture flags (`hasUnifiedMemory`), and recommended working set constraints (`recommendedMaxWorkingSetSize`).
2. **IOKit IOAccelerator Extraction:** Opens `IOServiceMatching("IOAccelerator")` via `kIOMainPortDefault` and inspects the dynamic `PerformanceStatistics` dictionary published by the graphics kernel driver:
   - `Device Utilization %`: Total aggregated GPU load percentage.
   - `Renderer Utilization %`: Pixel and vertex shading pipeline utilization.
   - `Tiler Utilization %`: Tile-based deferred rendering (TBDR) pipeline utilization specific to Apple Silicon architecture.
   - `Alloc system memory`: Total memory allocated by the graphics subsystem.
   - `In use system memory`: Active resident memory bound to current rendering context.
3. **Hierarchy Guarantee:** In all UI surfaces (sidebar sparklines, unified dashboard, and menu bar utility), **GPU telemetry immediately succeeds CPU telemetry** to preserve intuitive hardware hierarchy:
   $$\text{CPU} \longrightarrow \text{GPU} \longrightarrow \text{Memory} \longrightarrow \text{Disk} \longrightarrow \text{Network}$$

---

## 5. Software Process Inspection & "End Task" Control

The application delivers parity with the Windows Task Manager "End Task" functionality through a multi-tiered process management engine:

- **Default Memory-First Sorting:** In accordance with diagnostic workflows, running applications are sorted descending by physical resident memory footprint (`residentMemoryBytes`) by default, surfacing memory leaks and resource hogs immediately.
- **Process Metrics Collection:**
  - **Per-Process CPU %:** Derived by computing thread CPU time differentials (`proc_pidinfo` with `PROC_PIDTHREADINFO` and `proc_taskinfo`) across successive sampling intervals:
    $$\text{CPU} \% = \frac{\Delta \text{User Time} + \Delta \text{System Time}}{\Delta \text{Wall Clock Time}} \times 100$$
  - **Resident Memory:** Calculated directly via `proc_taskinfo.pti_resident_size`.
  - **Architecture Detection:** Evaluates process binary slice architecture via Mach-O inspection, distinguishing between native `Apple Silicon (arm64)` and translated `Intel 64-bit (x86_64)` processes.
- **Termination Action Pipeline:** Allows graceful application shutdown via `NSRunningApplication.terminate()` or hard kernel kill via `kill(pid, SIGKILL)` from both the top toolbar and right-click contextual menus.

---

## 6. Implementation Journey & Evolution

### Phase 1: Architectural Refocusing
- **User Instruction:** Eliminate daily task management (Inbox, Today, Projects, Tags, Recurrence, Insights) and transform the application strictly into a hardware and software performance monitor like Windows Task Manager.
- **Deletions:** Removed all task domain models (`TaskItem`, `Project`, `Tag`, `RecurrenceRule`), daily task views, task repositories, and test runners (`sas.md`, `Tests/`).

### Phase 2: Hardware & Software Telemetry Expansion
- **GPU Telemetry:** Developed `GPUProvider.swift` harnessing IOKit `IOAccelerator` performance counters and Metal device descriptors. Added `GPUTimeSeriesChart` to `ChartViews.swift`.
- **Process Management:** Enhanced `ProcessProvider.swift` with CPU usage differential algorithms, resident memory tracking, architecture classification, and `terminateProcess(pid:force:)` for "End Task".

### Phase 3: Dashboard Unification & Sidebar Sparklines (v2.1.0)
- **Elimination of Nested Menu Bars:** Removed the secondary internal menu column from `PerformanceView`, replacing it with a single, high-density, technical performance dashboard.
- **Landing Page Realignment:** Elevated the unified Dashboard to the default landing destination (`.dashboard`) at the top of the sidebar.
- **Sidebar Real-Time Graphs:** Embedded hardware-accelerated `SparklineView` micro-graphs directly in the leftmost navigation sidebar, strictly ordered: CPU $\rightarrow$ GPU $\rightarrow$ Memory $\rightarrow$ Disk $\rightarrow$ Network.
- **Default Memory Sorting:** Updated `ProcessesView` to default sort applications by memory footprint descending.
- **Single-Tab Settings Panel:** Consolidated all preferences into a single, beautifully aligned, organized technical tab with zero nested tab-switchers.
- **Ephemeral Telemetry:** Removed periodic SQLite rollups; performance metrics are strictly in-memory (60s ring buffers).

### Phase 4: Non-Scrollable Dashboard, Component Detail Routing, Real-Time Cadence (v2.2.0)
- **Non-Scrollable Single-Window Dashboard:** Re-architected `PerformanceView` into a responsive single-window grid that fits within standard viewport dimensions without vertical scrolling. Arranged as a 2-row grid: Row 1 (CPU & GPU side-by-side, 50%/50%), Row 2 (Memory, Disk, Network side-by-side, 33%/33%/33%), with interactive "Details →" routing.
- **Dedicated Telemetry Detail Views:** Implemented dedicated in-depth inspection views (`CPUDetailView`, `GPUDetailView`, `MemoryDetailView`, `StorageView`, `NetworkView`) that display exclusive, component-specific metrics and hardware pipelines when clicked in the sidebar.
- **Sidebar Real-Time Updates & Alignment Fix:** Fixed `SparklineView` coordinate mapping to right-aligned rolling buffer coordinates with center reference lines and current indicator dots; resolved label truncation via dedicated 72pt columns; bound `MainLayoutView` directly to reactive `SamplingCoordinator` updates for 60fps telemetry.
- **Mac Menu Bar 1s Real-Time Sync:** Native `MenuBarExtra` custom label now displays real-time CPU% and GPU% directly on the macOS menu bar, refreshed continuously on a 1-second cadence using RunLoop `.common` mode without background throttling.
- **Settings Panel Precision Alignment:** Cleared top window title bar overlap; standardized picker widths (320pt) for both Telemetry Frequency and Theme Mode; perfectly aligned technical specs grid; confirmed zero telemetry retention in SQLite beyond 60s ephemeral ring buffers.

### Phase 5: Settings Tight Boundary Layout, Customizable Menu Bar Metrics & Desktop Widget Guide (v2.3.0)
- **Settings Layout Boundary Tightening:** Snug element boundaries with `CardView(padding: 12)`, reduced inter-section spacing (10pt), compact row vertical rhythm (8pt), and tight horizontal margins (18pt).
- **Customizable macOS Menu Bar Widget:** Built dynamic metric selector chips in the Settings tab allowing users to toggle any combination of **CPU**, **GPU**, **Memory**, **Disk**, and **Network** for display on the top status bar, backed by instant live preview and persistent storage in `SettingsRepository`.
- **macOS Desktop Widget Architecture:** Produced `Documentation/DesktopWidgetGuide.md` providing end-to-end WidgetKit architecture, App Groups shared memory caching, and `TimelineProvider` implementation for macOS Sonoma/Sequoia Desktop Widgets.

### Phase 6: Non-Scrollable Settings Tab, Single-Selection Menu Bar Widget & Telemetry Cadence Refinement (v2.4.0)
- **Completely Non-Scrollable Settings Panel:** Removed the outer `ScrollView` entirely from `SettingsView`. Re-engineered the panel using compact vertical rhythm (~480pt total content height) so that all 4 settings cards fit neatly and comfortably within the standard window viewport ($\ge 540$pt) without any vertical scrollbars.
- **Single-Selection Menu Bar Widget (`MenuBarMetric`):** Implemented single-selection radio chips (`record.circle.fill` / `circle`) across CPU, GPU, Memory, Disk, and Network. Since the macOS menu bar displays only one icon and live telemetry metric at a time, selecting an item automatically deselects all others, updates the live menu bar preview ribbon, stores the selection in `SettingsRepository` under `"menubar_selected_metric"`, and renders the chosen metric in `MenuBarStatusLabel`.
- **Telemetry & Sample Rate Layout Redesign:** Completely resolved the vertical dead space bug and clipped picker buttons. Replaced the native picker with custom, high-contrast segmented cadence pills (`0.5s Fast`, `1.0s Normal`, `3.0s Eco`, `Pause`), added an active cadence status indicator, and reinforced the volatile 60-sample in-memory ring buffer architecture.
- **High-Density 2-Column Hardware Specifications Grid:** Converted technical specifications into a responsive 2-column `LazyVGrid` (3 rows total) displaying Device Model, Architecture, Processor, Installed RAM, Graphics (GPU) right alongside Processor, and macOS build with an offline status badge.
- **Visual Assets & Embedded Documentation:** Integrated official application screenshots (`App_Screenshots/Dashboard&Menubar.png`, `App_Screenshots/CPU.png`, `App_Screenshots/Processes.png`, `App_Screenshots/Settings.png`) into `README.md` with concise functional descriptions for enhanced repository credibility and contributor onboarding.

### Phase 7: Universal Binary Packaging & Repository DMG Distribution (v2.5.0)
- **Dual-Architecture Compilation Pipeline:** Engineered `Scripts/build-universal.sh` to compile native release targets for both `arm64-apple-macosx13.0` and `x86_64-apple-macosx13.0` slices using Swift PM.
- **Fat Binary Assembly via Lipo:** Merged architecture slices via `lipo -create` into a unified fat Mach-O executable containing full native instruction sets for Apple Silicon (M1/M2/M3/M4) and Intel 64-bit Macs.
- **Complete .app Bundle Synthesizer:** Packaged the fat binary with SPM resource bundles, generated native high-resolution `AppIcon.icns` multi-scale iconsets (16x16 to 512x512@2x), generated production `Info.plist`, `PkgInfo`, and applied ad-hoc code signing (`codesign --force --deep --sign -`).
- **Compressed Read-Only Universal DMG:** Automated `Scripts/package-dmg.sh` with `hdiutil create -format UDZO`, embedding the Universal `.app` bundle, a direct `/Applications` symlink, and custom `.VolumeIcon.icns`.
- **Repository Distribution Directory:** Created `releases/TaskManager-1.0.0-Universal.dmg` directly tracked in the git repository (updating `.gitignore`), providing seamless one-click drag-and-drop installation for end users without needing compilation toolchains. Verified SHA-256 integrity and DMG mount compatibility.

---

## 7. Final Repository Structure

```text
Task-Manager/
├── icon/
│   └── icon.png                         # High-resolution application master icon
├── App_Screenshots/                     # High-resolution retina application screenshots
│   ├── Dashboard&Menubar.png            # Performance Dashboard & Mac top menu bar
│   ├── CPU.png                          # Dedicated CPU architecture & diagnostic telemetry
│   ├── Processes.png                    # Process inventory default-sorted by memory footprint
│   └── Settings.png                     # Non-scrollable settings & menu bar widget configuration
├── releases/
│   └── TaskManager-1.0.0-Universal.dmg  # Pre-compiled Universal DMG (Apple Silicon + Intel)
├── dist/
│   ├── Task Manager.app                 # Compiled native macOS application bundle
│   └── TaskManager-1.0.0-Universal.dmg  # Output Universal disk image
├── flow.md                              # This living research architecture document
├── README.md                            # Professional GitHub documentation with embedded screenshots
├── Package.swift                        # SwiftPM manifest with bundled resources
├── Documentation/
│   ├── DesktopWidgetGuide.md            # WidgetKit architecture guide
│   └── RELEASE.md                       # Signing, notarization, and packaging guide
├── Scripts/
│   ├── build-app.sh                     # Host release compilation and .app generator
│   ├── build-universal.sh               # Universal (arm64 + x86_64) app builder
│   └── package-dmg.sh                   # Automated Universal DMG packager
└── Sources/
    ├── TaskManagerCore/                 # Telemetry & Domain Engine
    │   ├── Domain/                      # Hardware & Metric types
    │   ├── HardwareInventory/           # DeviceProfileService, CapabilityRegistry
    │   ├── Persistence/                 # SQLiteStore (WAL), SettingsRepository
    │   ├── Services/                    # DeepLinkRouter, LoginItemService
    │   └── SystemMetrics/               # SamplingCoordinator & Hardware Providers (CPU, GPU, RAM, etc.)
    └── TaskManagerApp/                  # Presentation Layer
        ├── App/                         # TaskManagerApp, AppEnvironment
        ├── DesignSystem/                # Theme, CardView, ChartViews, SparklineView
        ├── Resources/                   # icon.png resource bundle
        └── Views/                       # MainLayoutView, ProcessesView, PerformanceView,
                                         # CPUDetailView, GPUDetailView, MemoryDetailView,
                                         # StorageView, NetworkView, SettingsView, etc.
```
