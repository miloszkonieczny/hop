import XCTest
@testable import HopCore

final class HopActionTests: XCTestCase {
    func testCorePersonalActionsExistOnce() {
        let ids = HopActionCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)

        for id in [
            "capture.screenshotToolbar",
            "capture.area",
            "capture.ocr",
            "window.minimize",
            "focus.timer25",
            "network.protonVPN",
        ] {
            XCTAssertTrue(ids.contains(id), id)
        }
    }

    func testScreenshotQueryPrefersNativeToolbar() {
        let results = HopActionCatalog.search("screenshot")
        XCTAssertEqual(results.first?.id, "capture.screenshotToolbar")
        XCTAssertTrue(results.contains { $0.id == "capture.area" })
    }

    func testShortAliasesFindExpectedActions() {
        XCTAssertEqual(HopActionCatalog.search("scr").first?.id, "capture.screenshotToolbar")
        XCTAssertEqual(HopActionCatalog.search("ocr").first?.id, "capture.ocr")
        XCTAssertEqual(HopActionCatalog.search("min").first?.id, "window.minimize")
        XCTAssertEqual(HopActionCatalog.search("vpn").first?.id, "network.protonVPN")
    }

    func testMultiTokenTimerQueryIsDeterministic() {
        XCTAssertEqual(HopActionCatalog.search("timer 25").first?.id, "focus.timer25")
        XCTAssertEqual(HopActionCatalog.search("25 focus").first?.id, "focus.timer25")
    }

    func testSystemTermsReachMonitor() {
        XCTAssertEqual(HopActionCatalog.search("cpu").first?.id, "navigate.system")
        XCTAssertEqual(HopActionCatalog.search("memory").first?.id, "navigate.system")
        XCTAssertEqual(HopActionCatalog.search("temperature").first?.id, "navigate.system")
    }

    func testEveryActionLivesInOneSemanticSpaceAndOptionalModuleIsKnown() {
        for action in HopActionCatalog.all {
            if let module = action.requiredModuleID {
                XCTAssertTrue(
                    ModuleCatalog.allIDs.contains(module),
                    "\(action.id) requires unknown module \(module)"
                )
                XCTAssertEqual(HopSpace.containing(module: module), action.space)
            }
        }
    }

    func testEveryExecutionKindHasExactlyOneCatalogAction() {
        XCTAssertEqual(
            Set(HopActionCatalog.all.map(\.execution)),
            Set(HopAction.Execution.allCases)
        )
        XCTAssertEqual(
            Set(HopActionCatalog.all.map(\.execution)).count,
            HopActionCatalog.all.count
        )
    }

    func testSearchRequiresEveryToken() {
        XCTAssertTrue(HopActionCatalog.search("vpn screenshot").isEmpty)
    }

    func testStableCatalogOrderBreaksTies() {
        let actions = [
            HopAction(
                id: "a", title: "Alpha Tool", subtitle: "",
                keywords: ["tool"], category: .navigate, space: .tools,
                systemImage: "a",
                execution: .showClipboard
            ),
            HopAction(
                id: "b", title: "Beta Tool", subtitle: "",
                keywords: ["tool"], category: .navigate, space: .tools,
                systemImage: "b",
                execution: .showClipboard
            ),
        ]
        XCTAssertEqual(HopActionCatalog.search("tool", in: actions).map(\.id), ["a", "b"])
    }

    func testEmptyQueryReturnsPersonalQuickActionsFirst() {
        XCTAssertEqual(
            HopActionCatalog.search("", limit: 6).map(\.id),
            [
                "capture.screenshotToolbar",
                "capture.area",
                "capture.ocr",
                "network.protonVPN",
                "window.minimize",
                "focus.timer25",
            ]
        )
    }
}
