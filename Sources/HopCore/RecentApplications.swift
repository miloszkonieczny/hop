import Foundation

/// Small, local-only MRU list used by the Work dashboard.
///
/// It records only application identity (bundle id/name/path), never document
/// titles, URLs, window text or activity duration.
public struct RecentApplication: Codable, Equatable, Identifiable, Sendable {
    public let bundleIdentifier: String?
    public let name: String
    public let path: String

    public init(bundleIdentifier: String?, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
    }

    public var id: String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return "bundle:\(bundleIdentifier)"
        }
        return "path:\(path)"
    }
}

public enum RecentApplications {
    public static let maximumCount = 5

    /// Move an activated application to the front, de-duplicating by the stable
    /// bundle identifier when available and by path otherwise.
    public static func recording(
        _ application: RecentApplication,
        in existing: [RecentApplication],
        maximumCount: Int = maximumCount
    ) -> [RecentApplication] {
        guard maximumCount > 0,
              !application.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !application.path.isEmpty
        else { return maximumCount > 0 ? existing : [] }

        var result = existing.filter { $0.id != application.id }
        result.insert(application, at: 0)
        if result.count > maximumCount {
            result.removeLast(result.count - maximumCount)
        }
        return result
    }

    public static func sanitized(
        _ applications: [RecentApplication],
        maximumCount: Int = maximumCount
    ) -> [RecentApplication] {
        guard maximumCount > 0 else { return [] }
        var result: [RecentApplication] = []
        for app in applications {
            guard !app.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !app.path.isEmpty,
                  !result.contains(where: { $0.id == app.id })
            else { continue }
            result.append(app)
            if result.count == maximumCount { break }
        }
        return result
    }
}
