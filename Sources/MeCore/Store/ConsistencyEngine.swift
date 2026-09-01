import Foundation
import SwiftData

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
        case aiDraftTable
        case missingSpouseLink
        case bidirectionalMismatch
        case selfReferentialEdge
        case duplicateEdge
        case figureWithoutType
        case figureWithoutDescription
        case eventWithNoLinks
        case placeWithoutCoordinates
        case deathBeforeBirth
        case reignOutsideLifespan
        case childBornBeforeParent
        case orphanedAlternateName
        case orphanedImageAsset
        case sourceWithoutURL

        package var displayLabel: String {
            switch self {
            case .pronounGender: return "Pronoun/Gender mismatch"
            case .genderedNoun: return "Gendered noun mismatch"
            case .roleGender: return "Role-gender mismatch"
            case .parentCycle: return "Parent cycle"
            case .invertedDates: return "Inverted dates"
            case .unknownEra: return "Unknown era"
            case .ambiguousAlias: return "Ambiguous alias"
            case .stubFigure: return "Stub figure"
            case .nameVariant: return "Name variant"
            case .aiDraftTable: return "AI-draft table"
            case .missingSpouseLink: return "Missing spouse link"
            case .bidirectionalMismatch: return "Bidirectional mismatch"
            case .selfReferentialEdge: return "Self-referential edge"
            case .duplicateEdge: return "Duplicate edge"
            case .figureWithoutType: return "Figure without type"
            case .figureWithoutDescription: return "Figure without description"
            case .eventWithNoLinks: return "Event with no links"
            case .placeWithoutCoordinates: return "Place without coordinates"
            case .deathBeforeBirth: return "Death before birth"
            case .reignOutsideLifespan: return "Reign outside lifespan"
            case .childBornBeforeParent: return "Child born before parent"
            case .orphanedAlternateName: return "Orphaned alternate name"
            case .orphanedImageAsset: return "Orphaned image"
            case .sourceWithoutURL: return "Source without URL"
            }
        }

        package var userDefaultsKey: String { "consistencyCheck_\(rawValue)" }
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

    /// Order-independent pair of PersistentIdentifiers for set membership checks.
    private struct StaticIdentifier: Hashable {
        let a: PersistentIdentifier
        let b: PersistentIdentifier
        init(_ x: PersistentIdentifier, _ y: PersistentIdentifier) {
            if x.hashValue <= y.hashValue { (a, b) = (x, y) }
            else { (a, b) = (y, x) }
        }
    }

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

    /// Self-descriptive gender nouns — words that label the FIGURE's own identity
    /// or title (a goddess, a king, a priest). Relational/kinship nouns (mother,
    /// father, son, daughter, sister, brother, wife, husband, widow) deliberately
    /// do NOT appear: they describe OTHER people in the figure's story, so merely
    /// mentioning them ("sons of the gods", "mother of the people") never counts
    /// as misgendering the figure herself.
    private static let feminineNouns: Set<String> = [
        "goddess", "queen", "priestess",
    ]
    private static let masculineNouns: Set<String> = [
        "god", "king", "priest", "prince",
    ]

    /// Figures whose records LEGITIMATELY use gender wording that contradicts the
    /// recorded gender — attested historical anomalies. Kubaba (Kug-Bau) was the
    /// only woman on the Sumerian King List, recorded as a "king" of Kish: the
    /// masculine-wording reading is correct, not an error. For these figures the
    /// gender-wording check is skipped entirely. Keys are normalized via
    /// `NameDuplicateCheck.normalizedKey`.
    private static let genderWordingExemptNames: Set<String> = ["Kug-Bau", "Kubaba", "Kugbau"]
    private static var genderWordingExemptKeys: Set<String> {
        Set(genderWordingExemptNames.map { NameDuplicateCheck.normalizedKey($0) })
    }

    /// Gendered nouns appearing in the text, as exact whole words.
    package static func genderedNounSignals(in text: String) -> (feminine: Set<String>, masculine: Set<String>) {
        let words = Set(tokens(in: text))
        return (words.intersection(feminineNouns), words.intersection(masculineNouns))
    }

    private static func conflictMessage(actual: Figure.Gender, found: String, evidence: [String]) -> String {
        let quoted = evidence.map { "\"\($0)\"" }.sorted().joined(separator: ", ")
        return "Text says \(found) (\(quoted)) but the figure is marked \(actual.rawValue)."
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
        if !ownKeys.isDisjoint(with: genderWordingExemptKeys) { return nil }
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
            return (.genderedNoun, conflictMessage(actual: .male, found: "feminine wording",
                                                   evidence: Array(nouns.feminine)))
        }
        if expectedFemale && !nouns.masculine.isEmpty && nouns.feminine.isEmpty && !competing.contains(.male) {
            return (.genderedNoun, conflictMessage(actual: .female, found: "masculine wording",
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
            // A name typed as a Syncretism is deliberately shared across the
            // syncretized deities (e.g. "Asarluhi" on both Asalluhi and Marduk),
            // so it never counts as an ambiguous/duplicate alias.
            if alt.nameType == .syncretism { continue }
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
            // Letters/digits form tokens; hyphens and apostrophes count as
            // word-interior so "Puzur-Suen" cannot split into a bare "Suen"
            // that then collides with the god "Su'en".
            func isWordChar(_ index: Int) -> Bool {
                index >= 0 && index < scalars.count &&
                (scalars[index].isLetter || scalars[index].isNumber ||
                 scalars[index] == "-" || scalars[index] == "'")
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
                    let spanStart = originIndices[start]
                    let spanEnd = originIndices[end - 1]
                    let span = scalars[spanStart...spanEnd]
                    // A genuine variant only differs in casing and simple
                    // separators. Spans crossing other punctuation ("…of Ur (Ur
                    // III…" fusing into "Urur") are two separate mentions.
                    let plausibleVariant = span.allSatisfy {
                        $0.isLetter || $0.isNumber || $0 == "-" || $0 == " " || $0 == "'"
                    }
                    guard plausibleVariant else { continue }
                    let written = String(span)
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

    /// Detects couples that share a child (via Mother/Father relationships)
    /// but have no Spouse relationship between them.
    private static func checkMissingSpouseLinks(
        figures: [Figure], relationships: [Relationship]
    ) -> [ConsistencyFinding] {
        let spouseType = "Spouse"
        let motherType = "Mother"
        let fatherType = "Father"

        // Build spouse pair set (bidirectional)
        var spousePairs: Set<StaticIdentifier> = []
        for rel in relationships where rel.relationshipType?.name == spouseType {
            if let from = rel.fromFigure, let to = rel.toFigure {
                spousePairs.insert(StaticIdentifier(from.persistentModelID, to.persistentModelID))
            }
        }

        // Build parent maps: child → {mothers, fathers}
        var childMothers: [PersistentIdentifier: Set<PersistentIdentifier>] = [:]
        var childFathers: [PersistentIdentifier: Set<PersistentIdentifier>] = [:]
        for rel in relationships {
            guard let from = rel.fromFigure, let to = rel.toFigure else { continue }
            if rel.relationshipType?.name == motherType {
                childMothers[to.persistentModelID, default: []].insert(from.persistentModelID)
            } else if rel.relationshipType?.name == fatherType {
                childFathers[to.persistentModelID, default: []].insert(from.persistentModelID)
            }
        }

        // For each child with both parents, check if they're linked as Spouse
        var findings: [ConsistencyFinding] = []
        var reported = Set<StaticIdentifier>()

        let idToFigure: [PersistentIdentifier: Figure] = Dictionary(
            figures.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })

        for (childId, mothers) in childMothers {
            guard let fathers = childFathers[childId] else { continue }
            for motherId in mothers {
                for fatherId in fathers {
                    let pair = StaticIdentifier(motherId, fatherId)
                    guard !reported.contains(pair) else { continue }
                    if !spousePairs.contains(pair) {
                        reported.insert(pair)
                        let mother = idToFigure[motherId]?.name ?? "?"
                        let father = idToFigure[fatherId]?.name ?? "?"
                        findings.append(ConsistencyFinding(
                            kind: .missingSpouseLink, severity: .info, entityKind: "Relationship",
                            entityName: "\(father) ↔ \(mother)",
                            message: "\(father) and \(mother) share a child but have no Spouse relationship."
                        ))
                    }
                }
            }
        }
        return findings
    }

    // MARK: - Relationship consistency

    /// Detects relationships that are inherently bidirectional (Spouse, Consort,
    /// Sibling, Ally, Enemy) but only exist in one direction.
    private static func checkBidirectionalMismatch(
        figures: [Figure], relationships: [Relationship]
    ) -> [ConsistencyFinding] {
        let bidirectionalTypes: Set<String> = ["Spouse", "Consort", "Sibling", "Ally", "Enemy"]

        // Build a set of all existing directed edges as (fromID, toID, typeName)
        struct EdgeKey: Hashable {
            let from: PersistentIdentifier
            let to: PersistentIdentifier
            let type: String
        }
        var existing = Set<EdgeKey>()
        for rel in relationships {
            guard let from = rel.fromFigure, let to = rel.toFigure,
                  let typeName = rel.relationshipType?.name else { continue }
            guard bidirectionalTypes.contains(typeName) else { continue }
            existing.insert(EdgeKey(from: from.persistentModelID, to: to.persistentModelID, type: typeName))
        }

        let idToFigure: [PersistentIdentifier: Figure] = Dictionary(
            figures.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })

        var findings: [ConsistencyFinding] = []
        var reported = Set<StaticIdentifier>()

        for edge in existing {
            let reverse = EdgeKey(from: edge.to, to: edge.from, type: edge.type)
            guard !existing.contains(reverse) else { continue }
            let pair = StaticIdentifier(edge.from, edge.to)
            guard !reported.contains(pair) else { continue }
            reported.insert(pair)
            let fromName = idToFigure[edge.from]?.name ?? "?"
            let toName = idToFigure[edge.to]?.name ?? "?"
            findings.append(ConsistencyFinding(
                kind: .bidirectionalMismatch,
                severity: .info,
                entityKind: "Relationship",
                entityName: "\(fromName) → \(toName) (\(edge.type))",
                message: "\(fromName) is \(edge.type.lowercased()) of \(toName), but the reverse link is missing."
            ))
        }
        return findings
    }

    /// Detects self-referential relationships (fromFigure === toFigure)
    /// across all relationship types, not just parent edges.
    private static func checkSelfReferentialEdges(
        relationships: [Relationship]
    ) -> [ConsistencyFinding] {
        var findings: [ConsistencyFinding] = []
        for rel in relationships {
            guard let from = rel.fromFigure, let to = rel.toFigure,
                  from.persistentModelID == to.persistentModelID,
                  let typeName = rel.relationshipType?.name else { continue }
            findings.append(ConsistencyFinding(
                kind: .selfReferentialEdge,
                severity: .warning,
                entityKind: "Relationship",
                entityName: "\(from.name) → \(typeName) → \(to.name)",
                message: "\(from.name) has a \(typeName.lowercased()) relationship to themselves."
            ))
        }
        return findings
    }

    /// Detects duplicate edges: the same from→to→type combination existing
    /// more than once.
    private static func checkDuplicateEdges(
        relationships: [Relationship]
    ) -> [ConsistencyFinding] {
        struct EdgeKey: Hashable {
            let from: PersistentIdentifier
            let to: PersistentIdentifier
            let type: String
        }
        var counts: [EdgeKey: Int] = [:]
        var edgeDisplay: [EdgeKey: (String, String, String)] = [:]

        for rel in relationships {
            guard let from = rel.fromFigure, let to = rel.toFigure,
                  let typeName = rel.relationshipType?.name else { continue }
            let key = EdgeKey(from: from.persistentModelID, to: to.persistentModelID, type: typeName)
            counts[key, default: 0] += 1
            edgeDisplay[key] = (from.name, to.name, typeName)
        }

        var findings: [ConsistencyFinding] = []
        for (key, count) in counts where count > 1 {
            guard let (fromName, toName, typeName) = edgeDisplay[key] else { continue }
            findings.append(ConsistencyFinding(
                kind: .duplicateEdge,
                severity: .warning,
                entityKind: "Relationship",
                entityName: "\(fromName) → \(toName) (\(typeName)) ×\(count)",
                message: "\(fromName) → \(toName) has \(count) identical \"\(typeName)\" relationships."
            ))
        }
        return findings
    }

    // MARK: - Data completeness

    /// Flags figures whose `figureType` is nil — likely newly created and never assigned.
    private static func checkFigureWithoutType(figures: [Figure]) -> [ConsistencyFinding] {
        figures.filter { $0.figureType == nil }.map {
            ConsistencyFinding(
                kind: .figureWithoutType, severity: .info,
                entityKind: "Figure", entityName: $0.name,
                message: "\($0.name) has no type assigned."
            )
        }
    }

    /// Flags figures with empty `figureDescription` — newly imported stubs.
    private static func checkFigureWithoutDescription(figures: [Figure]) -> [ConsistencyFinding] {
        figures.filter { $0.figureDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map {
            ConsistencyFinding(
                kind: .figureWithoutDescription, severity: .info,
                entityKind: "Figure", entityName: $0.name,
                message: "\($0.name) has no description."
            )
        }
    }

    /// Flags events that have no involved figures and no place associations.
    private static func checkEventWithNoLinks(events: [Event]) -> [ConsistencyFinding] {
        events.filter { $0.involvedFigures.isEmpty && $0.placeAssociations.isEmpty }.map {
            ConsistencyFinding(
                kind: .eventWithNoLinks, severity: .info,
                entityKind: "Event", entityName: $0.name,
                message: "\($0.name) has no figures or places linked."
            )
        }
    }

    /// Flags places with nil latitude and longitude — unless the place is
    /// explicitly marked as having unknown coordinates (its site has not been
    /// identified).
    private static func checkPlaceWithoutCoordinates(places: [Place]) -> [ConsistencyFinding] {
        places.filter { $0.latitude == nil && $0.longitude == nil && $0.coordinatesUnknown != true }.map {
            ConsistencyFinding(
                kind: .placeWithoutCoordinates, severity: .info,
                entityKind: "Place", entityName: $0.name,
                message: "\($0.name) has no coordinates."
            )
        }
    }

    // MARK: - Temporal logic

    /// Flags figures whose death date is earlier than their birth date.
    private static func checkDeathBeforeBirth(figures: [Figure]) -> [ConsistencyFinding] {
        var findings: [ConsistencyFinding] = []
        for figure in figures {
            guard let birthYear = figure.birthDate.startYear ?? figure.birthDate.endYear,
                  let deathYear = figure.deathDate.endYear ?? figure.deathDate.startYear else { continue }
            if deathYear < birthYear {
                findings.append(ConsistencyFinding(
                    kind: .deathBeforeBirth, severity: .warning,
                    entityKind: "Figure", entityName: figure.name,
                    message: "\(figure.name) dies (\(deathYear)) before being born (\(birthYear))."
                ))
            }
        }
        return findings
    }

    /// Flags figures whose reign dates fall outside their lifespan.
    private static func checkReignOutsideLifespan(figures: [Figure]) -> [ConsistencyFinding] {
        var findings: [ConsistencyFinding] = []
        for figure in figures {
            guard let reignStart = figure.reignStartYear,
                  let reignEnd = figure.reignEndYear else { continue }
            let birthYear = figure.birthDate.startYear ?? figure.birthDate.endYear
            let deathYear = figure.deathDate.endYear ?? figure.deathDate.startYear

            if let birth = birthYear, reignStart < birth {
                findings.append(ConsistencyFinding(
                    kind: .reignOutsideLifespan, severity: .warning,
                    entityKind: "Figure", entityName: figure.name,
                    message: "\(figure.name)'s reign starts (\(reignStart)) before birth (\(birth))."
                ))
            }
            if let death = deathYear, reignEnd > death {
                findings.append(ConsistencyFinding(
                    kind: .reignOutsideLifespan, severity: .warning,
                    entityKind: "Figure", entityName: figure.name,
                    message: "\(figure.name)'s reign ends (\(reignEnd)) after death (\(death))."
                ))
            }
        }
        return findings
    }

    /// Flags children whose birth date is earlier than their parent's.
    private static func checkChildBornBeforeParent(
        figures: [Figure], relationships: [Relationship]
    ) -> [ConsistencyFinding] {
        let parentTypes: Set<String> = ["Father", "Mother"]

        // Build child → parent mapping
        var childParents: [PersistentIdentifier: [(name: String, birthYear: Int?)]] = [:]
        let idToFigure: [PersistentIdentifier: Figure] = Dictionary(
            figures.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })

        for rel in relationships {
            guard let typeName = rel.relationshipType?.name,
                  parentTypes.contains(typeName),
                  let parent = rel.fromFigure, let child = rel.toFigure else { continue }
            let parentBirth = parent.birthDate.startYear ?? parent.birthDate.endYear
            childParents[child.persistentModelID, default: []].append((parent.name, parentBirth))
        }

        var findings: [ConsistencyFinding] = []
        var reported = Set<String>()

        for (childId, parents) in childParents {
            guard let child = idToFigure[childId],
                  let childBirth = child.birthDate.startYear ?? child.birthDate.endYear else { continue }
            for parent in parents {
                guard let parentBirth = parent.birthYear else { continue }
                if childBirth < parentBirth {
                    let key = "\(child.name)|\(parent.name)"
                    guard !reported.contains(key) else { continue }
                    reported.insert(key)
                    findings.append(ConsistencyFinding(
                        kind: .childBornBeforeParent, severity: .warning,
                        entityKind: "Figure", entityName: child.name,
                        message: "\(child.name) is born (\(childBirth)) before \(parent.name) (\(parentBirth))."
                    ))
                }
            }
        }
        return findings
    }

    // MARK: - Data integrity

    /// Flags alternate names whose figure and place are both nil.
    private static func checkOrphanedAlternateNames(alternateNames: [AlternateName]) -> [ConsistencyFinding] {
        alternateNames.filter { $0.figure == nil && $0.place == nil }.map {
            ConsistencyFinding(
                kind: .orphanedAlternateName, severity: .warning,
                entityKind: "AlternateName", entityName: $0.name,
                message: "Alternate name \"\($0.name)\" is not linked to any figure or place."
            )
        }
    }

    /// Flags image assets not linked to any figure, place, event, or thing.
    private static func checkOrphanedImageAssets(imageAssets: [ImageAsset]) -> [ConsistencyFinding] {
        imageAssets.filter {
            $0.figures.isEmpty && $0.mugshots.isEmpty && $0.places.isEmpty && $0.events.isEmpty && $0.things.isEmpty
        }.map {
            ConsistencyFinding(
                kind: .orphanedImageAsset, severity: .warning,
                entityKind: "ImageAsset", entityName: $0.filename.isEmpty ? "(unnamed)" : $0.filename,
                message: "Image \"\($0.filename.isEmpty ? "(unnamed)" : $0.filename)\" is not linked to any entity."
            )
        }
    }

    /// Flags sources with empty or blank URL.
    private static func checkSourcesWithoutURL(sources: [Source]) -> [ConsistencyFinding] {
        sources.filter { $0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map {
            ConsistencyFinding(
                kind: .sourceWithoutURL, severity: .info,
                entityKind: "Source", entityName: $0.name,
                message: "Source \"\($0.name)\" has no URL."
            )
        }
    }

    /// True when a source string points at LLM-generated placeholder content
    /// rather than a citable work. Matched on the normalized key so spacing,
    /// casing, and punctuation variants all count.
    package static func isAIDraftSourceName(_ name: String) -> Bool {
        let key = NameDuplicateCheck.normalizedKey(name)
        return key.contains("gemini")
            || key.contains("aigenerated")
            || key.contains("chatgpt")
            || key.contains("claude")
            || key.contains("llm")
    }

    /// Flags comparison tables whose provenance still rests on AI-generated
    /// content — either via the table-wide source or individual cells — and
    /// reports how many cells lack their own verified source yet.
    package static func checkAIDraftTables(tables: [PopupTable]) -> [ConsistencyFinding] {
        var findings: [ConsistencyFinding] = []
        for table in tables {
            let tableIsDraft = table.source.map { isAIDraftSourceName($0) } ?? false
            let draftCellCount = table.cells.filter { cell in
                cell.effectiveCellSourceNames.contains { isAIDraftSourceName($0.name) }
            }.count
            guard tableIsDraft || draftCellCount > 0 else { continue }

            let total = table.cells.count
            let tableSource = (table.source ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // A non-AI table-wide source covers every cell that lacks its own
            // individual source. Only when the table-wide source is absent or
            // itself AI-generated are uncovered cells still reported as unsourced.
            let cellsCoveredByTable = !tableSource.isEmpty && !tableIsDraft
            let unsourcedCount = cellsCoveredByTable
                ? 0
                : table.cells.filter { $0.effectiveCellSourceNames.isEmpty }.count

            var parts: [String] = []
            if tableIsDraft {
                parts.append("table-wide source is AI-generated content")
            }
            if draftCellCount > 0 {
                parts.append("\(draftCellCount) cell\(draftCellCount == 1 ? "" : "s") cit\(draftCellCount == 1 ? "es" : "e") AI-generated content")
            }
            let coverage: String
            if total == 0 {
                coverage = "The table has no cells yet."
            } else if unsourcedCount == 0 {
                coverage = cellsCoveredByTable
                    ? "All cells are covered by the table-wide source."
                    : "All \(total) cells carry their own source."
            } else {
                coverage = "\(unsourcedCount) of \(total) cells have no individual source yet."
            }
            findings.append(ConsistencyFinding(
                kind: .aiDraftTable,
                severity: .info,
                entityKind: "Comparison Table",
                entityName: table.name,
                message: "Comparison table \"\(table.name)\": \(parts.joined(separator: "; ")). \(coverage)"
            ))
        }
        return findings
    }

    package static func runAll(
        figures: [Figure],
        relationships: [Relationship],
        alternateNames: [AlternateName],
        events: [Event],
        eras: [Era],
        places: [Place] = [],
        imageAssets: [ImageAsset] = [],
        sources: [Source] = [],
        popupTables: [PopupTable] = []
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
        findings += checkMissingSpouseLinks(figures: figures, relationships: relationships)
        findings += checkBidirectionalMismatch(figures: figures, relationships: relationships)
        findings += checkSelfReferentialEdges(relationships: relationships)
        findings += checkDuplicateEdges(relationships: relationships)
        findings += checkFigureWithoutType(figures: figures)
        findings += checkFigureWithoutDescription(figures: figures)
        findings += checkEventWithNoLinks(events: events)
        findings += checkPlaceWithoutCoordinates(places: places)
        findings += checkDeathBeforeBirth(figures: figures)
        findings += checkReignOutsideLifespan(figures: figures)
        findings += checkChildBornBeforeParent(figures: figures, relationships: relationships)
        findings += checkOrphanedAlternateNames(alternateNames: alternateNames)
        findings += checkOrphanedImageAssets(imageAssets: imageAssets)
        findings += checkSourcesWithoutURL(sources: sources)
        findings += checkAIDraftTables(tables: popupTables)

        return findings.sorted {
            ($0.entityName, $0.kind.rawValue) < ($1.entityName, $1.kind.rawValue)
        }
    }
}
