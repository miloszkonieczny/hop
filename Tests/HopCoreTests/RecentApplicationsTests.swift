import XCTest
@testable import HopCore

final class RecentApplicationsTests: XCTestCase {
    private func app(_ id: String, _ name: String, path: String? = nil) -> RecentApplication {
        RecentApplication(
            bundleIdentifier: id,
            name: name,
            path: path ?? "/Applications/\(name).app"
        )
    }

    func testRecordingMovesExistingAppToFrontWithoutDuplication() {
        let safari = app("com.apple.Safari", "Safari")
        let finder = app("com.apple.finder", "Finder")
        let existing = [finder, safari]

        XCTAssertEqual(
            RecentApplications.recording(safari, in: existing),
            [safari, finder]
        )
    }

    func testRecordingCapsListAtFive() {
        var items: [RecentApplication] = []
        for index in 0..<7 {
            items = RecentApplications.recording(
                app("example.\(index)", "App \(index)"),
                in: items
            )
        }
        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items.first?.bundleIdentifier, "example.6")
        XCTAssertEqual(items.last?.bundleIdentifier, "example.2")
    }

    func testPathIsFallbackIdentityWithoutBundleIdentifier() {
        let first = RecentApplication(bundleIdentifier: nil, name: "Tool", path: "/A/Tool.app")
        let renamed = RecentApplication(bundleIdentifier: nil, name: "Tool 2", path: "/A/Tool.app")

        XCTAssertEqual(
            RecentApplications.recording(renamed, in: [first]),
            [renamed]
        )
    }

    func testSanitizedDropsInvalidAndDuplicateRows() {
        let safari = app("com.apple.Safari", "Safari")
        let duplicate = app("com.apple.Safari", "Safari renamed")
        let blank = RecentApplication(bundleIdentifier: "bad", name: "", path: "/bad.app")

        XCTAssertEqual(
            RecentApplications.sanitized([safari, duplicate, blank]),
            [safari]
        )
    }

    func testZeroCapacityStoresNothing() {
        XCTAssertEqual(
            RecentApplications.recording(app("x", "X"), in: [], maximumCount: 0),
            []
        )
    }
}
