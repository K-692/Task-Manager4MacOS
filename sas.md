# Software Architecture Specification (SAS)

# Task Manager

**Document status:** Proposed baseline for implementation  
**Version:** 1.2  
**Product:** Task Manager for macOS  
**Primary goal:** A polished, lightweight, privacy-first task manager with an advanced local Mac system-information dashboard, native macOS widgets, and an optional always-available menu-bar presence.  
**Distribution goal:** A user should not need Homebrew, Node.js, Python, Xcode, a terminal, or any other development package. They download one signed and notarized release, install it using the familiar macOS flow, and launch it like any other Mac app.

---

## 1. Executive summary

Task Manager is a native macOS desktop application that combines task planning with a clear, interactive view of the user's Mac. The product has two first-class areas: **Tasks** for planning and completing work, and **Mac Dashboard** for monitoring device health and activity. The visual language should be modern and information-rich without becoming noisy: refined typography, generous spacing, subtle materials, interactive charts, compact sparklines, contextual detail panels, and keyboard-first workflows. The system dashboard must adapt at runtime to the actual Mac model, installed hardware, connected peripherals, macOS version, and exposed capabilities. A base MacBook and a high-end MacBook Pro use the same application build; their device inventory and visible readings differ only when the hardware or OS truly differs.

The application should feel light because it uses Apple's native UI and system frameworks, keeps its data local, avoids a bundled browser runtime, does not run a permanent privileged helper, and samples metrics only as quickly as the currently visible screen needs them. It must remain useful if system metrics are unavailable; restricted values must be shown as unavailable rather than guessed.

### 1.1 Core product principles

1. **Native first:** macOS conventions, window behavior, menus, keyboard shortcuts, notifications, and system appearance.
2. **Fast by default:** instant task capture, responsive filtering, short startup time, and a quiet idle state.
3. **Local-first privacy:** tasks and metric history stay on the Mac by default. No account is needed for the core product.
4. **Useful visualizations:** charts explain a trend, comparison, or state; they are not decorative gauges with misleading precision.
5. **Truthful system data:** distinguish live samples, estimates, cached values, and unavailable metrics.
6. **Simple distribution:** consumers install a prebuilt, signed, notarized app. Developer dependencies are build-time concerns only.
7. **Graceful capability limits:** no kernel extension, root daemon, Full Disk Access, Screen Recording, or Accessibility permission should be required for baseline features.
8. **Runtime capability discovery:** identify every hardware/system category that can be reliably inspected through supported APIs; show whether it is present, absent, unsupported, restricted, or not exposed rather than assuming a fixed spec for a model tier.
9. **Always available, never wasteful:** offer macOS widgets, a menu-bar quick surface, and opt-in launch at login, while keeping high-frequency telemetry paused unless the full dashboard is actively visible.
10. **Widget-native behavior:** widgets must use WidgetKit, keep useful task snapshots, and open the appropriate screen in the main application when tapped.

### 1.2 Product statement

> Task Manager helps people organize their work and understand their Mac through one responsive, private, visually refined native application.

A native **Task Manager widget suite** is part of the product, not a companion website. Widgets offer quick context and navigation; the full application remains the place for complete task editing, detailed charts, and system diagnostics.

### 1.3 Product scope boundary

Task Manager is not intended to replace Activity Monitor, Disk Utility, a professional hardware diagnostics suite, a team project-management server, or an enterprise device-management tool. Its dashboard should prioritize common, reliable, understandable information that can be accessed by an ordinary signed-in user through supported macOS interfaces.

---

## 2. Goals, non-goals, and assumptions

### 2.1 Goals

- Provide a complete personal task-management workflow without requiring an account.
- Offer high-quality list, board, calendar/timeline, search, and insights views.
- Show useful Mac information, including CPU, GPU, memory, storage, battery, network interfaces, running applications/processes, displays, macOS version, model identifier, architecture, and other supported hardware fields.
- Discover model-specific features at runtime and present accurate values for entry-level, mid-tier and high-end MacBooks without maintaining separate app builds.
- Include an explicit hardware/capability inventory whose rows account for features that are present, absent, unsupported on that OS, not exposed through supported APIs, or inaccessible due to a permission/system restriction.
- Offer smooth, interactive and accessible visualizations with informative tooltips and time-range controls.
- Distribute a self-contained application for Intel and Apple Silicon Macs within the supported macOS range.
- Ship through a signed and notarized DMG as the recommended direct-download method; provide an optional PKG installer when a guided installation flow is useful.
- Support safe in-app updates without asking users to run shell commands or reinstall developer packages.
- Provide native macOS desktop and Notification Center widgets in multiple sizes, with configurable task and optional device-summary content.
- Let users keep Task Manager readily accessible from the menu bar and optionally start it at login without a privileged daemon or continuous high-frequency polling.
- Meet clear performance, privacy, accessibility, security, energy-efficiency, and release-quality requirements.

### 2.2 Non-goals for version 1.0

- Cloud accounts, team collaboration, shared workspaces, and synchronization across devices.
- An AI assistant or remote AI API requirement. The first release must work completely offline after download.
- A kernel extension, system extension, root helper, privileged daemon, or custom driver.
- A widget that promises real-time CPU, memory, network, or other continuously changing metrics; WidgetKit refresh cadence is system-controlled and must be represented honestly.
- A mandatory always-on high-frequency metrics collector. Always-available task access is required, but continuous telemetry collection is not.
- Fabricating readings for CPU/GPU temperature, fan speed, GPU utilization, Neural Engine details, or battery-health statistics that macOS does not expose reliably. These categories must still be represented in the inventory with a truthful capability status.
- Monitoring other users' sessions or bypassing macOS process privacy protections.
- Automatically scanning the user's entire disk to categorize storage.
- Cross-platform Windows/Linux support.
- A web application or Electron-based runtime.

### 2.3 Working assumptions

- **Platform:** macOS, running on Apple Silicon or Intel hardware.
- **Initial minimum OS target:** macOS 13 Ventura as a design target, subject to an early API-availability and CI feasibility check. If a required capability cannot be implemented robustly on macOS 13, the implementation team must document the exact dependency before raising the minimum target.
- **Architecture:** a universal binary with `arm64` and `x86_64` slices, provided all linked dependencies support both.
- **Primary distribution:** direct website download using Developer ID signing and notarization. Mac App Store distribution may be pursued separately after validating sandbox limits for the system dashboard.
- **Default storage:** local application-support directory; no server is required for normal usage.
- **App display name:** `Task Manager`. The bundle identifier, publisher identity, and trademark/name availability must be confirmed before public release.

“Every macOS user” cannot literally mean every Mac and every historic macOS release. The target is **all base-to-high-end MacBook configurations and both Intel and Apple Silicon models that meet the published minimum macOS version**. The app must not assume every model has the same GPU, core topology, display feature, battery fields, or sensor access. Model support and metric support are separate: a device can be fully supported while an individual metric is unavailable. The download page must state the minimum macOS version and the tested architecture/OS matrix plainly.

### 2.4 Cross-model hardware compatibility mandate

The dashboard is capability-driven, not SKU-driven. Do not ship “Base”, “Pro”, or “Max” branches in the UI as the source of truth. Probe the running machine and its currently available hardware/interfaces, normalize the results into a stable internal inventory, and render the corresponding values and status. Model-family metadata can enrich the presentation, but must never override a live capability probe.

Requirements:
- A single release must work across all tested supported MacBook Air and MacBook Pro configurations, including differences in CPU architecture, CPU core counts, GPU devices, unified/system memory, built-in display capabilities, battery fields, ports/interfaces, and external display configuration.
- Detect both the machine profile and the individual metric providers independently. A CPU metric can work while a thermal sensor metric is unavailable.
- Use capability states including `available`, `notPresent`, `unsupportedByOS`, `notExposedBySupportedAPI`, `restricted`, `permissionRequired`, `temporarilyUnavailable`, and `probeFailed`. Never convert an unknown or failed probe into “not present” or zero.
- Hardware categories must remain discoverable even when values are absent. The concise Overview may prioritize available information, but the detailed **Hardware & Capabilities** page must list every defined category and its state/reason.
- Support hot-plug and state changes where applicable: external displays, storage volumes, network interfaces, docks, AC/battery transitions, sleep/wake, and OS power/thermal state changes.
- Do not use a remote service or a vendor database to decide what hardware exists. Core inventory and status must work offline. An optional local mapping can translate an exact model identifier into a marketing name, with the raw identifier retained as the authoritative fallback.
- Do not display a serial number by default. If a diagnostic report ever includes one, require explicit user intent and clearly warn before export.

---

## 3. User profiles and primary use cases

### 3.1 Personal productivity user

Needs a fast Inbox, a clear Today view, priorities, due dates, recurring tasks, reminders, projects, and a way to find tasks without managing a complex workspace.

### 3.2 Power user or developer

Prefers keyboard shortcuts, global quick capture, quick switching, dense but readable task lists, multiple windows, predictable local storage, and no forced account or cloud dependency.

### 3.3 Mac-curious user

Wants understandable CPU, memory, battery, storage, network and process information in one attractive interface, without configuring monitoring agents or granting excessive permissions.

### 3.4 Typical journeys

1. Launch Task Manager and immediately see today's work and a brief Mac status overview.
2. Press the global quick-capture shortcut, enter a task, optionally choose a due date or project, and return to the previous app.
3. Turn a task into a project, tag it, prioritize it, and view it as a list, board, or calendar item.
4. Open Mac Dashboard, inspect current resource utilization, zoom into a recent history chart, and identify a resource-heavy running application when the OS provides the data.
5. Receive a local notification for an enabled reminder.
6. Download a new release and update from within the application with clear release notes and signature verification.
7. Add a Task Manager widget from the macOS widget gallery, see today's tasks at a glance, and click it to open the relevant page in Task Manager.
8. Enable launch at login and close the main window while keeping a small menu-bar entry available; the app stays idle without continuously sampling system metrics.

---

## 4. Product information architecture

### 4.1 Primary navigation

The main window should use a native-feeling sidebar with no more than two visible hierarchy levels.

**Work**
- Today
- Inbox
- Upcoming
- All Tasks
- Projects
- Tags
- Completed

**Insights**
- Productivity
- Focus / Work Sessions (optional MVP-lite; see roadmap)

**This Mac**
- Overview
- Performance
- Storage
- Battery & Power
- Network
- Processes
- Hardware & Capabilities
- About This Mac

**System**
- Settings
- Help & Feedback
- About Task Manager

Sidebar requirements:
- Collapsible, resizable within reasonable minimum and maximum widths.
- Restore the last selected navigation destination across launches.
- Support keyboard navigation and full VoiceOver labels.
- Respect the user's accent color where possible.
- Show small, quiet counts when they provide useful information; avoid turning every row into a badge.

### 4.2 Main application surfaces

| Surface | Purpose | Primary interactions |
|---|---|---|
| Today | A prioritized daily command center | Complete, reorder, defer, add task, open detail |
| Inbox | Fast capture and triage | Edit, assign project, set date, tag, promote |
| All Tasks | Searchable master task list | Filter, sort, bulk select, inline edit |
| Project | Work grouped by project and section | List/board views, progress, project metadata |
| Upcoming | Tasks over the near future | Calendar/timeline, reschedule, inspect conflicts |
| Productivity | Personal completion trends | Date ranges, comparison, filters, details |
| Mac Overview | High-level device status | Open metric detail, change time range |
| Performance | CPU and memory | Interactive time series, top processes |
| Storage | Volumes and free capacity | View capacity and filesystem attributes |
| Battery & Power | Battery status and recent samples | Charge state, health fields when available |
| Network | Interfaces and throughput | Per-interface inbound/outbound chart |
| Processes | Running applications/processes | Sort by supported CPU/memory fields, inspect details |
| Hardware & Capabilities | Full model-adaptive inventory | Verified component values, availability state, source, last probe time and explanation for unavailable fields |
| About This Mac | Device summary | Model identifier/name, macOS version/build, architecture and verified hardware facts |
| Settings | Preferences, privacy, appearance, updates | Configure app behavior |

