import Foundation

/// One executable command exposed by the compact Hop command palette.
///
/// Execution lives in the macOS app target. HopCore owns only identity, search,
/// ordering and availability metadata, which keeps ranking deterministic and
/// unit-testable.
public struct HopAction: Identifiable, Equatable, Hashable, Sendable {
    public enum Category: String, Hashable, Sendable {
        case focus
        case capture
        case windows
        case files
        case network
        case navigate
    }

    /// Typed bridge into the macOS app layer. PanelView switches this enum
    /// exhaustively, so adding a new execution kind cannot compile until the
    /// real behavior is implemented.
    public enum Execution: String, CaseIterable, Hashable, Sendable {
        case screenshotToolbar
        case captureArea
        case ocrScreen
        case drawOnScreen
        case minimizeWindow
        case maximizeWindow
        case moveWindowLeft
        case moveWindowRight
        case startTimer25
        case toggleTimer
        case openProtonVPN
        case showSystemMonitor
        case openConverter
        case openArchive
        case openUninstaller
        case showClipboard
        case showTodos
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let keywords: [String]
    public let category: Category
    public let space: HopSpace
    public let systemImage: String
    public let requiredModuleID: String?
    public let execution: Execution

    public init(
        id: String,
        title: String,
        subtitle: String,
        keywords: [String],
        category: Category,
        space: HopSpace,
        systemImage: String,
        requiredModuleID: String? = nil,
        execution: Execution
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.category = category
        self.space = space
        self.systemImage = systemImage
        self.requiredModuleID = requiredModuleID
        self.execution = execution
    }
}

public enum HopActionCatalog {
    public static let all: [HopAction] = [
        HopAction(
            id: "capture.screenshotToolbar",
            title: "Screenshot Toolbar",
            subtitle: "Open the macOS screenshot and recording controls",
            keywords: ["screenshot", "screen", "capture", "toolbar", "cmd shift 5", "command shift 5"],
            category: .capture,
            space: .tools,
            systemImage: "camera.viewfinder",
            requiredModuleID: "shot",
            execution: .screenshotToolbar
        ),
        HopAction(
            id: "capture.area",
            title: "Capture Area",
            subtitle: "Select an area and capture it with Hop",
            keywords: ["screenshot", "region", "selection", "snip", "area"],
            category: .capture,
            space: .tools,
            systemImage: "viewfinder",
            requiredModuleID: "shot",
            execution: .captureArea
        ),
        HopAction(
            id: "capture.ocr",
            title: "OCR from Screen",
            subtitle: "Select an area and recognize its text locally",
            keywords: ["ocr", "recognize", "recognise", "text", "screen", "scan"],
            category: .capture,
            space: .tools,
            systemImage: "text.viewfinder",
            requiredModuleID: "ocr",
            execution: .ocrScreen
        ),
        HopAction(
            id: "capture.markup",
            title: "Draw on Screen",
            subtitle: "Open Hop's screen markup layer",
            keywords: ["markup", "annotate", "draw", "screen", "pen"],
            category: .capture,
            space: .tools,
            systemImage: "pencil.tip.crop.circle",
            requiredModuleID: "annotate",
            execution: .drawOnScreen
        ),

        HopAction(
            id: "window.minimize",
            title: "Minimize Current Window",
            subtitle: "Minimize the last active app window",
            keywords: ["minimize", "minimise", "hide window", "window"],
            category: .windows,
            space: .tools,
            systemImage: "minus.rectangle",
            requiredModuleID: "windows",
            execution: .minimizeWindow
        ),
        HopAction(
            id: "window.maximize",
            title: "Maximize Current Window",
            subtitle: "Fill the current screen with the active window",
            keywords: ["maximize", "maximise", "full", "window"],
            category: .windows,
            space: .tools,
            systemImage: "rectangle.inset.filled",
            requiredModuleID: "windows",
            execution: .maximizeWindow
        ),
        HopAction(
            id: "window.leftHalf",
            title: "Move Window Left",
            subtitle: "Place the active window on the left half",
            keywords: ["left", "half", "tile", "window"],
            category: .windows,
            space: .tools,
            systemImage: "rectangle.lefthalf.inset.filled",
            requiredModuleID: "windows",
            execution: .moveWindowLeft
        ),
        HopAction(
            id: "window.rightHalf",
            title: "Move Window Right",
            subtitle: "Place the active window on the right half",
            keywords: ["right", "half", "tile", "window"],
            category: .windows,
            space: .tools,
            systemImage: "rectangle.righthalf.inset.filled",
            requiredModuleID: "windows",
            execution: .moveWindowRight
        ),

        HopAction(
            id: "focus.timer25",
            title: "Start 25 Minute Timer",
            subtitle: "Set a 25 minute focus timer and start it",
            keywords: ["timer", "25", "pomodoro", "focus", "study"],
            category: .focus,
            space: .work,
            systemImage: "timer",
            requiredModuleID: "timer",
            execution: .startTimer25
        ),
        HopAction(
            id: "focus.timerToggle",
            title: "Start or Pause Timer",
            subtitle: "Toggle the current Hop timer",
            keywords: ["timer", "start", "pause", "resume", "focus"],
            category: .focus,
            space: .work,
            systemImage: "playpause",
            requiredModuleID: "timer",
            execution: .toggleTimer
        ),

        HopAction(
            id: "network.protonVPN",
            title: "Open Proton VPN",
            subtitle: "Bring Proton VPN to the front",
            keywords: ["proton", "vpn", "network", "privacy"],
            category: .network,
            space: .mac,
            systemImage: "lock.shield",
            requiredModuleID: "vpn",
            execution: .openProtonVPN
        ),
        HopAction(
            id: "navigate.system",
            title: "System Monitor",
            subtitle: "Show Hop's Mac monitoring tools",
            keywords: ["cpu", "ram", "memory", "temperature", "network", "monitor", "mac"],
            category: .navigate,
            space: .mac,
            systemImage: "gauge.with.dots.needle.50percent",
            requiredModuleID: "system",
            execution: .showSystemMonitor
        ),

        HopAction(
            id: "files.convert",
            title: "File Converter",
            subtitle: "Open Hop's file converter",
            keywords: ["convert", "converter", "image", "pdf", "file"],
            category: .files,
            space: .tools,
            systemImage: "arrow.triangle.2.circlepath.doc.on.clipboard",
            requiredModuleID: "convert",
            execution: .openConverter
        ),
        HopAction(
            id: "files.archive",
            title: "Archive or Extract",
            subtitle: "Open Hop's archive tool",
            keywords: ["archive", "extract", "zip", "rar", "7z", "compress"],
            category: .files,
            space: .tools,
            systemImage: "archivebox",
            requiredModuleID: "archive",
            execution: .openArchive
        ),
        HopAction(
            id: "files.uninstall",
            title: "App Uninstaller",
            subtitle: "Open Hop's app cleanup tool",
            keywords: ["uninstall", "remove app", "delete app", "cleanup"],
            category: .files,
            space: .tools,
            systemImage: "trash.slash",
            requiredModuleID: "uninstall",
            execution: .openUninstaller
        ),

        HopAction(
            id: "navigate.clipboard",
            title: "Clipboard History",
            subtitle: "Show recent non-sensitive clipboard items",
            keywords: ["clipboard", "copy", "paste", "history"],
            category: .navigate,
            space: .work,
            systemImage: "doc.on.clipboard",
            requiredModuleID: "clipboard",
            execution: .showClipboard
        ),
        HopAction(
            id: "navigate.todos",
            title: "To-Dos",
            subtitle: "Show Hop's task list",
            keywords: ["todo", "task", "tasks", "study", "work"],
            category: .navigate,
            space: .work,
            systemImage: "checklist",
            requiredModuleID: "todos",
            execution: .showTodos
        ),
    ]

