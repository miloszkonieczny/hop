import Foundation

/// The text of a duration being edited, and the way back.
///
/// The field used to shorten what it showed — "11:00" for eleven hours flat,
/// "45" for three quarters of an hour — and a shortened duration is ambiguous:
/// 11:00 reads as eleven minutes just as easily. It always spells out
/// hours:minutes:seconds now, and reads them back the same way, from the right:
/// the last number is seconds, whatever else is there.
public enum DurationField {
    /// The full form, always three parts. Hours are not padded and are not
    /// capped — a task can hold hundreds of them.
    public static func text(for seconds: TimeInterval) -> String {
        // Casting NaN, infinity or a rounded value above Int.max traps in Swift.
        guard seconds.isFinite, seconds > 0 else { return "0:00:00" }
        let rounded = seconds.rounded()
        let total = rounded >= Double(Int.max) ? Int.max : Int(rounded)
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// Reads a typed duration. Parts are counted from the RIGHT, so a lone
    /// number is seconds and a pair is minutes and seconds — the same reading
    /// order the field itself shows. Over-large parts are allowed and simply
    /// add up (90 minutes is an hour and a half), because correcting somebody
    /// mid-edit is worse than understanding them.
    ///
    /// nil for empty or unparseable input, which the callers treat as "cancel".
    public static func parse(_ raw: String) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count <= 3 else { return nil }

        var seconds = 0
        for (index, part) in parts.reversed().enumerated() {
            // an empty slot reads as zero: "1::30" is a minute and a half's
            // worth of typing, not a refusal
            let value = part.isEmpty ? 0 : Int(part)
            guard let value, value >= 0 else { return nil }
            let multiplier = index == 0 ? 1 : (index == 1 ? 60 : 3600)
            let (component, multiplyOverflow) = value.multipliedReportingOverflow(by: multiplier)
            guard !multiplyOverflow else { return nil }
            let (total, addOverflow) = seconds.addingReportingOverflow(component)
            guard !addOverflow else { return nil }
            seconds = total
        }
        return TimeInterval(seconds)
    }
}