### 4.3 Navigation and window behavior

- Use a resizable `NavigationSplitView` or equivalent native split view.
- Support normal, maximized, and full-screen windows.
- Persist reasonable window size and position; handle multiple displays and removed displays.
- Use sheets or popovers for focused edits; do not nest modal dialogs unnecessarily.
- Provide a main-window keyboard map, contextual menus, menu-bar commands, and discoverable toolbar controls.
- Do not require the app to stay frontmost for the user to use the system normally.

---

## 5. UI and visual design specification

### 5.1 Design direction

The interface should feel premium and deliberate, not like a generic web dashboard inside a Mac window. Use SwiftUI and AppKit where necessary, with system-native controls and carefully scoped custom components. Do not imitate a future OS appearance using large, opaque decorative glass effects. Materials should preserve legibility and hierarchy.

**Visual characteristics**
- Typography: SF system fonts; use semantic text styles and a clear size hierarchy.
- Spacing: consistent 4/8-point spacing scale, with more breathing room on overview pages and more density in task tables.
- Shape: restrained corner radii; consistent controls; avoid excessive nested cards.
- Color: system semantic colors by default, with a restrained app accent; separate status colors from decoration.
- Motion: short transitions for navigation, task completion and chart selection; honor Reduce Motion.
- Surface hierarchy: clear page background, content regions, and detail inspector; use shadows sparingly.
- Visualizations: legible axes, units, time ranges, selected-point markers, accessible summaries, and informative empty states.

### 5.2 Theme behavior

- Follow macOS appearance automatically by default.
- Offer System / Light / Dark override in Settings.
- Ensure text and chart marks meet accessibility contrast targets in both themes.
- Respect increased contrast, Reduce Motion, and system text sizing wherever feasible.
- Never encode meaning only through hue; pair colors with labels, patterns, or symbols.

### 5.3 Task Manager visualizations

Use **Swift Charts** for standard charts and native accessibility support. Use SwiftUI `Canvas` for small high-volume custom visualizations such as sparklines and a completion heatmap. Use Metal only if profiling proves a compelling performance need; it is not part of the MVP stack.

Candidate visualizations:

1. **Today progress ring:** completed versus remaining tasks. It must not imply effort or time spent if only task counts are known.
2. **Completion activity heatmap:** completed tasks by day over a configurable period; include a textual summary for accessibility.
3. **Weekly completion trend:** completed-task count by day/week, with a comparison period.
4. **Project progress:** counts or percentages clearly derived from defined task states.
5. **Upcoming workload timeline:** tasks placed on due dates/time ranges; indicate overdue tasks and dates with heavy workload.
6. **Priority distribution:** show task counts by priority, with a legend and absolute counts.
7. **Focus session timeline:** only if focus sessions are enabled; do not infer time spent from task completion events.

Every chart must:
- Include a title and meaningful time range.
- Show units and sample intervals where relevant.
- Support pointer hover and keyboard selection as far as the framework allows.
- Provide an accessible summary or alternative data representation.
- Avoid smoothing that changes the interpretation of data.
- Avoid claims such as “productivity score” until its formula is explicit and user-understandable.

### 5.4 Mac Dashboard visualizations

1. **CPU time series:** user/system/idle categories if the chosen supported provider can reliably supply them; show total usage as a clearly labelled percentage.
2. **Memory composition:** used/free and optional app/wired/compressed categories only when the underlying values can be explained accurately. Distinguish pressure from raw use.
3. **Compact metric cards:** present current value, a tiny recent sparkline, and a label for last sample time.
4. **Network throughput:** inbound and outbound bytes per second by selected interface, with explicit units (B/s, KB/s, MB/s).
5. **Storage capacity:** used and available capacity for each volume. Do not invent storage-category attribution.
6. **Battery status:** charge percentage, charging state, power source, cycle count/health fields only when the OS exposes them.
7. **Process table:** sortable process/application list with the timestamp of the last sample; show unsupported or restricted fields as unavailable.
8. **Device summary:** macOS version/build, model name/identifier, CPU architecture and verified core information, GPU device list where exposed, total memory, display details, uptime, and volumes.
9. **Hardware capability inventory:** a searchable, grouped list for compute, memory, graphics, display, power/battery, storage, network, connectivity and exposed sensors. Each row shows value plus status and source/probe time; rows that are unsupported or not exposed remain visible with an explanation.

### 5.5 State design

Every view must define the following states explicitly:
- Loading (brief, skeleton or subtle progress indication only when necessary).
- Empty (first-use guidance with a direct next action).
- Normal populated state.
- Filtered/no results.
- Error/unavailable data.
- Stale data, with last-updated timestamp.
- Permission not granted (when applicable), with the smallest required explanation.
- Reduced capability (for instance, a hardware field that is not available on this Mac).
- Hardware absent (e.g. no internal battery for a desktop Mac, if the app is run there for development/testing) versus a probe failure or an API restriction. These states must have different wording and iconography.

Never display placeholder percentages as if they were real readings. Design mock data can only be used in previews and development fixtures.

### 5.6 Responsive window sizing

- Design around a comfortable main window of approximately 1200 × 800 points while remaining useful at 900 × 600 points.
- Below the comfortable width, collapse secondary details into an inspector or sheet.
- Avoid forcing horizontally scrolling task tables for basic workflows.
- Ensure charts reflow without clipping axes or tooltips.

---

## 6. Task management functional requirements

### 6.1 Task lifecycle

Each task must have a title and stable unique ID. Optional fields include description, project, section, tags, priority, start/due date, estimate, recurrence, and reminder.

Statuses:
- Inbox / Unsorted
- To do
- In progress (optional configurable status)
- Completed
- Archived / Deleted (recoverable for a defined period if using soft delete)

Required interactions:
- Create, edit, complete, reopen, duplicate, archive and delete tasks.
- Inline title editing without a separate modal for simple changes.
- Undo for destructive or high-impact actions.
- Multi-select, batch completion, batch tagging and batch move where feasible.
- Drag to reorder lists; maintain a deterministic `sort_order`.
- Move or reschedule tasks by drag-and-drop with keyboard-accessible alternatives.
- Keep task edits local and durable after application termination.

### 6.2 Task fields

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID/string | Yes | Stable primary key |
| `title` | Text | Yes | Trim whitespace; empty task title rejected |
| `notes` | Text | No | Plain text first; Markdown rendering may be added later |
| `status` | Enum | Yes | Explicit state machine |
| `priority` | Enum | Yes | Default Normal; e.g. Low, Normal, High, Urgent |
| `created_at` | Date/time | Yes | Persisted timestamp |
| `updated_at` | Date/time | Yes | Updated on meaningful changes |
| `due_at` | Date/time | No | Store with clearly defined timezone semantics |
| `start_at` | Date/time | No | Optional scheduling field |
| `completed_at` | Date/time | No | Set/cleared by completion state transition |
| `project_id` | UUID/string | No | Foreign key to project |
| `section_id` | UUID/string | No | Optional project section |
| `sort_order` | Integer/decimal | Yes | Supports user ordering |
| `estimate_minutes` | Integer | No | No auto-assumption of actual time spent |
| `recurrence_rule` | Structured text | No | Validated supported recurrence syntax |
| `parent_task_id` | UUID/string | No | Relates recurrence instance to series/template |
| `deleted_at` | Date/time | No | Optional soft-delete / undo support |

### 6.3 Projects, sections, and tags

- Create, rename, color-code and archive projects.
- Projects may contain ordered sections.
- Tags are reusable and many-to-many with tasks.
- Project deletion must define whether tasks are reassigned, retained without a project, or deleted; do not silently delete tasks.
- Colors must remain optional; users must be able to identify a project by its name, not color alone.

### 6.4 Smart lists and filters

Include built-in Today, Upcoming, Overdue, Inbox, All Tasks, Completed, and per-project lists. Users can filter by status, priority, project, tag, and date range; sorting can use priority, due date, creation date, project, or custom order.

Smart lists should be computed from local task data, not duplicated as manually persisted task copies.

### 6.5 Search and command palette

- Global search across task title, notes, project names and tags.
- Use SQLite FTS5 if available in the system SQLite on the chosen OS support range; validate availability and provide a fallback indexed search.
- Support keyboard-first command palette for actions such as New Task, Search, Switch Project, Open Today, Open Inbox, and Open Mac Dashboard.
- Avoid a proprietary query syntax in MVP; basic filters first.

### 6.6 Recurrence and reminders

- Support daily, weekly, monthly and custom interval recurrence within a documented set of rules.
- Clarify recurrence behavior for overdue incomplete tasks; do not create a storm of missed instances.
- Recurring tasks create new task instances according to explicit rules and preserve completion history.
- Use UserNotifications for local reminders where supported; request authorization only when the user enables a reminder or notification feature.
- Show reminder permission status inside Settings and explain how to change it in macOS System Settings.
- Schedule a reasonable future horizon for recurring reminders, and rebuild scheduled notifications when task/recurrence data changes.
- Notifications must not require a server or an always-running privileged service.

### 6.7 Daily planning

- Today view groups overdue, scheduled and unscheduled tasks clearly.
- Quick actions for complete, defer to tomorrow, set date, and move to project.
- A task count must be labelled as a count; do not call it “workload” unless duration/effort data has been provided.
- Optional daily summary should be generated locally from task data, not sent to a cloud service.

### 6.8 Import/export and backup

MVP requirements:
- Export tasks/projects/tags to a documented JSON format and CSV for task rows.
- Import from Task Manager's own JSON export with validation and a preview.
- Provide an explicit backup/restore route before destructive imports or schema migrations.
- Do not silently overwrite current data during import.

Potential later additions: Apple Reminders import/export, calendar integration, and iCloud sync. These need separate permission, conflict resolution, and data-ownership specifications.

---

## 7. Mac Dashboard functional requirements

### 7.1 Metric reliability model

Every metric provider must return a structured sample, not only a number:

```text
MetricSample<T> {
  value: T?
  unit: String
  observedAt: Date
  source: String
  quality: exact | estimated | partial | unavailable
  reason: String?
}
```

The UI must preserve this quality state. When a metric is stale, unavailable, or partially exposed, the interface must say so clearly. Do not substitute a guessed value.

### 7.2 Metric catalogue

