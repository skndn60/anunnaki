import Foundation

/// Detects likely duplicate entity names at entry time. Comparison is
/// normalization-based (case-, hyphen-, space- and punctuation-insensitive)
/// so "Ea Nasir" and "Ea-nasir" collide, mirroring `Migration.seedNameKey`.
/// Warnings are informational only — legitimate homonyms (e.g. the two
/// deities named Uraš) must stay creatable.
package enum NameDuplicateCheck {
    package static func normalizedKey(_ raw: String) -> String {
        String(raw.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// Returns the existing names colliding with `candidate`, or nil when the
    /// name is free. Deduplicated and sorted for display.
    package static func warning(candidate: String, existingNames: [String]) -> String? {
        let key = normalizedKey(candidate)
        guard !key.isEmpty else { return nil }
        var seen = Set<String>()
        var matches: [String] = []
        for name in existingNames where normalizedKey(name) == key {
            if seen.insert(name).inserted { matches.append(name) }
        }
        guard !matches.isEmpty else { return nil }
        return matches.sorted().joined(separator: ", ")
    }
}
