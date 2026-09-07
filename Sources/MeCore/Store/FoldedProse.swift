import Foundation

/// Folded form of a prose string so registered names match their variant
/// spellings in running text ("Nin-Nibru" → the registered "Ninnibru").
///
/// Folding mirrors `DuplicateMerger.normalizationKey`: lowercase, diacritics
/// stripped, hyphens/apostrophes/dots dropped, and whitespace runs folded to a
/// single space (a real space between words stays a word boundary, so "Nin
/// Nibru" never matches "Ninnibru"). Every surviving character in `text`
/// retains its original range, so a regex hit in the folded form maps back to
/// the original span — stripped characters fall inside that span.
public struct FoldedProse {
    public let original: String
    public let text: String
    private let charOrigRanges: [Range<String.Index>]

    public init(source: String) {
        original = source
        var built = ""
        var ranges: [Range<String.Index>] = []
        var pendingSpace = false
        var lastOrigRange: Range<String.Index>?
        var index = source.startIndex
        while index < source.endIndex {
            let character = source[index]
            let charRange = index..<source.index(after: index)
            index = source.index(after: index)
            if Self.punctuationToDrop.contains(character) { continue }
            let folded = String(character).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if folded.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                pendingSpace = true
                continue
            }
            if pendingSpace, !built.isEmpty {
                built.append(" ")
                if let last = lastOrigRange { ranges.append(last) }
            }
            pendingSpace = false
            let kept = folded.first ?? character
            built.append(kept)
            lastOrigRange = charRange
            for _ in String(kept).utf16 {
                ranges.append(charRange)
            }
        }
        text = built
        charOrigRanges = ranges
    }

    /// Maps a range in `text` (UTF-16 offsets, as produced by
    /// `NSRegularExpression`) back to the same span in `original`.
    public func origRange(for range: NSRange) -> NSRange? {
        guard range.length > 0,
              range.location >= 0,
              range.location + range.length <= charOrigRanges.count else { return nil }
        let lower = charOrigRanges[range.location].lowerBound
        let last = range.location + range.length - 1
        let upper = charOrigRanges[last].upperBound
        return NSRange(lower..<upper, in: original)
    }

    private static let punctuationToDrop: Set<Character> = ["-", "‐", "‑", "‒", "–", "—", "―", "'", "’", "."]
}