| Area | Target metric | Candidate public/system source | Cadence | Reliability / caveats |
|---|---|---|---|---|
| Device | macOS version/build | `ProcessInfo`, system version APIs | On launch / settings | High |
| Device | Architecture | `uname`/supported process/system APIs | On launch | High |
| Device | CPU/core information | Supported system APIs / `sysctl` values | On launch | Generally high; label logical/physical accurately |
| Device | Total installed memory | `ProcessInfo.physicalMemory` | On launch | High |
| CPU | CPU utilization | Mach host statistics or another verified public API | 1–2 s when visible | Must compute deltas across samples and validate denominator |
| Memory | VM statistics / memory pressure | Mach VM statistics and documented signals where available | 2–5 s when visible | “Memory used” definitions differ; explain calculation |
| Storage | Volume total/free capacity | `FileManager` / URL resource values | 10–30 s and on view entry | High for volume values; category breakdown not inferred |
| Battery | Charge, charging state, power source | IOKit power-source interfaces | 5–15 s when visible | Device-dependent; desktop Macs may have no battery |
| Battery | Cycle count / condition | Publicly accessible power-source fields if exposed | On view entry / several minutes | Best-effort; field availability varies |
| Network | Interface identity/state | `getifaddrs` and verified system interfaces | 5–10 s | Some interface metadata is contextual/permission-dependent |
| Network | Bytes in/out per second | Interface counters via verified public/system-supported interfaces | 1–2 s when visible | Calculate deltas; handle interface reset/disconnect |
| Processes | Running apps | `NSWorkspace` / `NSRunningApplication` | Event-driven / 5 s fallback | App list is different from a complete privileged process monitor |
| Processes | Process CPU/memory | `libproc` or a verified supported interface | 2–5 s when visible | Some process details may be limited; do not imply complete Activity Monitor parity |
| Display | Resolution / scale | AppKit display APIs | On display change | High for connected accessible displays |
| Uptime | Time since boot | Supported kernel/system uptime source | 30–60 s | Validate sleep/wake behavior |
| Thermal | CPU/GPU temperature and fans | No baseline dependency on private SMC APIs | N/A | Out of scope unless a stable supported source is proven |
| GPU | GPU utilization/power | No baseline dependency on private APIs | N/A | Out of scope for v1 unless a supported source is verified |

The engineering team must validate all calls against official SDK documentation for the minimum OS target. The table identifies candidate sources, not a claim that each raw metric is universally available or stable. Do not use private frameworks, undocumented selectors, kernel extensions, or vendor-specific hacks in the baseline product.

#### Required inventory coverage by category

The following categories are part of the **Hardware & Capabilities** page. “Show” means show either a verified value or an explicit capability state; it does not mean invent a value where the OS does not expose one.

| Category | Required fields when available | Expected fallback when unavailable | Implementation notes |
|---|---|---|---|
| Mac identity | Model identifier, marketing name if confidently mapped, OS version/build, architecture, boot time/uptime | Display the exact identifier and “Marketing name unavailable” if mapping is incomplete | Never use marketing-name mapping as the source of hardware measurements. Keep serial number hidden by default. |
| CPU | CPU family/architecture, logical CPU count, physical/core information when reliably exposed, utilization over time | Preserve known values and mark topology details unavailable if not reliably exposed | Never assume P-core/E-core split from a marketing label. Expose cluster breakdown only when a tested source provides it. |
| GPU / graphics | Enumerated GPU devices, device name, low-power/removable/headless characteristics where APIs expose them, display association if known | State that the OS does not expose utilization/VRAM/core count if those fields cannot be obtained reliably | Use public Metal device enumeration for GPU identity where available; do not infer discrete vs integrated solely from a marketing label. Unified memory is not the same as dedicated VRAM. |
| Neural / ML acceleration | Presence only if supported APIs can establish it accurately; capabilities exposed to Core ML where appropriate | “Detailed Neural Engine specifications are not exposed by supported APIs” | Do not claim core count, load, frequency or temperature without a stable supported source. |
| Memory | Installed memory; verified pressure and memory statistics; unified-memory note if known | Show installed memory if known, but mark detailed breakdown unavailable | Do not present an invented application-level memory breakdown or mislabel compressed/cached memory. |
| Built-in and external displays | Detected display list, pixel/logical dimensions, scale, refresh rate when exposed, built-in/external state, active display | Per-field unavailable state; do not assume every panel has ProMotion, HDR or the same resolution | Re-enumerate on display configuration change; handle dock/adapter changes. |
| Battery and power | Battery presence, charge level, charging state, power source, cycle count/condition/capacity if provided | “No battery detected”, “field not provided by this battery/OS”, or “probe failed” as distinct states | Apple documents that power-source dictionaries may omit keys. Do not show missing values as zero or healthy by default. |
| Storage | Mounted volumes, volume name, capacity/free capacity, filesystem and removable state where exposed | Show the volume and the field state; never claim disk health without evidence | No automatic whole-disk crawl. Hardware media type and SMART status are not guaranteed in v1. |
| Network / connectivity | Interface name/type/state, addresses only when appropriate, per-interface byte counters and throughput, attached network interfaces where supported | Hide sensitive connection details by default; explain if permissions/system restrictions apply | SSID/BSSID and location-linked Wi-Fi details are optional and are not required for the core app. Avoid requesting location permission solely for a decorative field. |
| Ports / attached devices | Connected displays, storage, and devices the public IOKit/system interface safely enumerates | “Not enumerated by supported API” for physical port inventories that cannot be read reliably | Do not promise detection of every empty physical port. Connected device inventory is not equivalent to a full chassis port map. |
| Thermal / cooling | System thermal pressure/state; fan speed or temperature only if stable supported sources exist | Show thermal pressure if available; separately label raw temperature/fan RPM as not exposed when applicable | Never use undocumented SMC keys or privileged helpers to populate a visual gauge. |
| Camera, microphone, audio and other peripherals | Enumerated connected devices where supported, without activating capture | “No device reported” or “enumeration unavailable” as appropriate | Do not request camera/microphone access unless the user starts a feature that actually uses them. Inventory must not activate sensors. |

#### Capability state contract

Each metric and hardware feature must produce a typed record equivalent to:

```swift
enum CapabilityStatus {
    case available
    case notPresent
    case unsupportedByOS
    case notExposedBySupportedAPI
    case restricted(reason: String)
    case permissionRequired(permission: String)
    case temporarilyUnavailable(reason: String)
    case probeFailed(code: String, userSafeMessage: String)
}

enum DataConfidence: String, Codable, Sendable {
    case exact
    case derived
    case partial
}

struct CapabilityRecord<Value: Codable & Sendable>: Sendable {
    let id: String                 // stable semantic identifier
    let category: String           // cpu, gpu, memory, display, battery, etc.
    let displayName: String
    let value: Value?              // nil unless there is a valid value
    let unit: String?
    let status: CapabilityStatus
    let source: String              // framework/provider name, never a guessed source
    let observedAt: Date?
    let refreshedAt: Date
    let explanation: String?        // user-facing explanation for non-available states
    let confidence: DataConfidence  // exact, derived, partial
}
```

This is a logical contract; adapt the exact Swift representation to Codable constraints, localization, and persistence needs. `status` and `confidence` are separate: a derived value may be available but must still be labelled as derived. The UI must not interpret `nil` as numeric zero.

Rules:
1. **Probe independent features independently.** Failure to read fan telemetry must not suppress CPU, GPU identity, battery, or task features.
2. **Keep raw and normalized values separate.** Preserve raw OS values for diagnostics/tests; normalize to stable, unit-bearing app values before presentation.
3. **Retain provenance.** Every displayed system field must map to a provider and documented calculation. The detail inspector should expose “Source and refresh” information.
4. **Avoid false inference.** The model identifier can help label a device, but it cannot establish live battery health, active GPU, current display mode, sensor support or whether an external device is connected.
5. **Refresh on relevant events.** Re-probe on launch; after wake; when display, network, storage or power state changes; and when the user asks to refresh. Do not run a full inventory crawl every second.
6. **Support version-specific providers.** Use availability checks and keep provider implementations behind protocols. If a provider is unavailable on an older supported OS, mark the exact field `unsupportedByOS` and continue with other fields.
7. **Do not silently fall back to shell parsing.** Use documented APIs first. A subprocess such as `system_profiler` may be evaluated only for on-demand supplemental reports after performance, localization, privacy and output-format risks are tested; it must not be required for live metrics or core identity.
8. **Show useful absence explanations.** For example: “Fan RPM isn't available through the supported macOS interfaces on this system”; not “0 RPM”, “0 °C”, or “N/A” without context.

### 7.3 CPU usage definition

CPU utilization should be computed using the difference between consecutive cumulative CPU statistics rather than a single instantaneous read. The denominator and categories must be defined in code and documented in the interface's help text. Handle counter wrap/reset, sleep/wake, CPU hot-plug where relevant, and unavailable readings.

### 7.4 Memory definition

Memory accounting on macOS can be misunderstood. Do not show “RAM used = physical memory minus free pages” as the only authoritative user-facing truth without explanation. Prefer displaying the system memory-pressure state if a reliable supported signal is available, along with a defined memory summary. Make wired, compressed, cached and app-related categories optional and only render them if the provider has verified definitions.

### 7.5 Process monitor boundaries

- Display user-visible running applications and processes for which the app can read reliable metadata.
- Do not attempt to bypass per-user, sandbox or OS restrictions.
- If full process enumeration is not possible under a supported configuration, state that the list is partial.
- Avoid force-quit controls in MVP; if added later, they must clearly distinguish normal app termination from force termination and require deliberate user action.
- Do not collect process names for analytics or upload them.

### 7.6 Storage behavior

- Show volume name, mounted state, total capacity, available capacity and filesystem where exposed.
- Do not scan the home folder or entire disk automatically.
- A future storage inspector may scan only a folder the user selects via a native open panel, with progress, cancellation and explicit disclosure.
- Exclude hidden/system folders from any default user-facing visualization unless the user explicitly requests detailed analysis.

### 7.7 Sampling and lifecycle policy

Metrics must be sampled based on current UI need:

| App state | CPU/memory | Network | Battery/storage | Process inventory |
|---|---|---|---|---|
| Dashboard active | Every 1–2 s | Every 1–2 s | Every 5–15 s | Every 2–5 s or on events |
| App active, dashboard hidden | Every 5–10 s only if a compact status surface requires it; otherwise pause | 5–10 s only if surfaced | 30–60 s or on view entry | Event-driven / slower refresh |
| App in background and no status surface | Pause high-frequency collection | Pause high-frequency collection | Pause or rare refresh | Event-driven only |
| App quits | No sampling | No sampling | No sampling | No sampling |

These are starting values. Profiling and user testing may revise them. The user must be able to disable metric history. Live charts need a rolling in-memory buffer; persisted history should use downsampled rollups rather than writing every sample indefinitely.

### 7.8 Historical data and chart retention

- Default live chart window: 60 seconds or 5 minutes, with selectable 1 minute / 5 minutes / 1 hour / 24 hours only when data exists.
- Store compact rollups, not every high-frequency reading forever.
- Provide a retention preference such as Off / 24 hours / 7 days / 30 days.
- Delete historical metrics when retention expires or when the user clears history.
- Keep metric history distinct from task data so the user can clear it without deleting tasks.
- No automatic telemetry upload.

### 7.9 Runtime device profile and capability registry

Create a `DeviceProfileService` and `CapabilityRegistry` as separate modules in `SystemMetrics`. Their job is to discover what this specific Mac and its current OS can report, not to decide what every Mac of a named tier should contain.

**DeviceProfileService responsibilities**
- Build a local machine profile on first launch and refresh it when the OS/hardware context changes.
- Record model identifier, OS version/build, architecture, CPU and memory attributes that have verified sources, and a stable app-generated device-profile ID. Do not persist serial number or other unnecessary identifiers.
- Enumerate currently visible GPUs/displays/network interfaces/storage volumes through verified providers; update inventories on relevant events.
- Mark fields as `observed`, `derived`, `notExposed`, or `notVerified` in the internal profile so presentation cannot accidentally show estimates as raw facts.
- Keep the profile local and editable only by the app; no network call is needed.

**CapabilityRegistry responsibilities**
- Register every metric/feature provider with a stable identifier, category, minimum OS, source, sampling cadence, and test fixture.
- Return an explicit state for every provider, including providers that are absent or unsupported on this Mac.
- Detect when the running OS lacks a framework/API at compile-time or runtime and degrade the affected field only.
- Keep category definitions versioned so adding a new feature does not corrupt saved metric history.
- Expose a support report to the UI and local diagnostics that lists available, unavailable and failed probes without sending it anywhere automatically.

