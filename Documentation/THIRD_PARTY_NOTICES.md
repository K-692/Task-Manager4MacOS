# Third-Party Notices & Dependency Audit

**Product:** Task Manager for macOS  
**Philosophy:** Zero Unnecessary Dependencies.  

Task Manager is crafted natively using Apple Swift and macOS system frameworks:
- **SwiftUI**: Declarative native user interface composition.
- **AppKit**: System workspace integration, menu-bar lifecycle, and window management.
- **Swift Charts**: Accessible, high-performance data visualizations.
- **libsqlite3**: Embedded SQLite engine provided natively by the macOS operating system (`/usr/lib/libsqlite3.dylib`).
- **IOKit & Darwin**: Direct Mach host kernel calls, sysctl interfaces, and power-source telemetry.
- **ServiceManagement**: Documented `SMAppService` for user-controlled launch at login.

**External Network Dependencies:** None.  
**Remote SDKs:** None.  
**Third-Party Binary Bundles:** None.
