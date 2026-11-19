import SwiftUI
import TaskManagerCore

/// Settings view: responsive, scrollable configuration panel.
public struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var updateSpeed: Double = 1.0

    public init() {}

    public var body: some View {
        DetailPage {
            DetailHeader(
                icon: "gearshape.fill",
                tint: .slate,
                title: "Settings",
                subtitle: "Menu bar widget, background behavior, telemetry cadence and appearance."
            )

            // 1. Menu Bar Widget
            SectionCard("Menu Bar Widget", icon: "menubar.rectangle", tint: .indigo, accessory: {
                PillTag(env.showMenuBarIcon ? "ON" : "OFF", tint: env.showMenuBarIcon ? .emerald : .secondary)
            }) {
                settingRow(
                    title: "Show in menu bar",
                    detail: "Show the live metric in the macOS menu bar. When off, Task Manager keeps running in the background and stays in the Dock so you can reopen it."
                ) {
                    Toggle("", isOn: $env.showMenuBarIcon)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                settingRow(
                    title: "Rotate metrics every 2 seconds",
                    detail: "Cycle CPU → GPU → Memory → Storage → Network in the menu bar. Turn off to always show the metric selected below."
                ) {
                    Toggle("", isOn: $env.rotateMenuBarMetrics)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                settingRow(
                    title: "Colour by usage",
                    detail: "Shade the icon and value continuously from green to red, brightened automatically for a dark or light menu bar. CPU, GPU, Memory, Storage: green at low use, red at high use. Network: green at 1 MB/s or more, red at 400 KB/s or less. Off: plain white (or black on a light menu bar)."
                ) {
                    Toggle("", isOn: $env.menuBarUsageColors)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                Divider()

                Text(env.rotateMenuBarMetrics
                     ? "Rotation starts from the metric selected below."
                     : "Choose the metric shown next to the Task Manager icon in the macOS menu bar.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                    menuBarRadioChip(metric: .cpu, color: .indigo,
                                     currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestCPU?.value?.totalUsagePercent ?? 0))
                    menuBarRadioChip(metric: .gpu, color: .purple,
                                     currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestGPU?.value?.utilizationPercent ?? 0))
                    menuBarRadioChip(metric: .memory, color: .blue,
                                     currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestMemory?.value?.usagePercentage ?? 0))
                    menuBarRadioChip(metric: .disk, color: .emerald,
                                     currentVal: String(format: "%.0f%%", env.samplingCoordinator.latestStorage?.value?.first?.usagePercentage ?? 0))
                    menuBarRadioChip(metric: .network, color: .cyan,
                                     currentVal: formatCompactRate((env.samplingCoordinator.latestNetwork?.value?.totalBytesInPerSecond ?? 0) + (env.samplingCoordinator.latestNetwork?.value?.totalBytesOutPerSecond ?? 0)))
                }

                HStack(spacing: 8) {
                    Text("Preview")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    // Mimics the real menu bar background so the colour preview is accurate.
                    HStack(spacing: 4) {
                        Image(systemName: env.displayedMenuBarMetric.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(valueForMetric(env.displayedMenuBarMetric))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(previewTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(env.menuBarIsDark ? Color(white: 0.16) : Color(white: 0.93))
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                    Spacer(minLength: 0)
                }
                }
                .disabled(!env.showMenuBarIcon)
                .opacity(env.showMenuBarIcon ? 1 : 0.45)
            }

            // 2. Background behavior
            SectionCard("Background & Startup", icon: "power", tint: .emerald) {
                VStack(spacing: 12) {
                    settingRow(
                        title: "Stay running in the menu bar",
                        detail: "Closing the window never quits Task Manager. It keeps monitoring from the menu bar until you choose Quit (⌘Q)."
                    ) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.emerald)
                            .help("Always enabled")
                    }

                    Divider()

                    settingRow(
                        title: "Hide Dock icon when window is closed",
                        detail: "Run as a pure menu bar utility while the main window is closed."
                    ) {
                        Toggle("", isOn: $env.hideDockIconWhenClosed)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }

                    Divider()

                    settingRow(
                        title: "Launch at login",
                        detail: "Start Task Manager automatically so the menu bar widget is always available."
                    ) {
                        Toggle("", isOn: $env.launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: env.launchAtLogin) { val in
                                try? env.loginItemService.setLaunchAtLogin(enabled: val)
                            }
                    }
                }
            }

            // 3. Telemetry cadence + 4. Theme side by side when there is room
            AdaptiveGrid(minimum: 320) {
                SectionCard("Sample Rate", icon: "timer", tint: .amber, accessory: {
                    Text(formattedInterval(updateSpeed))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }) {
                    Text("Refresh rate for CPU, GPU, memory, disk and network monitors.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 2) {
                        cadenceButton(label: "0.5s", tag: "Fast", interval: 0.5)
                        cadenceButton(label: "1s", tag: "Normal", interval: 1.0)
                        cadenceButton(label: "3s", tag: "Eco", interval: 3.0)
                        cadenceButton(label: "Pause", tag: "", interval: 0.0)
                    }
                    .padding(2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }

                SectionCard("Appearance", icon: "circle.lefthalf.filled", tint: .purple) {
                    Text(env.visualTheme.isPublication
                         ? "The Publication theme always uses a white background."
                         : "Match macOS or force light or dark mode.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 2) {
                        themeButton(label: "System", icon: "circle.lefthalf.filled", mode: "system")
                        themeButton(label: "Light", icon: "sun.max.fill", mode: "light")
                        themeButton(label: "Dark", icon: "moon.fill", mode: "dark")
                    }
                    .padding(2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .disabled(env.visualTheme.isPublication)
                    .opacity(env.visualTheme.isPublication ? 0.45 : 1)
                }
            }

            // 4b. Visual theme (standard vs. paper-ready)
            SectionCard("Theme", icon: "doc.richtext", tint: .indigo, accessory: {
                PillTag(env.visualTheme.title.uppercased(), tint: .indigo)
            }) {
                Text("Publication gives a minimal, paper-ready look for screenshots and figures: white background, serif text, colour-blind-safe lines and the markings you choose below. The dashboard's Capture button uses the current theme.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(VisualTheme.allCases, id: \.self) { option in
                        themeOption(option)
                    }
                }
            }

            // 4c. Publication markings
            if env.visualTheme.isPublication {
                publicationMarkingsCard
            }

            // 5. About
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        AppLogoView()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Task Manager for macOS")
                                .font(.system(size: 13, weight: .bold))
                            Text("Version \(appVersion) • Native Swift • MIT License")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 4)
                        PillTag("NO TELEMETRY", tint: .emerald)
                    }

                    Divider()

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)], alignment: .leading, spacing: 6) {
                        SpecRow("Device Model", env.deviceProfile.marketingName)
                        SpecRow("Architecture", env.deviceProfile.architecture)
                        SpecRow("Processor", "\(env.deviceProfile.cpuName) (\(env.deviceProfile.physicalCores)C)")
                        SpecRow("Installed RAM", env.deviceProfile.formattedMemory)
                        SpecRow("Graphics", env.deviceProfile.gpuNames.first ?? "Apple Silicon GPU")
                        SpecRow("macOS", env.deviceProfile.osVersion.replacingOccurrences(of: "Version ", with: ""))
                    }
                }
            }

            HStack {
                Spacer()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit Task Manager", systemImage: "power")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .onAppear {
            updateSpeed = env.samplingCoordinator.samplingInterval
        }
    }

    /// Colour of the menu bar preview, matching what the real status item draws.
    private var previewTint: Color {
        let dark = env.menuBarIsDark
        guard env.menuBarUsageColors else { return dark ? .white : .black }
        let s = env.samplingCoordinator
        switch env.displayedMenuBarMetric {
        case .cpu: return UsageColor.menuBarColor(s.latestCPU?.value?.totalUsagePercent ?? 0, scale: .percent, darkMenuBar: dark)
        case .gpu: return UsageColor.menuBarColor(s.latestGPU?.value?.utilizationPercent ?? 0, scale: .percent, darkMenuBar: dark)
        case .memory: return UsageColor.menuBarColor(s.latestMemory?.value?.usagePercentage ?? 0, scale: .percent, darkMenuBar: dark)
        case .disk: return UsageColor.menuBarColor(s.latestStorage?.value?.first?.usagePercentage ?? 0, scale: .percent, darkMenuBar: dark)
        case .network:
            let n = s.latestNetwork?.value
            return UsageColor.menuBarColor((n?.totalBytesInPerSecond ?? 0) + (n?.totalBytesOutPerSecond ?? 0), scale: .network, darkMenuBar: dark)
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.4.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "7"
        return "\(short) (\(build))"
    }

    // MARK: - Publication markings

    private var publicationMarkingsCard: some View {
        SectionCard("Publication Markings", icon: "ruler", tint: .indigo, accessory: {
            HStack(spacing: 4) {
                presetButton("Minimal", .minimal)
                presetButton("Default", .standard)
                presetButton("All", .all)
            }
        }) {
            // Live preview using the real CPU history and the current colour settings.
            TelemetryChart(
                series: [ChartSeries(name: "CPU", values: env.samplingCoordinator.cpuHistory.values.isEmpty ? [0, 0] : env.samplingCoordinator.cpuHistory.values,
                                     color: TelemetryKind.cpu.publicationColor)],
                yDomain: 0...100,
                unit: "Utilization (%)"
            )
            .environment(\.visualTheme, .publication)
            .environment(\.publicationMarkings, env.publicationMarkings)
            .frame(height: 190)
            .padding(10)
            .background(Color.white)
            .overlay(Rectangle().strokeBorder(PublicationPalette.axis.opacity(0.3), lineWidth: 0.5))

            // Four compact columns so every option is visible at once (hover a box for details).
            AdaptiveGrid(minimum: 150, maxColumns: 4, spacing: 12) {
                markingGroup("Reference lines") {
                    markToggle("Mean", "Dotted line at the average", \.mean)
                    markToggle("Median", "Dash-dot line at the median", \.median)
                    markToggle("Linear trend", "Least-squares fit over the window", \.trendLine)
                    HStack(spacing: 4) {
                        markToggle("Moving avg", "Trailing average that smooths noise", \.movingAverage)
                        compactStepper(value: binding(\.movingAverageWindow), range: 2...30, step: 1, suffix: "",
                                       enabled: env.publicationMarkings.movingAverage)
                    }
                    HStack(spacing: 4) {
                        markToggle("Threshold", "Fixed level on % charts", \.threshold)
                        compactStepper(value: binding(\.thresholdValue), range: 5...100, step: 5, suffix: "%",
                                       enabled: env.publicationMarkings.threshold)
                    }
                }
                markingGroup("Markers") {
                    markToggle("Peak ▲", "Highest value in the window", \.peak)
                    markToggle("Minimum ◆", "Lowest value in the window", \.minimum)
                    markToggle("Latest ●", "Most recent sample", \.latest)
                    markToggle("Data points", "A dot on every sample", \.dataPoints)
                    markToggle("Value labels", "Print numbers next to markings", \.valueLabels)
                }
                markingGroup("Bands") {
                    markToggle("Mean ± 1σ", "Shaded standard-deviation band", \.stdDevBand)
                    markToggle("Min–max range", "Shaded envelope of the data", \.rangeBand)
                }
                markingGroup("Axes & layout") {
                    markToggle("Gridlines", "Light major gridlines", \.gridlines)
                    markToggle("Axis ticks", "Tick marks on both axes", \.axisTicks)
                    markToggle("Axis titles", "Time (s) and unit labels", \.axisTitles)
                    markToggle("Plot frame", "Box around the plot area", \.plotFrame)
                    markToggle("Legend / key", "Explains lines and markers", \.legend)
                    markToggle("Smooth curves", "Off = straight segments between samples", \.smoothCurves)
                    markToggle("Panel labels", "Prefix captured titles with (a)–(e)", \.panelLabels)
                }
            }

            Text("Captured figures use exactly these settings.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private func compactStepper(value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String, enabled: Bool) -> some View {
        HStack(spacing: 2) {
            Text("\(Int(value.wrappedValue))\(suffix)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(enabled ? .primary : .secondary)
                .frame(minWidth: 26, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .controlSize(.mini)
        }
        .disabled(!enabled)
    }

    private func compactStepper(value: Binding<Int>, range: ClosedRange<Int>, step: Int, suffix: String, enabled: Bool) -> some View {
        compactStepper(
            value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) }),
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step), suffix: suffix, enabled: enabled
        )
    }

    private func binding<T>(_ keyPath: WritableKeyPath<PublicationMarkings, T>) -> Binding<T> {
        Binding(
            get: { env.publicationMarkings[keyPath: keyPath] },
            set: { env.publicationMarkings[keyPath: keyPath] = $0 }
        )
    }

    private func markingGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundColor(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func markToggle(_ title: String, _ detail: String, _ keyPath: WritableKeyPath<PublicationMarkings, Bool>) -> some View {
        Toggle(isOn: binding(keyPath)) {
            Text(title).font(.system(size: 11)).lineLimit(1)
        }
        .toggleStyle(.checkbox)
        .help(detail)
    }

    private func presetButton(_ title: String, _ preset: PublicationMarkings) -> some View {
        Button(title) { env.publicationMarkings = preset }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(env.publicationMarkings == preset ? .indigo : nil)
    }

    private func themeOption(_ option: VisualTheme) -> some View {
        let selected = env.visualTheme == option
        return Button {
            env.visualTheme = option
        } label: {
            HStack(spacing: 12) {
                ThemePreview(theme: option)
                    .frame(width: 92, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(option.subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? .indigo : .secondary.opacity(0.5))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? Color.indigo.opacity(0.10) : Color.primary.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(selected ? Color.indigo.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingRow<Accessory: View>(title: String, detail: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            accessory()
        }
    }

    // MARK: - Menu Bar Radio Chip
    private func menuBarRadioChip(
        metric: MenuBarMetric,
        color: Color,
        currentVal: String
    ) -> some View {
        let isSelected = env.selectedMenuBarMetric == metric
        return Button(action: {
            env.selectedMenuBarMetric = metric
        }) {
            HStack(spacing: 5) {
                Image(systemName: metric.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? color : .secondary)

                VStack(alignment: .leading, spacing: 0) {
                    Text(metric.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    Text(currentVal)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(isSelected ? color : .secondary.opacity(0.8))
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "record.circle.fill" : "circle")
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? color : .secondary.opacity(0.35))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(isSelected ? color.opacity(0.12) : Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cadence Button
    private func cadenceButton(label: String, tag: String, interval: Double) -> some View {
        let isSelected = abs(updateSpeed - interval) < 0.05
        return Button(action: {
            updateSpeed = interval
            env.samplingCoordinator.samplingInterval = interval
        }) {
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                if !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .indigo : .secondary.opacity(0.7))
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isSelected ? Color.primary.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Theme Button
    private func themeButton(label: String, icon: String, mode: String) -> some View {
        let isSelected = env.appearanceMode == mode
        return Button(action: {
            env.appearanceMode = mode
            try? env.settingsRepo.set(key: "appearance", value: mode)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .indigo : .secondary)
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.primary.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func specItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func colorForMetric(_ metric: MenuBarMetric) -> Color {
        switch metric {
        case .cpu: return .indigo
        case .gpu: return .purple
        case .memory: return .blue
        case .disk: return .emerald
        case .network: return .cyan
        }
    }

    private func valueForMetric(_ metric: MenuBarMetric) -> String {
        switch metric {
        case .cpu:
            return "\(Int(env.samplingCoordinator.latestCPU?.value?.totalUsagePercent ?? 0))%"
        case .gpu:
            return "\(Int(env.samplingCoordinator.latestGPU?.value?.utilizationPercent ?? 0))%"
        case .memory:
            return "\(Int(env.samplingCoordinator.latestMemory?.value?.usagePercentage ?? 0))%"
        case .disk:
            return "\(Int(env.samplingCoordinator.latestStorage?.value?.first?.usagePercentage ?? 0))%"
        case .network:
            let rate = (env.samplingCoordinator.latestNetwork?.value?.totalBytesInPerSecond ?? 0) + (env.samplingCoordinator.latestNetwork?.value?.totalBytesOutPerSecond ?? 0)
            return formatCompactRate(rate)
        }
    }

    private func formattedInterval(_ interval: Double) -> String {
        if interval <= 0.05 {
            return "Paused"
        } else {
            return String(format: "%.1fs", interval)
        }
    }

    private func formatCompactRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1fM/s", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0fK/s", bytesPerSec / 1024)
        } else {
            return "0K/s"
        }
    }

}

/// Small static thumbnail illustrating each theme.
private struct ThemePreview: View {
    let theme: VisualTheme

    var body: some View {
        let pub = theme.isPublication
        let line: [CGFloat] = [0.55, 0.4, 0.62, 0.35, 0.5, 0.3, 0.45, 0.25, 0.38]
        ZStack {
            if pub {
                Color.white
            } else {
                LinearGradient(colors: [Color(white: 0.16), Color(white: 0.11)], startPoint: .top, endPoint: .bottom)
            }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                Path { p in
                    for (i, v) in line.enumerated() {
                        let pt = CGPoint(x: w * CGFloat(i) / CGFloat(line.count - 1), y: h * v)
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                }
                .stroke(pub ? PublicationPalette.blue : Color.indigo, lineWidth: 1.5)
                if pub {
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.42))
                        p.addLine(to: CGPoint(x: w, y: h * 0.42))
                    }
                    .stroke(Color.black.opacity(0.7), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
                }
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: pub ? 2 : 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: pub ? 2 : 6, style: .continuous)
                .strokeBorder(pub ? Color.black.opacity(0.6) : Color.white.opacity(0.1), lineWidth: pub ? 0.75 : 1)
        )
    }
}
