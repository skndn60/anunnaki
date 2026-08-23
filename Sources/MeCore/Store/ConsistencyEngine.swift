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
        case nameVariant
    }

    package enum Severity: String {
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
    /// title. Pronouns must appear at least TWICE in the opposite direction to
    /// flag: a lone backward-referring pronoun ("…consort of Inanna. Sent to the
    /// underworld as her substitute.") usually points at the other person, while
    /// genuinely misgendered text ("She guards her temple") repeats itself.
    /// Mixed-signal text always stays silent because it may describe several
    /// people. Gendered nouns flag on their own since they are unambiguous —
    /// UNLESS the text also mentions another figure of the conflicting gender
    /// (`mentionIndex`), who may own those words instead ("…him" after naming
    /// Enki; "born to mother Nammu"). Callers should pass an index built by
    /// `mentionGenderIndex`; empty defaults keep the old behavior. `ownKeys`
    /// excludes the figure's own names so homonyms cannot silence genuine
    /// findings about themselves.
    package static func genderConflict(
        gender: Figure.Gender, title: String, figureDescription: String,
        mentionIndex: [String: Figure.Gender] = [:], ownKeys: Set<String> = []
    ) -> (kind: ConsistencyFinding.Kind, message: String)? {
        switch gender {
        case .male, .female:
            break
        case .nonBinary, .unknown:
            return nil
        }
        let expectedFemale = gender == .female
        let text = title + " " + figureDescription
        let competing = mentionedOtherGenders(
            in: text, index: mentionIndex, ownKeys: ownKeys
        )
        let pronouns = pronounSignals(in: text)
        if !expectedFemale && pronouns.female >= 2 && pronouns.male == 0 && !competing.contains(.female) {
            return (.pronounGender, "Description uses \"she/her\" but the figure is marked Male.")
        }
        if expectedFemale && pronouns.male >= 2 && pronouns.female == 0 && !competing.contains(.male) {
            return (.pronounGender, "Description uses \"he/him\" but the figure is marked Female.")
        }
        let nouns = genderedNounSignals(in: text)
        if !expectedFemale && !nouns.feminine.isEmpty && nouns.masculine.isEmpty && !competing.contains(.female) {
            return (.genderedNoun, conflictMessage(expected: .female, found: "feminine wording",
                                                   evidence: Array(nouns.feminine)))
        }
        if expectedFemale && !nouns.masculine.isEmpty && nouns.feminine.isEmpty && !competing.contains(.male) {
            return (.genderedNoun, conflictMessage(expected: .male, found: "masculine wording",
                                                   evidence: Array(nouns.masculine)))
        }
        return nil
    }

    /// Maps each figure name / alias to its gender, for the third-party mention
    /// veto. Keys claimed by different genders become `.unknown` (never veto).
    package static func mentionGenderIndex(figures: [Figure]) -> [String: Figure.Gender] {
        var index: [String: Figure.Gender] = [:]
        func insert(_ raw: String, _ gender: Figure.Gender) {
            let key = NameDuplicateCheck.normalizedKey(raw)
            guard !key.isEmpty else { return }
            if let existing = index[key] {
                if existing != gender { index[key] = .unknown }
            } else {
                index[key] = gender
            }
        }
        for figure in figures {
            insert(figure.name, figure.gender)
            for alt in figure.alternateNames where !alt.name.isEmpty {
                insert(alt.name, figure.gender)
            }
        }
        return index
    }

    /// Genders of OTHER registered figures whose names appear in the text,
    /// matched as whole-token sequences (up to four tokens, punctuation
    /// stripped per token — handles multi-word and hyphenated names alike).
    private static func mentionedOtherGenders(
        in text: String, index: [String: Figure.Gender], ownKeys: Set<String>
    ) -> Set<Figure.Gender> {
        let tokens: [String] = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { String($0.filter { $0.isLetter || $0.isNumber }) }
            .filter { !$0.isEmpty }
        var genders: Set<Figure.Gender> = []
        for start in tokens.indices {
            var joined = ""
            for token in tokens[start..<min(start + 4, tokens.count)] {
                joined += token
                guard let candidate = index[joined], candidate != .unknown, !ownKeys.contains(joined) else {
                    continue
                }
                genders.insert(candidate)
            }
        }
        return genders
    }

    // MARK: - Rules

    private static func checkGenderWording(
        figure: Figure, mentionIndex: [String: Figure.Gender], ownKeys: Set<String>
    ) -> [ConsistencyFinding] {
        guard let result = genderConflict(
            gender: figure.gender, title: figure.title, figureDescription: figure.figureDescription,
            mentionIndex: mentionIndex, ownKeys: ownKeys
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
            let names = [from.name, to.name].sorted()
            findings.append(ConsistencyFinding(
                kind: .parentCycle, severity: .warning, entityKind: "Relationship",
                entityName: "\(names[0]) ↔ \(names[1])",
                message: "\(names[0]) and \(names[1]) are each listed as the other's parent."
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
            let spellings = Dictionary(grouping: entries, by: \.name)
            let alias = spellings.max { lhs, rhs in
                lhs.value.count != rhs.value.count
                    ? lhs.value.count < rhs.value.count
                    : lhs.key > rhs.key
            }?.key ?? entries[0].name
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

    /// Finds description mentions that normalize to a registered figure name
    /// or alias but are spelled differently ("Enbiishtar" vs "Enbi-Ishtar").
    /// Sloppy spellings also break the auto-link feature, which matches exact
    /// names. Matching runs over separator-collapsed text with word-boundary
    /// checks against the ORIGINAL string, so "Anu" never fires inside
    /// "Anunnaki", and possessives ("Inanna's") never flag. Keys shorter than
    /// four characters and keys shared by several distinct spellings (Uraš-style
    /// homonyms) are skipped — too noisy or impossible to recommend a form.
    private static func checkNameVariants(figures: [Figure]) -> [ConsistencyFinding] {
        var displaysByKey: [String: Set<String>] = [:]
        for figure in figures {
            if !figure.name.isEmpty {
                displaysByKey[NameDuplicateCheck.normalizedKey(figure.name), default: []]
                    .insert(figure.name)
            }
            for alt in figure.alternateNames where !alt.name.isEmpty {
                displaysByKey[NameDuplicateCheck.normalizedKey(alt.name), default: []]
                    .insert(alt.name)
            }
        }
        var buckets: [Character: [(key: [Character], display: String)]] = [:]
        for (key, displays) in displaysByKey {
            guard key.count >= 4, displays.count == 1, let display = displays.first else { continue }
            let chars = Array(key)
            buckets[chars[0], default: []].append((chars, display))
        }

        var findings: [ConsistencyFinding] = []
        for figure in figures {
            let text = figure.figureDescription
            guard !text.isEmpty else { continue }
            let scalars = Array(text)
            func isWordChar(_ index: Int) -> Bool {
                index >= 0 && index < scalars.count && (scalars[index].isLetter || scalars[index].isNumber)
            }
            var collapsed: [Character] = []
            var originIndices: [Int] = []
            for (i, ch) in scalars.enumerated() where ch.isLetter || ch.isNumber {
                collapsed.append(Character(ch.lowercased()))
                originIndices.append(i)
            }

            var reported: Set<String> = []
            for start in 0..<collapsed.count {
                guard let candidates = buckets[collapsed[start]], !candidates.isEmpty else { continue }
                for entry in candidates {
                    let keyChars = entry.key
                    let end = start + keyChars.count
                    guard end <= collapsed.count,
                          collapsed[start..<end].elementsEqual(keyChars) else { continue }
                    guard !isWordChar(originIndices[start] - 1),
                          !isWordChar(originIndices[end - 1] + 1) else { continue }
                    let written = String(scalars[originIndices[start]...originIndices[end - 1]])
                    if written.lowercased() != entry.display.lowercased(),
                       reported.insert(entry.display).inserted {
                        findings.append(ConsistencyFinding(
                            kind: .nameVariant, severity: .warning, entityKind: "Figure",
                            entityName: figure.name,
                            message: "Description writes \"\(written)\"; the registered name is \"\(entry.display)\". Auto-linking misses variant spellings."
                        ))
                    }
                }
            }
        }
        return findings
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
        let mentionIndex = mentionGenderIndex(figures: figures)

        var findings: [ConsistencyFinding] = []
        for figure in figures {
            var ownKeys = Set([figure.name].map { NameDuplicateCheck.normalizedKey($0) })
            ownKeys.formUnion(figure.alternateNames.map { NameDuplicateCheck.normalizedKey($0.name) })
            findings += checkGenderWording(figure: figure, mentionIndex: mentionIndex, ownKeys: ownKeys)
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
        findings += checkNameVariants(figures: figures)

        return findings.sorted {
            ($0.entityName, $0.kind.rawValue) < ($1.entityName, $1.kind.rawValue)
        }
    }
}
