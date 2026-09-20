import XCTest
@testable import HopCore

final class ClipboardSecretDetectorTests: XCTestCase {
    private func repeated(_ character: Character, _ count: Int) -> String {
        String(repeating: String(character), count: count)
    }

    func testPrivateKeysAreSensitive() {
        XCTAssertTrue(ClipboardSecretDetector.containsSecret(
            "-----BEGIN " + "PRIVATE KEY-----\n" + repeated("A", 40)
        ))
        XCTAssertTrue(ClipboardSecretDetector.containsSecret(
            "-----BEGIN " + "OPENSSH PRIVATE KEY-----\n" + repeated("B", 40)
        ))
        XCTAssertTrue(ClipboardSecretDetector.containsSecret(
            "-----BEGIN " + "PGP PRIVATE KEY BLOCK-----"
        ))
    }

    func testProviderTokensAreSensitive() {
        let secrets = [
            "gh" + "p_" + repeated("a", 32),
            "github_" + "pat_" + repeated("b", 36),
            "sk-" + "proj-" + repeated("c", 36),
            "gsk" + "_" + repeated("d", 36),
            ["sk", "live", repeated("e", 32)].joined(separator: "_"),
            "wh" + "sec_" + repeated("f", 32),
            "xox" + "b-" + repeated("g", 12) + "-" + repeated("h", 24),
            "npm" + "_" + repeated("i", 36),
            "pypi-" + repeated("j", 36),
            "hf" + "_" + repeated("k", 36),
            "glpat-" + repeated("l", 36),
            "dckr_" + "pat_" + repeated("m", 36),
            "sb_" + "secret_" + repeated("n", 36),
            "AIza" + repeated("o", 35),
        ]

        for secret in secrets {
            XCTAssertTrue(
                ClipboardSecretDetector.containsSecret(secret),
                "expected provider-shaped token to be classified"
            )
        }
    }

    func testJWTIsSensitive() {
        let jwt = "eyJ" + repeated("a", 12)
            + "." + repeated("b", 16)
            + "." + repeated("c", 20)
        XCTAssertTrue(ClipboardSecretDetector.containsSecret(jwt))
    }

    func testAuthorizationHeadersAreSensitive() {
        let bearer = "Authorization: " + "Bearer " + "AbCdEf0123456789.AbCdEf0123456789"
        let basicPayload = "QWxh" + "ZGRpbjpvcGVu" + "U2VzYW1l" + "MTIz"
        let basic = "authorization: " + "basic " + basicPayload
        XCTAssertTrue(ClipboardSecretDetector.containsSecret(bearer))
        XCTAssertTrue(ClipboardSecretDetector.containsSecret(basic))
    }

    func testLabelledHighEntropyCredentialsAreSensitive() {
        let values = [
            "API_KEY=" + "AbcdEFGH0123456789+/xyz",
            "client_secret: " + "AbCdEf0123456789_-ZYXW",
            "\"aws_secret_access_key\": \"" + "AbCdEf0123456789+/AbCdEf0123456789+" + "\"",
            "PASSWORD='" + "Correct-Horse-7-Battery-Staple!" + "'",
            "CLOUDFLARE_API_TOKEN=" + "AbCdEf0123456789_-ZYXW987654",
            "service_role_key: " + "AbCdEf0123456789_-ServiceRole",
        ]
        for value in values {
            XCTAssertTrue(ClipboardSecretDetector.containsSecret(value))
        }
    }

    func testCredentialInURLIsSensitive() {
        let url = "postgres://service:" + "AbC123!secure" + "@db.example.com/app"
        XCTAssertTrue(ClipboardSecretDetector.containsSecret(url))
    }

    func testCommonNonSecretsRemainAllowed() {
        let safe = [
            "https://github.com/antonyshakirov/hop",
            "550e8400-e29b-41d4-a716-446655440000",
            "af6c53a2d48ad87422ef606b8a77b13960eb6cd3",
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGenericPublicKey user@example",
            "pk_" + "live_" + repeated("p", 32),
            "The password policy requires at least 12 characters.",
            "Bearer tokens are commonly used for API authentication.",
            "version 2.1.4",
            "https://user@example.com/path",
        ]
        for value in safe {
            XCTAssertFalse(ClipboardSecretDetector.containsSecret(value), value)
        }
    }

    func testPlaceholdersAndDocumentationExamplesRemainAllowed() {
        let safe = [
            "API_KEY=YOUR_API_KEY",
            "token: <token>",
            "password=your-password-here",
            "client_secret=replace_me_before_running",
            "SECRET=" + repeated("x", 32),
            "\"api_key\": \"example-key-" + repeated("1", 20) + "\"",
        ]
        for value in safe {
            XCTAssertFalse(ClipboardSecretDetector.containsSecret(value))
        }
    }

    func testUnlabelledOpaqueDataIsNotGuessedToBeSecret() {
        XCTAssertFalse(ClipboardSecretDetector.containsSecret(
            "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789+/="
        ))
    }
}
