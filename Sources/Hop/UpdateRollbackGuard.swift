import Darwin
import Foundation
import HopCore

/// A tiny headless process started from the OLD Hop binary before the app bundle
/// is exchanged. It owns the rollback copy until the replacement proves it can
/// launch and survive Hop's normal stability window.
enum UpdateRollbackGuard {
    private static let parentExitTimeout: TimeInterval = 60
    private static let stableLaunchGrace: TimeInterval = 15
    private static let pollInterval: useconds_t = 200_000

    /// Called at the very beginning of HopApp.init(). A guard invocation never
    /// reaches SwiftUI or AppDelegate startup.
    static func runIfRequested() {
        guard let request = UpdateRollbackProtocol.guardRequest(arguments: CommandLine.arguments)
        else { return }

        let result = run(request)
        exit(result)
    }

    /// The replacement app receives the acknowledgement path. Hop acknowledges
    /// only after the SAME 30-second window LaunchGuard already defines as a
    /// stable launch (or on a clean user-requested termination before then).
    static func acknowledgeStableLaunchIfRequested() {
        guard let path = UpdateRollbackProtocol.acknowledgementPath(
            arguments: CommandLine.arguments
        ) else { return }
        touch(path)
    }

    /// Parent-side readiness gate. A successful Process.run() only proves the
    /// kernel accepted exec; the updater does not exchange bundles until the
    /// helper itself has parsed its transaction and written this marker.
    static func waitUntilReady(path: String, timeout: TimeInterval = 5) -> Bool {
        waitForFile(path, timeout: timeout)
    }

    private static func run(_ request: UpdateRollbackProtocol.GuardRequest) -> Int32 {
        let fm = FileManager.default
        touch(request.guardReadyPath)

        // An aborted transaction can resolve while the helper is starting.
        if fm.fileExists(atPath: request.stableAcknowledgementPath) {
            cleanupSuccessfulOrCancelled(request)
            return 0
        }

        // Never exchange paths underneath a still-running parent. If the updater
        // did not terminate, leaving both complete bundles in place is safer than
        // guessing which state the parent reached.
        guard waitForProcessExit(
            request.parentPID,
            timeout: parentExitTimeout,
            cancellationPath: request.stableAcknowledgementPath
        ) else {
            if fm.fileExists(atPath: request.stableAcknowledgementPath) {
                cleanupSuccessfulOrCancelled(request)
            }
            return 2
        }

        if fm.fileExists(atPath: request.stableAcknowledgementPath) {
            cleanupSuccessfulOrCancelled(request)
            return 0
        }

        // Launch the candidate now occupying the canonical target path and pass
        // only the acknowledgement marker. Process avoids shell interpolation.
        guard launch(
            appPath: request.targetPath,
            arguments: [
                UpdateRollbackProtocol.acknowledgementFlag,
                request.stableAcknowledgementPath,
            ]
        ) else {
            return rollbackAndRelaunch(request)
        }

        let stable = waitForFile(
            request.stableAcknowledgementPath,
            timeout: LaunchGuard.stableAfter + stableLaunchGrace
        )
        guard stable else { return rollbackAndRelaunch(request) }

        // The new app survived the same window Hop already calls a successful
        // launch. Only now is the old bundle discarded.
        cleanupSuccessfulOrCancelled(request)
        return 0
    }

    private static func rollbackAndRelaunch(
        _ request: UpdateRollbackProtocol.GuardRequest
    ) -> Int32 {
        do {
            try UpdateAtomicReplacement.swap(
                request.targetPath,
                request.rollbackPath
            )
        } catch {
            // Preserve BOTH bundles for manual recovery if the atomic rollback
            // itself cannot be completed. Never delete the only known-good copy.
            return 3
        }

        // rollbackPath now contains the failed candidate; targetPath is the
        // known-good old app again.
        try? FileManager.default.removeItem(atPath: request.rollbackPath)
        try? FileManager.default.removeItem(atPath: request.stateDirectoryPath)
        return launch(appPath: request.targetPath, arguments: []) ? 0 : 4
    }

    private static func cleanupSuccessfulOrCancelled(
        _ request: UpdateRollbackProtocol.GuardRequest
    ) {
        let fm = FileManager.default
        try? fm.removeItem(atPath: request.rollbackPath)
        try? fm.removeItem(atPath: request.stateDirectoryPath)
    }

    private static func launch(appPath: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", appPath] + (arguments.isEmpty ? [] : ["--args"] + arguments)
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func waitForProcessExit(
        _ pid: Int32,
        timeout: TimeInterval,
        cancellationPath: String
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: cancellationPath) { return false }
            errno = 0
            if kill(pid, 0) != 0, errno == ESRCH { return true }
            usleep(pollInterval)
        }
        return false
    }

    private static func waitForFile(_ path: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: path) { return true }
            usleep(pollInterval)
        }
        return FileManager.default.fileExists(atPath: path)
    }

    private static func touch(_ path: String) {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: Data())
        }
    }
}

private extension UpdateRollbackProtocol.GuardRequest {
    var stateDirectoryPath: String {
        (guardReadyPath as NSString).deletingLastPathComponent
    }
}
