import Foundation
import SwiftData
import NaturalLanguage

package enum FromTextGender: String, Hashable {
    case male, female, unknown
}

package enum FromTextFigureKind: String, Hashable {
    case deity, human, primordial, unknown

    package var figureTypeName: String? {
        switch self {
        case .deity: return "Deity"
        case .human: return "Human"
        case .primordial: return "Primordial Being"
        case .unknown: return nil
        }
    }
}

package struct FromTextRelationship: Hashable {
    package var fromFigure: String
    package var toFigure: String
    package var relationshipType: String
    package var isPreferred: Bool

    package init(fromFigure: String, toFigure: String, relationshipType: String, isPreferred: Bool = false) {
        self.fromFigure = fromFigure
        self.toFigure = toFigure
        self.relationshipType = relationshipType
        self.isPreferred = isPreferred
    }
}

package struct FromTextPlaceLink: Hashable {
    package var figure: String
    package var place: String
    package var roleName: String

    package init(figure: String, place: String, roleName: String) {
        self.figure = figure
        self.place = place
        self.roleName = roleName
    }
}

/// Structured result mirroring the Figure form's fields. The preview renders these as a list.
package struct FromTextResult {
    package var subject: String
    package var gender: FromTextGender
    package var figureKind: FromTextFigureKind
    package var title: String?
    package var domain: String?
    package var birthYear: Int?
    package var deathYear: Int?
    package var reignStart: Int?
    package var reignEnd: Int?
    package var description: String
    package var parents: [FromTextRelationship]
    package var otherRelationships: [FromTextRelationship]
    package var placeLinks: [FromTextPlaceLink]
    package var alternateNames: [String]
    package var newFigures: [String]
    package var newPlaces: [String]

    package init(subject: String = "", gender: FromTextGender = .unknown, figureKind: FromTextFigureKind = .unknown, title: String? = nil, domain: String? = nil, birthYear: Int? = nil, deathYear: Int? = nil, reignStart: Int? = nil, reignEnd: Int? = nil, description: String = "", parents: [FromTextRelationship] = [], otherRelationships: [FromTextRelationship] = [], placeLinks: [FromTextPlaceLink] = [], alternateNames: [String] = [], newFigures: [String] = [], newPlaces: [String] = []) {
        self.subject = subject
        self.gender = gender
        self.figureKind = figureKind
        self.title = title
        self.domain = domain
        self.birthYear = birthYear
        self.deathYear = deathYear
        self.reignStart = reignStart
        self.reignEnd = reignEnd
        self.description = description
        self.parents = parents
        self.otherRelationships = otherRelationships
        self.placeLinks = placeLinks
        self.alternateNames = alternateNames
        self.newFigures = newFigures
        self.newPlaces = newPlaces
    }

    package var allReferences: [String] {
        var set = Set<String>([subject])
        for rel in parents { set.insert(rel.fromFigure); set.insert(rel.toFigure) }
        for rel in otherRelationships { set.insert(rel.fromFigure); set.insert(rel.toFigure) }
        return set.sorted()
    }
}

