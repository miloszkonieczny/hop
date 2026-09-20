import Foundation

/// High-confidence secret detection for clipboard-history persistence.
///
/// This is intentionally conservative: Hop should skip credentials it can
/// identify with strong evidence, without turning normal source code, hashes,
/// URLs, UUIDs or prose into false positives. Detection happens locally and
/// returns only a boolean; secret material is never logged or transformed.
public enum ClipboardSecretDetector {
    private struct Pattern {
        let expression: NSRegularExpression
        let capturedCredentialGroup: Int?

        init(_ source: String, options: NSRegularExpression.Options = [],
             capturedCredentialGroup: Int? = nil) {
            // All patterns are compile-time constants. A construction failure is
            // a programmer error, not clipboard input that should be recoverable.
            self.expression = try! NSRegularExpression(
                pattern: source,
                options: options
            )
            self.capturedCredentialGroup = capturedCredentialGroup
        }
    }

    /// Provider-defined formats have enough structure to classify directly.
    /// Public-key formats (ssh-ed25519, ssh-rsa), publishable Stripe keys and
    /// ordinary opaque hashes are deliberately absent.
    private static let structuredPatterns: [Pattern] = [
        // PEM / OpenSSH / PGP private-key material.
        Pattern(#"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----"#),
        Pattern(#"-----BEGIN OPENSSH PRIVATE KEY-----"#),
        Pattern(#"-----BEGIN PGP PRIVATE KEY BLOCK-----"#),

        // JWT / bearer-style credentials. JWTs commonly begin "eyJ" because the
        // encoded JOSE header is JSON; requiring three substantial segments
        // avoids treating dotted version strings as credentials.
        Pattern(#"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b"#),

        // GitHub classic/fine-grained/OAuth/app tokens.
        Pattern(#"\bgh[pousr]_[A-Za-z0-9]{20,}\b"#),
        Pattern(#"\bgithub_pat_[A-Za-z0-9_]{20,}\b"#),

        // Common API-token formats relevant to developer workflows.
        Pattern(#"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b"#),
        Pattern(#"\bgsk_[A-Za-z0-9]{20,}\b"#),
        Pattern(#"\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,}\b"#),
        Pattern(#"\bwhsec_[A-Za-z0-9]{16,}\b"#),
        Pattern(#"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"#),
        Pattern(#"\bxapp-[A-Za-z0-9-]{20,}\b"#),
        Pattern(#"\bnpm_[A-Za-z0-9]{20,}\b"#),
        Pattern(#"\bpypi-[A-Za-z0-9_-]{20,}\b"#),
        Pattern(#"\bhf_[A-Za-z0-9]{20,}\b"#),
        Pattern(#"\bglpat-[A-Za-z0-9_-]{20,}\b"#),
        Pattern(#"\bdckr_pat_[A-Za-z0-9_-]{20,}\b"#),
        Pattern(#"\bsb_secret_[A-Za-z0-9_-]{20,}\b"#),
        Pattern(#"\bsbp_[A-Za-z0-9]{20,}\b"#),
        Pattern(#"\bAIza[0-9A-Za-z_-]{30,}\b"#),

        // Telegram bot tokens are bearer credentials with a stable shape.
        Pattern(#"\b[0-9]{8,12}:[A-Za-z0-9_-]{30,}\b"#),

        // Explicit HTTP authorization headers.
        Pattern(
            #"\bauthorization\s*:\s*bearer\s+([A-Za-z0-9._~+/=-]{16,})"#,
            options: [.caseInsensitive],
            capturedCredentialGroup: 1
        ),
        Pattern(
            #"\bauthorization\s*:\s*basic\s+([A-Za-z0-9+/=]{12,})"#,
            options: [.caseInsensitive],
            capturedCredentialGroup: 1
        ),

        // Credentials embedded in a URL, e.g. postgres://user:password@host.
        Pattern(
            #"\b[a-z][a-z0-9+.-]*://[^\s/:@]+:([^\s/@]{8,})@"#,
            options: [.caseInsensitive],
            capturedCredentialGroup: 1
        ),
    ]

    /// Generic configuration labels catch providers whose token format has no
    /// unique prefix. They require both a sensitive NAME and a credential-like
    /// VALUE; placeholders and low-entropy examples remain persistable.
    private static let labelledCredential = Pattern(
        #"(?:^|[\s{,])["']?(?:api[_-]?(?:key|token)|access[_-]?token|auth[_-]?token|refresh[_-]?token|client[_-]?secret|secret(?:[_-]?key)?|password|passwd|private[_-]?key|database[_-]?password|db[_-]?password|service[_-]?role[_-]?key|(?:cloudflare|cf)[_-]?api[_-]?token|aws[_-]?secret[_-]?access[_-]?key|aws[_-]?session[_-]?token)["']?\s*[:=]\s*["']?([^\s"',;}]{12,})"#,
        options: [.caseInsensitive, .anchorsMatchLines],
        capturedCredentialGroup: 1
    )

    public static func containsSecret(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        for pattern in structuredPatterns {
            guard let match = pattern.expression.firstMatch(
                in: text,
                options: [],
                range: range
            ) else { continue }

            guard let group = pattern.capturedCredentialGroup else {
                return true
            }
            let value = captured(group, from: match, in: text)
            if value.map(looksCredentialLike) ?? false {
                return true
            }
        }

        for match in labelledCredential.expression.matches(
            in: text,
            options: [],
            range: range
        ) {
            if let value = captured(1, from: match, in: text),
               looksCredentialLike(value) {
                return true
            }
        }

        return false
    }

    private static func captured(
        _ group: Int,
        from match: NSTextCheckingResult,
        in text: String
    ) -> String? {
        guard group < match.numberOfRanges,
              let range = Range(match.range(at: group), in: text)
        else { return nil }
        return String(text[range])
    }

    /// Generic labelled values need an additional entropy-shaped gate. This is
    /// not cryptographic entropy estimation; it is a false-positive filter.
    private static func looksCredentialLike(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        guard value.count >= 12, !looksLikePlaceholder(value) else { return false }

        var hasLower = false
        var hasUpper = false
        var hasDigit = false
        var hasSymbol = false

        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 97...122: hasLower = true
            case 65...90: hasUpper = true
            case 48...57: hasDigit = true
            default: hasSymbol = true
            }
        }

        let classes = [hasLower, hasUpper, hasDigit, hasSymbol].filter { $0 }.count
        if value.count >= 32 { return classes >= 2 }
        if value.count >= 20 { return classes >= 3 }

        // Shorter values are accepted only for explicit authorization/URL
        // contexts and must be compositionally strong.
        return classes == 4
    }

    private static func looksLikePlaceholder(_ value: String) -> Bool {
        let lower = value.lowercased()
        let markers = [
            "your_api_key", "your-api-key", "your_token", "your-token",
            "your_secret", "your-secret", "your_password", "your-password",
            "replace_me", "replace-me", "changeme", "placeholder",
            "example", "dummy", "redacted", "<token>", "<secret>",
            "${", "{{",
        ]
        if markers.contains(where: { lower.contains($0) }) { return true }

        // Repeated mask/example characters are documentation, not credentials.
        let compact = lower.filter { !$0.isWhitespace }
        if !compact.isEmpty,
           Set(compact).isSubset(of: Set("x*.-_")),
           compact.count >= 8 {
            return true
        }
        return false
    }
}
