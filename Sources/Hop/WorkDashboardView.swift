import AppKit
import HopCore
import SwiftUI

/// The compact default Work surface. It summarizes existing controllers rather
/// than introducing parallel productivity state. Full modules remain one click
/// away through the section disclosure buttons.
struct WorkDashboardView: View {
    let engine: TimerEngine
    @ObservedObject var todos: TodosController
    @ObservedObject var clipboard: ClipboardController
    @ObservedObject var recentApps: RecentAppsController

    @AppStorage(SettingsKey.todoImportantOnTop) private var importantOnTop = false

    let visibleModules: Set<String>
    let timerPresets: [Int]
    let quickActions: [HopAction]
    let executeAction: (HopAction) -> Void
    let openModule: (String) -> Void
    let closePanel: () -> Void
    let taskInputEditingChanged: (Bool) -> Void

    @State private var copiedClipboardID: UUID?
    @State private var showQuickAdd = false
    @State private var newTaskText = ""
    @FocusState private var quickAddFocused: Bool

    private var activeTodos: [TodoItem] {
        todos.list
            .displayItems(importantFirst: importantOnTop)
            .filter { !$0.done }
    }

    var body: some View {
        VStack(spacing: 10) {
            if visibleModules.contains("timer") {
                focusCard
            }
            if !quickActions.isEmpty {
                quickActionsCard
            }
            if visibleModules.contains("todos") {
                todosCard
            }
            if visibleModules.contains("clipboard") {
                clipboardCard
            }
            recentAppsRow
            if visibleModules.contains("tracker") {
                trackerLink
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: quickAddFocused) { _, focused in
            taskInputEditingChanged(focused)
            if !focused && newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showQuickAdd = false
            }
        }
        .onDisappear {
            taskInputEditingChanged(false)
        }
    }

    // MARK: - Focus

    private var focusCard: some View {
        WorkFocusCard(
            engine: engine,
            presets: timerPresets,
            openFullTimer: { openModule("timer") }
        )
    }

    // MARK: - To-dos

    private var todosCard: some View {
        dashboardCard {
            VStack(spacing: 7) {
                HStack {
                    dashboardTitle("Tasks", symbol: "checklist")
                    Spacer()
                    Text("\(activeTodos.count) remaining")
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.textTertiary)

                    Button {
                        showQuickAdd.toggle()
                        if showQuickAdd {
                            DispatchQueue.main.async { quickAddFocused = true }
                        } else {
                            quickAddFocused = false
                            newTaskText = ""
                        }
                    } label: {
                        Image(systemName: showQuickAdd ? "xmark" : "plus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 22, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(4)
                    .help(showQuickAdd ? "Cancel quick add" : "Add task")

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

                if showQuickAdd {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                        TextField("Add a task…", text: $newTaskText)
                            .textFieldStyle(.plain)
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.textPrimary)
                            .focused($quickAddFocused)
                            .onSubmit { commitQuickTask() }
                        Button {
                            commitQuickTask()
                        } label: {
                            Image(systemName: "return")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(
                                    newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Theme.textTertiary : Theme.textSecondary
                                )
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(Theme.chipBg, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.divider, lineWidth: 1)
                    )
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
        dashboardCard(padding: 8) {
            VStack(spacing: 5) {
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

                                Text(ClipPreviewCache.line(for: item))
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
                            .frame(height: 20)
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

    private var recentAppsRow: some View {
        VStack(spacing: 7) {
            HStack {
                dashboardTitle("Recent Apps", symbol: "square.grid.2x2")
                Spacer()

                if recentApps.enabled {
                    if !recentApps.applications.isEmpty {
                        Button("clear") {
                            recentApps.clear()
                        }
                        .font(Theme.mono(8, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .buttonStyle(.plain)
                        .hoverDim()
                        .help("Clear recent apps")
                    }

                    Button {
                        recentApps.setEnabled(false)
                    } label: {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 20, height: 18)
                    }
                    .buttonStyle(.plain)
                    .hoverDim()
                    .help("Turn off recent apps and erase the stored list")
                } else {
                    Button("enable") {
                        recentApps.setEnabled(true)
                    }
                    .font(Theme.mono(8, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .buttonStyle(.plain)
                    .hoverDim()
                    .help("Enable local recent-app tracking")
                }
            }

            if recentApps.enabled {
                if recentApps.applications.isEmpty {
                    Text("Apps you use will appear here · local only")
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                } else {
                    HStack(spacing: 10) {
                        ForEach(recentApps.applications.prefix(4)) { application in
                            Button {
                                closePanel()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    recentApps.open(application)
                                }
                            } label: {
                                VStack(spacing: 3) {
                                    Image(nsImage: RecentAppIconCache.icon(
                                        for: application.path
                                    ))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 26, height: 26)

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

                        if recentApps.applications.count < 4 {
                            Spacer(minLength: 0)
                        }
                    }
                }
            } else {
                Text("Off · no app activations are being recorded")
                    .font(Theme.mono(8))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.rowBg.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.divider, lineWidth: 1)
        )
    }

    // MARK: - Quick actions

    private var quickActionsCard: some View {
        VStack(spacing: 6) {
            HStack {
                dashboardTitle("Quick Actions", symbol: "bolt")
                Spacer()
                Text("search above for more")
                    .font(Theme.mono(7))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(spacing: 6) {
                ForEach(quickActions.prefix(5)) { action in
                    Button {
                        executeAction(action)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.systemImage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 24, height: 20)
                            Text(shortActionTitle(action))
                                .font(Theme.mono(7, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Theme.chipBg, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(7)
                    .help(action.title)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func shortActionTitle(_ action: HopAction) -> String {
        switch action.id {
        case "capture.screenshotToolbar": return "Screenshot"
        case "capture.area": return "Area"
        case "capture.ocr": return "OCR"
        case "network.protonVPN": return "VPN"
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

    private func commitQuickTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard todos.add(text: trimmed) != nil else { return }
        newTaskText = ""
        showQuickAdd = false
        quickAddFocused = false
    }

    // MARK: - Shared pieces

    private func dashboardCard<Content: View>(
        padding: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(padding)
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


/// Isolated from the rest of the Work dashboard so TimerEngine's 4 Hz heartbeat
/// redraws only the clock card, not tasks, clipboard previews or app icons.
private struct WorkFocusCard: View {
    @ObservedObject var engine: TimerEngine
    let presets: [Int]
    let openFullTimer: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Focus")
                        .font(Theme.mono(9, weight: .semibold))
                }
                .foregroundStyle(Theme.textTertiary)

                Spacer()

                Button(action: openFullTimer) {
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
                    ForEach(presets.prefix(3), id: \.self) { minutes in
                        presetChip(minutes)
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Theme.rowBg, in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Theme.divider, lineWidth: 1)
        )
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
                .background(
                    active ? Theme.chipBg : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5)
                )
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
        if engine.isStopwatch {
            return engine.state == .running ? "stopwatch running" : "stopwatch"
        }
        switch engine.state {
        case .idle: return "ready"
        case .running: return "focus in progress"
        case .paused: return "paused"
        case .finished: return "finished"
        }
    }
}

@MainActor
private enum RecentAppIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}
