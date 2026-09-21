import AppKit
import HopCore
import SwiftUI

/// The compact default Work surface. It summarizes existing controllers rather
/// than introducing parallel productivity state. Full modules remain one click
/// away through the section disclosure buttons.
struct WorkDashboardView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var todos: TodosController
    @ObservedObject var clipboard: ClipboardController
    @ObservedObject var recentApps: RecentAppsController

    let visibleModules: Set<String>
    let quickActions: [HopAction]
    let executeAction: (HopAction) -> Void
    let openModule: (String) -> Void
    let closePanel: () -> Void

    @State private var copiedClipboardID: UUID?

    private var activeTodos: [TodoItem] {
        todos.list.displayItems.filter { !$0.done }
    }

    var body: some View {
        VStack(spacing: 10) {
            if visibleModules.contains("timer") {
                focusCard
            }
            if visibleModules.contains("todos") {
                todosCard
            }
            if visibleModules.contains("clipboard") {
                clipboardCard
            }
            recentAppsCard
            if !quickActions.isEmpty {
                quickActionsCard
            }
            if visibleModules.contains("tracker") {
                trackerLink
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Focus

    private var focusCard: some View {
        dashboardCard {
            VStack(spacing: 10) {
                HStack {
                    dashboardTitle("Focus", symbol: "timer")
                    Spacer()
                    Button {
                        openModule("timer")
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 22, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(4)
                    .help("Open full timer")
                }

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(timerText)
                            .font(Theme.mono(28, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()

                        Text(timerStatus)
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    Spacer(minLength: 10)

                    if engine.state != .idle {
                        Button {
                            engine.reset()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(Theme.chipBg, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .hoverDim()
                        .help("Reset timer")
                    }

                    Button {
                        engine.toggle()
                    } label: {
                        Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.playFg)
                            .frame(width: 34, height: 34)
                            .background(Theme.playBg, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .hoverDim()
                    .help(engine.state == .running ? "Pause timer" : "Start timer")
                }

                if engine.state == .idle && !engine.isStopwatch {
                    HStack(spacing: 6) {
                        presetChip(25)
                        presetChip(45)
                        presetChip(60)
                        Spacer()
                    }
                }
            }
        }
    }

    private func presetChip(_ minutes: Int) -> some View {
        let active = engine.duration == TimeInterval(minutes * 60)
        return Button {
            engine.setPreset(minutes: minutes)
        } label: {
            Text("\(minutes) min")
                .font(Theme.mono(9, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, 7)
                .frame(height: 23)
                .background(active ? Theme.chipBg : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Theme.divider, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(5)
    }

    private var timerText: String {
        let interval = engine.isStopwatch ? engine.elapsed : engine.remaining
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timerStatus: String {
        if engine.isStopwatch { return engine.state == .running ? "stopwatch running" : "stopwatch" }
        switch engine.state {
        case .idle: return "ready"
        case .running: return "focus in progress"
        case .paused: return "paused"
        case .finished: return "finished"
        }
    }

    // MARK: - To-dos

    private var todosCard: some View {
        dashboardCard {
            VStack(spacing: 7) {
                HStack {
                    dashboardTitle("Today", symbol: "checklist")
                    Spacer()
                    Text("\(activeTodos.count) remaining")
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.textTertiary)
                    Button {
                        openModule("todos")
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 22, height: 20)
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(4)
                    .help("Open all to-dos")
                }

                if activeTodos.isEmpty {
                    emptyLine("No active tasks")
                } else {
                    ForEach(Array(activeTodos.prefix(3))) { item in
                        HStack(spacing: 7) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    todos.toggle(item.id)
                                }
                            } label: {
                                Circle()
                                    .stroke(Theme.textSecondary, lineWidth: 1.2)
                                    .frame(width: 15, height: 15)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .hoverDim()

                            Text(item.text)
                                .font(Theme.mono(10))
                                .foregroundStyle(Theme.listText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 4)

                            if item.important {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .frame(height: 22)
                    }

                    if activeTodos.count > 3 {
                        Button {
                            openModule("todos")
                        } label: {
                            Text("+ \(activeTodos.count - 3) more")
                                .font(Theme.mono(8, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hoverDim()
                    }
                }
            }
        }
    }

    // MARK: - Clipboard

    private var clipboardCard: some View {
        dashboardCard {
            VStack(spacing: 7) {
                HStack {
                    dashboardTitle("Clipboard", symbol: "doc.on.clipboard")
                    Spacer()
                    Button {
                        openModule("clipboard")
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 22, height: 20)
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(4)
                    .help("Open clipboard history")
                }

                if clipboard.items.isEmpty {
                    emptyLine("No recent clipboard items")
                } else {
                    ForEach(Array(clipboard.items.prefix(3))) { item in
                        Button {
                            clipboard.copy(item)
                            markCopied(item.id)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: clipboardSymbol(item))
                                    .font(.system(size: 9))
                                    .foregroundStyle(
                                        copiedClipboardID == item.id
                                            ? Theme.accentGreen : Theme.textTertiary
                                    )
                                    .frame(width: 14)

                                Text(ClipboardRules.previewLine(item.text))
                                    .font(Theme.mono(9))
                                    .foregroundStyle(Theme.listText)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer(minLength: 4)

                                if copiedClipboardID == item.id {
                                    Text("copied")
                                        .font(Theme.mono(8, weight: .semibold))
                                        .foregroundStyle(Theme.accentGreen)
                                }
                            }
                            .frame(height: 22)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hoverHighlight(4)
                    }
                }
            }
        }
    }

    private func clipboardSymbol(_ item: ClipboardItem) -> String {
        if item.colorHex != nil { return "paintpalette" }
        if item.filePaths != nil { return "doc" }
        if item.imageFile != nil { return "photo" }
        return "text.alignleft"
    }

    private func markCopied(_ id: UUID) {
        copiedClipboardID = id
        Task {
            try? await Task.sleep(for: .seconds(1))
            if copiedClipboardID == id { copiedClipboardID = nil }
        }
    }

    // MARK: - Recent apps

    private var recentAppsCard: some View {
        dashboardCard {
            VStack(spacing: 8) {
                HStack {
                    dashboardTitle("Recent Apps", symbol: "square.grid.2x2")
                    Spacer()
                    Text("local only")
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.textTertiary)
                }

                if recentApps.applications.isEmpty {
                    emptyLine("Apps you use will appear here")
                } else {
                    HStack(spacing: 8) {
                        ForEach(recentApps.applications.prefix(5)) { application in
                            Button {
                                closePanel()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    recentApps.open(application)
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(nsImage: NSWorkspace.shared.icon(
                                        forFile: application.path
                                    ))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)

                                    Text(application.name)
                                        .font(Theme.mono(7))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .hoverDim()
                            .help(application.name)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick actions

    private var quickActionsCard: some View {
        dashboardCard {
            VStack(spacing: 8) {
                HStack {
                    dashboardTitle("Quick Actions", symbol: "bolt")
                    Spacer()
                    Text("⌘ palette")
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.textTertiary)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                    ],
                    spacing: 6
                ) {
                    ForEach(quickActions.prefix(5)) { action in
                        Button {
                            executeAction(action)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: action.systemImage)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 16)
                                Text(shortActionTitle(action))
                                    .font(Theme.mono(8, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 30)
                            .background(Theme.chipBg, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hoverHighlight(6)
                        .help(action.title)
                    }
                }
            }
        }
    }

    private func shortActionTitle(_ action: HopAction) -> String {
        switch action.id {
        case "capture.screenshotToolbar": return "Screenshot"
        case "capture.area": return "Capture Area"
        case "capture.ocr": return "OCR"
        case "network.protonVPN": return "Proton VPN"
        case "window.minimize": return "Minimize"
        default: return action.title
        }
    }

    // MARK: - Tracker access

    private var trackerLink: some View {
        Button {
            openModule("tracker")
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                Text("Time Tracker")
                    .font(Theme.mono(9, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Theme.rowBg, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(7)
    }

    // MARK: - Shared pieces

    private func dashboardCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Theme.rowBg, in: RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Theme.divider, lineWidth: 1)
            )
    }

    private func dashboardTitle(_ title: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .font(Theme.mono(9, weight: .semibold))
        }
        .foregroundStyle(Theme.textTertiary)
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.mono(9))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
    }
}
