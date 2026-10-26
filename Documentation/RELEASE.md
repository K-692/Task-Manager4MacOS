# Release, Signing, & Notarization Workflow

**Product:** Task Manager for macOS  
**Target Matrix:** macOS 13.0+ (Ventura, Sonoma, Sequoia)  
**Binary Architecture:** Universal (`arm64` Apple Silicon + `x86_64` Intel)  

---

## 1. Local Development Build

```bash
# Debug build
swift build

# Run native app
swift run TaskManager

# Run test suite
swift run TaskManagerTestRunner
```

---

## 2. Packaging Release Artifacts

To produce a Universal (`arm64` + `x86_64`) macOS `.app` bundle:
```bash
./Scripts/build-universal.sh
```

To produce a single-architecture host `.app` bundle (for fast local development):
```bash
./Scripts/build-app.sh
```

To produce the compressed, read-only Universal `.dmg` installer with an Applications symlink:
```bash
./Scripts/package-dmg.sh
```
This automatically updates `releases/TaskManager-1.0.0-Universal.dmg` for repository distribution.

---

## 3. Developer ID Code Signing & Apple Notarization

When releasing for public distribution:

### Step 1: Code Signing with Hardened Runtime
```bash
codesign --force --options runtime --deep --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --entitlements TaskManager.entitlements \
    "dist/Task Manager.app"
```

### Step 2: Assemble DMG and Sign
```bash
hdiutil create -volname "Task Manager" -srcfolder "dist/dmg_staging" -ov -format UDZO "dist/TaskManager-1.0.0.dmg"
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" "dist/TaskManager-1.0.0.dmg"
```

### Step 3: Notarization via Apple Notary Service
```bash
xcrun notarytool submit "dist/TaskManager-1.0.0.dmg" \
    --apple-id "your-apple-id@example.com" \
    --team-id "TEAM_ID" \
    --password "app-specific-password" \
    --wait
```

### Step 4: Staple Ticket
```bash
xcrun stapler staple "dist/TaskManager-1.0.0.dmg"
spctl --assess --type open --context context:primary-signature "dist/TaskManager-1.0.0.dmg"
```
