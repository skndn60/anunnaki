import Foundation

package enum EntitySearch {
    package static func fold(_ text: String) -> String {
        DuplicateMerger.normalizationKey(text)
    }

    package static func score(query: String, primary: String, secondary: [String] = []) -> Int? {
        let q = fold(query)
        guard !q.isEmpty else { return nil }
        if let s = tierScore(q, in: fold(primary)) { return s }
        var best = 0
        for field in secondary {
            guard let s = tierScore(q, in: fold(field)) else { continue }
            let discounted = s * 3 / 4
            if discounted > best { best = discounted }
        }
        return best > 0 ? best : nil
    }

    package static func matches(query: String, primary: String, secondary: [String] = []) -> Bool {
        score(query: query, primary: primary, secondary: secondary) != nil
    }

    package static func bestMatch(query: String, in alternatives: [String]) -> String? {
        let q = fold(query)
        guard !q.isEmpty else { return nil }
        var best = 0
        var bestName: String?
        for name in alternatives {
            guard let s = tierScore(q, in: fold(name)) else { continue }
            if s > best {
                best = s
                bestName = name
            }
        }
        return bestName
    }

    private static func tierScore(_ q: String, in folded: String) -> Int? {
        guard !folded.isEmpty else { return nil }
        guard let range = folded.range(of: q) else { return nil }
        if range.lowerBound == folded.startIndex {
            return folded.count == q.count ? 100 : 80
        }
        if folded[folded.index(before: range.lowerBound)] == " " { return 60 }
        return 40
    }
}
