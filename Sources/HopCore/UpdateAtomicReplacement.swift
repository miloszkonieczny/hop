import Darwin
import Foundation

/// A rollback-safe update transaction.
///
/// The candidate lives beside the production app, so macOS can exchange the two
/// directory entries with RENAME_SWAP in one filesystem operation. At every
/// instant /Applications/Hop.app therefore names one complete bundle: either the
/// old one or the already-verified candidate.
public enum UpdateAtomicReplacement {
    public enum Error: Swift.Error, Equatable {
        case renameFailed(Int32)
    }

    /// Atomically exchange two existing filesystem entries on macOS.
    ///
    /// Both paths must exist and be on the same volume. No remove-then-move
    /// fallback is permitted: losing atomicity here would recreate the exact
    /// failure mode this updater is designed to prevent.
    public static func swap(_ firstPath: String, _ secondPath: String) throws {
        let result = firstPath.withCString { first in
            secondPath.withCString { second in
                renamex_np(first, second, UInt32(RENAME_SWAP))
            }
        }
        guard result == 0 else { throw Error.renameFailed(errno) }
    }
}

/// Paths and command-line protocol shared by the updater and its rollback guard.
/// Kept in HopCore so transaction construction and parsing are deterministic and
/// unit-testable without launching the application.
public struct UpdateReplacementPlan: Equatable, Sendable {
    public let targetPath: String
    public let rollbackPath: String
    public let stateDirectory: String
    public let guardReadyPath: String
    public let stableAcknowledgementPath: String

    public init(
        targetPath: String,
        cacheDirectory: String,
        transactionID: String
    ) {
        self.targetPath = targetPath

        let target = URL(fileURLWithPath: targetPath)
        let parent = target.deletingLastPathComponent()
        let rollbackName = ".Hop-update-rollback-\(transactionID).app"
        self.rollbackPath = parent.appendingPathComponent(rollbackName).path

        let state = URL(fileURLWithPath: cacheDirectory, isDirectory: true)
            .appendingPathComponent("hop-update-transaction-\(transactionID)", isDirectory: true)
        self.stateDirectory = state.path
        self.guardReadyPath = state.appendingPathComponent("guard-ready").path
        self.stableAcknowledgementPath = state.appendingPathComponent("launch-stable").path
    }

    public func guardArguments(parentPID: Int32) -> [String] {
        [
            UpdateRollbackProtocol.guardFlag,
            String(parentPID),
            targetPath,
            rollbackPath,
            guardReadyPath,
            stableAcknowledgementPath,
        ]
    }

    public func launchArguments() -> [String] {
        [
            UpdateRollbackProtocol.acknowledgementFlag,
            stableAcknowledgementPath,
        ]
    }
}

public enum UpdateRollbackProtocol {
    public static let guardFlag = "--update-rollback-guard"
    public static let acknowledgementFlag = "--update-ack"

    public struct GuardRequest: Equatable, Sendable {
        public let parentPID: Int32
        public let targetPath: String
        public let rollbackPath: String
        public let guardReadyPath: String
        public let stableAcknowledgementPath: String
    }

    public static func guardRequest(arguments: [String]) -> GuardRequest? {
        guard let index = arguments.firstIndex(of: guardFlag),
              arguments.count > index + 5,
              let pid = Int32(arguments[index + 1])
        else { return nil }

        return GuardRequest(
            parentPID: pid,
            targetPath: arguments[index + 2],
            rollbackPath: arguments[index + 3],
            guardReadyPath: arguments[index + 4],
            stableAcknowledgementPath: arguments[index + 5]
        )
    }

    public static func acknowledgementPath(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: acknowledgementFlag),
              arguments.count > index + 1
        else { return nil }
        return arguments[index + 1]
    }

    /// Production guard invocations are deliberately path-constrained. This
    /// hidden launch mode must never become a general-purpose rename/delete
    /// primitive merely because another local process can execute Hop.
    public static func isValidGuardRequest(
        _ request: GuardRequest,
        productionTargetPath: String,
        cacheDirectory: String
    ) -> Bool {
        let target = standardized(request.targetPath)
        let expectedTarget = standardized(productionTargetPath)
        guard target == expectedTarget else { return false }

        let targetURL = URL(fileURLWithPath: target)
        let rollbackURL = URL(fileURLWithPath: standardized(request.rollbackPath))
        guard rollbackURL.deletingLastPathComponent().path
                == targetURL.deletingLastPathComponent().path
        else { return false }

        let rollbackName = rollbackURL.lastPathComponent
        let rollbackPrefix = ".Hop-update-rollback-"
        guard rollbackName.hasPrefix(rollbackPrefix),
              rollbackName.hasSuffix(".app")
        else { return false }
        let transactionID = String(
            rollbackName.dropFirst(rollbackPrefix.count).dropLast(".app".count)
        )
        guard !transactionID.isEmpty,
              !transactionID.contains("/"),
              !transactionID.contains("..")
        else { return false }

        let expectedState = URL(
            fileURLWithPath: standardized(cacheDirectory),
            isDirectory: true
        ).appendingPathComponent(
            "hop-update-transaction-\(transactionID)",
            isDirectory: true
        ).standardizedFileURL.path

        let ready = URL(fileURLWithPath: standardized(request.guardReadyPath))
        let acknowledgement = URL(
            fileURLWithPath: standardized(request.stableAcknowledgementPath)
        )
        return ready.lastPathComponent == "guard-ready"
            && acknowledgement.lastPathComponent == "launch-stable"
            && ready.deletingLastPathComponent().path == expectedState
            && acknowledgement.deletingLastPathComponent().path == expectedState
    }

    public static func isValidAcknowledgementPath(
        _ path: String,
        cacheDirectory: String
    ) -> Bool {
        let acknowledgement = URL(fileURLWithPath: standardized(path))
        guard acknowledgement.lastPathComponent == "launch-stable" else { return false }

        let state = acknowledgement.deletingLastPathComponent()
        guard state.lastPathComponent.hasPrefix("hop-update-transaction-") else {
            return false
        }
        return state.deletingLastPathComponent().path == standardized(cacheDirectory)
    }

    private static func standardized(_ path: String) -> String {
        (path as NSString).standardizingPath
    }
}
