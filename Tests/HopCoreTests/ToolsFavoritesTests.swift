import XCTest
@testable import HopCore

final class ToolsFavoritesTests: XCTestCase {
    private let valid: Set<String> = [
        "capture.screenshotToolbar",
        "capture.area",
        "capture.ocr",
        "capture.markup",
        "files.convert",
        "files.archive",
        "files.uninstall",
        "window.minimize",
        "window.maximize",
    ]

    func testMissingOrDefaultMarkerUsesDefaultsFilteredByCatalog() {
        let expected = [
            "capture.screenshotToolbar",
            "capture.area",
            "capture.ocr",
            "files.convert",
            "window.minimize",
        ]
        XCTAssertEqual(ToolsFavorites.resolved(raw: nil, validIDs: valid), expected)
        XCTAssertEqual(
            ToolsFavorites.resolved(raw: ToolsFavorites.defaultMarker, validIDs: valid),
            expected
        )
    }

    func testExplicitEmptyDoesNotRestoreDefaults() {
        XCTAssertEqual(
            ToolsFavorites.resolved(raw: ToolsFavorites.emptyMarker, validIDs: valid),
            []
        )
        XCTAssertEqual(ToolsFavorites.encoded([]), ToolsFavorites.emptyMarker)
    }

    func testResolutionDropsUnknownDuplicatesAndCaps() {
        let raw = [
            "capture.area",
            "unknown",
            "capture.area",
            "capture.ocr",
            "capture.markup",
            "files.convert",
            "files.archive",
            "files.uninstall",
            "window.minimize",
        ].joined(separator: ",")

        XCTAssertEqual(
            ToolsFavorites.resolved(raw: raw, validIDs: valid),
            [
                "capture.area",
                "capture.ocr",
                "capture.markup",
                "files.convert",
                "files.archive",
                "files.uninstall",
            ]
        )
    }

    func testToggleAddsAndRemovesWithoutReorderingOthers() {
        let initial = ["capture.area", "files.convert"]
        XCTAssertEqual(
            ToolsFavorites.toggling("capture.ocr", in: initial, validIDs: valid),
            ["capture.area", "files.convert", "capture.ocr"]
        )
        XCTAssertEqual(
            ToolsFavorites.toggling("capture.area", in: initial, validIDs: valid),
            ["files.convert"]
        )
    }

    func testToggleRefusesUnknownOrSeventhFavorite() {
        let full = [
            "capture.screenshotToolbar",
            "capture.area",
            "capture.ocr",
            "capture.markup",
            "files.convert",
            "files.archive",
        ]
        XCTAssertEqual(
            ToolsFavorites.toggling("files.uninstall", in: full, validIDs: valid),
            full
        )
        XCTAssertEqual(
            ToolsFavorites.toggling("nope", in: [], validIDs: valid),
            []
        )
    }
}