**UI behavior across model tiers**
- A base-model MacBook may show a smaller inventory (for example, fewer GPU devices, fewer reported core details, different maximum display capabilities or fewer battery-health fields). A high-end MacBook may expose additional devices/fields. The same screens and data model render both.
- The Overview should prioritize currently available high-value metrics. A dedicated Hardware & Capabilities page must provide full category coverage and the reason a value isn't shown.
- Do not render a zero-valued card for a missing hardware feature. Use a named state: **Not present**, **Not exposed by macOS**, **Not supported on this OS**, **Access restricted**, **Temporarily unavailable**, or **Could not read**.
- Distinguish “not present” from “not detected”: the first requires a reliable probe confirming absence; the second means the app could not establish presence/absence.
- Provide a “Refresh hardware information” action and show the last scan time. Prevent repeated button presses from spawning parallel probes.
- The app must remain fully useful for tasks if a hardware provider hangs, fails, or is unsupported.

**Model and OS compatibility testing**
- Build a fixture suite for representative capability profiles: Intel integrated graphics; Intel with integrated/discrete graphics when supported; Apple Silicon base-tier; Apple Silicon Pro/Max-tier; different memory capacities; built-in displays with and without high refresh rates; battery fields present/partial; and external displays/docks.
- Unit tests must feed profiles through the same UI models and confirm all values and states render accurately. Fixtures are test-only; the production app must not present fixture data.
- Real hardware qualification must include representative physical devices across the supported architectures and OS range. Hardware emulation/fixtures complement this test matrix but do not replace it.
- When a new macOS release changes a field or framework behavior, provider tests must catch stale values, missing keys and changed units before release.

---

## 8. Functional requirements for app settings and utilities

### 8.1 Settings categories

- General: launch behavior, reopen last view, confirmation behavior, keep-in-menu-bar, close-window behavior, and opt-in launch at login.
- Appearance: System / Light / Dark, accent preference if custom palette is supported, density.
- Tasks: default priority/project, completed-task visibility, recurrence behavior.
- Notifications: permission state, sound, reminders, notification preview options.
- Mac Dashboard: sampling profiles, chart retention, compact system-status surfaces, and metric freshness policy.
- Widgets: default widget destination, privacy/preview behavior, optional Mac Snapshot metrics, widget data refresh behavior, and project/list configuration guidance.
- Privacy: clear metric history, export all data, reset application data, telemetry (off by default; ideally absent in v1).
- Updates: automatic/manual check, update channel, release notes.
- Menu Bar: show/hide menu-bar icon, quick-capture shortcut, default menu contents, launch at login, start quietly, and quit behavior.
- About: version, build, architecture, privacy statement, licenses and diagnostics export.

### 8.2 Native macOS widgets (required)

Implement widgets using **WidgetKit + SwiftUI** in a dedicated widget extension included in the signed application. Widgets must appear in the macOS widget gallery and work in the widget locations supported by the installed OS (including Notification Center; desktop placement is available on macOS versions that support it). The same app release should support the oldest declared OS target with graceful family/placement differences rather than requiring a separate product.

**Widget types**

1. **Today Tasks** — small, medium and large layouts showing a task count, a small prioritized list, overdue state and due-time hints where appropriate.
2. **Inbox / Quick Capture entry point** — a compact summary and an action that opens the app's capture screen. The widget must not imply that arbitrary text entry is possible directly inside the widget if the chosen WidgetKit interaction model cannot provide it.
3. **Daily Progress** — completed versus open tasks, a compact activity visualization and a link to Productivity/Today.
4. **Project Focus** — configurable project progress and next tasks, if a project is selected by the user.
5. **Mac Snapshot** — optional summary using the last known safe sample (for example battery/charging state, storage free space, and a timestamp). Do not promise live CPU/RAM/network values in the widget. Any sampled metric shown must include freshness or last-updated context when relevant.

**Widget sizes and configuration**
- Support appropriate small, medium and large families on the targeted macOS versions; add extra-large or accessory families only where the platform actually offers them.
- Use a widget configuration intent, where supported, to let users choose which project/list and which optional metric summary appears.
- Respect light/dark appearance, macOS widget materials, readable contrast, Dynamic Type where applicable, and VoiceOver.
- Avoid complex real-time animations, high-frequency chart updates, continuous sensors, network calls, or expensive computation in the extension.
- Use compact native visualizations such as a progress ring, short sparkline based on stored history, task count, or a small status glyph. Charts must communicate the time span and must not present stale data as live.

**Tap and navigation behavior**
- Tapping the main widget surface must open the actual Task Manager application, not a web page or a separate standalone experience.
- Route the app to a relevant destination using a versioned deep-link scheme, such as `taskmanager://today`, `taskmanager://inbox`, `taskmanager://project/<id>`, `taskmanager://dashboard/performance`, or `taskmanager://capture`. Validate and normalize all URL payloads; never trust an incoming project ID or path without checking it against local data.
- The app must handle the URL when already running, running only as a menu-bar app, or not currently running. It should activate or create the primary window and focus the matching screen.
- Widgets with separately presented action controls may expose narrow App Intents such as “Mark task complete” only after data safety and confirmation behavior are tested. The overall widget tap remains an app-opening interaction; actions must not accidentally turn the entire widget into a non-opening task toggle.

**Refresh and data freshness**
- Treat WidgetKit as a system-managed snapshot/timeline mechanism. It is not a continuously running widget process. The system decides when to render/reload timelines, and reload timing can be delayed or budgeted.
- Prefer timeline entries derived from locally stored task state and predictable dates. When a task is changed in the main app or by an App Intent, request a relevant widget timeline reload through `WidgetCenter` rather than periodically rebuilding all widgets.
- The widget should remain useful if the host app has not been open recently. It may read a small shared data snapshot from an App Group container, but the widget must not start continuous collection of system metrics.
- Include stale/last-updated labeling for sampled system data. If a metric has no recent sample, show “Last updated …” or omit that metric instead of suggesting a live reading.
- Do not depend on an exact reload interval. The UI, data model, support page and marketing must not guarantee per-second, per-minute, or immediate refresh from WidgetKit.

### 8.3 Always-available app behavior and launch at login (required, user-controlled)

“Always on” means easy to access and ready for task actions—not permanently busy or exempt from macOS power management.

- Keep the menu-bar entry enabled by default after the user launches the app, so closing the main window does not remove quick access. Provide a **Keep in Menu Bar** preference to disable this behavior and an optional **Launch at Login** preference. Explain both clearly; do not silently register a login item on first launch. Launch at Login remains opt-in.
- Use a native SwiftUI `MenuBarExtra` or equivalent AppKit implementation for quick capture, Today tasks, a small set of quick actions and a link to the main window. The menu-bar icon must have a clear tooltip/accessibility label and a way to open the full application.
- The user may close the main window while leaving the menu-bar surface running if that preference is enabled. If the preference is disabled, normal macOS close/quit behavior should be respected.
- On supported OS targets, use the documented `SMAppService` login-item mechanism for opt-in startup registration. Explain that macOS may show its own approval/status UI and provide a settings link if the user disables it at OS level. Never bypass user consent or manipulate system settings.
- No separate LaunchDaemon, root helper, kernel extension, or background service installation is allowed for baseline functionality. Avoid creating a separate helper process unless testing demonstrates it is necessary; any later helper needs a separate security and energy review.
- Launch-at-login must not automatically open a large full-screen window unless the user explicitly chooses that behavior. The default is to start quietly in the menu bar when enabled.
- A menu-bar presence must not imply that CPU/GPU/battery/network sensors are continuously polled. High-frequency metrics stop when the full dashboard is hidden, except a user-configured compact indicator may use an explicitly documented low-frequency/low-cost provider.
- Local reminders should use `UserNotifications`, not a custom polling loop. Task due-state transitions and widget timeline dates should be scheduled using system facilities wherever possible.
- Provide **Quit Task Manager** as a standard menu-bar action and a visible preference for launch behavior. When quit, the menu-bar icon and app process must exit cleanly. Widgets can continue to display their last valid snapshot and open the app when tapped.

### 8.4 Menu-bar utility behavior

The menu-bar surface must remain small and predictable rather than becoming a second full application. Initial contents:
- New Task / Quick Capture.
- Today: a few prioritized tasks and a count of remaining tasks.
- Open Task Manager.
- Optional compact system status, disabled by default unless the user selects it.
- Settings, About, and Quit.

Use native controls and keyboard support. Menubar UI must not display an exhaustive task list or a dense monitoring dashboard. Do not show sensitive task notes in a compact view unless the user has enabled that behavior.

### 8.5 Global keyboard shortcut

A system-wide shortcut for quick capture may require registering a global hotkey. Explain that it is optional, expose a customization option, and handle conflicts gracefully. Do not request Accessibility permission solely for a basic shortcut when the selected supported implementation does not require it. Validate permissions and behavior on the supported OS matrix.

### 8.6 Accessibility

- VoiceOver labels for all controls, widgets, menus and chart summaries.
- Full keyboard access through navigation, edit forms, list selection, reorder alternatives, and menus.
- No status communicated solely by color.
- Support Reduce Motion and increased contrast.
- Hit targets and focus indicators must be usable with pointing-device and keyboard interaction.
- Avoid rapidly changing screen-reader announcements from live metrics; announce state changes only when meaningful or explicitly requested.
- Widget actions must be understandable without visual-only labels and must use confirmation or undo for destructive operations.

---

## 9. Recommended technology stack

### 9.1 Primary stack: native macOS

| Layer | Technology | Reason |
|---|---|---|
| Language | Swift | Native language and direct framework access |
| UI | SwiftUI | Native window composition, accessibility, appearance and state-driven UI |
| Platform interop | AppKit | Menu-bar behavior, some window and application integrations where needed |
| macOS widgets | WidgetKit + SwiftUI widget extension | System-managed desktop/Notification Center widgets with timeline refresh and deep links |
| Widget and shortcut actions | App Intents | Narrow system-exposed actions such as mark complete or quick capture where supported |
| Shared app/widget data | App Groups container + validated shared snapshot/repository | Read consistent local task summaries from the widget extension without a server |
| Launch at login | ServiceManagement `SMAppService` where supported | User-controlled login item; no privileged daemon |
| Standard charts | Swift Charts | Interactive, native chart composition and accessibility |
| Small custom visuals | SwiftUI `Canvas` | Efficient sparklines, heatmaps and custom marks |
| Advanced GPU rendering | Metal only if justified by profiling | Not required for v1; avoid unneeded complexity |
| Local persistence | SQLite through the system SQLite library, with a small typed repository layer | Efficient, inspectable, migratable local data without a server |
| Search | SQLite FTS5 when validated; fallback indexed search | Fast local search |
| Notifications | `UserNotifications` | Native local notifications |
| Running-app inventory | `NSWorkspace` / `NSRunningApplication` | Native app lifecycle information |
| Hardware/system readings | Documented Apple system frameworks and verified OS APIs | Avoid privileged or private-API dependency |
| Update framework | Sparkle 2 for direct distribution, after security/configuration review | Signed, secure, in-app macOS updates |
| Build | Xcode command-line tools / `xcodebuild` | Reproducible macOS build pipeline |
| CI/release | macOS CI runner, automated signing/notarization/release steps | Build artifacts can be reproduced and verified |

**No browser runtime:** do not use Electron, Tauri, React, a bundled Node.js runtime, or a local web server for the initial version. A native implementation removes the need to ship a browser runtime and provides the strongest alignment with a lightweight Mac-first product.

