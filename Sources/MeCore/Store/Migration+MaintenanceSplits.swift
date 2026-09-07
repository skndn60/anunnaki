import Foundation
import SwiftData

extension Migration {
    /// Backfill ActivityLogEntry.user links for entries written before the
    /// key-based relation existed (they only carry the userName snapshot).
    /// Idempotent: only touches entries whose user is nil and whose snapshot
    /// name matches exactly one user (case-insensitive).
    package static func ensureActivityLogUserLinks(context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<ActivityLogEntry>())) ?? []
        let unlinked = entries.filter { $0.user == nil && !$0.userName.isEmpty }
        guard !unlinked.isEmpty else { return }

        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        guard !users.isEmpty else { return }

        var changed = false
        for entry in unlinked {
            let matches = users.filter { $0.name.caseInsensitiveCompare(entry.userName) == .orderedSame }
            guard matches.count == 1, let user = matches.first else { continue }
            entry.user = user
            user.activityLogEntries?.append(entry)
            changed = true
        }
        if changed { try? context.save() }
    }
}

extension Migration {
    /// Promote the earliest-created user to administrator when no admin exists.
    /// Idempotent: fires only while the store has zero administrators, so a
    /// later admin demotion or role edit is never overridden.
    package static func ensureFirstUserIsAdmin(context: ModelContext) {
        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        guard !users.isEmpty else { return }
        guard !users.contains(where: \.isAdministrator) else { return }

        let first = users.min { ($0.createdAt, $0.name) < ($1.createdAt, $1.name) }
        first?.isAdmin = true
        try? context.save()
    }

