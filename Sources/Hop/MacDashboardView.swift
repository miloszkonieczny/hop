import AppKit
import Darwin
import HopCore
import SwiftUI

/// Compact default surface for the semantic Mac space.
///
/// It summarizes the existing monitor / VPN / speed / awake / keyboard modules
/// and keeps their full legacy views one disclosure away. No metric has a second
/// source of truth here.
struct MacDashboardView: View {
    @ObservedObject var stats: SystemStatsController
    @ObservedObject var speedTest: SpeedTestController
    @ObservedObject var vpn: VPNController
    @ObservedObject var keepAwake: KeepAwakeController
    @ObservedObject var keyboardLock: KeyboardLockController
    @ObservedObject var processes: MacProcessSummaryController

    let visibleModules: Set<String>
    let openModule: (String) -> Void
    let openProtonVPN: () -> Void

    @AppStorage("tempUnit") private var tempUnitRaw = "auto"

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(spacing: 10) {
            header

            if visibleModules.contains("system") {
                LazyVGrid(columns: columns, spacing: 8) {
                    cpuCard
                    memoryCard
                    cpuTemperatureCard
                    gpuTemperatureCard
                    networkCard
                    batteryCard
                    topCPUCard
                    topMemoryCard
                }
            }

            if visibleModules.contains("vpn") || visibleModules.contains("speedtest") {
                LazyVGrid(columns: columns, spacing: 8) {
                    if visibleModules.contains("vpn") {
                        vpnCard
                    }
                    if visibleModules.contains("speedtest") {
                        speedCard
                    }
                }
            }

            if visibleModules.contains("awake")
                || visibleModules.contains("keyboard")
                || visibleModules.contains("torrent")
                || visibleModules.contains("system") {
                controlsRow
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if visibleModules.contains("system") {
                stats.startPolling()
                processes.start()
            }
            if visibleModules.contains("vpn") {
                vpn.panelAppeared()
            }
        }
        .onDisappear {
            stats.stopPolling()
            processes.stop()
            if visibleModules.contains("vpn") {
                vpn.panelDisappeared()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mac at a glance")
                    .font(Theme.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("System health and performance")
                    .font(Theme.mono(8))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if visibleModules.contains("system") {
                HStack(spacing: 5) {
                    Circle()
                        .fill(thermalColor)
                        .frame(width: 6, height: 6)
                    Text(thermalLabel)
                        .font(Theme.mono(8, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(Theme.chipBg, in: Capsule())
            }
        }
    }

    // MARK: - System cards

    private var cpuCard: some View {
        metricCard(
            title: "CPU Usage",
            symbol: "cpu",
            value: StatsFormatting.percent(stats.sample.cpuLoad),
            subtitle: HardwareIdentity.chipName ?? "Processor",
            accent: Theme.accentGreen,
            points: stats.history.cpuLoad.suffix(28).map(\.v),
            maxValue: 1,
            action: { openModule("system") }
        )
    }

    private var memoryCard: some View {
        let pressure = MemoryStrain.fromPressure(stats.sample.memPressure)
        let used = StatsFormatting.gb(stats.sample.memUsed)
        let total = StatsFormatting.gb(stats.sample.memTotal)
        return metricCard(
            title: "Memory Pressure",
            symbol: "memorychip",
            value: memoryPressureLabel(pressure),
            subtitle: "\(used) / \(total) GB",
            accent: memoryColor(pressure),
            points: stats.history.memShare.suffix(28).map(\.v),
            maxValue: 1,
            action: { openModule("system") }
        )
    }

    private var cpuTemperatureCard: some View {
        metricCard(
            title: "CPU Temperature",
            symbol: "thermometer.medium",
            value: temperatureText(stats.sample.cpuTemp),
            subtitle: thermalLabel,
            accent: thermalColor,
            points: stats.history.cpuTemp.suffix(28).map(\.v),
            maxValue: 100,
            action: { openModule("system") }
        )
    }

    private var gpuTemperatureCard: some View {
        let subtitle: String
        if stats.sample.gpuTemp == nil {
            subtitle = stats.sample.gpuLoad == nil ? "Sensor unavailable" : "No dedicated sensor"
        } else {
            subtitle = StatsFormatting.percent(stats.sample.gpuLoad) + " load"
        }
        return metricCard(
            title: "GPU Temperature",
            symbol: "fan",
            value: temperatureText(stats.sample.gpuTemp),
            subtitle: subtitle,
            accent: Theme.accentBlue,
            points: stats.history.gpuTemp.suffix(28).map(\.v),
            maxValue: 100,
            action: { openModule("system") }
        )
    }

    private var networkCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 8) {
                cardHeader("Network", symbol: "wifi", accent: Theme.accentBlue)
                HStack(spacing: 12) {
                    networkValue(
                        symbol: "arrow.up",
                        value: networkMbps(stats.sample.netUp),
                        label: "Upload"
                    )
                    networkValue(
                        symbol: "arrow.down",
                        value: networkMbps(stats.sample.netDown),
                        label: "Download"
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openModule("system") }
        .help("Open full system monitor")
    }

    private var batteryCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 7) {
                cardHeader("Battery", symbol: "battery.100percent", accent: Theme.accentGreen)

                if let battery = stats.sample.battery {
                    HStack(alignment: .firstTextBaseline) {
                        Text(battery.percent.map { "\($0)%" } ?? "—")
                            .font(Theme.mono(20, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                        Spacer()
                        Text(battery.isCharging ? "Charging" : "Discharging")
                            .font(Theme.mono(7, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    HStack(spacing: 8) {
                        if let temp = battery.tempC {
                            Label(temperatureText(temp), systemImage: "thermometer.low")
                        }
                        if let health = battery.healthPercent {
                            Label("\(health)% health", systemImage: "heart")
                        }
                    }
                    .font(Theme.mono(7))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                } else {
                    Text("No battery")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openModule("system") }
        .help("Open full system monitor")
    }

    private var topCPUCard: some View {
        processCard(
            title: "Top CPU Process",
            symbol: "chart.bar.fill",
            entry: processes.summary.topCPU,
            trailing: processes.summary.topCPU.map {
                String(format: "%.1f%%", $0.cpuPercent)
            }
        )
    }

    private var topMemoryCard: some View {
        processCard(
            title: "Top RAM Process",
            symbol: "memorychip.fill",
            entry: processes.summary.topMemory,
            trailing: processes.summary.topMemory.map {
                memoryText($0.memoryBytes)
            }
        )
    }

    // MARK: - VPN / speed

    private var vpnCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 4) {
                    cardHeader("Proton VPN", symbol: "lock.shield", accent: Theme.accentCyan)
                    Button {
                        openModule("vpn")
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(4)
                    .help("Open full VPN module")
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(protonStateColor)
                        .frame(width: 7, height: 7)
                    Text(protonStateText)
                        .font(Theme.mono(9, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }

                Text(protonSubtitle)
                    .font(Theme.mono(7))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)

                Button("Open Proton VPN") {
                    openProtonVPN()
                }
                .font(Theme.mono(8, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(Theme.chipBg, in: RoundedRectangle(cornerRadius: 6))
                .hoverHighlight(6)
            }
        }
    }

    private var speedCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 4) {
                    cardHeader("Internet Speed", symbol: "speedometer", accent: Theme.accentBlue)
                    Button {
                        openModule("speedtest")
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(4)
                    .help("Open full speed-test module")
                }

                HStack(spacing: 10) {
                    speedValue(
                        symbol: "arrow.down",
                        value: speedDownText,
                        label: "Download"
                    )
                    speedValue(
                        symbol: "arrow.up",
                        value: speedUpText,
                        label: "Upload"
                    )
                }

                Button(speedTest.isRunning ? "Testing… \(speedTest.elapsed)s" : "Run Speed Test") {
                    speedTest.run()
                }
                .font(Theme.mono(8, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(Theme.chipBg, in: RoundedRectangle(cornerRadius: 6))
                .hoverHighlight(6)
                .disabled(speedTest.isRunning)
            }
        }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 6) {
            if visibleModules.contains("awake") {
                controlButton(
                    title: keepAwake.isActive ? "Awake On" : "Keep Awake",
                    symbol: keepAwake.isActive ? "moon.fill" : "moon",
                    active: keepAwake.isActive
                ) {
                    openModule("awake")
                }
            }

            if visibleModules.contains("keyboard") {
                controlButton(
                    title: keyboardLock.isLocked ? "Locked" : "Keyboard",
                    symbol: "keyboard",
                    active: keyboardLock.isLocked
                ) {
                    openModule("keyboard")
                }
            }

            if visibleModules.contains("torrent") {
                controlButton(
                    title: "Torrents",
                    symbol: "arrow.down.circle",
                    active: false
                ) {
                    openModule("torrent")
                }
            }

            if visibleModules.contains("system") {
                controlButton(
                    title: "Details",
                    symbol: "gauge.with.dots.needle.50percent",
                    active: false
                ) {
                    openModule("system")
                }
            }
        }
    }

    // MARK: - Shared UI

    private func metricCard(
        title: String,
        symbol: String,
        value: String,
        subtitle: String,
        accent: Color,
        points: [Double],
        maxValue: Double,
        action: @escaping () -> Void
    ) -> some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 6) {
                cardHeader(title, symbol: symbol, accent: accent)
                HStack(alignment: .bottom, spacing: 5) {
                    Text(value)
                        .font(Theme.mono(19, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 4)
                    MiniMetricSparkline(points: points, maxValue: maxValue, accent: accent)
                        .frame(width: 54, height: 24)
                }
                Text(subtitle)
                    .font(Theme.mono(7))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .help("Open full system monitor")
    }

    private func processCard(
        title: String,
        symbol: String,
        entry: ProcessUsageEntry?,
        trailing: String?
    ) -> some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 7) {
                cardHeader(title, symbol: symbol, accent: Theme.accentPurple)
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry?.name ?? "—")
                            .font(Theme.mono(9, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(trailing ?? "No sample yet")
                            .font(Theme.mono(7))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openActivityMonitor() }
        .help("Open Activity Monitor")
    }

    private func dashboardCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(Theme.rowBg, in: RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Theme.divider, lineWidth: 1)
            )
    }

    private func cardHeader(_ title: String, symbol: String, accent: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(accent)
            Text(title)
                .font(Theme.mono(8, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func networkValue(symbol: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accentBlue)
                Text(value)
                    .font(Theme.mono(10, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }
            Text(label)
                .font(Theme.mono(7))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func speedValue(symbol: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.accentBlue)
                Text(value)
                    .font(Theme.mono(9, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Text(label)
                .font(Theme.mono(7))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controlButton(
        title: String,
        symbol: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(Theme.mono(8, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                active ? Theme.chipBg : Theme.rowBg,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Theme.divider, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(7)
    }

    // MARK: - Values

    private var thermalLabel: String {
        switch stats.sample.thermal {
        case .critical: return "Critical"
        case .warning: return "High"
        case .normal: return "Normal"
        case nil: return "Unknown"
        }
    }

    private var thermalColor: Color {
        switch stats.sample.thermal {
        case .critical: return Theme.accentRed
        case .warning: return Theme.accentYellow
        case .normal: return Theme.accentGreen
        case nil: return Theme.textTertiary
        }
    }

    private func memoryPressureLabel(_ level: MemoryStrain.Level) -> String {
        switch level {
        case .critical: return "Critical"
        case .warning: return "Warning"
        case .normal: return "Normal"
        case .unknown: return "Unknown"
        }
    }

    private func memoryColor(_ level: MemoryStrain.Level) -> Color {
        switch level {
        case .critical: return Theme.accentRed
        case .warning: return Theme.accentYellow
        case .normal: return Theme.accentPurple
        case .unknown: return Theme.textTertiary
        }
    }

    private var useFahrenheit: Bool {
        switch tempUnitRaw {
        case "f": return true
        case "c": return false
        default: return Locale.current.measurementSystem == .us
        }
    }

    private func temperatureText(_ celsius: Double?) -> String {
        guard let celsius else { return "—" }
        let shown = useFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(shown.rounded()))°\(useFahrenheit ? "F" : "C")"
    }

    private func temperatureText(_ celsius: Double) -> String {
        temperatureText(Optional(celsius))
    }

    private func networkMbps(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond else { return "—" }
        let mbps = bytesPerSecond * 8 / 1_000_000
        if mbps >= 100 { return "\(Int(mbps.rounded())) Mbps" }
        if mbps >= 10 { return String(format: "%.1f Mbps", mbps) }
        return String(format: "%.2f Mbps", mbps)
    }

    private func memoryText(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return "\(Int((Double(bytes) / 1_048_576).rounded())) MB"
    }

    private var protonConfiguration: VPNConfiguration? {
        vpn.configurations.first { configuration in
            [
                configuration.name,
                configuration.appName ?? "",
                configuration.bundleIdentifier ?? "",
            ].contains { $0.localizedCaseInsensitiveContains("proton") }
        }
    }

    private var protonStateText: String {
        guard let configuration = protonConfiguration else { return "Open app" }
        switch configuration.state {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnecting: return "Disconnecting"
        case .disconnected: return "Disconnected"
        case .unknown: return "Status unknown"
        }
    }

    private var protonStateColor: Color {
        guard let state = protonConfiguration?.state else { return Theme.textTertiary }
        switch state {
        case .connected: return Theme.accentGreen
        case .connecting, .disconnecting: return Theme.accentYellow
        case .disconnected, .unknown: return Theme.textTertiary
        }
    }

    private var protonSubtitle: String {
        if let subtitle = protonConfiguration?.subtitle { return subtitle }
        if protonConfiguration != nil { return "macOS VPN configuration" }
        return "Open Proton VPN app"
    }

    private var speedDownText: String {
        if speedTest.isRunning, let value = speedTest.liveDown {
            return speedNumber(value)
        }
        return speedTest.last.map { speedNumber($0.down) } ?? "—"
    }

    private var speedUpText: String {
        if speedTest.isRunning, let value = speedTest.liveUp {
            return speedNumber(value)
        }
        return speedTest.last.map { speedNumber($0.up) } ?? "—"
    }

    private func speedNumber(_ mbit: Double) -> String {
        if mbit >= 100 { return "\(Int(mbit.rounded())) Mbps" }
        return String(format: "%.1f Mbps", mbit)
    }

    private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: configuration
        ) { _, _ in }
    }
}

/// Tiny dashboard sparkline. Unlike the full monitor charts this has no labels or
/// verdicts; it only shows recent direction inside the already-labelled card.
private struct MiniMetricSparkline: View {
    let points: [Double]
    let maxValue: Double
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard points.count > 1, maxValue > 0 else { return }
                let width = geometry.size.width
                let height = geometry.size.height
                let denominator = Double(points.count - 1)

                for (index, point) in points.enumerated() {
                    let x = width * CGFloat(Double(index) / denominator)
                    let normalized = min(max(point / maxValue, 0), 1)
                    let y = height * CGFloat(1 - normalized)
                    let target = CGPoint(x: x, y: y)
                    if index == 0 { path.move(to: target) }
                    else { path.addLine(to: target) }
                }
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        }
    }
}

private enum HardwareIdentity {
    static let chipName: String? = {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0,
              size > 1 else { return nil }

        var buffer = [CChar](repeating: 0, count: size)
        let status = buffer.withUnsafeMutableBytes { bytes in
            sysctlbyname(
                "machdep.cpu.brand_string",
                bytes.baseAddress,
                &size,
                nil,
                0
            )
        }
        guard status == 0 else { return nil }
        return buffer.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return nil }
            return String(cString: base)
        }
    }()
}