**No user-installed packages:** any libraries needed to compile the app are resolved during development/CI and incorporated into the shipped application as appropriate. Users must never be instructed to install packages, run commands, configure a runtime, or build from source to use a release.

### 9.2 Why not Tauri for this particular product?

Tauri is appropriate for cross-platform apps, but this product is explicitly Mac-first and needs polished native system integration. SwiftUI/Swift provides native controls, native charts, direct access to Apple frameworks, and avoids maintaining a web UI and desktop-webview bridge. If Windows/Linux becomes a committed target, the architecture can be revisited instead of prematurely paying the complexity cost in v1.

### 9.3 Dependency policy

- Prefer Apple system frameworks and a small number of maintained third-party dependencies.
- Pin dependency versions and audit update-framework releases.
- Maintain a software bill of materials and license notices for shipped third-party code.
- Avoid analytics SDKs, remote feature flags, remote fonts and runtime package downloads.
- Every dependency must justify its binary size, maintenance impact, privacy characteristics and compatibility with the minimum supported OS.

---

## 10. High-level architecture

### 10.1 Architecture style

Use a modular, layered native architecture with clear boundaries between SwiftUI presentation, domain logic, persistence, and OS integrations. Avoid a monolithic view file and avoid excessive abstraction where there is only one implementation.

```text
┌──────────────────────────────────────────────────────────────┐
│                 Native App Presentation                      │
│ Today • Inbox • Projects • Insights • Dashboard • Settings   │
│ MenuBarExtra / quick-capture surface                          │
└──────────────────────────────┬───────────────────────────────┘
                               │ View state / user actions
┌──────────────────────────────▼───────────────────────────────┐
│                 Presentation Models / State                  │
│  TaskViewModel • ProjectViewModel • DashboardViewModel       │
│  ChartViewModel • SearchCoordinator • SettingsViewModel      │
└─────────────────────┬─────────────────────┬─────────────────┘
                      │                     │
┌─────────────────────▼──────────┐  ┌───────▼──────────────────┐
│          Domain Services       │  │       OS Integrations    │
│ Task rules / recurrence        │  │ CPU / memory providers   │
│ Filters / sort / search        │  │ Battery / network        │
│ Insights calculations          │  │ Storage / process list   │
│ Import / export / validation   │  │ Notifications / hotkey   │
└─────────────────────┬──────────┘  └────────┬─────────────────┘
                      │                      │
┌─────────────────────▼──────────────────────▼─────────────────┐
│                     Infrastructure                            │
│ SQLite repositories / migrations / metric ring buffer         │
│ App Group snapshot / settings / export / updater integration  │
└──────────────────────────────────────────────────────────────┘
                              ▲
                              │ versioned local snapshot / deep links / App Intents
┌─────────────────────────────┴────────────────────────────────┐
│                 WidgetKit Extension (system managed)         │
│ Today Tasks • Daily Progress • Project Focus • Mac Snapshot   │
│ Bounded timeline generation; no continuous polling or backend│
└──────────────────────────────────────────────────────────────┘
```

### 10.2 Module boundaries

Suggested modules or Swift packages/targets (split physically only where it improves build time and ownership):

- `AppShell`: application lifecycle, navigation, deep-link router, dependency composition, app-wide state.
- `Widgets`: WidgetKit configurations, timeline providers, widget families, deep links, and optional App Intents.
- `SharedWidgetData`: compact App Group snapshots, schema/version validation and safe read/write coordination.
- `MenuBar`: `MenuBarExtra`, quick capture, Today summary, menu-bar lifecycle and launch-at-login preferences.
- `DesignSystem`: reusable typography tokens, spacing, colors, status tokens, buttons, cards and chart styling.
- `TasksDomain`: task models, state transitions, recurrence calculations and filter logic.
- `TasksUI`: Today, Inbox, task list, task details, project, calendar and productivity views.
- `Persistence`: SQLite connection, schema, migrations, repositories and transaction handling.
- `SystemMetrics`: protocols and per-metric providers, sampling scheduler and metric quality model.
- `HardwareInventory`: device profile, runtime capability registry, hardware-category states, provider provenance and cross-model normalization.
- `DashboardUI`: device overview, performance, network, battery, storage and process pages.
- `Notifications`: local reminders and notification authorization state.
- `ImportExport`: JSON/CSV import, export and validation.
- `Updates`: version check and secure updater integration.

Avoid exposing raw IOKit/Mach/SQLite types to SwiftUI views. Views consume stable domain-level structures and format them for presentation.

### 10.3 Widget data contract and shared state

The widget extension is a separate, system-managed execution target. It must not open or migrate the application's primary database independently at arbitrary times without a defined concurrency policy.

- Use an App Group container for the smallest required shared state. The main app owns database creation and schema migrations; the widget reads a compact snapshot rather than opening the primary database for ordinary rendering.
- Produce a compact, versioned widget snapshot containing only what widgets need: selected task IDs/titles/due-state, task counts, project selection metadata, last-calculated progress, chosen safe system metric values, and observation timestamps. Do not copy all task notes or private metadata into a widget snapshot.
- Update the snapshot atomically (write temporary file then replace) after task changes, project changes, user configuration changes, and selected metric refreshes. Include a schema version and generated-at timestamp.
- The widget extension validates snapshot version and fields. A missing/corrupt snapshot should display a calm empty/refresh state and must never crash or erase the primary database.
- If optional App Intents change task state while the main app is not running, use a clearly defined, idempotent action queue or a shared transactional store with cross-process locking. Reconcile pending actions against the authoritative task records when the app next opens. Do not allow the widget to perform schema migrations, and do not allow uncoordinated simultaneous database writes.
- Call `WidgetCenter` to reload only widget kinds affected by a meaningful data change; do not reload every widget after every metric sample.
- Widgets have no required network dependency. Keep all task information and widget state local.

### 10.4 Concurrency

- Use structured concurrency (`async`/`await`, actors, or serial queues) for metric collection and database operations.
- Keep OS sampling and database work off the main thread.
- Coalesce duplicate requests for the same metric.
- Ensure UI updates are delivered on the main actor.
- Cancel sampling tasks when the relevant view is no longer active or the app is quitting.
- Widget timeline generation must be bounded, read-only by default, and complete within WidgetKit execution limits; no perpetual async task is allowed in the widget extension.
- Use bounded buffers and avoid unbounded tasks per chart point.

### 10.5 Failure isolation

Each metric provider should fail independently. If battery access fails, CPU, tasks and storage remain available. The dashboard aggregates provider state without allowing one failed metric to break the entire screen. Hardware-category presence and per-metric data availability must be evaluated independently; a provider failure must never be treated as proof that a component is absent.

---

## 11. Persistence and data model

### 11.1 Storage location

Use a per-user application-support directory under the standard macOS container path for local application data. Exact bundle identifiers and paths must be finalized before release. Store temporary exports and caches in appropriate temporary/cache locations and clear them safely.

### 11.2 Proposed logical schema

**`tasks`**
- `id` primary key
- `title`, `notes`
- `status`, `priority`
- `created_at`, `updated_at`, `completed_at`
- `start_at`, `due_at`
- `project_id`, `section_id`
- `sort_order`, `estimate_minutes`
- `recurrence_rule`, `parent_task_id`
- `deleted_at`

**`projects`**
- `id`, `name`, `description`, `color_token`
- `created_at`, `updated_at`, `archived_at`, `sort_order`

**`sections`**
- `id`, `project_id`, `name`, `sort_order`

**`tags`**
- `id`, `name`, `color_token`, `created_at`

**`task_tags`**
- `task_id`, `tag_id`; unique composite constraint

**`task_reminders`**
- `id`, `task_id`, `fire_at`, `kind`, `enabled`, `notification_identifier`

**`settings`**
- key/value or typed settings table with schema versioning

**`metric_rollups`** (created only when history is enabled)
- `id`, `metric_key`, `observed_at`, `bucket_seconds`
- `min_value`, `max_value`, `avg_value`, `last_value`
- `unit`, `provider_quality`, optional source metadata

**`schema_migrations`**
- version, applied timestamp, migration checksum or identifier

### 11.3 Database rules

- Enable foreign-key constraints.
- Use transactions for multi-table changes and imports.
- Add indexes for due date, status, project, sort order and common filtering combinations.
- Add a migration path for every schema change.
- Backup or preserve a recoverable copy before an irreversible migration.
- Test database recovery from forced termination during writes.
- Do not keep duplicate “Today” or “Upcoming” records; derive smart lists from tasks.
- Use UTC timestamps for absolute instants and preserve a timezone identifier where recurrence semantics require local wall-clock time.

### 11.4 Data privacy and deletion

- Task data, search indexes, settings and metric history stay on-device.
- No usage analytics or background upload by default.
- Provide separate controls for deleting completed tasks, resetting all tasks, clearing metric history, and resetting settings.
- Display a confirmation and provide an export/backup opportunity before full reset.
- Diagnostic logs must not contain task titles, task notes, or process lists by default.

---

## 12. State and data-flow examples

### 12.1 Task creation

1. User invokes New Task or quick capture.
2. Presentation model validates title and normalizes optional fields.
3. Task domain service applies defaults and checks date/recurrence rules.
4. Repository writes the task in a SQLite transaction.
5. App state updates affected lists and badges.
6. Reminder scheduler is reconciled only if reminder information changed.
7. An undo action is made available where appropriate.

### 12.2 Live metric chart

1. Dashboard becomes visible.
2. Sampling coordinator requests the active metric profile.
3. Provider obtains one sample without blocking the main actor.
4. Provider emits value, unit, timestamp, quality and failure reason if any.
5. A bounded in-memory ring buffer receives the sample.
6. Chart view model derives the visible series and downsampled points.
7. Chart refreshes smoothly without recreating the entire dashboard.
8. If metric history is enabled, a lower-frequency rollup writer persists aggregated samples.
9. When dashboard is hidden, the sampling profile slows or stops according to policy.

### 12.3 Recurring task reminder

1. User selects a recurrence and enables a reminder.
2. The app requests notification authorization if necessary.
3. Recurrence service calculates the next supported occurrences.
4. Local notification requests are scheduled within a bounded horizon.
5. Completion or edits reconcile future requests idempotently.
6. If notifications are denied, the task still works and Settings explains that reminders are unavailable until permission changes.

---

## 13. Performance and resource budgets

These are **initial engineering targets**, not claims about results before profiling. CI and release qualification must measure them on representative Intel and Apple Silicon Macs.

### 13.1 Target budgets

| Metric | Initial target | Measurement approach |
|---|---:|---|
| Cold launch to usable Today view | ≤ 2.5 s on reference hardware | Repeated release-build launch tests |
| Warm launch | ≤ 1.5 s on reference hardware | Automated/manual measurement |
| Common task interaction | p95 ≤ 100 ms after local data is loaded | UI instrumentation and benchmark fixtures |
| Search for typical personal dataset | p95 ≤ 150 ms for 10,000 tasks | Seeded database benchmark |
| Idle CPU, dashboard hidden | Target below 1% average over 5 minutes with keep-in-menu-bar enabled | Instruments / Activity Monitor; no artificial polling |
| Menu-bar idle energy | No sustained high-frequency CPU wakeups when idle; target no material energy impact in a 30-minute idle test | Instruments Energy Log / Activity Monitor on battery |
| Widget extension execution | Short, bounded timeline generation; no network or long-running task | Widget extension diagnostics and Instruments |
| Widget refresh behavior | Correct, useful under delayed/coalesced WidgetKit reloads; never depends on exact refresh timing | Test stale-data cases and simulate app-not-running widget state |
| Hidden-dashboard metric sampling | Stop high-frequency sampling | Unit/integration test on lifecycle transitions |
| Memory use | Establish release baseline; target ≤ 150 MB typical after warm start, subject to feature/profile | Activity Monitor / Instruments; disclose deviations and investigate leaks |
| UI frame cadence | Smooth interactions; target 60 FPS where supported and meaningful | Core Animation / Instruments profiling |
| Disk writes | No per-frame disk writes; aggregate metric rollups | Instrumentation and repository tests |
| Database integrity | No data loss in forced-close stress tests | Automated termination/restart test harness |

