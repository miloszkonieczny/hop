import XCTest
@testable import HopCore

final class UpdateCodeSignaturePolicyTests: XCTestCase {
    func testRequirementPinsHopDeveloperIDIdentity() {
        let requirement = UpdateCodeSignaturePolicy.developerIDRequirement

        XCTAssertTrue(requirement.contains("anchor apple generic"))
        XCTAssertTrue(requirement.contains(
            "identifier \"com.antonshakirov.minimo\""
        ))
        XCTAssertTrue(requirement.contains(
            "certificate 1[field.1.2.840.113635.100.6.2.6] exists"
        ))
        XCTAssertTrue(requirement.contains(
            "certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
        ))
        XCTAssertTrue(requirement.contains(
            "certificate leaf[subject.OU] = \"8GL36WUJPX\""
        ))
    }

    func testVerificationIsStrictAndChecksEveryArchitecture() {
        let path = "/tmp/Hop candidate.app"
        let arguments = UpdateCodeSignaturePolicy.verificationArguments(appPath: path)

        XCTAssertEqual(arguments, [
            "--verify",
            "--strict",
            "--all-architectures",
            "-R",
            "=" + UpdateCodeSignaturePolicy.developerIDRequirement,
            path,
        ])
    }

    func testRequirementDoesNotAcceptDevelopmentOrAdHocIdentityClasses() {
        let requirement = UpdateCodeSignaturePolicy.developerIDRequirement

        XCTAssertFalse(requirement.contains("Apple Development"))
        XCTAssertFalse(requirement.contains("anchor apple and"))
        XCTAssertTrue(requirement.contains("1.2.840.113635.100.6.1.13"))
    }
}