    /// Marks figures that already had syncretised deity names in the database
    /// before the 2026-08-26 missing-deities import. Each gets a sticky note
    /// so the user can review the relationship. Additive + idempotent.
    package static func markPreExistingSyncretisms(context: ModelContext) {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName: [String: Figure] = Dictionary(uniqueKeysWithValues: figures.map { ($0.name.lowercased(), $0) })

        let syncretisms: [(existingName: String, altName: String)] = [
            ("Ninhursag", "Ki"),
            ("Nergal", "Erra"),
            ("Marduk", "Asarluhi"),
            ("Kug-Bau", "Bau"),
            ("Damkina", ""),
        ]

        let stickyPrefix = "FROM 26-08-2026 IMPORT"
        var changed = false
        for (existingName, altName) in syncretisms {
            guard let figure = figureByName[existingName.lowercased()] else { continue }
            let alreadyHas = figure.stickies.contains { $0.text.hasPrefix(stickyPrefix) }
            guard !alreadyHas else { continue }
            let note = altName.isEmpty
                ? stickyPrefix
                : "\(stickyPrefix) — \(altName) was already an alternate name"
            context.insert(StickyNote(text: note, figure: figure))
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Re-types Nergal's "Irra" alternate name from an Epithet to a Syncretism
    /// and adds a sticky note on both Nergal and Erra documenting the parallel
    /// cult survival. Irra is a variant spelling of Erra, so an Epithet-typed
    /// Irra on Nergal tripped the shared-alias check (ambiguity between Erra and
    /// Nergal). Additive + idempotent.
    package static func alignNergalErraSyncretism(context: ModelContext) {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName: [String: Figure] = Dictionary(uniqueKeysWithValues: figures.map { ($0.name.lowercased(), $0) })
        guard let nergal = figureByName["nergal"] else { return }

        var changed = false

        for alt in nergal.alternateNames {
            guard alt.name.caseInsensitiveCompare("Irra") == .orderedSame,
                  alt.nameType == .epithet else { continue }
            alt.nameType = .syncretism
            alt.note = "Variant spelling of Erra; the Erra identification is treated as completed for lookups."
            changed = true
        }

        let noteText = "Nergal and Erra are treated as the same deity (syncretism). Historically Erra's cult ran in parallel for centuries (Erra Epic, 8th c. BC) before the name settled as an aspect of Nergal."
        for figure in figures where figure.name.caseInsensitiveCompare("Nergal") == .orderedSame || figure.name.caseInsensitiveCompare("Erra") == .orderedSame {
            guard !figure.stickies.contains(where: { $0.text == noteText }) else { continue }
            context.insert(StickyNote(text: noteText, figure: figure))
            changed = true
        }

        guard changed else { return }
        try? context.save()
    }

    /// Merges the duplicate Asalluhi figure into Asarluhi (variant spellings of
    /// the same god: Eridu's god of incantation, son of Enki, later equated with
    /// Marduk). The missing-deities import created Asarluhi by exact-name match
    /// without seeing the older Asalluhi figure, leaving the shared byname
    /// "Asaralimnuna" on both. After the merge: reconciles to a single canonical
    /// mother (Damkina) and drops a self-referencing alternate whose name equals
    /// the keeper's own name. Additive + idempotent; no-op when only one figure
    /// exists (fresh seeds already have just Asarluhi).
    package static func deduplicateAsalluhiAsarluhi(context: ModelContext) {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        guard let asalluhi = figures.first(where: { $0.name.caseInsensitiveCompare("Asalluhi") == .orderedSame }),
              let asarluhi = figures.first(where: { $0.name.caseInsensitiveCompare("Asarluhi") == .orderedSame }),
              asalluhi.persistentModelID != asarluhi.persistentModelID else { return }

        try? DuplicateMerger.mergeFigures(asarluhi, asalluhi, in: context)

        var changed = false

        for alt in asarluhi.alternateNames where alt.name.caseInsensitiveCompare(asarluhi.name) == .orderedSame {
            context.delete(alt)
            changed = true
        }

        if let damkina = figures.first(where: { $0.name.caseInsensitiveCompare("Damkina") == .orderedSame }) {
            let motherEdges = ((try? context.fetch(FetchDescriptor<Relationship>())) ?? [])
                .filter { $0.toFigure === asarluhi && $0.relationshipType?.name.caseInsensitiveCompare("Mother") == .orderedSame }
            if motherEdges.count > 1, let kept = motherEdges.first(where: { $0.fromFigure === damkina }) {
                for edge in motherEdges where edge !== kept {
                    context.delete(edge)
                    changed = true
                }
            }
        }

        if changed { try? context.save() }
    }

    /// Ensures canonical spouse and family links for key deity couples.
    /// Dynamically detects all couples that share a child (via Mother/Father
    /// relationships) but have no Spouse relationship between them, and creates
    /// the missing link. Also fixes Asarluhi's mother from Ninhursag to Damkina
    /// where applicable. Additive + idempotent.
    package static func ensureCanonicalDeityFamilies(context: ModelContext) {
        func key(_ s: String) -> String { NameDuplicateCheck.normalizedKey(s) }
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName: [String: Figure] = Dictionary(
            allFigures.map { (key($0.name), $0) }, uniquingKeysWith: { first, _ in first })

        let types = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        let motherType = types.first { $0.name == "Mother" }
        let fatherType = types.first { $0.name == "Father" }
        let spouseType = types.first { $0.name == "Spouse" }
        guard let motherType, let fatherType else { return }

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        var changed = false

        // Build spouse pair set (bidirectional)
        var spousePairs: Set<StaticIdentifier> = []
        if let spouseType {
            for edge in edges where edge.relationshipType === spouseType {
                if let from = edge.fromFigure, let to = edge.toFigure {
                    spousePairs.insert(StaticIdentifier(from.persistentModelID, to.persistentModelID))
                }
            }
        }

        // Build parent maps: child → {mothers, fathers}
        var childMothers: [PersistentIdentifier: Set<PersistentIdentifier>] = [:]
        var childFathers: [PersistentIdentifier: Set<PersistentIdentifier>] = [:]
        for edge in edges {
            guard let from = edge.fromFigure, let to = edge.toFigure else { continue }
            if edge.relationshipType === motherType {
                childMothers[to.persistentModelID, default: []].insert(from.persistentModelID)
            } else if edge.relationshipType === fatherType {
                childFathers[to.persistentModelID, default: []].insert(from.persistentModelID)
            }
        }

        // Find all couples with shared children but no Spouse link
        let idToFigure: [PersistentIdentifier: Figure] = Dictionary(
            allFigures.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })

        var fixedPairs: Set<StaticIdentifier> = []
        if let spouseType {
            for (childId, mothers) in childMothers {
                guard let fathers = childFathers[childId] else { continue }
                for motherId in mothers {
                    for fatherId in fathers {
                        let pair = StaticIdentifier(motherId, fatherId)
                        guard !fixedPairs.contains(pair) else { continue }
                        if !spousePairs.contains(pair),
                           let mother = idToFigure[motherId],
                           let father = idToFigure[fatherId] {
                            let rel = Relationship(fromFigure: father, toFigure: mother, relationshipType: spouseType, source: "Mythological tradition")
                            context.insert(rel)
                            fixedPairs.insert(pair)
                            changed = true
                        }
                    }
                }
            }
        }

        // Fix Asarluhi's mother: reassign from Ninhursag to Damkina
        if let damkina = figureByName["damkina"], let ninhursag = figureByName["ninhursag"] {
            for childName in ["asarluhi", "asalluhi"] {
                guard let child = figureByName[childName] else { continue }
                for edge in edges where edge.relationshipType === motherType &&
                    edge.fromFigure === ninhursag && edge.toFigure === child {
                    edge.fromFigure = damkina
                    changed = true
                }
            }
        }

        if changed { try? context.save() }
    }

    /// Ensures bidirectional consistency for relationship types that are
    /// inherently mutual (Spouse, Consort, Sibling, Ally, Enemy). If X→Y
    /// exists but Y→X does not, creates the reverse link preserving the
    /// original source. Additive + idempotent.
    /// Splits the merged "Lugal-irra and Meslamta-ea" figure (created by the
    /// Mesopotamian deities import) into two individual figures, matching the
    /// curation rule that twins are modelled as two separate figures: reuses
    /// the ORACC "Lugalirra" figure when present, creates "Meslamta-ea", adds a
    /// bidirectional Twin edge between them, and removes the now-empty merged
    /// row (its content is distributed across the two individuals). Also runs
    /// the Twin-type + edge creation when both individuals already exist but the
    /// pair row is gone, so a formerly imported store converges to the same shape.
    /// Additive where possible; only the unused merged import row is deleted.
    /// Idempotent.
    package static func splitLugalIrraMeslamtaea(context: ModelContext) {
        func key(_ s: String) -> String { DuplicateMerger.normalizationKey(s) }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var figuresByKey: [String: Figure] = [:]
        for figure in allFigures { figuresByKey[key(figure.name)] = figure }

        let pair = figuresByKey[key("Lugal-irra and Meslamta-ea")]
        let existingLugalirra = figuresByKey[key("Lugalirra")]
        let existingMeslamtaea = figuresByKey[key("Meslamta-ea")]
        guard pair != nil || (existingLugalirra != nil && existingMeslamtaea != nil) else { return }

        let deityType: FigureType
        if let existing = try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate { $0.name == "Deity" })).first {
            deityType = existing
        } else {
            let created = FigureType(name: "Deity", icon: "star.fill", colorHex: "007AFF")
            context.insert(created)
            deityType = created
        }

