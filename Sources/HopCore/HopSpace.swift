import Foundation

/// The fixed top-level information architecture of the personalized Hop shell.
///
/// This is deliberately independent from `PanelTabsModel`. The existing tab
/// model remains the durable compatibility/layout store; the shell is a semantic
/// lens over the same modules, so adopting Work / Mac / Tools never destroys a
/// user's stored module arrangement or visibility state.
public enum HopSpace: String, CaseIterable, Codable, Sendable {
    case work
    case mac
    case tools

    public var title: String {
        switch self {
        case .work: return "Work"
        case .mac: return "Mac"
        case .tools: return "Tools"
        }
    }

    public var systemImage: String {
        switch self {
        case .work: return "briefcase"
        case .mac: return "display"
        case .tools: return "wrench.and.screwdriver"
        }
    }

    /// Every built-in module has one semantic home. Unknown/copyable modules
    /// (notably user-created app shelves) fall into Tools rather than silently
    /// disappearing from the new shell.
    public static func containing(module id: String) -> HopSpace {
        switch id {
        case "timer", "tracker", "todos", "clipboard":
            return .work

        case "system", "speedtest", "vpn", "torrent", "awake", "keyboard":
            return .mac

        default:
            return .tools
        }
    }
}

/// A module together with the legacy tab that still owns it. Keeping the source
/// tab id lets existing module actions/settings continue to operate against the
/// unchanged `PanelTabsModel` while the shell groups modules semantically.
public struct HopSpaceModulePlacement: Equatable, Identifiable, Sendable {
    public let moduleID: String
    public let sourceTabID: UUID

    public init(moduleID: String, sourceTabID: UUID) {
        self.moduleID = moduleID
        self.sourceTabID = sourceTabID
    }

    public var id: String { moduleID }
}

public enum HopSpaceLayout {
    /// Flatten the existing stored layout in its current tab/module order, then
    /// select the modules whose semantic home is `space`. Hidden modules stay
    /// stored but are omitted from the shell.
    public static func placements(
        in model: PanelTabsModel,
        space: HopSpace
    ) -> [HopSpaceModulePlacement] {
        model.tabs.flatMap { tab in
            tab.moduleKeys.compactMap { moduleID in
                guard !model.isHidden(moduleID),
                      HopSpace.containing(module: moduleID) == space
                else { return nil }
                return HopSpaceModulePlacement(
                    moduleID: moduleID,
                    sourceTabID: tab.id
                )
            }
        }
    }

    /// Resolve a persisted value defensively. Unknown/future values never make
    /// the panel blank; Work is the stable fallback.
    public static func restoredSpace(from rawValue: String?) -> HopSpace {
        rawValue.flatMap(HopSpace.init(rawValue:)) ?? .work
    }
}