package struct FromTextParser {

    // MARK: - Family detection

    private struct FamilyRule {
        let word: String
        let outputType: String
        let reversed: Bool
    }

    private static let familyRules: [FamilyRule] = [
        FamilyRule(word: "father", outputType: "Father", reversed: false),
        FamilyRule(word: "mother", outputType: "Mother", reversed: false),
        FamilyRule(word: "son", outputType: "Father", reversed: true),
        FamilyRule(word: "daughter", outputType: "Mother", reversed: true),
        FamilyRule(word: "brother", outputType: "Sibling", reversed: false),
        FamilyRule(word: "sister", outputType: "Sibling", reversed: false),
        FamilyRule(word: "sibling", outputType: "Sibling", reversed: false),
        FamilyRule(word: "consort", outputType: "Spouse", reversed: false),
        FamilyRule(word: "spouse", outputType: "Spouse", reversed: false),
        FamilyRule(word: "husband", outputType: "Spouse", reversed: false),
        FamilyRule(word: "wife", outputType: "Spouse", reversed: false),
        FamilyRule(word: "creator", outputType: "Creator", reversed: true),
    ]

    private struct PlaceRule {
        let word: String
        let roleName: String
    }

    private static let placeRules: [PlaceRule] = [
        PlaceRule(word: "patron", roleName: "Patron Deity"),
        PlaceRule(word: "ruler", roleName: "Ruler"),
        PlaceRule(word: "king", roleName: "Ruler"),
        PlaceRule(word: "born", roleName: "Born At"),
        PlaceRule(word: "lived", roleName: "Resident Of"),
    ]

    /// Every clause starts with one of these "X of ..." or "known as X" markers.
    private enum MatchKind {
        case family(rule: FamilyRule)
        case place(rule: PlaceRule)
        case alternateMarker
    }

    package static func parse(_ text: String) -> FromTextResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return FromTextResult() }

        let lower = trimmed.lowercased()
        let clauses = scanClauses(in: trimmed, lower: lower)
        let subject = firstSubject(trimmed, clauses: clauses)

        var result = FromTextResult(subject: subject)
        result.parents = []
        result.otherRelationships = []
        result.alternateNames = []
        result.placeLinks = []
        result.description = trimmed  // the bio is the whole clip

        var newFigures = Set<String>()
        var newPlaces = Set<String>()

        for (index, clause) in clauses.enumerated() {
            let valueStart = clause.range.upperBound
            let valueEnd = index + 1 < clauses.count ? clauses[index + 1].range.lowerBound : trimmed.endIndex
            let rawValue = String(trimmed[valueStart..<valueEnd])
            let value = cleanClauseValue(rawValue)

            switch clause.kind {
            case .family(let rule):
                let names = splitNames(value)
                for (i, name) in names.enumerated() {
                    guard !name.isEmpty, name != subject else { continue }
                    var type = rule.outputType
                    // For "son/daughter of X and Y", the parents alternate Father/Mother
                    if rule.reversed && names.count > 1 {
                        type = (type == "Father") ? (i == 0 ? "Father" : "Mother") : (i == 0 ? "Mother" : "Father")
                    }
                    let from = rule.reversed ? name : subject
                    let to = rule.reversed ? subject : name
                    let rel = FromTextRelationship(fromFigure: from, toFigure: to, relationshipType: type, isPreferred: rule.outputType == "Spouse")
                    if type == "Father" || type == "Mother" {
                        result.parents.append(rel)
                    } else {
                        result.otherRelationships.append(rel)
                    }
                    newFigures.insert(name)
                }
            case .place(let rule):
                if let place = splitNames(value).first, !place.isEmpty, place != subject {
                    result.placeLinks.append(FromTextPlaceLink(figure: subject, place: place, roleName: rule.roleName))
                    newPlaces.insert(place)
                }
            case .alternateMarker:
                for name in splitNames(value) {
                    if !name.isEmpty, name != subject {
                        result.alternateNames.append(name)
                    }
                }
            }
        }

        detectGender(in: lower, into: &result)
        detectFigureKind(in: lower, into: &result)
        detectTitle(in: lower, into: &result)
        detectDomain(in: lower, into: &result)
        detectYears(in: lower, into: &result)

        if !subject.isEmpty { newFigures.remove(subject) }
        result.newFigures = newFigures.sorted()
        result.newPlaces = newPlaces.sorted()

        return result
    }

    // MARK: - Scanning

    private struct ClauseMatch {
        let kind: MatchKind
        let range: Range<String.Index>
    }

    private static func scanClauses(in text: String, lower: String) -> [ClauseMatch] {
        var allMarkers: [(marker: String, kind: MatchKind)] = []
        for family in familyRules {
            allMarkers.append((family.word + " of ", .family(rule: family)))
        }
        for place in placeRules {
            allMarkers.append((place.word + " of ", .place(rule: place)))
        }
        for alt in alternateMarkers {
            allMarkers.append((alt, .alternateMarker))
        }

        var results: [ClauseMatch] = []
        var cursor = lower.startIndex

        while cursor < lower.endIndex {
            var best: (marker: String, kind: MatchKind, lowerStart: String.Index, upper: String.Index)? = nil
            for (marker, kind) in allMarkers {
                guard let r = lower.range(of: marker, range: cursor..<lower.endIndex) else { continue }
                if best == nil || r.lowerBound < best!.lowerStart {
                        // longer marker wins ties (e.g. "also known as" beats "known as")
                        if let b = best, r.lowerBound == b.lowerStart, marker.count <= b.marker.count { continue }
                        best = (marker, kind, r.lowerBound, r.upperBound)
                    }
            }
            guard let chosen = best else { break }
            let start = text.index(text.startIndex, offsetBy: chosen.lowerStart.utf16Offset(in: lower))
            let end = text.index(text.startIndex, offsetBy: chosen.upper.utf16Offset(in: lower))
            results.append(ClauseMatch(kind: chosen.kind, range: start..<end))
            cursor = chosen.upper
        }
        return results
    }

    // MARK: - Helpers

    private static let alternateMarkers: [String] = [
        "also known as ", "otherwise known as ", "known as ", "known by the name ",
        "also called ", "aka ", "named ",
    ]

    private static func splitNames(_ text: String) -> [String] {
        let stopwords: Set<String> = ["the", "a", "an", "of", "and", "his", "her", "their", "its"]
        return text.components(separatedBy: " and ")
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && !stopwords.contains($0.lowercased()) }
    }

    private static func cleanClauseValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "the ", with: "")
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func firstSubject(_ text: String, clauses: [ClauseMatch]) -> String {
        let prefix: String
        if let first = clauses.first, first.range.lowerBound > text.startIndex {
            prefix = String(text[text.startIndex..<first.range.lowerBound])
        } else {
            prefix = text
        }
        var words = prefix.components(separatedBy: .whitespacesAndNewlines)
        let stoppers: Set<String> = ["is", "was", "are", "were", "the", "a", "an", "and", "also", "known", "as"]
        while let head = words.first, stoppers.contains(head.lowercased()) {
            words.removeFirst()
        }
        while let tail = words.last, stoppers.contains(tail.lowercased()) || tail.isEmpty {
            words.removeLast()
        }
        let candidate = words.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",;"))
        guard !candidate.isEmpty else {
            // fall back: first capitalized token in the whole text
            let tokens = text.components(separatedBy: .whitespacesAndNewlines)
            return tokens.first { t in
                guard let c = t.first, c.isUppercase else { return false }
                return !stoppers.contains(t.lowercased())
            } ?? ""
        }
        return candidate
    }

    private static func detectGender(in lower: String, into result: inout FromTextResult) {
        let tokens = Set(lower.components(separatedBy: CharacterSet.alphanumerics.inverted))
        if tokens.contains("goddess") || tokens.contains("female") {
            result.gender = .female
        } else if tokens.contains("god") || tokens.contains("male") {
            result.gender = .male
        }
    }

    private static func detectFigureKind(in lower: String, into result: inout FromTextResult) {
        if lower.contains("primordial") {
            result.figureKind = .primordial
            return
        }
        // Deity only when the subject is predicated as a god — not when "god" merely
        // appears in a reign line ("successor of the god X") for a human king.
        let deityPhrases = [
            " is a god", " is the god", " god of ", "goddess of ", " chief god",
            " deity of ", " the god of ", " patron god", " god over ",
        ]
        if deityPhrases.contains(where: { lower.contains($0) }) {
            result.figureKind = .deity
            return
        }
        // A king, ruler, or reigned monarch is a human by default even though
        // their biography may mention deities.
        let humanPhrases = [" king of ", " king", "queen ", "ruler of ", " ruler ",
                            " reigned ", " ruled ", "queen of "]
        if humanPhrases.contains(where: { lower.contains($0) }) {
            result.figureKind = .human
            return
        }
        if lower.contains("human") {
            result.figureKind = .human
        }
    }

    private static func detectTitle(in lower: String, into result: inout FromTextResult) {
        let patterns = ["lord of ", "king of ", "lord over "]
        for pattern in patterns {
            if let range = lower.range(of: pattern + " ") ?? lower.range(of: pattern) {
                let tail = String(lower[range.upperBound...])
                if let word = tail.components(separatedBy: .whitespaces).first, !word.isEmpty {
                    result.title = word.capitalized
                    return
                }
            }
        }
    }

    private static func detectDomain(in lower: String, into result: inout FromTextResult) {
        // Heuristic: "god of X, Y and Z" captures the domain list.
        guard let range = lower.range(of: "god of ") ?? lower.range(of: "goddess of ") ?? lower.range(of: "deity of ") else { return }
        let tail = String(lower[range.upperBound...])
        let parts = tail.components(separatedBy: CharacterSet(charactersIn: ".,;")).first?
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty } ?? []
        let domain = parts.prefix(3).map { $0.capitalized }.joined(separator: ", ")
        if !domain.isEmpty { result.domain = domain }
    }

    private static func detectYears(in lower: String, into result: inout FromTextResult) {
        // BCE/CE patterns: "born c. 1240 BCE", "reigned 2047–2030 BCE"
        if let regex = try? NSRegularExpression(pattern: #"\b(\d[\d,]*)\s*(BCE|BC|CE|AD)\b"#, options: [.caseInsensitive]) {
            let ns = lower as NSString
            let all = regex.matches(in: lower, range: NSRange(location: 0, length: ns.length))
            var years: [Int] = []
            for m in all {
                guard m.numberOfRanges == 3 else { continue }
                let numStr = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: "")
                let era = ns.substring(with: m.range(at: 2)).uppercased()
                guard let magnitude = Int(numStr) else { continue }
                let signed = (era == "BC" || era == "BCE") ? -magnitude : magnitude
                years.append(signed)
            }
            if !years.isEmpty {
                let sorted = years.sorted()
                result.birthYear = sorted.first
                result.deathYear = sorted.last
            }
        }
    }
}