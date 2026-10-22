import Foundation

/// The display unit for a torrent speed limit. The canonical stored value is
/// always KB/s; the UI can show and accept it as either unit.
public enum RateUnit: String, CaseIterable, Sendable {
    case kb
    case mb
}

/// Torrent speed-limit conversion. Storage is canonical KB/s (0 = unlimited);
/// the UI may display and enter it as KB/s or MB/s. 1 MB = 1000 KB — the same
/// decimal convention the torrent card uses when it prints speeds (bytes ÷ 10^6).
public enum RateLimit {
    public static let kbPerMB = 1000
    /// Upper bound on the canonical KB/s value: MB mode allows up to 9999.9 MB.
    public static let maxKB = 9_999_900

    /// Filter a torrent rate while editing. The filter must preserve every
    /// canonical KB/s limit through the UI, not only the core parser/display.
    /// MB mode allows 4 digits before and 3 digits after the decimal point;
    /// KB mode allows 7 digits (maxKB itself has 7 digits).
    public static func filterInput(_ raw: String, unit: RateUnit) -> String {
        switch unit {
        case .kb:
            return String(raw.filter(\.isNumber).prefix(7))
        case .mb:
            var seenDot = false, intDigits = 0, fracDigits = 0
            var out = ""
            for ch in raw {
                if ch.isNumber {
                    if seenDot {
                        guard fracDigits < 3 else { continue }
                        fracDigits += 1
                    } else {
                        guard intDigits < 4 else { continue }
                        intDigits += 1
                    }
                    out.append(ch)
                } else if ch == ".", !seenDot {
                    seenDot = true
                    out.append(ch)
                }
            }
            return out
        }
    }

    /// Clamp a canonical KB/s value into the valid range (0…maxKB).
    public static func clampKB(_ kb: Int) -> Int {
        max(0, min(kb, maxKB))
    }

    /// Render a canonical KB/s value in the given unit. KB mode is the integer;
    /// MB mode preserves all three KB-derived decimal places, trimming trailing
    /// zeros — otherwise 1…49 KB/s would look like "0" (unlimited), and editing
    /// the shown value would silently change the limit.
    public static func display(kb: Int, unit: RateUnit) -> String {
        switch unit {
        case .kb:
            return "\(clampKB(kb))"
        case .mb:
            let amount = clampKB(kb)
            let whole = amount / kbPerMB
            let remainder = amount % kbPerMB
            guard remainder != 0 else { return "\(whole)" }
            var fractional = String(format: "%03d", remainder)
            while fractional.last == "0" { fractional.removeLast() }
            return "\(whole).\(fractional)"
        }
    }

    /// Parse user input in the given unit into a canonical KB/s value. An empty
    /// string or "0" is 0 (unlimited). KB mode takes digits only; MB mode takes a
    /// decimal (digits with at most one dot). Anything else returns nil (= keep
    /// the current value). The result is clamped to maxKB.
    public static func parse(_ text: String, unit: RateUnit) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        switch unit {
        case .kb:
            guard trimmed.allSatisfy(\.isNumber), let v = Int(trimmed) else { return nil }
            return clampKB(v)
        case .mb:
            let dots = trimmed.filter { $0 == "." }.count
            guard dots <= 1, trimmed.allSatisfy({ $0.isNumber || $0 == "." }),
                  let mb = Double(trimmed), mb >= 0 else { return nil }
            // Clamp before converting to Int: large pasted numbers (including
            // Double.infinity) otherwise trigger a runtime conversion trap.
            let capMB = Double(maxKB) / Double(kbPerMB)
            if mb >= capMB { return maxKB }
            return clampKB(Int((mb * Double(kbPerMB)).rounded()))
        }
    }
}
