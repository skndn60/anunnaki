import Foundation

package struct ReignLength {
    package let years: Int
    package let display: String

    package static func parse(from description: String) -> ReignLength? {
        guard let regex = try? NSRegularExpression(pattern: "Reigned\\s+([\\d,]+)\\s+years"),
              let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
              let range = Range(match.range(at: 1), in: description) else { return nil }
        let raw = String(description[range])
        let cleaned = raw.replacingOccurrences(of: ",", with: "")
        guard let years = Int(cleaned) else { return nil }
        return ReignLength(years: years, display: "\(raw) years")
    }
}
