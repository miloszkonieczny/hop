import XCTest
@testable import HopCore

/// Regression coverage for integer overflow, nonfinite values and lossy rate displays.
final class DefensiveFormattingTests: XCTestCase {
    func testDurationParsingRejectsOverflowRatherThanCrashing() {
        XCTAssertNil(DurationField.parse("9223372036854775807:00"))
        XCTAssertNil(DurationField.parse("9223372036854775807:1"))
        XCTAssertNil(DurationField.parse("99999999999999999999999999999"))
        XCTAssertEqual(DurationField.parse("90:00"), 5_400)
    }

    func testDurationFormattingHandlesNonfiniteAndHugeNumbers() {
        XCTAssertEqual(DurationField.text(for: .nan), "0:00:00")
        XCTAssertEqual(DurationField.text(for: -.infinity), "0:00:00")
        XCTAssertEqual(DurationField.text(for: .infinity), "0:00:00")
        XCTAssertEqual(DurationField.text(for: 1.0e30),
                       DurationField.text(for: Double(Int.max)))
    }

    func testTimerFormattingHandlesNonfiniteAndHugeNumbers() {
        for amount in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(TimeFormatting.display(amount), "00:00:00")
            XCTAssertEqual(TimeFormatting.short(amount), "00:00")
        }
        XCTAssertEqual(TimeFormatting.display(59.1), "00:01:00")
        XCTAssertEqual(TimeFormatting.short(3_601), "1:00:01")
        XCTAssertEqual(TimeFormatting.display(1.0e30),
                       TimeFormatting.display(Double(Int.max)))
    }

    func testRateParsingClampsHugeInputsRatherThanCrashing() {
        XCTAssertEqual(RateLimit.parse("99999999999999999999999999999999", unit: .mb),
                       RateLimit.maxKB)
        XCTAssertEqual(RateLimit.parse(String(repeating: "9", count: 400), unit: .mb),
                       RateLimit.maxKB)
        XCTAssertNil(RateLimit.parse("-1", unit: .mb))
    }

    func testRateDisplayRoundTripsEveryKBIncludingTinyLimits() {
        for kb in [0, 1, 9, 49, 50, 99, 101, 999, 1_001, 1_234, 1_500, 2_000, 9_999_900] {
            let text = RateLimit.display(kb: kb, unit: .mb)
            XCTAssertEqual(RateLimit.parse(text, unit: .mb), kb, "rate: \(kb) => \(text)")
        }
        XCTAssertEqual(RateLimit.display(kb: 1, unit: .mb), "0.001")
        XCTAssertEqual(RateLimit.display(kb: 49, unit: .mb), "0.049")
        XCTAssertEqual(RateLimit.display(kb: 1_234, unit: .mb), "1.234")
    }

    func testRateFieldFilterPreservesCanonicalMBValues() {
        for kb in [0, 1, 9, 49, 99, 101, 999, 1_001, 1_234, 9_999_900] {
            let shown = RateLimit.display(kb: kb, unit: .mb)
            let filtered = RateLimit.filterInput(shown, unit: .mb)
            XCTAssertEqual(filtered, shown, "input filter changed \(kb) KB/s")
            XCTAssertEqual(RateLimit.parse(filtered, unit: .mb), kb)
        }
        XCTAssertEqual(RateLimit.filterInput("1.23456", unit: .mb), "1.234")
        XCTAssertEqual(RateLimit.filterInput("9999.999", unit: .mb), "9999.999")
    }

    func testRateFieldFilterAcceptsMaxCanonicalKBInput() {
        XCTAssertEqual(RateLimit.filterInput("9999900", unit: .kb), "9999900")
        XCTAssertEqual(RateLimit.parse(RateLimit.filterInput("9999900", unit: .kb), unit: .kb),
                       RateLimit.maxKB)
    }

    func testSharedRoundingSupportsAllTimerReadoutStyles() {
        for value in [Double.nan, Double.infinity, -Double.infinity, -12] {
            XCTAssertEqual(TimeFormatting.wholeSeconds(value), 0)
        }
        XCTAssertEqual(TimeFormatting.wholeSeconds(59.1), 60)
        XCTAssertEqual(TimeFormatting.wholeSeconds(1.0e30), Int.max)
    }

}
