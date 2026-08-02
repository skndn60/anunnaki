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

        let clauses = splitClauses(trimmed)
        let subject = extractSubject(from: clauses.first ?? trimmed)

        var relationships: [FromTextRelationship] = []
        var placeLinks: [FromTextPlaceLink] = []
        var newFigures = Set<String>()
        var newPlaces = Set<String>()

        for clause in clauses {
            parseClause(clause, subject: subject, relationships: &relationships, placeLinks: &placeLinks, newFigures: &newFigures, newPlaces: &newPlaces)
        }

        if let subject {
            newFigures.remove(subject)
        }

        return FromTextResult(
            subject: subject,
            relationships: relationships,
            placeLinks: placeLinks,
            newFigures: newFigures.sorted(),
            newPlaces: newPlaces.sorted()
        )
    }

    private static func parseClause(_ clause: String, subject: String?, relationships: inout [FromTextRelationship], placeLinks: inout [FromTextPlaceLink], newFigures: inout Set<String>, newPlaces: inout Set<String>) {
        guard let subject else { return }
        let lower = clause.lowercased()

        for (word, roleType) in placeWords {
            if let tail = extractTail(lower, prefix: word + " of "),
               let original = originalTail(in: clause, lowerPrefix: word + " of ", lowerTail: tail) {
                placeLinks.append(FromTextPlaceLink(figure: subject, place: original, role: roleType))
                newPlaces.insert(original)
                return
            }
        }

        for (word, category) in familyWords {
            if let tail = extractTail(lower, prefix: word + " of "),
                let original = originalTail(in: clause, lowerPrefix: word + " of ", lowerTail: tail) {
                let names = splitNames(original)
                for target in names {
                    relationships.append(makeRelationship(subject: subject, target: target, word: word, category: category))
                    newFigures.insert(target)
                }
                return
            }
        }
    }

    private static func extractTail(_ text: String, prefix: String) -> String? {
        guard let range = text.range(of: prefix) else { return nil }
        let after = text[range.upperBound...]
        let cleaned = after
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func originalTail(in clause: String, lowerPrefix: String, lowerTail: String) -> String? {
        guard let fullLower = clause.lowercased().range(of: lowerPrefix + lowerTail) else { return nil }
        return String(clause[fullLower]).dropFirst(lowerPrefix.count).trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .punctuationCharacters)
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
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    private static func extractSubject(from clause: String) -> String? {
        let tokens = tokenize(clause)
        guard let first = tokens.first else { return nil }
        let lower = first.lowercased()
        let connectors: Set<String> = [
            "is", "was", "are", "were", "the", "a", "an", "who", "and", "son", "daughter",
            "father", "mother", "brother", "sister", "spouse", "consort", "wife", "husband",
            "creator", "patron", "ruler",
        ]
        if connectors.contains(lower) { return nil }
        return first
    }

    private static func splitClauses(_ text: String) -> [String] {
        let bySemicolon = text.components(separatedBy: ";")
        var out: [String] = []
        for part in bySemicolon {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { out.append(trimmed) }
        }
        return out
    }

    private static func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            tokens.append(String(text[range]))
            return true
        }
        return tokens
    }

    private static func lemmatize(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var pieces: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma) { tag, range in
            let raw = tag?.rawValue ?? String(text[range])
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { pieces.append(trimmed.lowercased()) }
            return true
        }
        return pieces.joined(separator: " ")
    }
}