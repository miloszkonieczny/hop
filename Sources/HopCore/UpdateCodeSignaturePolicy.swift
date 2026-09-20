import Foundation

/// The Apple code-signing identity an official Hop update must satisfy.
///
/// Ed25519 authenticates the downloaded archive. This independent macOS
/// requirement proves that the extracted app is also distribution-signed as Hop
/// by the expected Apple Developer team before the updater removes quarantine or
/// replaces the installed application.
public enum UpdateCodeSignaturePolicy {
    public static let expectedBundleIdentifier = "com.antonshakirov.minimo"
    public static let expectedTeamIdentifier = "8GL36WUJPX"

    /// Requirement language follows Apple's Developer ID designated-requirement
    /// model: Apple-issued chain + Developer ID CA + Developer ID Application
    /// leaf + stable Team ID + Hop's stable code-signing identifier.
    public static var developerIDRequirement: String {
        "anchor apple generic" +
        " and identifier \"" + expectedBundleIdentifier + "\"" +
        " and certificate 1[field.1.2.840.113635.100.6.2.6] exists" +
        " and certificate leaf[field.1.2.840.113635.100.6.1.13] exists" +
        " and certificate leaf[subject.OU] = \"" + expectedTeamIdentifier + "\""
    }

    /// Arguments are kept pure and testable; UpdateChecker invokes /usr/bin/codesign
    /// directly with Process, so no shell parses the path or the requirement.
    public static func verificationArguments(appPath: String) -> [String] {
        [
            "--verify",
            "--strict",
            "--all-architectures",
            "-R",
            "=" + developerIDRequirement,
            appPath,
        ]
    }
}
