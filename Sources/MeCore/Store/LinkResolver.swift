import Foundation

/// Resolves registered entity names against narrative prose, matching both
/// exact spellings and folded variant spellings ("Nin-Nibru" → "Ninnibru").
///
/// The exact pass uses `\b`-bounded alternation over the names; the variant
/// pass folds the prose with `FoldedProse` — the same folding
/// `DuplicateMerger.normalizationKey` applies — and runs a keyed regex over
/// it, mapping each hit back to its original span. Anything the exact pass
/// already linked wins; the rest append. Alternation is longest-first so a
/// short key that is a prefix of a longer one (e.g. "nin" vs "ninnibru")
/// cannot shadow it.
public struct LinkResolver {
    public struct ResolvedSpan: Equatable {
        /// Span in the original prose.
        public let range: NSRange
        /// The folded key that matched (a `DuplicateMerger.normalizationKey`).
        public let key: String
        /// The exact candidate text when this is an exact match, else nil
        /// (variant match; resolve the entity via `key`).
        public let matchText: String?
    }

    private let exactRegex: NSRegularExpression
    private let keyRegex: NSRegularExpression

    public init(matchTexts: [String]) {
        var deduped: [String] = []
        for text in matchTexts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { continue }
            guard !deduped.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { continue }
            deduped.append(trimmed)
        }

        let alternatives = deduped
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .sorted { $0.count > $1.count }
        let exactPattern = alternatives.isEmpty
            ? "(?!)"
            : "\\b(?:" + alternatives.map { "(?:\($0))" }.joined(separator: "|") + ")\\b"
        exactRegex = try! NSRegularExpression(pattern: exactPattern, options: [.caseInsensitive])

        let keys = deduped
            .compactMap { DuplicateMerger.normalizationKey($0) }
            .filter { $0.count >= 2 }
        let keyPattern = keys.isEmpty
            ? "(?!)"
            : "\\b(?:" + keys.map { "(?:\(NSRegularExpression.escapedPattern(for: $0)))" }
                .sorted { $0.count > $1.count }
                .joined(separator: "|") + ")\\b"
        keyRegex = try! NSRegularExpression(pattern: keyPattern, options: [.caseInsensitive])
    }

    /// Merged, location-sorted spans: exact matches first, then variant
    /// matches that do not overlap an already-linked span.
    public func resolve(in prose: String) -> [ResolvedSpan] {
        guard !prose.isEmpty else { return [] }

        var resolved: [(range: NSRange, key: String, matchText: String?)] = []
        var taken: [NSRange] = []

        let exactRanges = exactRegex.matches(in: prose, range: NSRange(prose.startIndex..., in: prose)).map { $0.range }
        for range in exactRanges {
            let matchText = (prose as NSString).substring(with: range)
            let key = DuplicateMerger.normalizationKey(matchText)
            resolved.append((range, key, matchText))
            taken.append(range)
        }

        let folded = FoldedProse(source: prose)
        let keyRanges = keyRegex.matches(in: folded.text, range: NSRange(folded.text.startIndex..., in: folded.text)).map { $0.range }
        for keyRange in keyRanges {
            let key = (folded.text as NSString).substring(with: keyRange)
            guard let origRange = folded.origRange(for: keyRange) else { continue }
            guard !taken.contains(where: { NSIntersectionRange($0, origRange).length > 0 }) else { continue }
            resolved.append((origRange, key, nil))
            taken.append(origRange)
        }

        resolved.sort { $0.range.location < $1.range.location }
        return resolved.map { ResolvedSpan(range: $0.range, key: $0.key, matchText: $0.matchText) }
    }
}