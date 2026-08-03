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
        let subject = firstSubject(trimmed)

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
            var valueEnd = index + 1 < clauses.count ? clauses[index + 1].range.lowerBound : trimmed.endIndex
            if let terminator = trimmed.range(of: #"[.;!?\n](?=\s+[A-Z])|\n"#, options: .regularExpression, range: valueStart..<valueEnd) {
                valueEnd = terminator.lowerBound
            }
            let rawValue = String(trimmed[valueStart..<valueEnd])
            let value = cleanClauseValue(rawValue)

            switch clause.kind {
            case .family(let rule):
                let names = splitNames(value, skipDescriptives: true)
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
                if let place = splitNames(value, capitalizedOnly: true).first, !place.isEmpty, place != subject {
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
                // Markers must begin at a word boundary — "aka " must not match
                // inside "Shabaka Stone".
                if r.lowerBound > lower.startIndex {
                    let prev = lower[lower.index(before: r.lowerBound)]
                    if prev.isLetter || prev.isNumber { continue }
                }
                if best == nil || r.lowerBound < best!.lowerStart {
                        // longer marker wins ties (e.g. "also known as" beats "known as")
                        if let b = best, r.lowerBound == b.lowerStart, marker.count <= b.marker.count { continue }
                        best = (marker, kind, r.lowerBound, r.upperBound)
                    }
            }
            guard let chosen = best else { break }
            let start = String.Index(utf16Offset: chosen.lowerStart.utf16Offset(in: lower), in: text)
            let end = String.Index(utf16Offset: chosen.upper.utf16Offset(in: lower), in: text)
            results.append(ClauseMatch(kind: chosen.kind, range: start..<end))
            cursor = chosen.upper
        }
        return results
    }

    // MARK: - Helpers

    private static let alternateMarkers: [String] = [
        "also known as ", "otherwise known as ", "known as ", "known by the name ",
        "also called ", "aka ", "named ", "also spelled ", "also transliterated ",
        "sometimes called ", "also written ",
    ]

    private static let nameFunctionWords: Set<String> = [
        "the", "a", "an", "of", "and", "or", "his", "her", "their", "its",
        "was", "is", "were", "are", "be", "been", "being", "became", "become",
        "reigning", "reigned", "reign", "ruling", "ruled", "rules", "calls", "called",
        "known", "also", "from", "to", "c", "circa", "bc", "bce", "ad", "ce",
        "king", "queen", "ruler", "lord", "son", "daughter", "the",
        "kingdom", "empire", "dynasty", "city", "land", "region", "river",
        "world", "country", "people", "throne", "rule",
    ]

    private static func extractProperNames(_ value: String, capitalizedOnly: Bool = false, skipDescriptives: Bool = false) -> [String] {
        var names: [String] = []
        for chunk in value.components(separatedBy: " and ").flatMap({ $0.components(separatedBy: ",") }) {
            let words = chunk.split(separator: " ")
            guard let firstWord = words.first else { continue }
            var index = 0
            while index < words.count, nameFunctionWords.contains(words[index].lowercased().trimmingCharacters(in: .punctuationCharacters)) {
                index += 1
            }
            if !capitalizedOnly, skipDescriptives,
               words[index...].contains(where: { $0.first?.isUppercase == true }) {
                // Family values may carry a descriptive lead-in before a capitalized
                // name ("father of the sage Imhotep"). Only skip to a capital that
                // actually follows, so a lone lowercase name ("humans") survives.
                while index < words.count, words[index].first?.isUppercase != true {
                    index += 1
                }
            }
            guard index < words.count else { continue }
            var kept: [String] = []
            while index < words.count {
                let word = words[index]
                let clean = word.trimmingCharacters(in: .punctuationCharacters)
                guard !clean.isEmpty else { index += 1; continue }
                if clean.first?.isUppercase == true {
                    kept.append(clean)
                    index += 1
                } else {
                    break
                }
            }
            if !kept.isEmpty {
                names.append(kept.joined(separator: " "))
            } else if !capitalizedOnly, words.count == 1, !words[0].trimmingCharacters(in: .punctuationCharacters).isEmpty {
                names.append(words[0].trimmingCharacters(in: .punctuationCharacters))
            }
        }
        return names
    }

    private static func splitNames(_ text: String, capitalizedOnly: Bool = false, skipDescriptives: Bool = false) -> [String] {
        return extractProperNames(text, capitalizedOnly: capitalizedOnly, skipDescriptives: skipDescriptives)
    }

    private static func cleanClauseValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "the ", with: "")
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func firstSubject(_ text: String) -> String {
        let noParens = text.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        let tokens = noParens.components(separatedBy: .whitespacesAndNewlines)
        let stoppers: Set<String> = ["is", "was", "are", "were", "the", "a", "an", "and", "also", "known", "as"]
        var name: [String] = []
        for t in tokens {
            let clean = t.trimmingCharacters(in: CharacterSet(charactersIn: ",;'\"()"))
            if clean.isEmpty { continue }
            if clean.first?.isUppercase == true, !stoppers.contains(clean.lowercased()) {
                name.append(clean)
            } else if !name.isEmpty {
                break
            }
        }
        if !name.isEmpty { return name.joined(separator: " ") }
        return tokens.first { t in
            let clean = t.trimmingCharacters(in: CharacterSet(charactersIn: ",;"))
            return !clean.isEmpty && !stoppers.contains(clean.lowercased())
        } ?? ""
    }

    private static func detectGender(in lower: String, into result: inout FromTextResult) {
        let tokens = lower.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let male: Set<String> = ["god", "king", "lord", "he", "his", "him", "son", "brother", "husband", "father", "male", "priest", "ruler", "reigned", "ruled", "man"]
        let female: Set<String> = ["goddess", "queen", "lady", "she", "her", "daughter", "sister", "wife", "mother", "female", "priestess", "woman"]
        var score = 0
        for t in tokens where male.contains(t) { score += 1 }
        for t in tokens where female.contains(t) { score -= 1 }
        if lower.contains("king of ") || lower.contains("god of ") || lower.contains("lord of ") { score += 3 }
        if lower.contains("queen of ") || lower.contains("goddess of ") || lower.contains("lady of ") { score -= 3 }
        if score > 0 { result.gender = .male }
        else if score < 0 { result.gender = .female }
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
        let roles: [(String, String)] = [
            ("king of ", "King"), ("queen of ", "Queen"), ("lord of ", "Lord"),
            ("lord over ", "Lord"), ("ruler of ", "Ruler"), ("god of ", "God"),
            ("goddess of ", "Goddess"),
        ]
        for (phrase, role) in roles where lower.contains(phrase) {
            result.title = role
            return
        }
    }

    private static func detectDomain(in lower: String, into result: inout FromTextResult) {
        // Heuristic: "god of X, Y and Z" captures the domain list.
        guard let range = lower.range(of: "god of ") ?? lower.range(of: "goddess of ") ?? lower.range(of: "deity of ") else { return }
        let tail = String(lower[range.upperBound...])
        let parts = tail.components(separatedBy: CharacterSet(charactersIn: ".,;")).first?
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && !nameFunctionWords.contains($0.lowercased()) } ?? []
        let domain = parts.prefix(3).map { $0.capitalized }.joined(separator: ", ")
        if !domain.isEmpty { result.domain = domain }
    }

    private static func detectYears(in lower: String, into result: inout FromTextResult) {
        // Parse all year tokens with their positions so reign years can be
        // separated from birth/death years instead of mixing them.
        struct YearToken {
            let value: Int
            let location: Int
            let length: Int
        }
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d[\d,]*)\s*(BCE|BC|CE|AD)\b"#, options: [.caseInsensitive]) else { return }
        let ns = lower as NSString
        let matches = regex.matches(in: lower, range: NSRange(location: 0, length: ns.length))
        var tokens: [YearToken] = []
        for m in matches {
            guard m.numberOfRanges == 3 else { continue }
            let numStr = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: "")
            let era = ns.substring(with: m.range(at: 2)).uppercased()
            guard let magnitude = Int(numStr) else { continue }
            let signed = (era == "BC" || era == "BCE") ? -magnitude : magnitude
            tokens.append(YearToken(value: signed, location: m.range.location, length: m.range.length))
        }
        guard !tokens.isEmpty else { return }

        // A reign clause names the reign span explicitly: "reigning from X to Y".
        let reignClause = lower.contains("reigned") || lower.contains("reigning") || lower.contains("ruling")
        if reignClause {
            // Take the two year tokens nearest the reign keyword — that is the
            // reign start/end. Any earlier/later tokens are birth/death.
            let keyword = lower.range(of: "reigning") ?? lower.range(of: "reigned") ?? lower.range(of: "ruling")
            if let kw = keyword {
                let kwOffset = lower.distance(from: lower.startIndex, to: kw.lowerBound)
                let sorted = tokens.sorted { abs($0.location - kwOffset) < abs($1.location - kwOffset) }
                if sorted.count >= 2 {
                    let span = sorted.prefix(2).map { $0.value }.sorted()
                    result.reignStart = span.first
                    result.reignEnd = span.last
                    // Remaining tokens describe the lifespan.
                    let lifed = tokens.filter { t in !sorted.prefix(2).contains { $0.location == t.location && $0.length == t.length } }
                    if !lifed.isEmpty {
                        let years = lifed.map { $0.value }.sorted()
                        result.birthYear = years.first
                        result.deathYear = years.last
                    }
                    return
                }
            }
        }

        // No explicit reign clause: all years are birth/death.
        let years = tokens.map { $0.value }.sorted()
        result.birthYear = years.first
        result.deathYear = years.last
    }
}