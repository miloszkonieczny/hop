import AppKit
import Combine
import Foundation
import HopCore

/// Local-only recent-app list for the compact Work dashboard.
///
/// We record application identity only. No window titles, document names,
/// websites, duration, keystrokes or remote telemetry are collected.
@MainActor
final class RecentAppsController: ObservableObject {
    @Published private(set) var applications: [RecentApplication] = []

    private static let storageKey = "recentApplications"
    private var activationObserver: NSObjectProtocol?
    private let demo: Bool

    init(demo: Bool = false) {
        self.demo = demo
        if demo || Snapshot.active {
            applications = []
            return
        }

        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([RecentApplication].self, from: data) {
            applications = RecentApplications.sanitized(decoded).filter {
                FileManager.default.fileExists(atPath: $0.path)
            }
        }

        if let current = NSWorkspace.shared.frontmostApplication {
            record(current)
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication else { return }
            Task { @MainActor in self?.record(app) }
        }
    }


    func clear() {
        guard !applications.isEmpty else { return }
        applications = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    func open(_ application: RecentApplication) {
        guard !demo, !Snapshot.active else { return }

        if let bundleID = application.bundleIdentifier,
           let running = NSRunningApplication.runningApplications(
               withBundleIdentifier: bundleID
           ).first {
            running.activate(options: [.activateIgnoringOtherApps])
            return
        }

        let url = URL(fileURLWithPath: application.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            applications.removeAll { $0.id == application.id }
            save()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: configuration
        ) { [weak self] _, error in
            guard error != nil else { return }
            Task { @MainActor in
                self?.applications.removeAll { $0.id == application.id }
                self?.save()
            }
        }
    }

    private func record(_ app: NSRunningApplication) {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.activationPolicy == .regular,
              let url = app.bundleURL,
              let name = app.localizedName,
              !name.isEmpty
        else { return }

        let entry = RecentApplication(
            bundleIdentifier: app.bundleIdentifier,
            name: name,
            path: url.path
        )
        let updated = RecentApplications.recording(entry, in: applications)
        guard updated != applications else { return }
        applications = updated
        save()
    }

    private func save() {
        guard !demo, !Snapshot.active,
              let data = try? JSONEncoder().encode(applications)
        else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
