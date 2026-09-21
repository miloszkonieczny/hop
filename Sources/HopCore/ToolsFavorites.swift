import Foundation

/// Persistence/rules for the personalized Tools dashboard's favorite actions.
///
/// Favorites reference HopAction IDs. The dashboard therefore never owns a
/// second command definition and automatically inherits action safety/module
/// availability from HopActionCatalog.
public enum ToolsFavorites {
    public static let maximumCount = 6
    public static let defaultMarker = "__default__"
    public static let emptyMarker = "__none__"

    public static let defaults = [
        "capture.screenshotToolbar",
        "capture.area",
        "capture.ocr",
        "files.convert",
        "window.minimize",
    ]

    public static func resolved(
        raw: String?,
        validIDs: Set<String>,
        maximumCount: Int = maximumCount
    ) -> [String] {
        guard maximumCount > 0 else { return [] }

        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let candidates: [String]
        if trimmed.isEmpty || trimmed == defaultMarker {
            candidates = defaults
        } else if trimmed == emptyMarker {
            candidates = []
        } else {
            candidates = trimmed
                .split(separator: ",")
                .map(String.init)
        }

        var seen: Set<String> = []
        var result: [String] = []
        for id in candidates {
            guard validIDs.contains(id), seen.insert(id).inserted else { continue }
            result.append(id)
            if result.count == maximumCount { break }
        }
        return result
    }

    public static func encoded(_ ids: [String]) -> String {
        ids.isEmpty ? emptyMarker : ids.joined(separator: ",")
    }

    public static func toggling(
        _ id: String,
        in favorites: [String],
        validIDs: Set<String>,
        maximumCount: Int = maximumCount
    ) -> [String] {
        guard validIDs.contains(id), maximumCount > 0 else { return favorites }

        if favorites.contains(id) {
            return favorites.filter { $0 != id }
        }

        guard favorites.count < maximumCount else { return favorites }
        return favorites + [id]
    }
}
