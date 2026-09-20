import XCTest
@testable import HopCore

final class UpdateArtifactBindingTests: XCTestCase {
    private let bundleID = "com.antonshakirov.minimo"

    private func accepts(
        manifestVersion: String = "2.2.0",
        embeddedVersion: String? = "2.2.0",
        expectedBundleIdentifier: String? = "com.antonshakirov.minimo",
        embeddedBundleIdentifier: String? = "com.antonshakirov.minimo",
        expectedCPUType: Int = UpdateArtifactBinding.arm64CPUType,
        executableCPUTypes: [Int] = [UpdateArtifactBinding.arm64CPUType]
    ) -> Bool {
        UpdateArtifactBinding.accepts(
            manifestVersion: manifestVersion,
            embeddedVersion: embeddedVersion,
            expectedBundleIdentifier: expectedBundleIdentifier,
            embeddedBundleIdentifier: embeddedBundleIdentifier,
            expectedCPUType: expectedCPUType,
            executableCPUTypes: executableCPUTypes
        )
    }

    func testExactArtifactBindingIsAccepted() {
        XCTAssertTrue(accepts())
    }

    func testUniversalArtifactContainingExpectedArchitectureIsAccepted() {
        XCTAssertTrue(accepts(executableCPUTypes: [
            UpdateArtifactBinding.arm64CPUType,
            UpdateArtifactBinding.x86_64CPUType,
        ]))
    }

    func testManifestVersionCannotRelabelOlderSignedArtifact() {
        XCTAssertFalse(accepts(
            manifestVersion: "99.0.0",
            embeddedVersion: "2.1.4"
        ))
    }

    func testMissingEmbeddedVersionIsRejected() {
        XCTAssertFalse(accepts(embeddedVersion: nil))
    }

    func testWrongBundleIdentifierIsRejected() {
        XCTAssertFalse(accepts(embeddedBundleIdentifier: "example.other-app"))
    }

    func testMissingRunningBundleIdentifierIsRejected() {
        XCTAssertFalse(accepts(expectedBundleIdentifier: nil))
    }

    func testWrongArchitectureIsRejected() {
        XCTAssertFalse(accepts(
            expectedCPUType: UpdateArtifactBinding.arm64CPUType,
            executableCPUTypes: [UpdateArtifactBinding.x86_64CPUType]
        ))
    }

    func testMissingArchitectureMetadataIsRejected() {
        XCTAssertFalse(accepts(executableCPUTypes: []))
    }

    func testEmptyManifestVersionIsRejected() {
        XCTAssertFalse(accepts(manifestVersion: "", embeddedVersion: ""))
    }
}
