<div align="center">

<img src="icon/icon.png" width="128" height="128" alt="Task Manager for macOS Logo" />

# Task Manager for macOS
### The Native Hardware & Software Performance Monitor for macOS

[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue?logo=apple&style=for-the-badge)](https://developer.apple.com/macos/)
[![Download DMG](https://img.shields.io/badge/Download-Universal%20DMG%20v1.6.1-2ea44f?logo=apple&style=for-the-badge)](releases/TaskManager-1.6.1-Universal.dmg)
[![Language](https://img.shields.io/badge/Swift-6.0%20%7C%205.9-orange?logo=swift&style=for-the-badge)](https://swift.org)
[![Architecture](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-purple?style=for-the-badge)](https://developer.apple.com/documentation/apple-silicon)
[![Graphics](https://img.shields.io/badge/GPU%20Telemetry-Metal%20%2B%20IOKit-indigo?logo=apple&style=for-the-badge)](https://developer.apple.com/metal/)
[![Storage](https://img.shields.io/badge/Telemetry-100%25%20In--Memory%20(Zero%20Disk%20I%2FO)-success?style=for-the-badge)](#-privacy--offline-guarantee)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Telemetry-emerald?style=for-the-badge)](#-privacy--offline-guarantee)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

<p align="center">
  <strong>A high-performance, featherlight, Windows Task Manager inspired software and hardware monitor for macOS. An always-on menu bar monitor, a fully responsive window that adapts from a full-screen command center down to a compact 460-pt panel, live multi-engine GPU metrics, Mach CPU loads, memory pressure graphs, dedicated hardware deep-dive tabs, per-process telemetry with instant "End Task", live menu bar status, and startup app control.</strong>
</p>

[Download DMG](#-download--installation) •
[Overview](#-overview) •
[Screenshots](#-application-screenshots) •
[Key Features](#-key-features) •
[GPU Monitoring](#6--gpu-visualization--telemetry-apple-metal--iokit) •
[Installation & Build](#-download--installation) •
[Keyboard Shortcuts](#-keyboard-shortcuts) •
[Contributing](#-contributing)

</div>

---

## 📖 Overview

**Task Manager for macOS** brings the familiarity, precision, and power of the **Windows Task Manager** to the Mac ecosystem. It provides real-time, empirical hardware telemetry and granular software inspection without electron bloat, root daemons, or cloud analytics.

### Why Task Manager for macOS?
- **Zero Web Runtimes:** 100% native Swift, SwiftUI, AppKit, Metal, and Darwin Mach kernel APIs. No Electron, Node.js, Chromium, or web servers.
- **Lightweight:** With the window closed it runs as a menu bar utility at about **3 % CPU** and **~75 MB** of memory (M1 MacBook Air, 1 s sampling). The window's live charts pause automatically while it is closed, minimised or fully covered.
- **Always-On Menu Bar Utility:** Closing the window never quits the app. Task Manager keeps monitoring from the menu bar (and drops its Dock icon) until you explicitly choose **Quit** (<kbd>⌘</kbd> + <kbd>Q</kbd>). It registers as a login item on first launch so it is there after every restart.
- **Fully Responsive Window:** Every screen adapts as the window shrinks: the sidebar auto-collapses, cards reflow from multi-column grids into a single column, tables hide lower-priority columns, and headers wrap. Nothing clips or overlaps from a full-screen window down to ~460 pt wide.
- **Command-Center Dashboard:** On large windows all 5 core performance graphs (CPU, GPU, Memory, Disk, Network) fill one viewport with zero scrolling; on smaller windows they become a scrollable card grid.
- **Dedicated Hardware Diagnostic Tabs:** Clicking any component in the sidebar opens an in-depth diagnostic tab exclusively detailing that component's microarchitecture, pipelines, and top processes.
- **Live Sidebar Sparklines:** Real-time mini-graphs rendered directly in the sidebar navigation in strict order: **CPU $\rightarrow$ GPU $\rightarrow$ Memory $\rightarrow$ Disk $\rightarrow$ Network**.
- **Rotating Menu Bar Ticker + Speed Test:** The menu bar item cycles CPU, GPU, Memory, Storage and Network every 2 seconds (icon + value), and its popup includes a one-click internet speed test.
- **True GPU Visualization:** Real-time GPU load percentage, renderer utilization, tiler utilization, and allocated/in-use VRAM directly from Apple Silicon & discrete GPUs.
- **Memory-First Process Sorting:** Processes default-sorted by physical resident memory footprint for instant leak detection, with instant "End Task" process control.
- **100% In-Memory Ephemeral Telemetry:** Zero disk I/O writes for metrics; live 60-second rolling ring buffers prevent SSD wear. No SQLite metric rollups $>60$ seconds.
- **Research-Ready Figures:** Switch to the minimal **Publication** theme, pick exactly which markings you want (mean, median, trend, σ band, peak, threshold and more) and press **Capture**. You get all five live telemetry charts as separate, clean title-and-graph PNG figures from the same moment.
- **Usage-Coloured Menu Bar Icon:** The menu bar icon shades continuously from green to red as usage rises; the value stays in the normal menu bar text colour (white on a dark menu bar). The icon can be hidden entirely.
- **Refreshed Design (v1.1):** Gradient icon badges, layered cards, smooth monotone charts with consistent per-component colors, and a redesigned menu bar popover with sparklines and top processes.

---

## 📸 Application Screenshots

### 1. Performance Dashboard
<p align="center">
  <img src="App_Screenshots/Dashboard.png" alt="Performance Dashboard" width="100%" />
</p>

*The Performance Dashboard is a command center with 60-second live charts for CPU, GPU, Memory, Disk and Network, a live stat ticker, and sidebar sparklines. Click any card to open that component's detail page.*

---

### 1b. Publication Theme (Paper-Ready)
<p align="center">
  <img src="App_Screenshots/Dashboard-Publication.png" alt="Dashboard in the Publication theme" width="100%" />
</p>

*The Publication theme strips the UI down to what a figure needs: white panels with thin rules, solid serif type, colour-blind-safe colours and labelled axes. Only the markings you choose are drawn (shown here: mean, median, linear trend, 80 % threshold, mean ± 1σ band, peak and minimum), each in its own publication colour. Values sit in the legend at the bottom right, so the plot stays clean.*

#### Choose your markings
<p align="center">
  <img src="App_Screenshots/Settings-Markings.png" alt="Publication markings settings with live preview" width="100%" />
</p>

*In **Settings → Publication Markings** you can toggle every marking and see a live preview. Presets: Minimal, Default, All. **Value labels** chooses where values appear: **In legend** (clean plot) or **Inside graph**. Hover any option for a description.*

#### Captured figures: title + graph only
Press **Capture** on the dashboard and five separate figures (CPU, GPU, Memory, Storage, Network) are saved to a new folder on your Desktop. All five come from the same instant, use the current theme and exactly the markings you selected, and contain nothing but the title and the graph:

<p align="center">
  <img src="App_Screenshots/Figure-CPU-Publication.png" alt="Captured CPU figure, publication theme" width="49%" />
  <img src="App_Screenshots/Figure-Network-Publication.png" alt="Captured network figure, publication theme" width="49%" />
</p>
<p align="center">
  <img src="App_Screenshots/Figure-CPU-Standard.png" alt="Captured CPU figure, standard theme" width="49%" />
</p>

*Top: Publication theme with values in the legend at the bottom right. Bottom: Standard theme.*

---

### 2. Always-On Menu Bar Monitor & Speed Test

<p align="center">
  <img src="App_Screenshots/Menubar-Usage.png" alt="Menu bar icon colour changing with usage" width="420" />
</p>

*The rotating menu bar item: only the **icon** is coloured by usage, and the value stays white. Shown: CPU 20 % (green), GPU 70 %, Memory 68 % and Storage 75 % (amber to orange), and Network at 1 KB/s (red, below 400 KB/s). The shading is continuous, not stepped.*

<p align="center">
  <img src="App_Screenshots/Menubar.png" alt="Menu bar popover" width="360" />
</p>

*The menu bar item rotates through CPU, GPU, Memory, Storage and Network every 2 seconds, showing just the component icon and its live value (or pins one metric if you turn rotation off). Its popup shows sparklines for every component, battery status, the top processes, a one-click **internet speed test** (download, upload, ping, jitter), and quick access to the dashboard, Settings, or Quit. It keeps running after the window is closed.*

---

### 3. Responsive Layout (Narrow Window)
<p align="center">
  <img src="App_Screenshots/Responsive.png" alt="Responsive narrow window layouts" width="80%" />
</p>

*Shrink the window and everything adapts: the sidebar collapses, the dashboard turns into a scrollable single-column card stack, stat pills wrap, and detail pages reflow their grids and tables.*

---

### 4. CPU Diagnostics
<p align="center">
  <img src="App_Screenshots/CPU.png" alt="CPU detail view" width="100%" />
</p>

*Each component has its own detail page, with a 60-second history, utilization breakdown bars, topology specs, and the top consuming processes.*

---

### 5. Memory Diagnostics
<p align="center">
  <img src="App_Screenshots/Memory.png" alt="Memory detail view" width="100%" />
</p>

*The Memory page shows the load history, a color-coded composition bar (wired, active, compressed, free), memory pressure, and the heaviest processes.*

---

### 6. Processes ("End Task")
<p align="center">
  <img src="App_Screenshots/Processes.png" alt="Processes view" width="100%" />
</p>

*A live inventory of every running process, sorted by memory by default. Click a column header to sort, filter by name, bundle ID or PID, and end or force-kill tasks. On narrow windows the PID, Architecture and Status columns hide automatically.*

---

### 7. Settings
<p align="center">
  <img src="App_Screenshots/Settings-MenuBar.png" alt="Menu bar widget settings" width="100%" />
</p>

*Pick the menu bar metric, control Dock-icon hiding and launch at login, set the sampling rate and appearance, and view hardware specs.*

---

## ⚡ Key Features

### 1. ⚡ Responsive Performance Dashboard (Landing Page)
- **Adaptive Command Center:** On windows ≥ 820×560 pt it shows real-time 60-second charts for all 5 hardware components in a 2-row grid that fills the window with no scrolling. Smaller windows switch to a scrollable adaptive card grid (2 columns, then 1):
  - **Row 1:** CPU Card (50% width) and GPU Card (50% width, immediately succeeding CPU).
  - **Row 2:** Memory Card (33% width), Disk Card (33% width), and Network Card (33% width).
- **Live Stat Ticker:** CPU, GPU, RAM, disk, network and process-count pills that wrap onto extra lines on narrow windows.
- **Direct Component Navigation:** Clicking any dashboard card or "Details →" button navigates straight to that component's dedicated in-depth view.

### 2. 🔍 Dedicated Hardware Diagnostic Tabs
Under `Live Hardware Telemetry` in the sidebar, selecting any component opens an isolated deep-dive inspection tab:
- **CPU:** 60s utilization chart, user/kernel/idle time split, core topology, clock speed, cache specs, and top CPU consuming processes.
- **GPU (Immediately after CPU):** 60s GPU utilization chart, renderer core %, tiler deferred rendering %, in-use VRAM, allocated VRAM, Metal 3 feature set, hardware ray tracing support, and mesh shading capabilities.
- **Memory:** 60s memory load chart, stacked color-coded Mach VM composition bar (Wired, Active, Compressed, Free), memory pressure status gauge, Mach page size, and top memory-consuming processes.
- **Disk:** 60s volume space history chart, all mounted APFS/external volume cards with capacity gauges, mount paths, and filesystem attributes.
- **Network:** 60s dual-line throughput chart (Download ↓ Cyan, Upload ↑ Indigo), primary interface status, and detailed interface adapter table with live transfer rates and session traffic.

### 3. 📊 Live Sidebar Sparklines (Real-Time Mini Graphs)
- Hardware-accelerated mini sparkline graphs stream live in the leftmost navigation sidebar in strict order:
  1. **CPU** — Live utilization % + Real-time sparkline graph
  2. **GPU** — Live GPU load % + Real-time sparkline graph (immediately after CPU!)
  3. **Memory** — Live RAM usage % + Real-time sparkline graph
  4. **Disk** — Live primary disk usage % + Real-time sparkline graph
  5. **Network** — Live throughput rate + Real-time sparkline graph
- The sidebar collapses automatically below ~680 pt of window width and comes back when the window grows (or toggle it manually).
- Uses right-aligned fixed-time coordinate mapping with center reference lines and active indicator dots.

### 4. 🍎 Always-On Menu Bar Utility
- **Optional icon:** turn **Show in menu bar** off in Settings to hide the icon. Task Manager keeps running and stays in the Dock so you can reopen it.
- **Usage-coloured icon** (always on): the menu bar **icon** shades continuously from green to red, while the **value text stays white** (black on a light menu bar):
  - **CPU, GPU, Memory, Storage:** green at low utilisation, through yellow and orange, to red at 100 %.
  - **Network:** green at 1 MB/s or more, red at 400 KB/s or less, with a smooth (logarithmic) blend in between.
  - **Adapts to the menu bar:** bright, white-leaning pastels on a dark menu bar and deeper tones on a light one, updated automatically when macOS switches between Light and Dark mode.
  - Colours apply **only to the menu bar icon**. Charts keep their normal theme colours.
- **Never Quits on Close:** Closing the main window leaves Task Manager running in the menu bar. The Dock icon hides automatically while the window is closed (toggle in Settings) and returns when you reopen it from the menu bar, Spotlight, or Finder. Only **Quit** (<kbd>⌘</kbd> + <kbd>Q</kbd>, or the power button in the popover) exits the app.
- **Starts with your Mac:** Launch at login is enabled on first run so the widget is always available after a restart. You can turn it off in Settings.
- **Rotating Status Bar Label:** Exactly every 2 seconds (driven by a strict, drift-free timer that only redraws the menu bar item) the menu bar item cycles **CPU → GPU → Memory → Storage → Network**, showing only the component's icon and its live value (no text labels) centred in a fixed-width slot, so neighbouring menu bar icons never shift. Switch rotation off in Settings to pin one metric; picking a metric while rotation is on makes the cycle start there.
- **Internet Speed Test:** Press **Run Speed Test** in the popup to measure download and upload (4 parallel streams, ~7 s and ~6 s), ping and jitter. A live Mbps gauge shows progress, and results stay in the popup until you run it again. It uses Cloudflare's public speed test servers (speed.cloudflare.com) and only runs when you press the button.
- **Popup Hardware Monitor:** Clicking the menu bar item opens a compact HUD with live sparklines for CPU, GPU, Memory, Disk and Network, battery status and the top 3 processes. Click any row to jump to its detail page.
- **Common Mode RunLoop:** Scheduling on `RunLoop.main` in `.common` mode guarantees uninterrupted 1-second updates during user mouse tracking and scrolling.

### 5. 🚀 Software & Process Management ("Processes" Tab)
- Real-time inventory of all running applications and processes with inspectable memory, PID, and architecture (`Apple Silicon` / `Intel 64-bit`).
- **Memory-First Default Sort:** Automatically sorted by resident memory footprint descending to immediately surface memory-heavy applications.
- Live CPU % utilization per process calculated across Mach thread runtime differentials.
- Instant **"End Task"** action button and context menu with graceful (`NSRunningApplication.terminate`) and forced (`SIGKILL`) termination options.
- Instant search filter by application name, bundle identifier, or process PID.

### 5b. 📄 Publication Theme & Figure Capture (for researchers)
- **Two themes** in **Settings → Theme**:
  - **Standard:** the colourful app look (follows System / Light / Dark).
  - **Publication:** minimal and paper-ready, always on a white background, with solid serif typography, solid black accents on buttons and controls, Okabe–Ito colour-blind-safe colours and solid/dashed line styles that survive greyscale printing.
- **Publication markings** (**Settings → Publication Markings**, with a live preview and Minimal / Default / All presets):

  | Group | Options |
  |:---|:---|
  | **Reference lines** | Mean (dotted) · Median (dash-dot) · Linear trend (least-squares) · Moving average (2–30 samples) · Threshold line (5–100 %, % charts) |
  | **Markers** | Peak ▲ · Minimum ◆ · Latest ● · All data points · Value labels |
  | **Bands** | Mean ± 1σ · Min–max range |
  | **Value labels** | **In legend** (default: clean plot, values listed in the legend) · **Inside graph** (values written next to each marking) · *Show values* on/off |
  | **Axes & layout** | Gridlines · Axis ticks · Axis titles (*Time (s)*, unit) · Plot frame · Legend · Smooth curves |

  - **Legend:** always below the graph and right-aligned. It shows each marking with its real line style, band or symbol in its own colour, and its value when values go in the legend. Dashboard cards, detail pages and captures all use the same legend and the same value placement.
  - **Marking colours** (Okabe–Ito, colour-blind safe): mean black, median reddish purple, linear trend bluish green, moving average sky blue, threshold vermillion, peak orange, minimum grey, bands grey. If a marking's colour would match the data line (e.g. the threshold on the vermillion GPU line), it switches to black automatically. On two-series charts (network) markings follow their series colour, and the legend lists the values for both (D = download, U = upload).
- **Capture button** on the Performance Dashboard:
  - Saves **five separate PNG figures** (`1-CPU.png`, `2-GPU.png`, `3-Memory.png`, `4-Storage.png`, `5-Network.png`) to `~/Desktop/Task Manager Capture <date> at <time> (<theme>)/`.
  - All five are rendered from **one snapshot taken at the same instant**.
  - Each figure contains **only the title and the graph** (no panel letters, device details, statistics or captions). It is drawn with exactly the selected markings, value placement and theme, with the legend at the bottom right, at 2880×1620 px.
  - Network figures auto-scale to KB/s or MB/s and never extend below zero.
- The first capture may trigger macOS's one-time **"access files in your Desktop folder"** prompt. Allow it so figures can be saved.

### 6. 🎮 GPU Visualization & Telemetry (Apple Metal + IOKit)
- **Live 60-Second Utilization Graph:** Continuous GPU engine load time-series rendered via Swift Charts.
- **Multi-Engine Breakdown:** Overall Device Utilization %, Renderer Core Utilization %, and Tiler Pipeline Utilization %.
- **VRAM / Unified Memory Tracking:** Real-time allocated system memory and active in-use VRAM.
- **Metal Hardware Profile:** Dynamic device identification via Apple Metal (`MTLCopyAllDevices`).

### 7. ⚙️ Settings & Single-Selection Menu Bar Widget
- **Responsive Layout:** Cards sit side by side on wide windows and stack on narrow ones; the page scrolls only when it has to.
- **Menu Bar Rotation Toggle:** Turn the 2-second CPU → GPU → Memory → Storage → Network rotation on or off.
- **Single-Selection Menu Bar Widget:** Select which hardware component (**CPU**, **GPU**, **Memory**, **Disk**, or **Network**) is visible on the macOS top status bar using single-selection radio chips, as only one icon and live telemetry metric can be displayed cleanly at a time.
- **Live Menu Bar Preview:** Immediate preview of the active menu bar status item.
- **Background & Startup:** Hide the Dock icon while the window is closed, and toggle launch at login.
- **Telemetry & Sample Rate Control:** Custom segmented cadence pills (`0.5s Fast`, `1.0s Normal`, `3.0s Eco`, `Pause`) with active interval badge and explicit volatile in-memory ring buffer architecture (zero disk writes).
- **Theme & markings:** Standard or Publication (paper-ready), plus the full set of publication markings. See the Publication Theme & Figure Capture section above.
- **Menu bar:** show or hide the icon and 2-second rotation (the icon is always coloured by usage).
- **Appearance:** System, Light, and Dark mode selectors (Standard theme; Publication always uses white).
- **Hardware Specs:** Device model, architecture, processor, installed RAM, graphics and macOS version in an adaptive grid.
- **Desktop Widget Blueprint:** See [`Documentation/DesktopWidgetGuide.md`](Documentation/DesktopWidgetGuide.md) for full architectural patterns and Swift source code to add native macOS Sonoma/Sequoia Desktop Widgets.

---

## 🛠 Download & Installation

### Option 1: Download Pre-Built Universal DMG (Recommended)

You can download the ready-to-run Universal macOS installer directly from the repository:

👉 **[Download TaskManager-1.6.1-Universal.dmg (v1.6.1)](https://github.com/K-692/Task-Manager4MacOS/raw/main/releases/TaskManager-1.6.1-Universal.dmg)**

The DMG is also attached to the **[latest GitHub Release](https://github.com/K-692/Task-Manager4MacOS/releases/latest)**.

#### What's new in v1.6.1
- **Fixes the v1.6.0 installer.** The v1.6.0 DMG accidentally contained the previous app binary (still showing the coloured value text and the "Colour by usage" setting). v1.6.1 ships the real v1.6.0 changes: only the menu bar icon is coloured, the value is white, and the setting is gone.
- **Reliable universal builds.** The build script now asks Swift for each architecture's output path, copies every slice right after building it, and checks the architecture, so stale binaries can never be packaged again.

#### What's new in v1.6.0
- **Menu bar: icon-only colour.** Only the icon is shaded green to red by usage. The value stays white (black on a light menu bar). The colour is always on, so the "Colour by usage" setting is gone.
- **Lighter app.** Measured on an M1 MacBook Air with the window closed: **about 3 % CPU and ~75 MB**, down from about 11–18 % and ~178 MB. Changes:
  - The window's live charts pause while it is closed, minimised or fully covered (SwiftUI used to keep redrawing a closed window).
  - The full process scan runs every second only while a screen showing processes is open (Processes, CPU or Memory page, menu bar popup). Otherwise every 5 s (window open) or 15 s (menu bar only).
  - Disk usage refreshes every 5 s (30 s with the window closed) and battery every 10 s.
  - One change notification per sample instead of about 13, forwarded without an extra async hop.
  - The menu bar label is drawn directly with AppKit and cached, instead of rendering a SwiftUI view each second.
- **Builds with the latest Command Line Tools.** The build scripts pick a compatible macOS SDK automatically when the SwiftUI macro plugin is missing (Command Line Tools 27.x without Xcode).

#### What's new in v1.5.1
- **Gridlines now visible:** the **Gridlines** option in Publication Markings now draws light grey major gridlines on every chart and captured figure. Previously the plot area's white background covered them.

#### What's new in v1.5.0
- **Value labels: in the legend or inside the graph:** a new **Value labels** setting. *In legend* (the default) keeps the plot clean: nothing is written inside the graph and each marking's value is listed in the legend. *Inside graph* writes the values next to the markings. Dashboard, detail pages and captures all follow it.
- **Legend always bottom-right**, below the graph, wrapping onto extra lines if needed.
- **Distinct publication colours per marking** (Okabe–Ito): mean black, median reddish purple, trend bluish green, moving average sky blue, threshold vermillion, peak orange, minimum grey. Any marking whose colour would match the data line switches automatically.
- **No panel letters** on captured figures: just the title and the graph.
- **Solid text in the Publication theme:** secondary labels, sidebar items, buttons and checkboxes use solid dark colours instead of faded grey.
- **Strict 2-second menu bar rotation:** a dedicated drift-free timer that only redraws the menu bar item, so the rotation no longer lags.

#### What's new in v1.4.0
- **Choose your publication markings:** **Settings → Publication Markings** has 20 options with a live preview: mean, median, linear trend, moving average (2–30 samples), threshold line (5–100 %), peak ▲, minimum ◆, latest ●, all data points, value labels, mean ± 1σ band, min–max band, gridlines, axis ticks, axis titles, plot frame, legend/key, smooth curves and panel labels (a)–(e). Presets: Minimal, Default, All. They fit in four columns without scrolling.
- **Clean captures:** each captured figure now contains **only the title and the graph**, drawn with exactly the markings you selected. No device details, statistics or captions.
- **Usage-coloured menu bar icon:** the menu bar icon and value shade **continuously from green to red** with usage. For network, green means 1 MB/s or more and red means 400 KB/s or less. The shades adapt to a dark or light menu bar (bright pastels on dark, deeper tones on light). You can turn this off for plain white.
- **Optional menu bar icon:** a new **Show in menu bar** switch. When it's off, Task Manager keeps running and stays in the Dock.
- Throughput charts no longer extend below zero, and peak labels stay inside the plot.

#### What's new in v1.3.0
- **Publication theme:** a second visual theme (**Settings → Theme**) for researchers: white background, serif type, colour-blind-safe (Okabe–Ito) lines, labelled *Time (s)* and unit axes, a dotted mean line and a ▲ peak marker on every chart, ready to paste into a paper.
- **One-click Capture:** a **Capture** button on the dashboard saves CPU, GPU, Memory, Storage and Network as **five separate high-resolution PNG figures** (2880×1620) from the **same instant**, in the current theme, into a new folder on your Desktop.

#### What's new in v1.2.2
- **Centered menu bar item:** the icon and value are now centred in a tightly sized fixed-width slot, so the spacing is even on both sides and the item still never changes size or pushes other menu bar icons.

#### What's new in v1.2.1
- **Fixed-width menu bar item:** the rotating metric now sits in a fixed-width slot, so other menu bar icons no longer shift as it cycles between CPU, GPU, Memory, Storage and Network.

#### What's new in v1.2.0
- **Rotating menu bar metric:** the menu bar icon and value cycle CPU → GPU → Memory → Storage → Network every 2 seconds (icon + value only, no text label). Turn it off in **Settings → Menu Bar Widget** to pin a single metric.
- **Internet speed test in the menu bar:** open the menu bar popup and press **Run Speed Test** to measure download, upload, ping and jitter, with results shown right in the popup.

#### What's new in v1.1.0
- Fully responsive window: sidebar auto-collapse, adaptive card grids, wrapping headers, and tables that hide columns on narrow widths. The minimum window size is now ~460×420 pt (was 960×640).
- Always-on menu bar mode: closing the window never quits; the Dock icon hides while the window is closed; launch at login is enabled on first run.
- Redesigned menu bar popover with sparklines, top processes, and quick actions.
- Refreshed UI: icon badges, layered cards, smoother charts with consistent component colors, sortable process columns.
- Fixed a duplicate **View** menu; navigation shortcuts now live in the **Go** menu.

#### Release Verification & Specifications

| Property | Details |
|:---|:---|
| **Package** | [`releases/TaskManager-1.6.1-Universal.dmg`](releases/TaskManager-1.6.1-Universal.dmg) |
| **Version** | `1.6.1` |
| **Target Architecture** | **Universal Binary** (`arm64` Apple Silicon M1/M2/M3/M4 + `x86_64` Intel 64-bit) |
| **Minimum OS** | macOS 13.0 (Ventura), macOS 14.0 (Sonoma), macOS 15.0 (Sequoia) |
| **Package Size** | ~6.3 MB (Compressed Read-Only UDZO) |
| **SHA-256 Checksum** | `1b95edcadb7a5e4804096291c388599ed287532dbc4b855668a225f6b27ba9b7` |

#### Installation Steps:
1. Download **[TaskManager-1.6.1-Universal.dmg](releases/TaskManager-1.6.1-Universal.dmg)**.
2. Double-click the `.dmg` file to mount it.
3. Drag **Task Manager** into your **Applications** folder shortcut.
4. Eject the disk image and launch **Task Manager** from Launchpad, Spotlight (<kbd>⌘</kbd> + <kbd>Space</kbd>), or Applications.
5. The live metric appears in your menu bar. Closing the window keeps it running there; use **Quit** (<kbd>⌘</kbd> + <kbd>Q</kbd>) to exit.

> [!TIP]
> **macOS Gatekeeper Notice:** Since this open-source build is ad-hoc signed for independent distribution without an Apple Developer ID certificate, macOS may prompt an alert on the first launch. Simply right-click **Task Manager.app** in `/Applications` and choose **Open**, or run the following command in Terminal:
> ```bash
> xattr -cr "/Applications/Task Manager.app"
> ```

---

### Option 2: Build & Package Universal DMG from Source

To compile both `arm64` and `x86_64` architecture slices, generate the universal fat binary, assemble the `.app` bundle, and package a compressed `.dmg`:

```bash
# Clone the repository
git clone https://github.com/K-692/Task-Manager4MacOS.git
cd Task-Manager4MacOS

# Build Universal app and package DMG
./Scripts/package-dmg.sh
```
The output disk image will be created at `dist/TaskManager-1.6.1-Universal.dmg` and updated in `releases/`.

---

### Option 3: Compile Local App Bundle

To assemble a native `.app` bundle directly on your Mac:

```bash
# For Universal (Apple Silicon + Intel) bundle:
./Scripts/build-universal.sh

# For native host architecture bundle:
./Scripts/build-app.sh

# Open Task Manager
open "dist/Task Manager.app"
```

---

### Option 4: Run via Swift Package Manager

```bash
swift run TaskManager
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|:---|:---|
| <kbd>⌘</kbd> + <kbd>1</kbd> | Navigate to **Performance Dashboard** (Landing Page) |
| <kbd>⌘</kbd> + <kbd>2</kbd> | Navigate to **Processes** (Default: Memory Footprint) |
| <kbd>⌘</kbd> + <kbd>3</kbd> | Navigate to **Startup Apps** |
| <kbd>⌘</kbd> + <kbd>4</kbd> | Navigate to **Settings** |
| <kbd>⌘</kbd> + <kbd>5</kbd> | Navigate to **CPU Telemetry** Detail View |
| <kbd>⌘</kbd> + <kbd>6</kbd> | Navigate to **GPU Telemetry** Detail View |
| <kbd>⌘</kbd> + <kbd>7</kbd> | Navigate to **Memory Telemetry** Detail View |
| <kbd>⌘</kbd> + <kbd>8</kbd> | Navigate to **Disk Telemetry** Detail View |
| <kbd>⌘</kbd> + <kbd>9</kbd> | Navigate to **Network Telemetry** Detail View |
| <kbd>⌘</kbd> + <kbd>K</kbd> | Open **Command Palette** (Instant Search & Actions) |
| <kbd>⌘</kbd> + <kbd>R</kbd> | Force Immediate Hardware Telemetry Refresh |
| <kbd>⌘</kbd> + <kbd>Q</kbd> | Quit Task Manager (closing the window keeps it in the menu bar) |

Navigation shortcuts are also listed in the **Go** menu.

---

## 🔒 Privacy & Offline Guarantee

- **No Telemetry:** Zero telemetry beaconing and zero analytics SDKs. The app makes no network requests on its own.
- **Speed Test on Demand Only:** The only network traffic is the internet speed test, and it runs only when you press **Run Speed Test**. It exchanges throw-away test data with Cloudflare's speed test servers and sends no personal or system information.
- **Purely In-Memory Telemetry:** Telemetry history is strictly volatile (in-memory 60-sample ring buffers).
- **User Space Execution:** Zero root permissions or kernel extensions required.

---

## 🤝 Contributing

Contributions to **Task Manager for macOS** are welcome! Whether filing bug reports, suggesting new hardware sensors, or submitting pull requests:

1. **Fork** the repository on GitHub.
2. **Create a branch** for your feature (`git checkout -b feature/hardware-sensor`).
3. **Commit your changes** (`git commit -m 'Add support for Apple Neural Engine telemetry'`).
4. **Push to branch** (`git push origin feature/hardware-sensor`).
5. **Open a Pull Request** with architectural explanations.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
