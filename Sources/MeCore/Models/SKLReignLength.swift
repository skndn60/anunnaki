import Foundation

package struct ReignLength {
    package let years: Int
    package let display: String

    package init(years: Int, display: String) {
        self.years = years
        self.display = display
    }

    /// Extract a reign duration from a figure description. Tries the SKL's canonical
    /// "(Listed reign: X years.)" suffix first, then "Reigned/Ruled X years" (with
    /// optional "for"/"around" and any capitalization).
    package static func parse(from description: String) -> ReignLength? {
        let patterns = [
            "[Ll]isted reign:\\s*([\\d,]+)\\s+years",
            "(?:[Rr]eigned|[Rr]uled)(?:\\s+for)?(?:\\s+around)?\\s+([\\d,]+)\\s+years",
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
                  let range = Range(match.range(at: 1), in: description) else { continue }
            let raw = String(description[range])
            let cleaned = raw.replacingOccurrences(of: ",", with: "")
            guard let years = Int(cleaned) else { continue }
            return ReignLength(years: years, display: "\(raw) years")
        }
        return nil
    }
}