        let undated = MythologicalDate(year: nil, era: "", isApproximate: true)
        let oraccSource = "ORACC AMGG (oracc.museum.upenn.edu/amgg)"

        let lugalirra: Figure
        if let existing = existingLugalirra {
            lugalirra = existing
        } else {
            let created = Figure(
                name: "Lugalirra",
                title: "Underworld God, Twin of Meslamtaea",
                figureType: deityType,
                gender: .male,
                domain: "Underworld",
                figureDescription: "'Great king' — underworld god, twin brother of Meslamtaea; together the pair act as gatekeepers of the netherworld within the circle of Nergal (whose byname Meslamtaea also is). Worshipped especially at Kisiga.",
                birthDate: undated,
                deathDate: undated,
                source: oraccSource
            )
            context.insert(created)
            context.insert(AlternateName(
                figure: created,
                name: "Lugal-irra",
                tradition: .sumerian,
                nameType: .spelling,
                note: "Hyphenated spelling variant"
            ))
            lugalirra = created
        }

        let meslamtaea: Figure
        if let existing = existingMeslamtaea {
            meslamtaea = existing
        } else {
            let created = Figure(
                name: "Meslamta-ea",
                title: "Underworld God, Twin of Lugal-irra",
                figureType: deityType,
                gender: .male,
                domain: "Underworld",
                figureDescription: "Twin brother of Lugal-irra; the pair are the gatekeepers of the netherworld, guarding its doorways and chopping the dead into pieces as they pass through the gates. Worshipped at Kisiga in northern Babylonia; together they were envisioned as a pair of twin guardians and identified with the constellation Gemini.",
                birthDate: undated,
                deathDate: undated,
                source: oraccSource
            )
            context.insert(created)
            context.insert(AlternateName(
                figure: created,
                name: "Meslamtaea",
                tradition: .sumerian,
                nameType: .spelling,
                note: "Unhyphenated spelling (ORACC)"
            ))
            meslamtaea = created
        }