    /// Deterministic ranking. Every query token must match somewhere. Exact
    /// title/keyword matches beat prefixes, which beat word prefixes, which beat
    /// plain containment. Catalog order is the final tie-breaker.
    private static let suggestedIDs = [
        "capture.screenshotToolbar",
        "capture.area",
        "capture.ocr",
        "network.protonVPN",
        "window.minimize",
        "focus.timer25",
        "capture.markup",
        "files.convert",
    ]

    public static func search(
        _ query: String,
        in actions: [HopAction] = all,
        limit: Int = 8
    ) -> [HopAction] {
        let normalizedQuery = normalize(query)
        if normalizedQuery.isEmpty {
            let byID = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
            let suggested = suggestedIDs.compactMap { byID[$0] }
            let suggestedSet = Set(suggested.map(\.id))
            let remainder = actions.filter { !suggestedSet.contains($0.id) }
            return Array((suggested + remainder).prefix(limit))
        }
        let tokens = normalizedQuery.split(separator: " ").map(String.init)

        let ranked: [(Int, Int, HopAction)] = actions.enumerated().compactMap { index, action in
            let title = normalize(action.title)
            let fields = [title, normalize(action.id)]
                + action.keywords.map(normalize)
                + [normalize(action.subtitle)]

            var score = 0
            for token in tokens {
                let tokenScores = fields.map { field -> Int in
                    if field == token { return 1_000 }
                    if field.hasPrefix(token) { return 800 }
                    if field.split(separator: " ").contains(where: { $0.hasPrefix(token) }) {
                        return 700
                    }
                    if field.contains(token) { return 450 }
                    return 0
                }
                guard let best = tokenScores.max(), best > 0 else { return nil }
                score += best
            }

            if title == normalizedQuery { score += 2_000 }
            else if title.hasPrefix(normalizedQuery) { score += 1_200 }
            else if title.contains(normalizedQuery) { score += 600 }

            return (score, index, action)
        }

        return ranked
            .sorted {
                if $0.0 != $1.0 { return $0.0 > $1.0 }
                return $0.1 < $1.1
            }
            .prefix(limit)
            .map { $0.2 }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
