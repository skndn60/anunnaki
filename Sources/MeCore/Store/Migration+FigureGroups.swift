import Foundation
import SwiftData

extension Migration {
    /// Create default figure groups if none exist.
    package static func ensureDefaultFigureGroups(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<FigureGroup>())) ?? 0
        guard count == 0 else { return }

        let defaults: [(name: String, description: String, icon: String, colorHex: String, filter: GroupMemberFilter?, kind: GroupKind)] = [
            ("Divine Council", "Gods who sit in council, including the Anunnaki and Igigi", "person.3", "5856D6", nil, .standard),
            ("Sumerian Pantheon", "Major gods and goddesses of the Sumerian pantheon", "star", "FF9500",
             GroupMemberFilter(figureTypeNames: ["Deity"], domainKeywords: ["Sumerian"]), .standard),
            ("Akkadian/East Semitic", "Gods of the Akkadian, Assyrian, and Babylonian traditions", "star.circle", "FF3B30",
             GroupMemberFilter(domainKeywords: ["Akkadian", "Babylonian", "Assyrian"]), .standard),
            ("Book of Enoch", "Figures from the Book of Enoch tradition", "book", "FBBF24", nil, .enoch),
            ("Primordial Beings", "Primordial entities from before the gods", "sparkles", "8E8E93",
             GroupMemberFilter(figureTypeNames: ["Primordial"]), .standard),
            ("SKL Kings", "Kings of the Sumerian King List", "list.star", "007AFF",
             GroupMemberFilter(domainKeywords: ["Kingship"]), .skl),
        ]

        for (idx, config) in defaults.enumerated() {
            let filterJSON: String?
            if let filter = config.filter, let data = try? JSONEncoder().encode(filter) {
                filterJSON = String(data: data, encoding: .utf8)
            } else {
                filterJSON = nil
            }
            let group = FigureGroup(
                name: config.name,
                groupDescription: config.description,
                icon: config.icon,
                colorHex: config.colorHex,
                orderIndex: idx,
                memberFilter: filterJSON,
                isSmart: config.filter != nil,
                kind: config.kind
            )
            context.insert(group)
        }
        try? context.save()
    }

    package static func ensureFigureGroupKinds(context: ModelContext) {
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []

        let kindByName: [String: GroupKind] = [
            "Book of Enoch": .enoch,
            "SKL Kings": .skl,
            "Sumerian King List": .skl,
        ]

        let iconByName: [String: String] = [
            "Divine Council": "person.3",
            "Sumerian Pantheon": "star",
            "Akkadian/East Semitic": "star.circle",
            "Book of Enoch": "book",
            "SKL Kings": "list.star",
            "Sumerian King List": "list.star",
        ]

        for group in allGroups {
            if let kind = kindByName[group.name], group.kind != kind {
                group.kind = kind
            }
            if let icon = iconByName[group.name], group.icon != icon {
                group.icon = icon
            }
        }

        try? context.save()
    }

    /// Remove the legacy empty "The Flood" placeholder group if it is still empty
    /// (no members, subgroups, or text blocks). Deletes nothing that has content.
    package static func removeFloodPlaceholder(context: ModelContext) {
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let group = allGroups.first(where: { $0.name == "The Flood" }) else { return }
        let hasContent = !group.figureAssociations.isEmpty
            || !((group.subgroups ?? []).isEmpty)
            || !((group.textBlocks ?? []).isEmpty)
        guard !hasContent else { return }
        try? context.transaction {
            group.figureAssociations = []
            group.subgroups = []
            group.textBlocks = []
            context.delete(group)
        }
    }

    /// Sweeps `FigureGroupAssociation` rows whose group was deleted. Group deletion empties the
    /// group-side association array (the crash-safe macOS 26 pattern), which nullifies each row's
    /// `group` but leaves the row itself linked from the entity-side arrays — so figures can show
    /// phantom group rows with a "?" description. Detach from every inverse side, then delete.
    package static func removeOrphanedGroupAssociations(context: ModelContext) {
        let orphans = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>()))?.filter { $0.group == nil } ?? []
        guard !orphans.isEmpty else { return }
        try? context.transaction {
            for assoc in orphans {
                assoc.figure?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                assoc.place?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                assoc.event?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                assoc.thing?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                context.delete(assoc)
            }
        }
    }

    package static func ensureImportedDeityRelationships(context: ModelContext) {
        let relationships: [(from: String, to: String, type: String, source: String)] = [
            ("Gugalanna", "Ereshkigal", "Spouse", "Sumerian mythology"),
            ("Inanna", "Shara", "Mother", "Sumerian texts"),
            ("Isimud", "Enki", "Servant", "Sumerian texts"),
            ("Ninshubur", "Inanna", "Servant", "Sumerian texts"),
            ("Papsukkal", "Anu", "Servant", "Akkadian texts"),
            ("Ereshkigal", "Ninazu", "Mother", "Sumerian texts"),
            ("Gugalanna", "Ninazu", "Father", "Sumerian texts"),
            ("Enki", "Kulla", "Creator", "Sumerian texts"),
            ("Enki", "Mushdamma", "Creator", "Sumerian texts"),
            ("Anu", "Ishkur", "Father", "Akkadian texts"),
        ]

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName = allFigures.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }

        let allRelTypes = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        let existingRelationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []

        for rel in relationships {
            guard let fromFigure = figureByName[rel.from.lowercased()],
                  let toFigure = figureByName[rel.to.lowercased()],
                  let relType = allRelTypes.first(where: { $0.name == rel.type }) else { continue }

            let alreadyExists = existingRelationships.contains { existing in
                existing.fromFigure?.persistentModelID == fromFigure.persistentModelID &&
                existing.toFigure?.persistentModelID == toFigure.persistentModelID &&
                existing.relationshipType?.persistentModelID == relType.persistentModelID
            }
            guard !alreadyExists else { continue }

            let relationship = Relationship(
                fromFigure: fromFigure,
                toFigure: toFigure,
                relationshipType: relType,
                source: rel.source
            )
            context.insert(relationship)
        }
        try? context.save()
    }

    /// Auto-assign reign order for Sumerian King List groups. For any group whose kind (or an
    /// ancestor's kind) is `.skl`, order its figure members by their chronological key
    /// (era position then in-era sequence) and enable manual ordering. Only runs when no member
    /// has an explicit `orderIndex` yet, so user-arranged orders are never overwritten. Additive.
    package static func ensureSKLRegnalOrder(context: ModelContext) {
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard !allGroups.isEmpty else { return }

        func partOfSKLChain(_ group: FigureGroup) -> Bool {
            if group.kind == .skl { return true }
            if let parent = group.parentGroup { return partOfSKLChain(parent) }
            return false
        }

        var changed = false
        for group in allGroups where partOfSKLChain(group) {
            guard group.entityType == .figure,
                  !group.figureAssociations.isEmpty,
                  group.figureAssociations.allSatisfy({ $0.orderIndex == nil }) else { continue }
            group.applyRegnalOrder()
            group.sortMode = .ordered
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Fix `Figure.orderIndex` for SKL figures whose seed order was wrong (Etana
    /// appeared before Jushur in an earlier seed_data.json). Reads the corrected
    /// seed, recomputes per-era orderIndex values, and re-runs `applyRegnalOrder`
    /// on every SKL-chain group so association display order matches the SKL.
    /// One-shot: only acts when at least one SKL figure's orderIndex doesn't match
    /// the seed (checked via a hash of expected values).
    package static func fixSKLFigureOrder(context: ModelContext) {
        guard let url = Bundle.module.url(forResource: "seed_data", withExtension: "json")
                ?? Bundle.main.url(forResource: "seed_data", withExtension: "json") else { return }
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []

        var expectedOrderIndex: [String: Int] = [:]
        var expectedOrderEra: [String: String] = [:]
        var sklEraIndex: [String: Int] = [:]
        for seedFig in root.figures {
            guard seedFig.source.contains("Sumerian King List") else { continue }
            let era = seedFig.birthDate.era.isEmpty ? "Antediluvian" : seedFig.birthDate.era
            let idx = sklEraIndex[era, default: 0]
            expectedOrderIndex[seedFig.name] = idx
            expectedOrderEra[seedFig.name] = era
            sklEraIndex[era] = idx + 1
        }

        var changed = false
        for (name, expectedIdx) in expectedOrderIndex {
            guard let figure = allFigures.first(where: { Self.seedNameKey($0.name) == Self.seedNameKey(name) && Self.seedNameKey($0.birthDate.era) == Self.seedNameKey(expectedOrderEra[name] ?? "") }),
                  figure.orderIndex != expectedIdx else { continue }
            figure.orderIndex = expectedIdx
            changed = true
        }
        guard changed else { return }
        try? context.save()

        func partOfSKLChain(_ group: FigureGroup) -> Bool {
            if group.kind == .skl { return true }
            if let parent = group.parentGroup { return partOfSKLChain(parent) }
            return false
        }
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        for group in allGroups where partOfSKLChain(group) && group.entityType == .figure && !group.figureAssociations.isEmpty {
            group.applyRegnalOrder()
            group.sortMode = .ordered
        }
        try? context.save()
    }

    /// Backfill `Figure.reignYears` from each figure's description ("Listed reign" /
    /// "Reigned X years" phrasing) when the field isn't set yet. Additive + idempotent —
    /// never overwrites a value the user typed. Runs after figure-creating migrations so
    /// newly seeded figures get populated on the same launch.
    package static func ensureReignYears(context: ModelContext) {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for figure in figures where figure.reignYears == nil {
            guard let reign = ReignLength.parse(from: figure.figureDescription) else { continue }
            figure.reignYears = reign.years
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Backfills `Figure.epithet` from the `Epithet: ...` prose embedded in
    /// `figureDescription` (our seed writes e.g. `Epithet: ''"the boatman"''.` or
    /// `Epithet: 'the shepherd'`). Additive + idempotent — never overwrites a
    /// user-entered value.
    package static func ensureEpithets(context: ModelContext) {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for figure in figures where figure.epithet == nil {
            guard let epithet = Self.extractEpithet(from: figure.figureDescription) else { continue }
            figure.epithet = epithet
            changed = true
        }
        if changed { try? context.save() }
    }

    package static func ensureComputedSKLDates(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let allEras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraOrder = allEras.reduce(into: [:]) { $0[$1.name] = $1.orderIndex }
        let timelines = SKLDatePropagator.compute(figures: allFigures, eraOrder: eraOrder)
        var changed = false
        for timeline in timelines {
            for reign in timeline.reigns {
                guard reign.figure.birthDate.startYear == nil,
                      let startBCE = reign.startBCE else { continue }
                let endBCE = reign.endBCE ?? startBCE
                reign.figure.birthDate = MythologicalDate(
                    startYear: startBCE,
                    endYear: endBCE,
                    era: reign.figure.birthDate.era,
                    isApproximate: true
                )
                if reign.figure.deathDate.endYear == nil {
                    reign.figure.deathDate = MythologicalDate(
                        startYear: nil,
                        endYear: endBCE,
                        era: reign.figure.deathDate.era,
                        isApproximate: true
                    )
                }
                reign.figure.dateSource = Figure.DateSource.computed.rawValue
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Reconciles `Figure.era` links so they always mirror the canonical era
    /// name (the `birthDate.era` string first, else the "Ruler from/in/of …"
    /// description prefix as a fallback). Runs every launch; idempotent and
    /// additive — `figure.era` is pure derived data, never hand-edited.
    package static func ensureFigureEraLinks(context: ModelContext) {
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        var eraByKey: [String: Era] = [:]
        for era in eras {
            eraByKey[era.name] = era
            if era.name == "Age of the Watchers" { eraByKey["Before the Flood"] = era }
            if era.name == "Gutian rule" { eraByKey["Guthian rule"] = era }
        }
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for figure in figures {
            changed = Self.reconcileBirthEraString(figure, eraByKey: eraByKey) || changed
            let target = Self.resolveEraTarget(for: figure, eraByKey: eraByKey)
            if figure.era?.persistentModelID != target?.persistentModelID {
                figure.era = target
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    package static let eraTypoMap: [String: String] = [
        "Guthian rule": "Gutian rule",
    ]

    package static func fixEraTypos(context: ModelContext) {
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByName = eras.reduce(into: [:]) { $0[$1.name] = $1 }
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for figure in figures {
            if let corrected = Self.eraTypoMap[figure.birthDate.era] {
                figure.birthDate.era = corrected
                figure.deathDate.era = corrected
                changed = true
            }
            if let eraName = Self.eraTypoMap.values.first(where: { $0 == figure.birthDate.era }),
               let target = eraByName[eraName],
               figure.era?.persistentModelID != target.persistentModelID {
                figure.era = target
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// If a figure's birth-era string is empty, derive the era name from the
    /// "Ruler from/in/of …" description prefix and write it into the string, so
    /// the string stays the complete source of truth (the description-derived
    /// era was historically only visible via a separate EraDetailView heuristic).
    /// Only writes when the derived name resolves to a known Era (or known alias)
    /// and clears provably auto-written garbage (an unmatched era string that
    /// exactly equals the description-derived name). Never touches a
    /// user-typed value.
    package static func reconcileBirthEraString(_ figure: Figure, eraByKey: [String: Era]) -> Bool {
        var changed = false
        let derived = eraName(fromDescription: figure.figureDescription)
        let current = figure.birthDate.era.trimmingCharacters(in: .whitespacesAndNewlines)

        if !current.isEmpty, let derived, derived == current, eraByKey[current] == nil {
            figure.birthDate.era = ""
            changed = true
        }
        if figure.birthDate.era.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let derived, let canonical = eraByKey[derived], figure.birthDate.era != canonical.name {
            figure.birthDate.era = canonical.name
            changed = true
        }
        return changed
    }

    package static func eraName(fromDescription desc: String) -> String? {
        let prefixes = ["Ruler from the ", "Ruler in the ", "Ruler of "]
        for prefix in prefixes where desc.hasPrefix(prefix) {
            let remainder = desc.dropFirst(prefix.count)
            let endChars: [Character] = [".", "(", "—", "\n"]
            let name = String(remainder.prefix { !endChars.contains($0) }).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                return name == "Sumerian King List" ? "Antediluvian Period" : name
            }
        }
        return nil
    }

    package static func resolveEraTarget(for figure: Figure, eraByKey: [String: Era]) -> Era? {
        let raw = figure.birthDate.era.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty { return eraByKey[raw] }
        return Self.eraName(fromDescription: figure.figureDescription).flatMap { eraByKey[$0] }
    }

    /// Resolves a single figure's era link from its birth-era string (alias-aware).
    /// Used by the figure form so an edit reflects immediately, not at next launch.
    package static func era(named text: String, context: ModelContext) -> Era? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let name = raw == "Before the Flood" ? "Age of the Watchers" : raw
        return (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == name })))?.first
    }

    package static func extractEpithet(from text: String) -> String? {
        // Matches `Epithet: ''"the boatman"''` (seed JSON-escaped quotes) and
        // `Epithet: 'the shepherd'` (single-quoted prose).
        let patterns = [
            #"Epithet:\s*''"(.+?)"''"#,
            #"Epithet:\s*'(.+?)'"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let epithet = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !epithet.isEmpty { return epithet }
            }
        }
        return nil
    }

}