        let twinType: RelationshipType
        if let existing = ((try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []).first(where: { $0.name == "Twin" }) {
            twinType = existing
        } else {
            let created = RelationshipType(name: "Twin", icon: "person.2.fill", colorHex: "FF9500", category: "sibling", reverseName: "Twin")
            context.insert(created)
            twinType = created
        }

        let existingEdges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let pairEdges = existingEdges.filter { edge in
            guard edge.relationshipType?.persistentModelID == twinType.persistentModelID else { return false }
            let fromID = edge.fromFigure?.persistentModelID
            let toID = edge.toFigure?.persistentModelID
            return (fromID == lugalirra.persistentModelID && toID == meslamtaea.persistentModelID) ||
                   (fromID == meslamtaea.persistentModelID && toID == lugalirra.persistentModelID)
        }
        // Collapse to a single canonical edge (Lugalirra → Twin → Meslamta-ea).
        // The relationship is symmetric, and the view already phrases the incoming
        // direction from the other card via the "Twin" reverseName — creating both
        // directions would show the pair twice on each card.
        for edge in pairEdges where edge.fromFigure?.persistentModelID == meslamtaea.persistentModelID {
            context.delete(edge)
        }
        if !pairEdges.contains(where: { $0.fromFigure?.persistentModelID == lugalirra.persistentModelID }) {
            context.insert(Relationship(fromFigure: lugalirra, toFigure: meslamtaea, relationshipType: twinType, source: oraccSource))
        }

        if let pair { context.delete(pair) }
        try? context.save()
    }