### 13.2 Optimization rules

- Do not poll metrics when the related screen is not visible. A widget is not a reason for high-frequency sampling: widgets use stored snapshots and WidgetKit-managed timeline reloads. A compact status provider may sample at a conservative cadence only if the user explicitly enables it and profiling shows low energy impact.
- Use event-driven application inventory updates where practical instead of constant full enumeration.
- When the main window is closed but the menu-bar item remains enabled, keep only minimal in-memory app/task state; no continuous CPU/GPU/network polling and no repeated whole-database scans.
- Keep chart buffers bounded and downsample large ranges before rendering.
- Reuse database connections and prepared statements.
- Avoid repeated view identity changes that cause full chart/list reconstruction.
- Debounce search input without making it feel sluggish.
- Use Instruments to profile CPU, memory allocations, energy impact, launch and SwiftUI updates.
- Do not add Metal, a background helper or an optimization cache without evidence of a real bottleneck.

---

## 14. Installation, signing, notarization, and updates

### 14.1 User experience objective

A normal user must never need to install a language runtime, package manager, command-line dependency, database server, monitoring daemon, or development tool. All required runtime components must be inside the signed app bundle or supplied by macOS.

### 14.2 Recommended direct download flow

**Primary package: `Task-Manager-macOS-universal.dmg`**

1. User downloads the DMG from the official release page.
2. User double-clicks the DMG in Finder.
3. A branded window shows `Task Manager.app` and a shortcut to `/Applications`.
4. User drags Task Manager into Applications.
5. User ejects the mounted disk image and opens Task Manager from Applications, Launchpad or Spotlight.
6. First-run onboarding asks only for optional capabilities when the user reaches them.

This is the familiar Mac application-install pattern. It does not need a package-manager setup or a terminal. It is not a single-button install; a DMG normally requires dragging the app into Applications. Do not describe that interaction inaccurately in marketing.

**Optional guided package: `Task-Manager-macOS-universal.pkg`**

Provide only if feedback indicates users strongly prefer a double-clicked installer with a guided Install flow. Sign the package with a Developer ID Installer certificate, notarize it, and verify whether any steps require user authorization. The PKG must not install a privileged helper, service, or login daemon.

### 14.3 Distribution path

Preferred for the first public release: **Developer ID direct distribution, code signing, hardened runtime, Apple notarization, and a stapled ticket**. This offers a direct-download path while allowing Gatekeeper to verify the publisher and notarization result. An App Store submission may be considered later, but sandbox requirements and system-information feature availability must be validated first.

