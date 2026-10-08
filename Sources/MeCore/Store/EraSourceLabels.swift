import Foundation
import SwiftData

/// The regnal numbering a source uses for an era, read from that source's citation.
///
/// "Chaldean Dynasty" carries no ordinal, yet the article it was taken from heads that
/// section "Dynasty X". The numeral is a fact about the *source's heading*, not about the
/// era, so it lives in `Citation.location` where the rest of the store's source
/// attribution lives and not in a new `Era` property — a second copy of the same fact
/// would be a second thing to forget to update, and would need a column added to a
/// model to hold.
///
/// Only the king-list citation carries a `Dynasty <numeral>` location. The Sumerian
/// dynasties ("First dynasty of Kish" … "Dynasty of Isin") are numbered by a different
/// work and have no such citation, so `eraSourceNumeral` returns nil for them and the
/// suffix is simply absent rather than wrong.
package enum EraSourceLabels {
    /// "Dynasty X" as written in a citation location, or nil when no citation for this
    /// era uses that shape. Matched per citation rather than by source name so a user's
    /// own renamed source still works, and so a citation on some *other* work cannot
    /// stamp a Babylonian numeral onto a Sumerian era.
    package static func numeral(for era: Era, in citations: [Citation]) -> String? {
        let eraKey = NameDuplicateCheck.normalizedKey(era.name)
        for citation in citations where citation.safeEntityType == .era {
            guard NameDuplicateCheck.normalizedKey(citation.safeEntityName) == eraKey,
                  let numeral = parseNumeral(citation.safeLocation) else { continue }
            return numeral
        }
        return nil
    }

    /// Numerals for many eras at once, for views that would otherwise call `numeral(for:)`
    /// once per row and re-scan the citation list each time. Keys on the era's
    /// `PersistentIdentifier`, not its name, so a rename cannot silently re-point a
    /// numeral at a different era.
    package static func numerals(for eras: [Era], in citations: [Citation]) -> [PersistentIdentifier: String] {
        var byName: [String: String] = [:]
        for citation in citations where citation.safeEntityType == .era {
            guard byName[citation.safeEntityName] == nil,
                  let numeral = parseNumeral(citation.safeLocation) else { continue }
            byName[NameDuplicateCheck.normalizedKey(citation.safeEntityName)] = numeral
        }
        guard !byName.isEmpty else { return [:] }
        var result: [PersistentIdentifier: String] = [:]
        for era in eras {
            if let numeral = byName[NameDuplicateCheck.normalizedKey(era.name)] {
                result[era.persistentModelID] = numeral
            }
        }
        return result
    }

    /// "Dynasty VIII" -> "Dynasty VIII", "Dynasty 4" -> "Dynasty IV"? No — an arabic
    /// numeral is not rewritten, because the point is to show the source's own label
    /// rather than our reading of it. Anything that is not `Dynasty <word-or-digits>` at
    /// the start of the location is not a numeral and yields nil, so a citation like
    /// "Dynasty X, lines 12–20" still matches (the numeral is its own whitespace
    /// token) and one like "Babylon under foreign rule" does not.
    private static func parseNumeral(_ location: String) -> String? {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("Dynasty ") else { return nil }
        let rest = trimmed.dropFirst("Dynasty ".count)
        let token = rest.prefix { !$0.isWhitespace && $0 != "," && $0 != "." }
        guard !token.isEmpty else { return nil }
        guard token.allSatisfy({ $0.isNumber || $0.isUppercase || $0 == "I" }) else { return nil }
        return "Dynasty \(token)"
    }
}