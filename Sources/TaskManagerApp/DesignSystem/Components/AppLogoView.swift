import SwiftUI
import AppKit

/// Resilient Application Logo view that safely loads the icon from application bundle resources
/// or falls back to system symbol, completely avoiding SwiftPM Bundle.module assertion failures.
public struct AppLogoView: View {
    public init() {}

    public var body: some View {
        if let nsImage = Self.loadLogoImage() {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "cpu.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.indigo)
        }
    }

    /// Resolves the app logo image safely across all runtime environments without throwing fatal errors.
    public static func loadLogoImage() -> NSImage? {
        // 1. Try AppKit's standard application icon (configured in Info.plist / AppIcon.icns)
        if let icon = NSImage(named: NSImage.applicationIconName), icon.isValid {
            return icon
        }

        // 2. Try loading AppIcon by standard asset name
        if let icon = NSImage(named: "AppIcon"), icon.isValid {
            return icon
        }

        // 3. Try standard macOS app bundle resources (Contents/Resources/icon.png)
        if let url = Bundle.main.url(forResource: "icon", withExtension: "png"),
           let img = NSImage(contentsOf: url), img.isValid {
            return img
        }

        // 4. Try standard macOS app bundle resources (Contents/Resources/AppIcon.icns)
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url), img.isValid {
            return img
        }

        // 5. Check if any SPM bundle directory exists in main bundle or resources
        let candidateBundleURLs = [
            Bundle.main.resourceURL?.appendingPathComponent("TaskManager_TaskManagerApp.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("TaskManager_TaskManagerApp.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/TaskManager_TaskManagerApp.bundle")
        ]
        for candidateURL in candidateBundleURLs {
            if let candidateURL = candidateURL,
               FileManager.default.fileExists(atPath: candidateURL.path),
               let subBundle = Bundle(url: candidateURL),
               let iconURL = subBundle.url(forResource: "icon", withExtension: "png"),
               let img = NSImage(contentsOf: iconURL), img.isValid {
                return img
            }
        }

        // 6. Development fallbacks (when running via swift run from repository root)
        let devPaths = [
            "icon/icon.png",
            "Sources/TaskManagerApp/Resources/icon.png"
        ]
        for path in devPaths {
            if FileManager.default.fileExists(atPath: path),
               let img = NSImage(contentsOfFile: path), img.isValid {
                return img
            }
        }

        return nil
    }
}