    /// Split the combined "Enki and Ninki" primordial figure (the first of the
    /// ancestor couples of Enlil) into two individuals linked as spouses. The
    /// pair used to be imported as one row; the codebase convention is one
    /// person per figure. Additive + idempotent — fires while the combined row
    /// still exists (to split + retag it) or while both split figures exist
    /// without a spouse link (to reconcile a fresh import). Never overwrites
    /// an already-split store.
    package static func splitEnkiNinkiPair(context: ModelContext) {
        func key(_ s: String) -> String { DuplicateMerger.normalizationKey(s) }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var figuresByKey: [String: Figure] = [:]
        for figure in allFigures { figuresByKey[key(figure.name)] = figure }

        let pair = figuresByKey[key("Enki and Ninki")]
        let existingEnki = figuresByKey[key("Enki (Primordial)")]
        let existingNinki = figuresByKey[key("Ninki")]
        guard pair != nil || (existingEnki != nil && existingNinki != nil) else { return }

        let primordialType: FigureType
        if let existing = ((try? context.fetch(FetchDescriptor<FigureType>())) ?? []).first(where: { $0.name == "Primordial" }) {
            primordialType = existing
        } else {
            let created = FigureType(name: "Primordial", icon: "sparkles", colorHex: "8E8E93")
            context.insert(created)
            primordialType = created
        }

        let undated = MythologicalDate(year: nil, era: "", isApproximate: true)

        let enkiPrimordial: Figure
        if let existing = existingEnki {
            enkiPrimordial = existing
        } else {
            let created = Figure(
                name: "Enki (Primordial)",
                title: "Primordial Ancestor of Enlil",
                figureType: primordialType,
                gender: .male,
                domain: "Abzu; ancestor of Enlil",
                figureDescription: "Enki was one of two primordial beings regarded as the first generation among the ancestors of Enlil. Enki and Ninki, followed by a varying number of pairs of deities whose names start with \"En\" and \"Nin\", appear as Enlil's ancestors in various sources: god lists, incantations, liturgical texts, and the Sumerian composition \"Death of Gilgamesh,\" where the eponymous hero encounters these divine ancestors in the underworld.",
                birthDate: undated,
                deathDate: undated,
                source: ""
            )
            context.insert(created)
            enkiPrimordial = created
        }

        let ninki: Figure
        if let existing = existingNinki {
            ninki = existing
        } else {
            let created = Figure(
                name: "Ninki",
                title: "Primordial Ancestress of Enlil",
                figureType: primordialType,
                gender: .female,
                domain: "Abzu; ancestress of Enlil",
                figureDescription: "Ninki was one of two primordial beings regarded as the first generation among the ancestors of Enlil. Enki and Ninki, followed by a varying number of pairs of deities whose names start with \"En\" and \"Nin\", appear as Enlil's ancestors in various sources: god lists, incantations, liturgical texts, and the Sumerian composition \"Death of Gilgamesh,\" where the eponymous hero encounters these divine ancestors in the underworld.",
                birthDate: undated,
                deathDate: undated,
                source: ""
            )
            context.insert(created)
            ninki = created
        }

        let spouseType: RelationshipType
        if let existing = ((try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []).first(where: { $0.name == "Spouse" }) {
            spouseType = existing
        } else {
            let created = RelationshipType(name: "Spouse", icon: "heart", colorHex: "FF3B30", category: "partner", reverseName: nil)
            context.insert(created)
            spouseType = created
        }

        let existingEdges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let hasEdge: (Figure, Figure) -> Bool = { from, to in
            existingEdges.contains {
                $0.fromFigure?.persistentModelID == from.persistentModelID &&
                $0.toFigure?.persistentModelID == to.persistentModelID &&
                $0.relationshipType?.persistentModelID == spouseType.persistentModelID
            }
        }
        if !hasEdge(enkiPrimordial, ninki) {
            context.insert(Relationship(fromFigure: enkiPrimordial, toFigure: ninki, relationshipType: spouseType, source: "Mesopotamian ancestor lists"))
        }
        if !hasEdge(ninki, enkiPrimordial) {
            context.insert(Relationship(fromFigure: ninki, toFigure: enkiPrimordial, relationshipType: spouseType, source: "Mesopotamian ancestor lists"))
        }

        if let pair {
            let sharedTags = pair.tags.filter { $0.name.lowercased() != "pair" }
            for figure in [enkiPrimordial, ninki] {
                for tag in sharedTags where !figure.tags.contains(where: { $0.persistentModelID == tag.persistentModelID }) {
                    figure.tags.append(tag)
                }
                for pantheon in pair.pantheons where !figure.pantheons.contains(where: { $0.persistentModelID == pantheon.persistentModelID }) {
                    figure.pantheons.append(pantheon)
                }
            }
            context.delete(pair)
        }

        try? context.save()
    }

    package static func ensureBidirectionalRelationshipConsistency(context: ModelContext) {
        let bidirectionalTypes: Set<String> = ["Spouse", "Consort", "Sibling", "Ally", "Enemy"]

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        var changed = false

        // Build a set of existing directed edges
        struct EdgeKey: Hashable {
            let from: PersistentIdentifier
            let to: PersistentIdentifier
            let type: String
        }
        var existing = Set<EdgeKey>()
        for edge in edges {
            guard let from = edge.fromFigure, let to = edge.toFigure,
                  let typeName = edge.relationshipType?.name else { continue }
            existing.insert(EdgeKey(from: from.persistentModelID, to: to.persistentModelID, type: typeName))
        }

        // For each edge, check if the reverse exists; if not, create it
        for edge in edges {
            guard let from = edge.fromFigure, let to = edge.toFigure,
                  let typeName = edge.relationshipType?.name,
                  bidirectionalTypes.contains(typeName) else { continue }

            let reverse = EdgeKey(from: to.persistentModelID, to: from.persistentModelID, type: typeName)
            guard !existing.contains(reverse) else { continue }

            let rel = Relationship(
                fromFigure: to,
                toFigure: from,
                relationshipType: edge.relationshipType,
                source: edge.source,
                sourceRef: edge.sourceRef,
                isPreferred: edge.isPreferred ?? false,
                groupID: edge.groupID
            )
            context.insert(rel)
            existing.insert(reverse)
            changed = true
        }

        if changed { try? context.save() }
    }

    package static func backfillBuziDescription(context: ModelContext) {
        guard let buzi = ((try? context.fetch(FetchDescriptor<Figure>())) ?? []).first(where: { $0.name == "Buzi" }),
              buzi.figureDescription.isEmpty else { return }
        buzi.figureDescription = "Buzi was the father of Ezekiel and a priest of Jerusalem (Ezekiel 1:3). The name derives from the Hebrew word Buz, meaning 'despise.' Some traditions identify Buzi with the prophet Jeremiah, also called Buzi because he was despised by his compatriots in Judah."
        try? context.save()
    }

    /// Import demons and monsters from demons_import.json.
    /// Requires Demon FigureType to exist (ensureDemonFigureTypeExists).
    /// Each imported figure gets a sticky note "IMPORTED — needs review".
    /// Additive + idempotent.
package static func ensureDemonsImportExist(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { DuplicateMerger.normalizationKey($0.name) } ?? [])

        let url: URL? = {
            if let u = Bundle.module.url(forResource: "demons_import", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "demons_import", withExtension: "json")
        }()
        guard let url,
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            return
        }

