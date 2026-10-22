# Task Manager for macOS

<div align="center">

[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue?logo=apple&style=for-the-badge)](https://developer.apple.com/macos/)
[![Language](https://img.shields.io/badge/Swift-6.0%20%7C%206.3-orange?logo=swift&style=for-the-badge)](https://swift.org)
[![Architecture](https://img.shields.io/badge/Architecture-Universal%20(arm64%20%2B%20x86__64)-purple?style=for-the-badge)](https://developer.apple.com/documentation/apple-silicon)
[![Storage](https://img.shields.io/badge/Storage-Embedded%20SQLite%20WAL-success?logo=sqlite&style=for-the-badge)](https://sqlite.org)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline%20%26%20Zero%20Telemetry-emerald?style=for-the-badge)](#privacy-first-guarantee)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

<p align="center">
  <strong>A polished, lightweight, privacy-first native task manager unified with an advanced local Mac system diagnostics dashboard and always-available menu-bar presence.</strong>
</p>

[Key Features](#key-features) •
[Architecture](#architecture--design-principles) •
[Quickstart](#quickstart--running-locally) •
[Hardware & Capabilities Model](#the-truthful-capability-model) •
[Documentation](#documentation) •
[Contributing](#contributing)

</div>

---

## 📖 Overview

**Task Manager for macOS** unifies two first-class workspaces into one cohesive, lightning-fast native desktop application:
1. **Work Management:** A prioritized daily command center (Today, Inbox, Upcoming, Projects, Tags, Completed) with keyboard-first workflows, inline title editing, recurrence storm prevention, and GitHub-style completion heatmaps.
2. **Mac Dashboard:** An empirical, kernel-level system monitoring suite (CPU utilization, Mach VM memory pressure, storage volumes, IOKit battery telemetry, BSD network throughput, and running processes).

### Why Task Manager?
- **Zero Web Runtimes:** No Electron, Chromium, Node.js, or local web servers. Built natively using SwiftUI, AppKit, Swift Charts, and Darwin Mach kernel APIs.
- **Featherlight Footprint:** Idles with negligible CPU usage (< 0.5%) and ~30MB memory.
- **Truthful Hardware Telemetry:** Distinguishes live samples, estimates, cached values, and unexposed APIs. Never fabricates fake temperatures (0°C) or fan speeds (0 RPM).
- **100% Offline & Local-First:** All task records, project hierarchies, and telemetry rollups stay strictly on your Mac in an embedded SQLite database (`~/Library/Application Support/TaskManager/taskmanager.sqlite`).

---

## ⚡ Key Features

### 📋 Task Management
- **Today Command Center:** Daily dashboard grouping overdue, scheduled, and unscheduled work alongside an animated circular progress ring.
- **Inbox & Rapid Capture:** Distraction-free triage area with priority assignment and project classification.
- **Upcoming Timeline:** Near-future calendar view grouping tasks by date to resolve schedule conflicts.
- **Projects & Sections:** Color-coded projects with progress tracking, sections, and safe deletion (reassigns tasks without silent data loss).
- **Recurrence Engine:** Daily, weekly, monthly, and weekday schedules with anti-storm algorithms preventing backlogs of missed instances.
- **Command Palette (`⌘K`):** Global Spotlight-style overlay for instant navigation, task search, and rapid creation.
- **Productivity Analytics:** 12-week GitHub-style activity matrix (`ActivityHeatmapCanvas`), weekly completion trends, and priority distribution bar charts.

### 🖥️ Mac System Diagnostics
- **CPU Time-Series:** Mach host tick deltas (`HOST_CPU_LOAD_INFO`) rendered in interactive Swift Charts with user/system/idle breakdowns.
- **Memory Composition:** Deep VM statistics (active, wired, compressed, and free pages) combined with Darwin kernel memory pressure alerts.
- **Volume Inspection:** Clean `NSURLResourceKey` filesystem gauges without intrusive whole-disk crawling.
- **IOKit Battery Telemetry:** Real-time charge level, charging status, cycle counts, health condition, and graceful desktop Mac fallbacks (`notPresent`).
- **Network Throughput:** Dual-line download/upload throughput charts in B/s, KB/s, and MB/s via BSD `getifaddrs`.
- **Process Inventory:** Zero-privilege inspectable application list via `NSWorkspace` and `libproc`.

### 🔍 Truthful Hardware & Capabilities Model
- Discovers hardware dynamically across all MacBook Air, MacBook Pro, Mac mini, Mac Studio, and iMac tiers (M1 through M4, plus Intel).
- Explicitly classifies every sensor reading into typed states:
  - `available`
  - `notPresent` (e.g. desktop Mac without internal battery)
  - `unsupportedByOS`
  - `notExposedBySupportedAPI` (e.g. Fan RPM or GPU utilization that Apple does not expose via non-private public APIs)
  - `permissionRequired` (e.g. Location Services for Wi-Fi SSID)

### 🚀 Native Integrations
- **Always-Available `MenuBarExtra`:** Minimal menu bar presence for quick task entry, Today's top tasks, and compact CPU/RAM/Battery status.
- **Native Widget Snapshot Store:** Atomically serialized JSON snapshots for WidgetKit extensions without SQLite database contention.
- **Opt-in Launch at Login:** Uses Apple's modern `SMAppService` framework without background root daemons.
- **Deep-Link URL Scheme:** Full routing support for `taskmanager://today`, `taskmanager://inbox`, `taskmanager://upcoming`, `taskmanager://dashboard/*`, and `taskmanager://capture`.

---

## 🏗 Architecture & Design Principles

```text
TaskManager/
├── Sources/
│   ├── TaskManagerCore/                 # Core Domain & System Engine
│   │   ├── Domain/
│   │   │   ├── Tasks/                   # TaskItem, TaskStatus, TaskPriority, TaskFilter
│   │   │   ├── Projects/                # Project, ProjectSection
│   │   │   ├── Tags/                    # Tag, TaskTag
│   │   │   ├── Recurrence/              # RecurrenceRule, RecurrenceEngine
│   │   │   ├── Metrics/                 # MetricSample, CapabilityStatus, CapabilityRecord
│   │   │   ├── Hardware/                # DeviceProfile, HardwareCategory
│   │   │   └── Insights/                # ProductivityInsights, HeatmapDay, TrendPoint
│   │   ├── Persistence/
│   │   │   ├── SQLiteStore.swift        # Thread-safe re-entrant SQLite wrapper with WAL
│   │   │   ├── Migrations/              # Schema Migration Manager (v1 Baseline)
│   │   │   └── Repositories/            # Task, Project, Tag, MetricRollup, Settings
│   │   ├── SystemMetrics/
│   │   │   ├── SamplingCoordinator.swift# Adaptive lifecycle telemetry sampler & ring buffers
│   │   │   └── Providers/               # CPU, Memory, Storage, Battery, Network, Process
│   │   ├── HardwareInventory/
│   │   │   ├── DeviceProfileService.swift # Model ID lookup (M1-M4 & Intel), OS version, Metal GPUs
│   │   │   └── CapabilityRegistry.swift   # Truthful inventory covering 10 hardware categories
│   │   └── Services/
│   │       ├── Notifications/           # UserNotifications local reminders
│   │       ├── ImportExport/            # JSON schema backup/import & CSV export
│   │       ├── SharedWidgetData/        # WidgetSnapshotStore atomic serialization
│   │       ├── LoginItem/               # SMAppService launch at login
│   │       └── DeepLink/                # DeepLinkRouter (taskmanager://)
│   └── TaskManagerApp/                  # SwiftUI Application Target
│       ├── App/                         # TaskManagerApp entry point, AppEnvironment
│       ├── DesignSystem/                # Spacing, typography, CardView, StatusBadge, Charts
│       └── Views/                       # Work, Insights, Dashboard, Settings, MenuBar, Palette
├── Tests/
│   └── TaskManagerTestRunner/           # Comprehensive automated 5-phase test suite
├── Scripts/
│   ├── build-app.sh                     # Native .app bundle packaging
│   ├── build-universal.sh               # Universal lipo binary compiler (arm64 + x86_64)
│   └── package-dmg.sh                   # Compressed read-only DMG generator
├── Documentation/
│   ├── PRIVACY.md                       # Comprehensive data handling audit
│   ├── RELEASE.md                       # Codesigning and notarization workflow
│   └── THIRD_PARTY_NOTICES.md           # Zero-dependency certification
├── flow.md                              # Living implementation log and research paper notes
├── Package.swift                        # Swift Package Manager manifest
└── LICENSE                              # MIT License
```

---

## 🛠 Quickstart & Running Locally

### Prerequisites
- macOS 13.0 or later.
- Apple Swift 5.9+ / Swift 6.x (installed via Xcode or Command Line Tools: `xcode-select --install`).

### Build & Run
```bash
# Clone the repository
git clone https://github.com/K-692/Task-Manager4MacOS.git
cd Task-Manager4MacOS

# Compile the project
swift build

# Run the native application
swift run TaskManager
```

### Run Automated Tests
```bash
swift run TaskManagerTestRunner
```

```text
==================================================
  Task Manager for macOS — Test Suite Runner
==================================================

👉 [1/5] Running TaskDomainTests...
   ✅ TaskDomainTests passed successfully.

👉 [2/5] Running RecurrenceEngineTests...
   ✅ RecurrenceEngineTests passed successfully.

👉 [3/5] Running SQLiteStore & RepositoryTests...
   ✅ SQLiteStore & RepositoryTests passed successfully.

👉 [4/5] Running DeviceProfile & CapabilityRegistryTests...
   ✅ DeviceProfile & CapabilityRegistryTests passed successfully.

👉 [5/5] Running ImportExport & WidgetSnapshotTests...
   ✅ ImportExport & WidgetSnapshotTests passed successfully.

==================================================
🎉 ALL TEST SUITES PASSED (5/5) WITH ZERO FAILURES!
==================================================
```

### Assemble `.app` and `.dmg` Installers
```bash
# Package standard .app bundle into dist/
./Scripts/build-app.sh

# Generate compressed DMG disk image with Applications link
./Scripts/package-dmg.sh
```

---

## 🔒 Privacy-First Guarantee

- **No Remote Network Calls:** Task Manager has zero networking code for sending telemetry, analytics, or task data.
- **Direct Export:** Users can export their complete workspace to documented JSON or CSV at any time in `Settings > Data & Privacy`.
- **Zero Sensor Activation:** Diagnostic scans never turn on the FaceTime camera or record microphone audio.
- Read our full audit in [PRIVACY.md](Documentation/PRIVACY.md).

---

## 🤝 Welcoming Contributors

Contributions from the developer community are warmly welcomed! Whether you want to improve accessibility, refine Swift Charts visualizations, add new hardware model mappings, or write localization strings:

1. **Fork the Repository** on GitHub.
2. **Create a Feature Branch:** `git checkout -b feature/amazing-feature`.
3. **Write Tests:** Ensure all existing and new tests pass via `swift run TaskManagerTestRunner`.
4. **Commit Your Changes:** `git commit -m 'feat: Add support for custom project sorting'`.
5. **Open a Pull Request:** We review and merge quality PRs actively!

---

## 📄 License

Task Manager is released under the **[MIT License](LICENSE)**. Feel free to use, modify, and distribute this software freely.
