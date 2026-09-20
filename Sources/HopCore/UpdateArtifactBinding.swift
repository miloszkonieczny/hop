import Foundation

/// Binds an update manifest to the app bundle that was actually downloaded.
///
/// The release signature authenticates the archive bytes, but the manifest is
/// fetched separately. A compromised mirror must therefore not be able to pair
/// an old, legitimately signed archive with a fabricated newer version number.
/// Installation is allowed only when the extracted bundle identifies itself as
/// exactly the release the manifest advertised and contains code for the
/// architecture of the process that is about to replace itself.
public enum UpdateArtifactBinding {
    /// Mach-O CPU type values reported by Bundle.executableArchitectures.
    public static let x86_64CPUType = 0x0100_0007
    public static let arm64CPUType = 0x0100_000C

    public static func accepts(
        manifestVersion: String,
        embeddedVersion: String?,
        expectedBundleIdentifier: String?,
        embeddedBundleIdentifier: String?,
        expectedCPUType: Int,
        executableCPUTypes: [Int]
    ) -> Bool {
        guard !manifestVersion.isEmpty,
              embeddedVersion == manifestVersion,
              let expectedBundleIdentifier,
              !expectedBundleIdentifier.isEmpty,
              embeddedBundleIdentifier == expectedBundleIdentifier
        else { return false }

        return executableCPUTypes.contains(expectedCPUType)
    }
}
