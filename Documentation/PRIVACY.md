# Privacy & Data Handling Specification

**Product:** Task Manager for macOS  
**Version:** 1.0.0  
**Status:** Authoritative  

## 1. Guiding Principles

Task Manager is built from the ground up on a **local-first, zero-surveillance** architecture:

1. **No Cloud Account Required:** All capabilities, from task planning to hardware diagnostics, run 100% offline.
2. **Local Data Residence:** Task entries, notes, project associations, tags, reminders, and historical metric rollups reside exclusively on your Mac in an embedded SQLite database (`~/Library/Application Support/TaskManager/taskmanager.sqlite`).
3. **No Telemetry by Default:** The application contains zero third-party analytics SDKs, zero crash tracking trackers, zero marketing beacons, and zero telemetry pings.
4. **Zero Intrusive Sensor Activation:** The Hardware & Capabilities inspection does not activate cameras, microphones, or audio recording hardware.
5. **No Whole-Disk Crawling:** Storage diagnostics read mounted volume resource values via public `NSURLResourceKey` attributes. It never walks personal folders or reads file contents.

---

## 2. macOS Permissions & OS APIs

Task Manager operates strictly within standard user-space privileges without requiring root, kernel extensions (`KEXTs`), or background daemons:

| Feature | macOS API / Framework | Permission Required | Purpose |
|---|---|---|---|
| Task & Data Storage | SQLite3 C API | Standard User Sandbox | Persisting tasks, projects, tags, and settings |
| CPU Load & Cores | Mach `host_statistics` / `sysctl` | None (Public System Call) | Computing accurate user/system/idle CPU load deltas |
| Memory Accounting | Mach `host_statistics64` | None (Public System Call) | Reading VM active, wired, compressed, and free pages |
| Storage Volumes | `FileManager.mountedVolumeURLs` | None (Standard File Access) | Checking free space and filesystem format on mounted drives |
| Battery & Power | IOKit Power Sources (`IOPSCopyPowerSourcesInfo`) | None (Public IOKit Interface) | Reading charge %, charging state, and cycle count |
| Network Throughput | `getifaddrs` / `if_data` | None (Public BSD API) | Measuring byte delta throughput (B/s, KB/s, MB/s) |
| Running Apps | `NSWorkspace.runningApplications` | None (Public AppKit Interface) | Displaying user-visible apps and PID |
| Process Memory | `libproc` (`proc_pidinfo`) | Standard User Permission | Reading inspectable resident memory |
| GPU Discovery | Metal (`MTLCopyAllDevices`) | None (Public Metal API) | Enumerating connected GPU hardware devices |
| Display Details | AppKit (`NSScreen.screens`) | None (Public AppKit API) | Reading screen resolutions and display scales |
| Reminders | `UserNotifications` | Optional User Prompt | Scheduling local calendar reminder notifications |
| Launch at Login | `SMAppService` | Optional User Prompt | Starting quietly in the menu bar on system boot |

---

## 3. Data Deletion & Backup

Task Manager gives users absolute control over their data:
- **Full JSON Export:** Export all tasks, projects, sections, and tags in an open, documented JSON schema.
- **CSV Export:** Export all tasks into standard CSV format for spreadsheet interoperability.
- **Clear Metric History:** Flush all historical telemetry rollups independently without touching tasks.
- **Factory Reset:** Completely erase local SQLite database records on demand with explicit confirmation.