        let toImport = root.figures.filter { !existingNames.contains(DuplicateMerger.normalizationKey($0.name)) }
        guard !toImport.isEmpty else { return }

        var filteredRoot = root
        filteredRoot.figures = toImport
        SeedData.importFrom(root: filteredRoot, context: context)

        let stickyPrefix = "IMPORTED — needs review"
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let importedNames = Set(toImport.map { DuplicateMerger.normalizationKey($0.name) })
        for figure in allFigures where importedNames.contains(DuplicateMerger.normalizationKey(figure.name)) {
            let alreadyHas = figure.stickies.contains { $0.text.hasPrefix(stickyPrefix) }
            guard !alreadyHas else { continue }
            context.insert(StickyNote(text: stickyPrefix, figure: figure))
        }
        try? context.save()
    }

    /// Import curated notable names from curated_names_import.json.
    /// These are recognizable mythological figures from the broader An = Anum
    /// attestation list that have Wikipedia articles or scholarly recognition.
    /// Each imported figure gets a sticky note "IMPORTED — needs review".
    /// Additive + idempotent.
    package static func ensureCuratedNamesImportExist(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { DuplicateMerger.normalizationKey($0.name) } ?? [])

        let url: URL? = {
            if let u = Bundle.module.url(forResource: "curated_names_import", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "curated_names_import", withExtension: "json")
        }()
        guard let url,
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            return
        }

        let toImport = root.figures.filter { !existingNames.contains(DuplicateMerger.normalizationKey($0.name)) }
        guard !toImport.isEmpty else { return }

        var filteredRoot = root
        filteredRoot.figures = toImport
        SeedData.importFrom(root: filteredRoot, context: context)

        let stickyPrefix = "IMPORTED — needs review"
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let importedNames = Set(toImport.map { DuplicateMerger.normalizationKey($0.name) })
        for figure in allFigures where importedNames.contains(DuplicateMerger.normalizationKey(figure.name)) {
            let alreadyHas = figure.stickies.contains { $0.text.hasPrefix(stickyPrefix) }
            guard !alreadyHas else { continue }
            context.insert(StickyNote(text: stickyPrefix, figure: figure))
        }
        try? context.save()
    }

    /// Corrects five `childBornBeforeParent` data-integrity complaints by fixing
    /// the underlying records. Idempotent: each step only fires while the figure
    /// still holds the stale (pre-fix) value, so a later user edit wins.
    ///  1. Manishtushu (Dynasty of Akkad) was dated -2205 — later than his son
    ///     Naram-Sin's -2280. Rebased to -2305 (reign c. 2269–2255 BC).
    ///  2. Lipit-Enlil (Dynasty of Isin) dated -1874 predates his father Bur-Suen
    ///     (-1821) by 53 years; his reign is pushed to just after his father's
    ///     death (-1800 → -1790), matching the DB's consecutive-reign convention.
    ///  3. The Father edge Hablum → Puzur-Suen is chronologically impossible (a
    ///     Gutian king ~150 years after a 4th-dynasty-of-Kish king) — removed.
    ///  4. Genesis 5 chronology: Mahalalel (age 65) → Jared (age 162) → Enoch.
    ///     Jared (-3544, before his father) and Enoch (-3382, before his father)
    ///     are re-derived from those begetting ages and lifespans (962, 365).
    ///  5. The mythical Watcher pair Rashujal/backed by Rachujal keeps its
    ///     invented dates; a FindingDismissal suppresses the finding instead.
    /// Stale persisted IntegrityFinding rows for the resolved signatures are
    /// deleted so the queue clears without a manual re-scan.
    package static func correctAnomalousGenealogy(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName = Dictionary(
            allFigures.map { (Self.seedNameKey($0.name), $0) }, uniquingKeysWith: { first, _ in first })
        var changed = false

        // 1. Manishtushu — birth was -2205, later than his son Naram-Sin (-2280).
        if let fig = figureByName[Self.seedNameKey("Manishtushu")],
           fig.birthDate.startYear == -2205 {
            fig.birthDate = MythologicalDate(startYear: -2305, endYear: -2305,
                                             era: fig.birthDate.era, isApproximate: true)
            changed = true
        }

        // 2. Lipit-Enlil — birth -1874 predates his father Bur-Suen (-1821).
        if let fig = figureByName[Self.seedNameKey("Lipit-Enlil")],
           fig.birthDate.startYear == -1874 {
            fig.birthDate = MythologicalDate(startYear: -1800, endYear: -1790,
                                             era: fig.birthDate.era, isApproximate: true)
            fig.deathDate = MythologicalDate(startYear: -1790, endYear: -1790,
                                             era: fig.deathDate.era, isApproximate: true)
            fig.reignStartYear = -1800
            fig.reignEndYear = -1790
            changed = true
        }

        // 3. Remove the chronologically impossible Father edge Hablum → Puzur-Suen.
        if let hablum = figureByName[Self.seedNameKey("Hablum")],
           let puzur = figureByName[Self.seedNameKey("Puzur-Suen")],
           let fatherType = try? context.fetch(FetchDescriptor<RelationshipType>(predicate: #Predicate { $0.name == "Father" })).first {
            let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
            for rel in rels where rel.relationshipType?.persistentModelID == fatherType.persistentModelID
                && rel.fromFigure?.persistentModelID == hablum.persistentModelID
                && rel.toFigure?.persistentModelID == puzur.persistentModelID {
                context.delete(rel)
                changed = true
            }
        }

        // 4. Jared / Enoch — Genesis 5 chronology (Mahalalel →65→ Jared →162→ Enoch).
        if let mahalalel = figureByName[Self.seedNameKey("Mahalalel")],
           let jared = figureByName[Self.seedNameKey("Jared")],
           jared.birthDate.startYear == -3544 {
            let jaredBirth = (mahalalel.birthDate.startYear ?? -3386) + 65
            jared.birthDate = MythologicalDate(startYear: jaredBirth, endYear: jaredBirth,
                                               era: jared.birthDate.era, isApproximate: true)
            jared.deathDate = MythologicalDate(startYear: jaredBirth + 962, endYear: jaredBirth + 962,
                                               era: jared.deathDate.era, isApproximate: true)
            jared.reignStartYear = jaredBirth
            jared.reignEndYear = jaredBirth + 962
            if let enoch = figureByName[Self.seedNameKey("Enoch")],
               enoch.birthDate.startYear == -3382 {
                let enochBirth = jaredBirth + 162
                enoch.birthDate = MythologicalDate(startYear: enochBirth, endYear: enochBirth,
                                                   era: enoch.birthDate.era, isApproximate: true)
                enoch.deathDate = MythologicalDate(startYear: enochBirth + 365, endYear: enochBirth + 365,
                                                   era: enoch.deathDate.era, isApproximate: true)
                enoch.reignStartYear = enochBirth
                enoch.reignEndYear = enochBirth + 365
            }
            changed = true
        }

        // 5. Dismiss the mythical Watcher finding (Rashujal ← Rachujal) forever.
        let dismissSignature = "childBornBeforeParent|Rashujal"
        let existingDismissals = (try? context.fetch(FetchDescriptor<FindingDismissal>())) ?? []
        if !existingDismissals.contains(where: { $0.signature == dismissSignature }) {
            context.insert(FindingDismissal(kindRaw: "childBornBeforeParent", entityKey: "Rashujal"))
            changed = true
        }

        // Clear stale persisted findings for every resolved signature.
        let resolved = Set(["Rashujal", "Lipit-Enlil", "Puzur-Suen", "Naram-Sin of Akkad", "Jared"]
            .map { Self.seedNameKey($0) })
        let stale = ((try? context.fetch(FetchDescriptor<IntegrityFinding>())) ?? []).filter {
            $0.kindRaw == "childBornBeforeParent" && resolved.contains(Self.seedNameKey($0.entityKey))
        }
        for row in stale {
            context.delete(row)
            changed = true
        }

        if changed { try? context.save() }
    }
}
