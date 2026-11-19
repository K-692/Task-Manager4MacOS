import SwiftUI
import TaskManagerCore
import ServiceManagement

/// Startup Apps view: Windows Task Manager style startup management view.
public struct StartupAppsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var launchAtLogin: Bool = false
    @State private var errorMessage: String? = nil

    public init() {}

    public var body: some View {
        DetailPage {
                DetailHeader(
                    icon: "bolt.fill",
                    tint: .amber,
                    title: "Startup Apps",
                    subtitle: "Manage background startup services and login items."
                )

                // Task Manager Login Item Card
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.amber)
                                .font(.system(size: 18))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Task Manager")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("com.k692.TaskManager • SMAppService")
                                    .font(.caption)
                                    .themedSecondary()
                            }

                            Spacer()

                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .onChange(of: launchAtLogin) { newValue in
                                    do {
                                        try env.loginItemService.setLaunchAtLogin(enabled: newValue)
                                        env.launchAtLogin = newValue
                                    } catch {
                                        errorMessage = "Failed to update startup configuration: \(error.localizedDescription)"
                                        launchAtLogin = env.loginItemService.isEnabled
                                    }
                                }
                        }

                        Divider()

                        HStack {
                            Text("Startup Impact")
                                .font(.caption.bold())
                                .themedSecondary()
                            Spacer()
                            Text("Low (< 0.2s)")
                                .font(.caption.monospaced())
                                .foregroundColor(.emerald)
                        }

                        HStack {
                            Text("Status")
                                .font(.caption.bold())
                                .themedSecondary()
                            Spacer()
                            Text(launchAtLogin ? "Enabled" : "Disabled")
                                .font(.caption.bold())
                                .foregroundColor(launchAtLogin ? .emerald : .secondary)
                        }
                    }
                }

                // Informational Card
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.indigo)
                            Text("System Login Items & LaunchDaemons")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        Text("To manage third-party system-wide login items and background launch daemons, visit System Settings > General > Login Items.")
                            .font(.caption)
                            .themedSecondary()

                        Button(action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Open macOS Login Items Settings", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.rose)
                        }
        }
        .onAppear {
            launchAtLogin = env.loginItemService.isEnabled
        }
    }
}
