import XCTest
@testable import HopCore

final class ProcessUsageSummaryTests: XCTestCase {
    func testParsesLeadersAndPreservesNamesWithSpaces() {
        let output = """
          101   7.5   204800 /System/Library/WindowServer
          202  13.2   150000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
          303   2.1   900000 /Applications/Xcode.app/Contents/MacOS/Xcode
        """

        let summary = ProcessUsageSummary.parsePS(output)

        XCTAssertEqual(summary.topCPU?.pid, 202)
        XCTAssertEqual(summary.topCPU?.name, "Google Chrome")
        XCTAssertEqual(summary.topCPU?.cpuPercent, 13.2)
        XCTAssertEqual(summary.topMemory?.pid, 303)
        XCTAssertEqual(summary.topMemory?.name, "Xcode")
        XCTAssertEqual(summary.topMemory?.memoryBytes, 900000 * 1024)
    }

    func testExcludesHopProcess() {
        let output = """
          42  90.0  900000 /Applications/Hop.app/Contents/MacOS/Hop
          99  12.0  200000 /System/Library/WindowServer
        """

        let summary = ProcessUsageSummary.parsePS(output, excludingPID: 42)

        XCTAssertEqual(summary.topCPU?.pid, 99)
        XCTAssertEqual(summary.topMemory?.pid, 99)
    }

    func testMalformedLinesAreIgnored() {
        let output = """
          rubbish
          12 nope 100 /bin/a
          13 4.2 nope /bin/b
          14 5.1 250 /bin/c
        """

        let summary = ProcessUsageSummary.parsePS(output)

        XCTAssertEqual(summary.topCPU?.pid, 14)
        XCTAssertEqual(summary.topMemory?.pid, 14)
    }

    func testEmptyOutputProducesNoLeaders() {
        XCTAssertEqual(
            ProcessUsageSummary.parsePS(""),
            ProcessUsageSummary(topCPU: nil, topMemory: nil)
        )
    }
}
