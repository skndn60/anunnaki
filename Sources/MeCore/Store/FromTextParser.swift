import Foundation
import SwiftData
import NaturalLanguage

package enum FromTextRoleType: Hashable {
    case patron
    case ruler

    package var displayName: String {
        switch self {
        case .patron: return "Patron Deity"
        case .ruler: return "Ruler"
        }
    }
}

package struct FromTextRelationship: Hashable {
    package var fromFigure: String
    package var toFigure: String
    package var relationshipType: String?
    package var isPreferred: Bool
    package var groupID: String

    package init(fromFigure: String, toFigure: String, relationshipType: String? = nil, isPreferred: Bool = false, groupID: String = "") {
        self.fromFigure = fromFigure
        self.toFigure = toFigure
        self.relationshipType = relationshipType
        self.isPreferred = isPreferred
        self.groupID = groupID
    }
}

package struct FromTextPlaceLink: Hashable {
    package var figure: String
    package var place: String
    package var role: FromTextRoleType

    package init(figure: String, place: String, role: FromTextRoleType) {
        self.figure = figure
        self.place = place
        self.role = role
    }
}

package struct FromTextResult {
    package var subject: String?
    package var relationships: [FromTextRelationship]
    package var placeLinks: [FromTextPlaceLink]
    package var newFigures: [String]
    package var newPlaces: [String]

    package init(subject: String? = nil, relationships: [FromTextRelationship] = [], placeLinks: [FromTextPlaceLink] = [], newFigures: [String] = [], newPlaces: [String] = []) {
        self.subject = subject
        self.relationships = relationships
        self.placeLinks = placeLinks
        self.newFigures = newFigures
        self.newPlaces = newPlaces
    }
}

package struct FromTextParser {

    private static let familyWords: [(word: String, category: String)] = [
        ("father", "parentOf"),
        ("mother", "parentOf"),
        ("son", "childOf"),
        ("daughter", "childOf"),
        ("brother", "siblingOf"),
        ("sister", "siblingOf"),
        ("sibling", "siblingOf"),
        ("consort", "partnerOf"),
        ("spouse", "partnerOf"),
        ("wife", "partnerOf"),
        ("husband", "partnerOf"),
        ("creator", "creatorOf"),
    ]

    private static let placeWords: [(word: String, role: FromTextRoleType)] = [
        ("patron", .patron),
        ("ruler", .ruler),
    ]

    package static func parse(_ text: String) -> FromTextResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return FromTextResult() }

        let matches = findClauses(in: trimmed)

        var relationships: [FromTextRelationship] = []
        var placeLinks: [FromTextPlaceLink] = []
        var newFigures = Set<String>()
        var newPlaces = Set<String>()

        guard let first = matches.first else {
            return FromTextResult(
                subject: cleanSubject(trimmed),
                relationships: relationships,
                placeLinks: placeLinks,
                newFigures: newFigures.sorted(),
                newPlaces: newPlaces.sorted()
            )
        }

        let subject = cleanSubject(String(trimmed[..<first.range.lowerBound]))

        for (index, match) in matches.enumerated() {
            let start = match.range.upperBound
            let end = index + 1 < matches.count ? matches[index + 1].range.lowerBound : trimmed.endIndex
            let tail = String(trimmed[start..<end])
                .trimmingCharacters(in: CharacterSet(charactersIn: ",;\n"))
                .trimmingCharacters(in: .whitespaces)

            if let placeRole = match.place {
                let place = cleanName(tail)
                if !place.isEmpty {
                    placeLinks.append(FromTextPlaceLink(figure: subject, place: place, role: placeRole))
                    newPlaces.insert(place)
                }
            } else if let familyEntry = familyEntry(for: match.word) {
                for target in splitNames(tail) {
                    relationships.append(makeRelationship(subject: subject, target: target, word: match.word, category: familyEntry.category))
                    newFigures.insert(target)
                }
            }
        }

        if !subject.isEmpty {
            newFigures.remove(subject)
        }

        return FromTextResult(
            subject: subject.isEmpty ? nil : subject,
            relationships: relationships,
            placeLinks: placeLinks,
            newFigures: newFigures.sorted(),
            newPlaces: newPlaces.sorted()
        )
    }

    private struct ClauseMatch {
        let word: String
        let place: FromTextRoleType?
        let range: Range<String.Index>
    }

    private static func findClauses(in text: String) -> [ClauseMatch] {
        let lower = text.lowercased()
        let markers: [(word: String, role: FromTextRoleType?)] =
            familyWords.map { ($0.word, nil) } + placeWords.map { ($0.word, $0.role) }

        var results: [ClauseMatch] = []
        var cursor = lower.startIndex

        while cursor < lower.endIndex {
            var best: (word: String, role: FromTextRoleType?, lowerStart: String.Index, upper: String.Index)? = nil

            for (word, role) in markers {
                let needle = word + " of "
                guard let r = lower.range(of: needle, range: cursor..<lower.endIndex) else { continue }
                if best == nil || r.lowerBound < best!.lowerStart {
                    best = (word, role, r.lowerBound, r.upperBound)
                }
            }

            guard let chosen = best else { break }
            let start = text.index(text.startIndex, offsetBy: chosen.lowerStart.utf16Offset(in: lower))
            let end = text.index(text.startIndex, offsetBy: chosen.upper.utf16Offset(in: lower))
            results.append(ClauseMatch(word: chosen.word, place: chosen.role, range: start..<end))
            cursor = chosen.upper
        }
        return results
    }

    private static func familyEntry(for word: String) -> (word: String, category: String)? {
        familyWords.first { $0.word == word }
    }

    private static func makeRelationship(subject: String, target: String, word: String, category: String) -> FromTextRelationship {
        switch category {
        case "parentOf":
            let typeName = word == "mother" ? "Mother" : "Father"
            return FromTextRelationship(fromFigure: subject, toFigure: target, relationshipType: typeName)
        case "childOf":
            let typeName = word == "daughter" ? "Mother" : "Father"
            return FromTextRelationship(fromFigure: target, toFigure: subject, relationshipType: typeName)
        case "creatorOf":
            return FromTextRelationship(fromFigure: target, toFigure: subject, relationshipType: "Creator")
        case "partnerOf":
            return FromTextRelationship(fromFigure: subject, toFigure: target, relationshipType: "Spouse", isPreferred: true)
        default:
            return FromTextRelationship(fromFigure: subject, toFigure: target, relationshipType: "Sibling")
        }
    }

    private static func splitNames(_ text: String) -> [String] {
        let parts: [String]
        if let range = text.lowercased().range(of: " and ") {
            parts = [String(text[..<range.lowerBound]), String(text[range.upperBound...])]
        } else {
            parts = [text]
        }
        return parts.map { cleanName($0) ?? "" }
            .filter { !$0.isEmpty }
    }

    private static func cleanSubject(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ",;\n"))
        let stoppers: Set<String> = [
            "is", "was", "are", "were", "the", "a", "an", "who", "and", "that", "-",
        ]

        var words = trimmed.split(separator: " ").map(String.init)
        while let first = words.first, stoppers.contains(first.lowercased()) {
            words.removeFirst()
        }
        while let last = words.last, stoppers.contains(last.lowercased()) {
            words.removeLast()
        }
        return words.joined(separator: " ")
    }

    private static func cleanName(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .punctuationCharacters)
    }
}