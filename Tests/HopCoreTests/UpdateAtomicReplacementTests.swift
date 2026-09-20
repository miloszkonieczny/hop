import XCTest
@testable import HopCore

final class UpdateAtomicReplacementTests: XCTestCase {
    func testPlanKeepsRollbackBesideTargetAndStateOutsideApplications() {
        let plan = UpdateReplacementPlan(
            targetPath: "/Applications/Hop.app",
            cacheDirectory: "/Users/test/Library/Caches/com.antonshakirov.minimo",
            transactionID: "ABC-123"
        )

        XCTAssertEqual(plan.targetPath, "/Applications/Hop.app")
        XCTAssertEqual(
            plan.rollbackPath,
            "/Applications/.Hop-update-rollback-ABC-123.app"
        )
        XCTAssertEqual(
            plan.stateDirectory,
            "/Users/test/Library/Caches/com.antonshakirov.minimo/hop-update-transaction-ABC-123"
        )
        XCTAssertTrue(plan.guardReadyPath.hasSuffix("/guard-ready"))
        XCTAssertTrue(plan.stableAcknowledgementPath.hasSuffix("/launch-stable"))
        XCTAssertTrue(plan.cleanExitPath.hasSuffix("/clean-exit"))
    }

    func testGuardArgumentsRoundTripWithoutShellParsing() {
        let plan = UpdateReplacementPlan(
            targetPath: "/Applications/Hop.app",
            cacheDirectory: "/tmp/Hop Cache",
            transactionID: "txn"
        )
        let arguments = ["Hop"] + plan.guardArguments(parentPID: 4321)

        XCTAssertEqual(
            UpdateRollbackProtocol.guardRequest(arguments: arguments),
            .init(
                parentPID: 4321,
                targetPath: plan.targetPath,
                rollbackPath: plan.rollbackPath,
                guardReadyPath: plan.guardReadyPath,
                stableAcknowledgementPath: plan.stableAcknowledgementPath
            )
        )
    }

    func testAcknowledgementArgumentRoundTrip() {
        let plan = UpdateReplacementPlan(
            targetPath: "/Applications/Hop.app",
            cacheDirectory: "/tmp/cache",
            transactionID: "txn"
        )

        XCTAssertEqual(
            UpdateRollbackProtocol.acknowledgementPath(
                arguments: ["Hop"] + plan.launchArguments()
            ),
            plan.stableAcknowledgementPath
        )
    }

    func testMalformedGuardRequestIsRejected() {
        XCTAssertNil(UpdateRollbackProtocol.guardRequest(arguments: [
            "Hop", UpdateRollbackProtocol.guardFlag, "not-a-pid", "/a", "/b", "/c", "/d",
        ]))
        XCTAssertNil(UpdateRollbackProtocol.guardRequest(arguments: [
            "Hop", UpdateRollbackProtocol.guardFlag, "123", "/a",
        ]))
    }

    func testAtomicSwapExchangesWholeDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hop-swap-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let old = root.appendingPathComponent("Hop.app", isDirectory: true)
        let candidate = root.appendingPathComponent(".Hop-update.app", isDirectory: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: old.appendingPathComponent("identity"))
        try Data("new".utf8).write(to: candidate.appendingPathComponent("identity"))

        try UpdateAtomicReplacement.swap(old.path, candidate.path)

        XCTAssertEqual(
            String(data: try Data(contentsOf: old.appendingPathComponent("identity")),
                   encoding: .utf8),
            "new"
        )
        XCTAssertEqual(
            String(data: try Data(contentsOf: candidate.appendingPathComponent("identity")),
                   encoding: .utf8),
            "old"
        )
    }

    func testAtomicSwapFailsClosedWhenOneSideIsMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hop-swap-missing-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let existing = root.appendingPathComponent("Hop.app", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)

        XCTAssertThrowsError(
            try UpdateAtomicReplacement.swap(
                existing.path,
                root.appendingPathComponent("missing.app").path
            )
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: existing.path))
    }
    func testGuardRequestIsAcceptedOnlyForMatchingCanonicalTransaction() {
        let cache = "/Users/test/Library/Caches/com.antonshakirov.minimo"
        let plan = UpdateReplacementPlan(
            targetPath: "/Applications/Hop.app",
            cacheDirectory: cache,
            transactionID: "ABC-123"
        )
        let request = UpdateRollbackProtocol.guardRequest(
            arguments: ["Hop"] + plan.guardArguments(parentPID: 123)
        )

        XCTAssertNotNil(request)
        XCTAssertTrue(UpdateRollbackProtocol.isValidGuardRequest(
            request!,
            productionTargetPath: "/Applications/Hop.app",
            cacheDirectory: cache
        ))
    }

    func testGuardRequestRejectsArbitraryTargetAndMismatchedState() {
        let cache = "/Users/test/Library/Caches/com.antonshakirov.minimo"
        let valid = UpdateReplacementPlan(
            targetPath: "/Applications/Hop.app",
            cacheDirectory: cache,
            transactionID: "ABC-123"
        )
        let arbitrary = UpdateRollbackProtocol.GuardRequest(
            parentPID: 123,
            targetPath: "/Users/test/Documents/anything",
            rollbackPath: valid.rollbackPath,
            guardReadyPath: valid.guardReadyPath,
            stableAcknowledgementPath: valid.stableAcknowledgementPath
        )
        XCTAssertFalse(UpdateRollbackProtocol.isValidGuardRequest(
            arbitrary,
            productionTargetPath: "/Applications/Hop.app",
            cacheDirectory: cache
        ))

        let mismatched = UpdateRollbackProtocol.GuardRequest(
            parentPID: 123,
            targetPath: valid.targetPath,
            rollbackPath: valid.rollbackPath,
            guardReadyPath: cache + "/hop-update-transaction-OTHER/guard-ready",
            stableAcknowledgementPath: valid.stableAcknowledgementPath
        )
        XCTAssertFalse(UpdateRollbackProtocol.isValidGuardRequest(
            mismatched,
            productionTargetPath: "/Applications/Hop.app",
            cacheDirectory: cache
        ))
    }

    func testAcknowledgementPathIsRestrictedToHopTransactionCache() {
        let cache = "/Users/test/Library/Caches/com.antonshakirov.minimo"
        XCTAssertTrue(UpdateRollbackProtocol.isValidAcknowledgementPath(
            cache + "/hop-update-transaction-ABC/launch-stable",
            cacheDirectory: cache
        ))
        XCTAssertFalse(UpdateRollbackProtocol.isValidAcknowledgementPath(
            "/Users/test/Documents/launch-stable",
            cacheDirectory: cache
        ))
        XCTAssertFalse(UpdateRollbackProtocol.isValidAcknowledgementPath(
            cache + "/hop-update-transaction-ABC/arbitrary-file",
            cacheDirectory: cache
        ))
        XCTAssertFalse(UpdateRollbackProtocol.isValidAcknowledgementPath(
            cache + "/hop-update-transaction-/launch-stable",
            cacheDirectory: cache
        ))
        XCTAssertFalse(UpdateRollbackProtocol.isValidAcknowledgementPath(
            cache + "/hop-update-transaction-../launch-stable",
            cacheDirectory: cache
        ))
    }

    func testCleanExitMarkerIsSiblingOfStableAcknowledgement() {
        let stable = "/tmp/hop-update-transaction-ABC/launch-stable"
        XCTAssertEqual(
            UpdateRollbackProtocol.cleanExitPath(forAcknowledgementPath: stable),
            "/tmp/hop-update-transaction-ABC/clean-exit"
        )
    }

}
