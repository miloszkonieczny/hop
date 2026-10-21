import XCTest
@testable import HopCore

final class PopoverClickPolicyTests: XCTestCase {
    func testPopoverAndStatusItemClicksDoNotDismiss() {
        XCTAssertFalse(PopoverClickPolicy.shouldDismiss(
            isPanelWindow: true, isStatusItemWindow: false, canBecomeKey: true, isTitled: true))
        XCTAssertFalse(PopoverClickPolicy.shouldDismiss(
            isPanelWindow: false, isStatusItemWindow: true, canBecomeKey: true, isTitled: true))
    }

    func testOnlyOtherKeyCapableTitledWindowsDismiss() {
        XCTAssertTrue(PopoverClickPolicy.shouldDismiss(
            isPanelWindow: false, isStatusItemWindow: false, canBecomeKey: true, isTitled: true))
        XCTAssertFalse(PopoverClickPolicy.shouldDismiss(
            isPanelWindow: false, isStatusItemWindow: false, canBecomeKey: false, isTitled: true))
        XCTAssertFalse(PopoverClickPolicy.shouldDismiss(
            isPanelWindow: false, isStatusItemWindow: false, canBecomeKey: true, isTitled: false))
    }
}
