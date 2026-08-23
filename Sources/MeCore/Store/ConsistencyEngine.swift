import Foundation

/// One content-consistency finding produced by `ConsistencyEngine`.
/// Findings are read-only observations for human review — nothing here
/// mutates data (unlike the structural fixes in DataIntegrityView).
package struct ConsistencyFinding: Identifiable {
    package enum Kind: String, CaseIterable {
        case pronounGender
        case genderedNoun
        case roleGender
        case parentCycle
        case invertedDates
        case unknownEra
        case ambiguousAlias
        case stubFigure
    }

    package enum Severity {
        /// Very likely wrong — worth fixing.
        case warning
        /// Worth a look, but has legitimate explanations.
        case info

        package var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    package let id = UUID()
    package let kind: Kind
    package let severity: Severity
    /// The kind of entity the finding is about ("Figure", "Relationship", …).
    package let entityKind: String
    package let entityName: String
    package let message: String

    package init(kind: Kind, severity: Severity, entityKind: String, entityName: String, message: String) {
        self.kind = kind
        self.severity = severity
        self.entityKind = entityKind
        self.entityName = entityName
        self.message = message
    }
}

/// Static, side-effect-free consistency rules over fetched model arrays.
/// Pure functions make every rule unit-testable without SwiftData observation,
/// and keep the DataIntegrityView scan on the approved precompute pattern.
package enum ConsistencyEngine {

    // MARK: - Text signals (shared with the live form hints)

    private static func tokens(in text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
    }

    /// Counts of female vs male pronouns as whole words ("her" inside
    /// "history" or "here" never counts).
    package static func pronounSignals(in text: String) -> (female: Int, male: Int) {
        var female = 0
        var male = 0
        for token in tokens(in: text) {
            switch token {
            case "she", "her", "hers": female += 1
            case "he", "him", "his": male += 1
            default: break
            }
        }
        return (female, male)
    }

    private static let feminineNouns: Set<String> = [
        "goddess", "queen", "priestess", "wife", "mother", "daughter", "sister", "widow",
    ]
    private static let masculineNouns: Set<String> = [
        "god", "king", "priest", "husband", "father", "son", "brother", "prince",
    ]

    /// Gendered nouns appearing in the text, as exact whole words.
    package static func genderedNounSignals(in text: String) -> (feminine: Set<String>, masculine: Set<String>) {
        let words = Set(tokens(in: text))
        return (words.intersection(feminineNouns), words.intersection(masculineNouns))
    }

    private static func conflictMessage(expected: Figure.Gender, found: String, evidence: [String]) -> String {
        let quoted = evidence.map { "\"\($0)\"" }.sorted().joined(separator: ", ")
        return "Text says \(found) (\(quoted)) but the figure is marked \(expected.rawValue)."
    }

    /// Combined pronoun + gendered-noun check for one figure's description and
    /// title. Only flags when ALL signals point the opposite way — mixed text
    /// stays silent because it may legitimately describe several people.
    package static func genderConflict(
        gender: Figure.Gender, title: String, figureDescription: String
    ) -> (kind: ConsistencyFinding.Kind, message: String)? {
        switch gender {
        case .male, .female:
            break
        case .nonBinary, .unknown:
            return nil
        }
        let expectedFemale = gender == .female
        let text = title + " " + figureDescription
        let pronouns = pronounSignals(in: text)
        if !expectedFemale && pronouns.female > 0 && pronouns.male == 0 {
            return (.pronounGender, "Description uses \"she/her\" but the figure is marked Male.")
        }
        if expectedFemale && pronouns.male > 0 && pronouns.female == 0 {
            return (.pronounGender, "Description uses \"he/him\" but the figure is marked Female.")
        }
        let nouns = genderedNounSignals(in: text)
        if !expectedFemale && !nouns.feminine.isEmpty && nouns.masculine.isEmpty {
            return (.genderedNoun, conflictMessage(expected: .female, found: "feminine wording",
                                                   evidence: Array(nouns.feminine)))
        }
        if expectedFemale && !nouns.masculine.isEmpty && nouns.feminine.isEmpty {
            return (.genderedNoun, conflictMessage(expected: .male, found: "masculine wording",
                                                   evidence: Array(nouns.masculine)))
        }
        return nil
    }

    // MARK: - Rules

    private static func checkGenderWording(figure: Figure) -> [ConsistencyFinding] {
        guard let result = genderConflict(
            gender: figure.gender, title: figure.title, figureDescription: figure.figureDescription
        ) else { return [] }
        return [ConsistencyFinding(
            kind: result.kind,
            severity: .warning,
            entityKind: "Figure",
            entityName: figure.name,
            message: result.message
        )]
    }

    /// Role names implying a gender, and which endpoint(s) they apply to.
    /// Parent roles are directional (from = parent); spouse/sibling roles bind
    /// both endpoints. Son/daughter are omitted — their direction is ambiguous
    /// in this model.
    private static let roleExpectations: [(keyword: String, expected: Figure.Gender, appliesToFrom: Bool, appliesToTo: Bool)] = [
        ("father", .male, true, false),
        ("mother", .female, true, false),
        ("husband", .male, true, true),
        ("wife", .female, true, true),
        ("brother", .male, true, true),
        ("sister", .female, true, true),
    ]

    private static func checkRoleGenders(relationships: [Relationship]) -> [ConsistencyFinding] {
        var findings: [ConsistencyFinding] = []
        for rel in relationships {
            guard let typeName = rel.relationshipType?.name else { continue }
            let lowered = typeName.lowercased()
            guard let rule = roleExpectations.first(where: { lowered.contains($0.keyword) }) else { continue }
            if rule.appliesToFrom, let from = rel.fromFigure, from.gender == opposite(of: rule.expected) {
                findings.append(ConsistencyFinding(
                    kind: .roleGender, severity: .warning, entityKind: "Relationship",
                    entityName: "\(from.name) —\(typeName)→ \(rel.toFigure?.name ?? "?")",
                    message: "\(from.name) is listed in the \"\(typeName)\" role but is marked \(from.gender.rawValue)."
                ))
            }
            if rule.appliesToTo, let to = rel.toFigure, to.gender == opposite(of: rule.expected) {
                findings.append(ConsistencyFinding(
                    kind: .roleGender, severity: .warning, entityKind: "Relationship",
                    entityName: "\(rel.fromFigure?.name ?? "?") —\(typeName)→ \(to.name)",
                    message: "\(to.name) is on the \"\(typeName)\" end of a relationship but is marked \(to.gender.rawValue)."
                ))
            }
        }
        return findings
    }

    private static func opposite(of gender: Figure.Gender) -> Figure.Gender {
        gender == .male ? .female : .male
    }

    private static func isParentEdge(typeName: String) -> Bool {
        let lowered = typeName.lowercased()
        return lowered.contains("father") || lowered.contains("mother") || lowered == "parent"
    }

    private static func checkParentCycles(relationships: [Relationship]) -> [ConsistencyFinding] {
        var findings: [ConsistencyFinding] = []
        let parentEdges = relationships.filter {
            $0.fromFigure != nil && $0.toFigure != nil &&
            (($0.relationshipType?.name).map { isParentEdge(typeName: $0) } ?? false)
        }
        for (i, rel) in parentEdges.enumerated() {
            guard let from = rel.fromFigure, let to = rel.toFigure else { continue }
            if from === to {
                findings.append(ConsistencyFinding(
                    kind: .parentCycle, severity: .warning, entityKind: "Relationship",
                    entityName: from.name,
                    message: "\(from.name) is listed as their own \(rel.relationshipType?.name.lowercased() ?? "parent")."
                ))
                continue
            }
            let hasMutual = parentEdges[(i + 1)...].contains { other in
                other.fromFigure === to && other.toFigure === from
            }
            guard hasMutual else { continue }
            findings.append(ConsistencyFinding(
                kind: .parentCycle, severity: .warning, entityKind: "Relationship",
                entityName: "\(from.name) ↔ \(to.name)",
                message: "\(from.name) and \(to.name) are each listed as the other's parent."
            ))
        }
        return findings
    }

    private static func checkInvertedDates(figure: Figure) -> [ConsistencyFinding] {
        guard let birth = figure.birthDate.startYear, let death = figure.deathDate.startYear,
              death < birth else { return [] }
        return [ConsistencyFinding(
            kind: .invertedDates, severity: .warning, entityKind: "Figure",
            entityName: figure.name,
            message: "Death year (\(death)) is before birth year (\(birth))."
        )]
    }

    private static func unknownEraFindings(eraString: String, label: String, entityKind: String, entityName: String, knownKeys: Set<String>) -> [ConsistencyFinding] {
        let trimmed = eraString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard !knownKeys.contains(NameDuplicateCheck.normalizedKey(trimmed)) else { return [] }
        return [ConsistencyFinding(
            kind: .unknownEra, severity: .info, entityKind: entityKind,
            entityName: entityName,
            message: "\(label) references era \"\(trimmed)\", which does not match any Era in the database."
        )]
    }

    private static func checkAmbiguousAliases(alternateNames: [AlternateName]) -> [ConsistencyFinding] {
        var byKey: [String: [(name: String, figureName: String)]] = [:]
        for alt in alternateNames {
            guard let figureName = alt.figure?.name else { continue }
            let key = NameDuplicateCheck.normalizedKey(alt.name)
            byKey[key, default: []].append((alt.name, figureName))
        }
        return byKey.compactMap { _, entries -> ConsistencyFinding? in
            let distinctFigures = Dictionary(grouping: entries, by: \.figureName)
            guard distinctFigures.count > 1 else { return nil }
            let holders = distinctFigures.keys.sorted().joined(separator: ", ")
            let alias = entries[0].name
            return ConsistencyFinding(
                kind: .ambiguousAlias, severity: .warning, entityKind: "AlternateName",
                entityName: alias,
                message: "The name \"\(alias)\" is attached to multiple figures: \(holders)."
            )
        }
    }

    private static func checkStubFigures(figures: [Figure]) -> [ConsistencyFinding] {
        figures.compactMap { figure in
            let isEmptyRecord = figure.figureDescription.isEmpty &&
                figure.domain.isEmpty &&
                figure.incomingRelationships.isEmpty &&
                figure.outgoingRelationships.isEmpty &&
                figure.events.isEmpty &&
                figure.placeAssociations.isEmpty
            guard isEmptyRecord, figure.coverageExempt != true else { return nil }
            return ConsistencyFinding(
                kind: .stubFigure, severity: .info, entityKind: "Figure",
                entityName: figure.name,
                message: "No description, domain, relationships, events, or place associations yet."
            )
        }
    }

    // MARK: - Entry point

    package static func runAll(
        figures: [Figure],
        relationships: [Relationship],
        alternateNames: [AlternateName],
        events: [Event],
        eras: [Era]
    ) -> [ConsistencyFinding] {
        let eraKeys = Set(eras.map { NameDuplicateCheck.normalizedKey($0.name) })

        var findings: [ConsistencyFinding] = []
        for figure in figures {
            findings += checkGenderWording(figure: figure)
            findings += checkInvertedDates(figure: figure)
            findings += unknownEraFindings(eraString: figure.birthDate.era, label: "Birth date",
                                           entityKind: "Figure", entityName: figure.name, knownKeys: eraKeys)
            findings += unknownEraFindings(eraString: figure.deathDate.era, label: "Death date",
                                           entityKind: "Figure", entityName: figure.name, knownKeys: eraKeys)
        }
        for event in events {
            findings += unknownEraFindings(eraString: event.era, label: "Event date",
                                           entityKind: "Event", entityName: event.name, knownKeys: eraKeys)
        }
        findings += checkRoleGenders(relationships: relationships)
        findings += checkParentCycles(relationships: relationships)
        findings += checkAmbiguousAliases(alternateNames: alternateNames)
        findings += checkStubFigures(figures: figures)

        return findings.sorted {
            ($0.entityName, $0.kind.rawValue) < ($1.entityName, $1.kind.rawValue)
        }
    }
}
