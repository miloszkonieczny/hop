import XCTest
@testable import HopCore

final class HopSpaceTests: XCTestCase {
    func testBuiltInModulesHaveExpectedSemanticHomes() {
        XCTAssertEqual(HopSpace.containing(module: "timer"), .work)
        XCTAssertEqual(HopSpace.containing(module: "tracker"), .work)
        XCTAssertEqual(HopSpace.containing(module: "todos"), .work)
        XCTAssertEqual(HopSpace.containing(module: "clipboard"), .work)

        XCTAssertEqual(HopSpace.containing(module: "system"), .mac)
        XCTAssertEqual(HopSpace.containing(module: "speedtest"), .mac)
        XCTAssertEqual(HopSpace.containing(module: "vpn"), .mac)
        XCTAssertEqual(HopSpace.containing(module: "torrent"), .mac)
        XCTAssertEqual(HopSpace.containing(module: "awake"), .mac)
        XCTAssertEqual(HopSpace.containing(module: "keyboard"), .mac)

        XCTAssertEqual(HopSpace.containing(module: "shot"), .tools)
        XCTAssertEqual(HopSpace.containing(module: "ocr"), .tools)
        XCTAssertEqual(HopSpace.containing(module: "annotate"), .tools)
        XCTAssertEqual(HopSpace.containing(module: "windows"), .tools)
        XCTAssertEqual(HopSpace.containing(module: "convert"), .tools)
        XCTAssertEqual(HopSpace.containing(module: "archive"), .tools)
        XCTAssertEqual(HopSpace.containing(module: "uninstall"), .tools)
        XCTAssertEqual(HopSpace.containing(module: "color"), .tools)
    }

    func testUnknownAndAppShelfModulesRemainReachableInTools() {
        XCTAssertEqual(HopSpace.containing(module: "apps:research"), .tools)
        XCTAssertEqual(HopSpace.containing(module: "future-module"), .tools)
    }

    func testLayoutPreservesLegacyGlobalOrderAndSourceTabIdentity() {
        let first = PanelTab(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            icon: "house",
            moduleKeys: ["timer", "shot", "clipboard"]
        )
        let second = PanelTab(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            icon: "display",
            moduleKeys: ["system", "vpn"]
        )
        let third = PanelTab(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            icon: "clock",
            moduleKeys: ["tracker", "todos"]
        )
        let model = PanelTabsModel(tabs: [first, second, third])

        XCTAssertEqual(
            HopSpaceLayout.placements(in: model, space: .work),
            [
                .init(moduleID: "timer", sourceTabID: first.id),
                .init(moduleID: "clipboard", sourceTabID: first.id),
                .init(moduleID: "tracker", sourceTabID: third.id),
                .init(moduleID: "todos", sourceTabID: third.id),
            ]
        )
        XCTAssertEqual(
            HopSpaceLayout.placements(in: model, space: .mac),
            [
                .init(moduleID: "system", sourceTabID: second.id),
                .init(moduleID: "vpn", sourceTabID: second.id),
            ]
        )
        XCTAssertEqual(
            HopSpaceLayout.placements(in: model, space: .tools),
            [.init(moduleID: "shot", sourceTabID: first.id)]
        )
    }

    func testHiddenModulesStayStoredButDoNotAppearInShell() {
        let tab = PanelTab(icon: "house", moduleKeys: ["timer", "clipboard"])
        var model = PanelTabsModel(tabs: [tab])
        model.setHidden("clipboard", hidden: true)

        XCTAssertEqual(
            HopSpaceLayout.placements(in: model, space: .work).map(\.moduleID),
            ["timer"]
        )
        XCTAssertEqual(model.tabs[0].moduleKeys, ["timer", "clipboard"])
        XCTAssertTrue(model.isHidden("clipboard"))
    }

    func testRestoredSpaceFailsClosedToWork() {
        XCTAssertEqual(HopSpaceLayout.restoredSpace(from: "mac"), .mac)
        XCTAssertEqual(HopSpaceLayout.restoredSpace(from: "tools"), .tools)
        XCTAssertEqual(HopSpaceLayout.restoredSpace(from: "future-value"), .work)
        XCTAssertEqual(HopSpaceLayout.restoredSpace(from: nil), .work)
    }
}