Relevant official Apple guidance:
- [Distributing software on macOS](https://developer.apple.com/macos/distribution)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
- [Packaging Mac software for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)

### 14.4 Release requirements

- Use an authentic Developer ID Application certificate for app signing.
- Enable hardened runtime with only the entitlements required by the app.
- Sign all nested executables and frameworks correctly.
- Submit the distribution artifact to Apple's notary service using the current supported workflow.
- Staple the notary ticket where supported and verify the final artifact with Apple's tooling.
- Test the actual downloaded DMG on a clean Mac/user account, not only the app built inside Xcode.
- Verify that widget extension registration succeeds after installation, widgets appear in the widget gallery, deep links launch/activate the main app, and widgets still render when the main app is not running.
- Confirm Gatekeeper's first-launch behavior is clear and does not require users to bypass security controls manually.
- Keep signing credentials out of the repository and CI logs. Use restricted CI secrets and rotate credentials according to policy.
- Publish SHA-256 checksums and release notes next to the download.

### 14.5 Universal builds

- Build `arm64` and `x86_64` slices for the stated support range.
- Validate every dependency supports both architectures.
- Test Apple Silicon natively and Intel hardware; test Intel-targeted code paths on Apple Silicon where useful.
- Never require the user to install Rosetta for the native architecture supported by their Mac. A legacy Intel-only dependency must not silently become a release blocker.

### 14.6 Secure automatic updates

Use Sparkle 2 or an equivalent well-maintained updater after reviewing its current security and deployment documentation. Sparkle advertises EdDSA signature verification and Apple code-signing validation; its version and configuration must be pinned and audited. See [Sparkle's official repository](https://github.com/sparkle-project/Sparkle).

Update requirements:
- HTTPS-only appcast/update endpoints.
- Verify update signatures and code signatures before installation.
- Present version number, release notes and restart requirement before an update unless the user enables quiet automatic updates.
- Support manual check and opt-out of automatic download/install.
- Never download or execute arbitrary scripts as an update mechanism.
- Use phased rollout for high-risk releases when practical.
- Maintain a tested rollback/recovery procedure: at minimum, an older known-good signed DMG remains available; updater should not overwrite user data.
- Updates must preserve the local database and run schema migrations safely.
- Update service must not collect task contents or system metric history.

### 14.7 Mac App Store decision

Evaluate the Mac App Store as a secondary channel after an entitlement prototype. The App Store improves discovery and update convenience but requires its own packaging, sandbox and review work. Do not promise identical system metrics in the App Store build until each metric and entitlement has been verified. Keep the architecture capable of presenting “not available in this distribution” states without breaking task management.

---

## 15. Privacy and security specification

### 15.1 Principles

- Local-first and offline-capable.
- No user account and no network dependency for core tasks or local system charts.
- No remote analytics or advertising SDKs in version 1.0.
- No collection of task titles, notes, process names, device identifiers or metric history by a vendor server.
- Request permissions contextually, only when a user activates a feature that requires them.
- No silent full-disk scans or changes to security settings.

### 15.2 Permission strategy

Baseline app features should work without Full Disk Access, Screen Recording, Accessibility or administrator privileges. Notifications require user consent when enabled. A global shortcut or future automation feature must use the least-privileged documented mechanism and explain any OS permission if it is actually needed.

### 15.3 Secure coding

- Parameterize all SQL statements.
- Validate imported files against size, schema and field limits before touching the live database.
- Treat imported task notes and file names as untrusted input.
- Avoid shelling out to commands for routine metric collection; prefer documented system APIs. If a subprocess is unavoidable, use a fixed executable/argument list, never interpolate user input, and document the rationale.
- Sanitize logs and redact private application data.
- Use App Sandbox if compatible with the chosen distribution/features; direct distribution outside the Mac App Store can use hardened runtime and should adopt sandboxing where it does not undermine explicitly documented core capabilities.
- Keep third-party update and signing libraries current.

### 15.4 Threat model

Protect against:
- Tampered or substituted release downloads.
- Malformed import files and SQL injection.
- Corrupt databases or interrupted schema migrations.
- Insecure updater feeds or unsigned update payloads.
- Accidental data exposure through logs or diagnostics.
- Excessive permission requests that erode user trust.

The application is not a security product and must not claim to prevent malware or provide forensic-grade hardware diagnostics.

---

## 16. Error handling and diagnostics

### 16.1 User-facing errors

Errors should explain what happened, whether data is safe, and one next action. Avoid raw Mach codes, SQLite messages or stack traces in normal UI.

Example: “Battery details aren't available on this Mac. Task Manager will continue to show the other system information.”

### 16.2 Logging

- Use unified logging with subsystem/category conventions.
- Default to concise operational logs.
- Do not log task text, notes, process command lines, or exported data.
- Add a user-initiated diagnostics export that explains what will be included before creating the file.
- Keep metrics provider failures distinct from app-wide failures.

### 16.3 Crash recovery

- A crash in a chart/provider must not corrupt task data.
- Database writes use transactions and integrity checks.
- The app must reopen to a working task view when the dashboard provider fails.
- Preserve a recent backup around schema migrations; define cleanup to avoid accumulating old copies indefinitely.

---

## 17. Testing and quality strategy

### 17.1 Unit tests

- Task state transitions.
- Due-date and timezone rules.
- Recurrence generation, daylight-saving transitions, and overdue behavior.
- Sorting, smart list filters, and project deletion policies.
- Import validation, malformed JSON and CSV handling.
- Search tokenizer/indexing behavior.
- CPU/network sample delta calculations and reset conditions.
- Metric quality/staleness handling.
- Sampling lifecycle start/stop behavior.
- Database migrations and transactions.

### 17.2 Integration tests

- CRUD flows against a temporary SQLite database.
- Restart persistence and interrupted write recovery.
- Reminder scheduling and reconciliation.
- Versioned widget snapshot creation, atomic replacement and malformed-snapshot recovery.
- Deep-link routing with app quit, menu-bar-only, main-window-open, invalid URL and missing target records.
- Widget timeline generation under stale/empty data and scheduled refresh delays.
- Optional App Intents task-completion paths, idempotency, undo/reconciliation and simultaneous app/extension access.
- Export/import round trip with Unicode and timezone edge cases.
- Metric provider failures isolated from the whole dashboard.
- Updater verification in a controlled release test channel.
- Sign, package, notarize, staple and Gatekeeper validation on release artifacts.

### 17.3 UI and accessibility tests

- First-run onboarding and permissions.
- Task creation, editing, completion, undo and deletion.
- Main navigation, window resizing and full-screen mode.
- Empty, stale, unavailable and partial-data dashboard states.
- Light/dark modes and supported accent settings.
- VoiceOver labels, keyboard-only operation and chart summaries.
- Reduced Motion and increased contrast.
- Localization-ready date, time, number, byte and temperature formatting.

### 17.4 Performance tests

- Launch and first-render timing.
- Task list rendering with 1,000, 10,000 and 50,000 tasks.
- Search latency under realistic and worst-case seeded data.
- Long-running chart sampling for memory leaks.
- Idle CPU with dashboard visible and hidden.
- Idle CPU, wakeups, memory and energy impact for a 30-minute menu-bar-only session with Launch at Login behavior enabled.
- Widget extension startup/execution time, allocations, and behavior with an absent or outdated shared snapshot.
- Energy use on battery-powered MacBooks.
- Disk writes and database size under each history-retention profile.

### 17.5 Hardware/OS matrix

At minimum, validate the following hardware/OS dimensions. A physical machine need not exist for every combinatorial combination, but the provider/profile test suite must exercise all meaningful states.

**Representative physical machines**
- Entry-level Apple Silicon MacBook Air with its base-tier chip and memory configuration.
- Higher-end Apple Silicon MacBook Pro with a Pro- or Max-tier chip and a larger memory configuration.
- Intel MacBook model with integrated graphics, if Intel is in the published support matrix.
- Intel MacBook Pro with a separate/discrete GPU, if that class is in the published support matrix.
- Oldest MacBook generation permitted by the published minimum OS and newest supported hardware generation available at release qualification.

**Capability/state combinations**
- Different reported CPU architectures, logical/physical core counts, and GPU device lists.
- Multiple memory capacities and provider states for fields that are not consistently exposed.
- Built-in display, built-in high-refresh display, one external display, multiple external displays, dock/adapter transitions, and display disconnection while the app is open.
- Battery present, charging, discharging, connected to power, field omitted by power-source API, and battery status temporarily unavailable.
- Available/free storage changes, removable storage connect/disconnect, and filesystem values missing where applicable.
- Wi-Fi, Ethernet/USB network interface changes, sleep/wake, network loss, and interface counter resets.
- Thermal states exposed by the system; raw temperature/fan values unavailable or restricted.
- Standard user account with no extra permissions, and tests for explicit optional permission denial when any future feature requests one.
- Minimum supported macOS version and newest stable macOS release used during release qualification.
- Fresh install, in-place update, offline first launch, and offline operation after installation.
- Widget availability and widget refresh/deep-link behavior on each supported macOS version; desktop placement must be tested only on OS versions that support it.

**Test mechanism**
- Provider-level unit tests with injected API responses, capability-profile fixtures, UI snapshot tests for every capability state, and hardware-in-the-loop qualification on representative devices.
- Compare displayed values against the source API or a carefully documented independent reference. Check units, rounding, refresh time, and transitions; never use marketing copy as ground truth for live fields.
- Maintain a release artifact containing the test matrix, OS build, model identifier (not serial number), provider pass/fail status and field-level deviations.

Do not advertise a system/OS combination as supported unless the app launches and all unavailable metrics degrade gracefully. A system may be fully compatible even when certain low-level sensor fields remain unavailable through supported macOS APIs.

---

## 18. Build, CI, release, and repository structure

### 18.1 Suggested repository layout

```text
TaskManager/
├── App/
│   ├── TaskManagerApp.swift
│   ├── AppEnvironment.swift
│   ├── DeepLinkRouter.swift
│   ├── MenuBarController.swift
│   ├── NavigationState.swift
│   └── Resources/
├── DesignSystem/
│   ├── Theme/
│   ├── Components/
│   └── Charts/
├── Domain/
│   ├── Tasks/
│   ├── Projects/
│   ├── Tags/
│   ├── Recurrence/
│   └── Insights/
├── Persistence/
│   ├── SQLiteStore.swift
│   ├── Migrations/
│   └── Repositories/
├── SystemMetrics/
│   ├── MetricSample.swift
│   ├── SamplingCoordinator.swift
│   ├── CPUProvider.swift
│   ├── MemoryProvider.swift
│   ├── StorageProvider.swift
│   ├── BatteryProvider.swift
│   ├── NetworkProvider.swift
│   └── ProcessProvider.swift
├── Widgets/
│   ├── TaskManagerWidgets.swift
│   ├── WidgetTimelineProvider.swift
│   ├── WidgetSnapshotStore.swift
│   ├── WidgetIntents.swift
│   └── WidgetConfiguration.swift
├── Features/
│   ├── Today/
│   ├── Inbox/
│   ├── Projects/
│   ├── Search/
│   ├── Productivity/
│   ├── Dashboard/
│   ├── Storage/
│   ├── Battery/
│   ├── Network/
│   ├── Processes/
│   └── Settings/
├── Services/
│   ├── Notifications/
│   ├── ImportExport/
│   ├── SharedWidgetData/
│   ├── LoginItem/
│   ├── MenuBar/
│   ├── Updates/
│   └── Logging/
├── Tests/
│   ├── UnitTests/
│   ├── IntegrationTests/
│   └── UITests/
├── Scripts/
│   ├── build-universal.sh
│   ├── sign-and-package.sh
│   ├── notarize-and-staple.sh
│   └── verify-release.sh
├── Documentation/
│   ├── PRIVACY.md
│   ├── RELEASE.md
│   └── THIRD_PARTY_NOTICES.md
├── LICENSE
├── README.md
└── .github/workflows/
```

This is a logical starting point, not a requirement to create dozens of tiny files immediately. Keep the implementation modular and let domain boundaries guide splits.

### 18.2 CI stages

1. Lint/format check if a formatter is adopted.
2. Build on a macOS CI worker for the minimum target and current SDK.
3. Run unit and integration tests.
4. Run static analysis and dependency/license checks.
5. Build a release universal app.
6. Sign app and nested components.
7. Assemble DMG and optional PKG.
8. Submit the intended artifacts to Apple's notary service.
9. Staple tickets and verify signatures/Gatekeeper assessment.
10. Run smoke tests on the packaged artifact.
11. Generate checksums, release notes, and updater metadata.
12. Publish artifacts only after every required gate passes.

Signing credentials and notarization credentials must be stored in protected CI secrets or an equivalent secure signing environment. Pull requests from untrusted branches must not have access to release credentials.

### 18.3 Release channels

- **Stable:** signed, notarized releases available to all users.
- **Beta (optional):** explicit opt-in, visually marked, separate update feed.
- **Internal development:** local unsigned/debug builds; never linked as the recommended consumer download.

### 18.4 Release checklist

- [ ] Update version and release notes.
- [ ] Review changed permissions and entitlements.
- [ ] Confirm database migration and rollback/recovery strategy.
- [ ] Run unit, integration, UI, accessibility and performance tests.
- [ ] Build universal binary and check both architecture slices for the main app and all embedded extensions/components.
- [ ] Confirm the WidgetKit extension, App Intents metadata, App Group entitlements, URL/deep-link registration and login-item configuration are embedded and signed correctly.
- [ ] Verify app bundle has no accidental secrets or debug endpoints.
- [ ] Sign with the correct Developer ID and hardened runtime settings.
- [ ] Notarize, staple and verify the exact release artifacts.
- [ ] Test DMG installation on a clean account with Gatekeeper enabled.
- [ ] Test update from the previous stable version.
- [ ] Publish checksum, privacy details, minimum OS and release notes.

---

## 19. Acceptance criteria for version 1.0

Version 1.0 is release-ready only when all required acceptance criteria pass.

### 19.1 Task workflows

- A user can create, edit, complete, reopen, search, filter and delete tasks without signing in.
- Tasks survive restart and force-quit stress tests.
- Today, Inbox, Upcoming, Projects and All Tasks produce consistent results from the same database records.
- Due dates and recurrence behave predictably across timezones and daylight-saving transitions.
- JSON export and re-import restore supported task metadata without silent data loss.
- Destructive actions have an undo or clearly defined recovery path.

### 19.2 Dashboard

- CPU, memory, storage, battery, network, app/process and system-information pages have an explicit availability state.
- Every visible metric has a defined unit, timestamp/refresh state and documented calculation/source.
- At least CPU, memory, storage, battery where hardware supports it, and network where supported are verified on the release test matrix.
- Missing permissions, unsupported hardware, or inaccessible metrics do not crash the app or block tasks.
- The UI does not display fake sample readings outside preview/demo mode.
- The menu-bar-only mode remains responsive and usable after the main window is closed; quitting exits the menu-bar component cleanly.
- Launch at Login is opt-in, visible in Settings, and uses supported user-consented macOS registration APIs; the app neither installs privileged daemons nor attempts to bypass OS approval.
- Sampling pauses/slows according to lifecycle policy, and the app has no unnecessary root/privileged background component.
- The same universal release correctly adapts to representative base-tier and high-end MacBook configurations without model-specific UI builds.
- The Hardware & Capabilities page lists every defined category and its state; it distinguishes true absence from missing API support, OS restrictions, permissions, temporary failure and an unsuccessful probe.
- Every displayed hardware/system value has a verified provider, unit, timestamp where relevant, and documented source/calculation. A missing value is never displayed as zero or replaced by a marketing-spec estimate.
- Hot-plug/display/network/storage/power events update the affected inventory without restarting the app; a single provider failure does not break other categories or task functionality.
- Tests cover multiple Apple Silicon tiers and Intel where included in the support matrix, and the user-facing minimum OS support statement matches the tested release matrix.

### 19.3 UI and accessibility

- All core screens work in light and dark appearance.
- Task operations are accessible by keyboard and VoiceOver.
- Charts have textual summaries and do not rely only on color.
- Window resizing does not hide critical controls or clip charts.
- Empty, error, stale and unavailable states are polished and understandable.

### 19.4 Widgets and always-available experience

- Task Manager includes a signed WidgetKit extension and exposes its widgets in the macOS widget gallery on every supported OS version where WidgetKit is available.
- Available widget sizes/families are adapted to the actual OS; desktop placement is not promised on OS releases that support Notification Center widgets but not desktop widgets.
- Tapping the widget body opens or activates the real Task Manager app and navigates to the relevant Today, Inbox, Project, Capture or dashboard destination via validated deep links.
- A widget continues to render a safe last-known snapshot when the main app is not running or the Mac is offline.
- Widget timeline updates are treated as system-scheduled and opportunistic. No acceptance test or marketing promise requires an exact refresh time or real-time CPU/RAM/network values.
- Widget data is stored/shared only through a versioned App Group contract, contains the minimum data required, and never includes task notes unless explicitly justified by user configuration.
- Main-app task changes trigger targeted widget invalidation; widget reloads are not triggered on every live metric sample.
- If optional widget buttons alter task state, actions are idempotent, transaction-safe, testable when the app is not running, and have documented recovery/undo behavior.
- Menu-bar quick access is available by default after the first launch and can be disabled in Settings. Launch at Login is opt-in, and the app never silently registers startup behavior.
- With the main window closed and menu-bar mode enabled, the app has no sustained high-frequency metrics sampling, no busy polling loop, and no unnecessary privileged background process.
- The user can find and invoke Quit Task Manager, and after quitting the app process/menu-bar entry exits cleanly.

### 19.5 Distribution

- A user needs no package manager, terminal, runtime installation, or developer tool.
- Download is a universal, signed, notarized DMG with a clear Applications shortcut.
- Gatekeeper accepts the delivered signed/notarized artifact under normal security settings.
- No consumer step asks users to bypass Gatekeeper or change security settings manually.
- The optional PKG, if shipped, is signed/notarized and does not install privileged helper services.
- Upgrade preserves user data and can recover from interrupted migration/update.

### 19.6 Performance and privacy

- Performance targets are measured and reportable in CI or release qualification.
- The dashboard does not continuously sample at a high rate while hidden.
- Task and metric history stays local unless a clearly defined, separately consented future feature says otherwise.
- Logs and diagnostics do not contain private task text or process information by default.
- Dependency licenses and third-party notices are included.

---

## 20. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Some OS metrics are not exposed consistently | Dashboard appears incomplete on some Macs | Runtime capability registry; all categories remain discoverable with truthful states; no fake fallback values |
| Model-specific assumptions leak into UI | Incorrect claims on base or Pro/Max MacBooks | Probe real capabilities; model names may label but never determine live values; cross-tier fixture and hardware tests |
| A hardware probe mistakes failure for absence | False inventory claims | Typed capability states, independent provider failure handling, provenance and retry path |
| Private API dependency breaks after macOS update | App instability or rejection | Use documented APIs; provider-level tests; exclude unofficial sensor readings from v1 |
| DMG install is not literally one-click | User expectation mismatch | Describe drag-to-Applications accurately; offer signed PKG or Mac App Store later |
| Intel support increases test burden | Build/release regressions | Universal-binary CI and hardware test matrix; publish minimum support clearly |
| Overly frequent polling drains battery | Poor MacBook experience | Visibility-aware sampling, bounded buffers, Instruments energy profiling |
| Charts create a visual overload | Reduced usability | Prioritize Today and a concise dashboard overview; allow detail-on-demand |
| Local database migration fails | Potential loss of user tasks | Backups, transactional migrations, recovery tests and export support |
| Updater compromise or tampered release | Security risk | HTTPS, EdDSA and code-signature validation, notarization, protected signing keys |
| Widget appears stale or refresh is delayed | User distrust / incorrect interpretation | Display data age, use WidgetKit timelines and invalidation, never promise exact cadence or real-time metrics |
| Widget/app shared data becomes inconsistent | Wrong task state or data corruption | Versioned App Group snapshots, one authoritative database writer, atomic replacement, transaction-safe intents and recovery tests |
| Always-on mode drains battery | Poor MacBook experience | Menu-bar-only idle budgets, visibility-aware sampling, opt-in startup and Instruments energy qualification |
| Login item is surprising or disabled by user | App seems unavailable | Explicit opt-in, clear Settings status, no attempt to override macOS controls, graceful manual launch fallback |
| App name is too generic or unavailable | Discoverability/legal ambiguity | Verify app name, bundle ID, domain, and trademark/marketplace availability before launch |
| App Store sandbox prevents desired metrics | Feature discrepancy between releases | Treat App Store as a separate compliance target and validate providers early |

---

## 21. Implementation roadmap

### Phase 0 — Feasibility and technical spikes

Deliverables:
- Confirm macOS 13 deployment viability with current Xcode/SDK.
- Build a tiny native app and validate universal linking.
- Prototype CPU/memory, storage, battery, network and process providers using documented APIs.
- Record field-by-field availability on base-tier and Pro/Max-tier Apple Silicon models and Intel test machines where Intel is supported.
- Design the capability-status contract and representative profile fixtures before building dashboard UI.
- Verify notification, WidgetKit/widget-family availability, app-group sharing, deep-link, App Intent and optional global-hotkey behavior.
- Prototype Swift Charts, accessibility summaries and live chart update cadence.
- Prototype a WidgetKit widget with stale data and a MenuBarExtra-only lifecycle; measure memory, wakeups and energy on battery.
- Build a signed local test DMG and notarization proof of concept.

**Exit gate:** no baseline dependency on private APIs or administrator privileges; minimum supported OS decided; distribution path proven.

### Phase 1 — Foundation and design system

Deliverables:
- Xcode project, application shell and navigation.
- Theme, typography, layout grid, reusable components and accessibility tokens.
- SQLite database, repository layer, migrations, backup strategy and logging.
- Settings persistence and first-launch flow.

**Exit gate:** stable shell, database recovery tests pass, all screens have empty/error states defined.

### Phase 2 — Task manager MVP

Deliverables:
- Tasks CRUD, Inbox, Today, All Tasks, projects, sections, tags, priority, due dates, filtering and sorting.
- Search and keyboard shortcuts.
- Completion, undo, archive/delete behavior.
- JSON/CSV export and JSON import validation.

**Exit gate:** core task workflows work offline and survive restart; seeded search/list performance targets are met or deviations documented.

### Phase 3 — Native dashboard

Deliverables:
- Metric-sample quality model, `DeviceProfileService`, `CapabilityRegistry`, and sampling coordinator.
- Full Hardware & Capabilities inventory with explicit absent/unsupported/restricted/not-exposed states.
- CPU/memory, storage, battery, network, process, and device overview pages.
- Native chart cards, detailed charts, stale/unavailable states and lifecycle-aware sampling.
- Optional metric history and retention controls.

**Exit gate:** providers verified on the supported hardware/OS matrix; all required capability states are tested; no stale/fake data presentation; cross-tier profile fixtures pass; idle/energy performance meets agreed targets.

### Phase 4 — Widgets, always-available access, reminders and refinement

Deliverables:
- WidgetKit extension with Today Tasks, Daily Progress, Project Focus and optional Mac Snapshot layouts.
- App Group snapshot contract, versioned widget data, refresh invalidation and deep-link routing.
- Menu-bar quick capture and Today summary; optional launch at login using supported macOS service APIs; clear quit and close-window behavior.
- Local notifications and recurrence scheduling.
- Productivity insights and activity heatmap.
- Light/dark polish, keyboard-only flows, VoiceOver review, Reduce Motion support.
- Window resizing, full-screen and multi-display validation.

**Exit gate:** accessibility and UX test review complete; notification-denied path remains fully usable; widgets open the main app to the intended destination; the menu-bar-only idle profile meets CPU/memory/energy targets; widget data can be stale without being misrepresented.

### Phase 5 — Packaging, release and updates

Deliverables:
- Universal signed build.
- Notarized/stapled DMG with Applications alias.
- Optional signed/notarized PKG decision.
- Secure update framework and release channel.
- CI release workflow, checksums, privacy documentation and third-party notices.

**Exit gate:** the exact downloadable artifact passes clean-machine install, first launch, update, uninstall/removal guidance, and Gatekeeper validation.

### Phase 6 — Post-release candidates

Prioritize only from user feedback and measurable gaps:
- Widget layouts/families beyond the core small/medium/large set, if supported by the minimum OS.
- Apple Reminders import/export or calendar integration.
- Optional iCloud sync with conflict policy and explicit data model.
- Focus sessions, carefully labelled effort metrics, and more personal insight views.
- App Store channel if entitlement and sandbox testing proves equivalent required functionality.

---

## 22. Product analytics and success metrics

No behavioral analytics should be enabled in v1 by default. Product success can be measured through opt-in surveys, issue reports, public feedback, crash reports explicitly enabled through release infrastructure where appropriate, and aggregate non-identifying release metrics only if implemented transparently.

Qualitative and opt-in success indicators:
- Users can capture a task in seconds without navigating multiple screens.
- Users understand Today, Inbox, and Upcoming without documentation.
- The Mac dashboard helps users understand device state without presenting ambiguous numbers.
- Users can install and update without a package manager or manual security bypass.
- App remains responsive and quiet during prolonged idle periods.
- Users trust the product because privacy claims are simple and verifiable.

Avoid engagement metrics that encourage unnecessary checking of system utilization or guilt-driven productivity streaks.

---

## 23. Documentation to ship with the product

- `README.md`: product overview, support matrix, build for contributors and report issues.
- `PRIVACY.md`: what stays on-device, what permissions are used, what is not collected.
- `RELEASE.md`: internal signing, notarization, artifact verification and rollback procedure.
- `THIRD_PARTY_NOTICES.md`: dependency versions and licenses.
- In-app Help: metric definitions, refresh behavior, capability caveats, task backup/export and install/update guidance.
- Download page: minimum macOS version, Intel/Apple Silicon support, signed/notarized status, file checksum, release notes and support contact.

---

## 24. Decision log

| Decision | Baseline | Rationale | Revisit when |
|---|---|---|---|
| Product platform | Native macOS only | Best fit for Mac-first UX and OS integrations | Cross-platform is formally prioritized |
| UI framework | SwiftUI + AppKit where necessary | Native controls, accessibility and integration | Prototype exposes a specific limitation |
| Language | Swift | Native ecosystem and system APIs | No planned change |
| Charts | Swift Charts + SwiftUI Canvas | Native chart semantics and lightweight custom marks | Profiling proves a gap in a specific visualization |
| Storage | System SQLite with typed repository layer | Local, efficient, migratable and no server | A compelling migration/relational need emerges |
| Task data | Local-first, no account | Privacy and ease of use | A separately specified sync feature is approved |
| Dashboard process | In-process, unprivileged | Avoids helper installation, privilege and support burden | A truly essential feature cannot work otherwise and security review approves it |
| Widgets | WidgetKit extension with versioned App Group snapshot | Native macOS widget experience, low wakeups and no always-running widget process | Platform constraints change or profiling identifies a justified alternative |
| Always-available access | Optional MenuBarExtra + opt-in `SMAppService` login item | Quick access without keeping the full dashboard active | User research or OS compatibility evidence requires a change |
| Hardware detection | Runtime capability registry with per-field status/provenance | Correct behavior across MacBook tiers and OS versions; no SKU assumptions | Provider tests prove a better documented approach |
| Distribution | Developer ID signed/notarized universal DMG | Straightforward direct download, no runtime installation | Store distribution or installer preference is validated |
| Installer | DMG primary; PKG optional | Standard drag-to-Applications flow without privilege | User testing strongly favors a guided installer |
| Updates | Sparkle 2 or audited equivalent | Secure macOS update pathway without manual re-download | Framework maintenance/security review changes recommendation |
| History | Bounded, opt-in local rollups | Avoid indefinite collection and disk writes | Users request longer history with clear retention semantics |
| Telemetry | None by default | Privacy-first product | Product requires explicit, disclosed opt-in diagnostics |

---

## 25. Official references and implementation resources

The following references inform platform distribution, interface conventions, charts, application inventory and updates. Before implementation or release, engineers should re-check current documentation and API availability for the selected minimum macOS version.

1. Apple — [Distributing software on macOS](https://developer.apple.com/macos/distribution)
2. Apple — [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
3. Apple — [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
4. Apple — [Packaging Mac software for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
5. Apple — [Distribution technology overview](https://developer.apple.com/documentation/technologyoverviews/distribution)
6. Apple — [Swift Charts](https://developer.apple.com/documentation/Charts)
7. Apple — [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
8. Apple — [Sidebars Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/sidebars)
9. Apple — [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace)
10. Apple — [NSWorkspace running applications](https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications)
11. Sparkle — [Secure macOS software update framework](https://github.com/sparkle-project/Sparkle)
12. Apple — [IOPSGetPowerSourceDescription](https://developer.apple.com/documentation/iokit/1523867-iopsgetpowersourcedescription) (power-source dictionaries may omit fields)
13. Apple — [IOPSCopyPowerSourcesInfo](https://developer.apple.com/documentation/iokit/1523839-iopscopypowersourcesinfo)
14. Apple — [Porting macOS apps to Apple silicon](https://developer.apple.com/documentation/apple-silicon/porting-your-macos-apps-to-apple-silicon)
15. Apple — [Building a universal macOS binary](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
16. Apple — [MTLDevice](https://developer.apple.com/documentation/metal/mtldevice) (GPU device properties; confirm the specific property and availability for each OS target)
17. Apple — [ProcessInfo](https://developer.apple.com/documentation/foundation/processinfo) (runtime/system process information)
18. Apple — [WidgetKit](https://developer.apple.com/documentation/widgetkit) (native system-managed widgets)
19. Apple — [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) (timeline and reload behavior; timing is controlled by the system)
20. Apple — [Linking to specific app scenes from your widget](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity) (widget deep links into the host application)
21. Apple — [Adding interactivity to widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities) (App Intents for widget actions)
22. Apple — [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) (login items and app-contained services on macOS 13 and later)

---

## 26. Final architecture recommendation

Build **Task Manager** as a native SwiftUI/Swift application, using Swift Charts for analytic visuals, SQLite for local task data and optional metric rollups, documented Apple APIs for system information, WidgetKit for native macOS widgets, an optional MenuBarExtra with opt-in launch at login for always-available access, local notifications for reminders, and a secure updater for releases. Begin with an offline-first task manager and a verified system-metric provider layer. In parallel, implement the runtime hardware capability registry before polishing detailed dashboard cards; it is the contract that lets the same app represent base-tier and high-end MacBooks accurately. Add detailed system views only when their source, accuracy, access constraints, battery cost and privacy behavior have been validated.

Ship a universal app inside a Developer ID-signed and Apple-notarized DMG. The end-user experience must not depend on package managers, command-line steps, external runtimes or a privileged system service. The actual distribution package—not just the development build—must be tested from download through installation, first launch, widget registration/deep linking, menu-bar-only idle operation, opt-in launch-at-login and update. Widget refresh timing must follow WidgetKit policy and should never be represented as real-time telemetry.

**Definition of done:** a user on a supported Mac can download Task Manager, install it through a familiar Finder interaction, open it without manually bypassing Gatekeeper, manage tasks fully offline, inspect verified device information, add native Task Manager widgets, tap a widget to open the correct app screen, optionally keep quick access through the menu bar/launch at login, and receive app updates without installing developer tools. The always-available mode remains quiet and energy-efficient, and widget data is clearly marked when it may be stale.
