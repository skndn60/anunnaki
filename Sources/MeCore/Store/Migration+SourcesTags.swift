import Foundation
import SwiftData

extension Migration {
    /// Links every `Relationship.sourceRef` to the `Source` entity named by its
    /// free-text `source` string. Existing Source names match case-insensitively
    /// ("Adapa myth" → seeded "Adapa Myth"); multi-text strings such as
    /// "Enuma Elish, Babylonian texts" use the first text as the primary
    /// attribution; unknown names get a coarse new `Source` created. Additive +
    /// idempotent — never re-points an existing `sourceRef`.
    package static func ensureRelationshipSources(context: ModelContext) {
        var byName: [String: Source] = [:]
        for source in (try? context.fetch(FetchDescriptor<Source>())) ?? [] {
            byName[NameDuplicateCheck.normalizedKey(source.name)] = source
        }

        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        var changed = false
        for relationship in relationships where relationship.sourceRef == nil {
            guard let name = Self.primarySourceName(from: relationship.source) else { continue }
            let key = NameDuplicateCheck.normalizedKey(name)
            if let existing = byName[key] {
                existing.relationships.append(relationship)
            } else {
                let source = Source(
                    name: name,
                    sourceType: name.localizedCaseInsensitiveContains("king list") ? .kingList : .ancientText,
                    author: "",
                    language: "",
                    period: "",
                    sourceDescription: "",
                    publicationInfo: "",
                    url: ""
                )
                context.insert(source)
                source.relationships.append(relationship)
                byName[key] = source
            }
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Links every association's `sourceRef` (7 types) to the `Source` entity
    /// named by its free-text `source` string. Reuses `primarySourceName` for
    /// matching and creates coarse Source rows for unknown names, mirroring
    /// `ensureRelationshipSources`. Additive + idempotent.
    package static func ensureAssociationSources(context: ModelContext) {
        var byName: [String: Source] = [:]
        for source in (try? context.fetch(FetchDescriptor<Source>())) ?? [] {
            byName[NameDuplicateCheck.normalizedKey(source.name)] = source
        }

        var changed = false

        // Figure ↔ Place
        for assoc in (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? [] where assoc.sourceRef == nil {
            guard let name = Self.primarySourceName(from: assoc.source) else { continue }
            let key = NameDuplicateCheck.normalizedKey(name)
            if let existing = byName[key] {
                existing.figurePlaceAssociations.append(assoc)
            } else {
                let source = Source(name: name, sourceType: .ancientText, author: "", language: "", period: "", sourceDescription: "", publicationInfo: "", url: "")
                context.insert(source)
                source.figurePlaceAssociations.append(assoc)
                byName[key] = source
            }
            assoc.sourceRef = byName[key]
            changed = true
        }

        // Place ↔ Place
        for assoc in (try? context.fetch(FetchDescriptor<PlacePlaceAssociation>())) ?? [] where assoc.sourceRef == nil {
            guard let name = Self.primarySourceName(from: assoc.source) else { continue }
            let key = NameDuplicateCheck.normalizedKey(name)
            if let existing = byName[key] {
                existing.placePlaceAssociations.append(assoc)
            } else {
                let source = Source(name: name, sourceType: .ancientText, author: "", language: "", period: "", sourceDescription: "", publicationInfo: "", url: "")
                context.insert(source)
                source.placePlaceAssociations.append(assoc)
                byName[key] = source
            }
            assoc.sourceRef = byName[key]
            changed = true
        }

        // Event ↔ Place
        for assoc in (try? context.fetch(FetchDescriptor<EventPlaceAssociation>())) ?? [] where assoc.sourceRef == nil {
            guard let name = Self.primarySourceName(from: assoc.source) else { continue }
            let key = NameDuplicateCheck.normalizedKey(name)
            if let existing = byName[key] {
                existing.eventPlaceAssociations.append(assoc)
            } else {
                let source = Source(name: name, sourceType: .ancientText, author: "", language: "", period: "", sourceDescription: "", publicationInfo: "", url: "")
                context.insert(source)
                source.eventPlaceAssociations.append(assoc)
                byName[key] = source
            }
            assoc.sourceRef = byName[key]
            changed = true
        }

        // Event ↔ Event
        for assoc in (try? context.fetch(FetchDescriptor<EventEventAssociation>())) ?? [] where assoc.sourceRef == nil {
            guard let name = Self.primarySourceName(from: assoc.source) else { continue }
            let key = NameDuplicateCheck.normalizedKey(name)
            if let existing = byName[key] {
                existing.eventEventAssociations.append(assoc)
            } else {
                let source = Source(name: name, sourceType: .ancientText, author: "", language: "", period: "", sourceDescription: "", publicationInfo: "", url: "")
                context.insert(source)
                source.eventEventAssociations.append(assoc)
                byName[key] = source
            }
            assoc.sourceRef = byName[key]
            changed = true
        }

        // Thing ↔ Figure
        for assoc in (try? context.fetch(FetchDescriptor<ThingFigureAssociation>())) ?? [] where assoc.sourceRef == nil {
            guard let name = Self.primarySourceName(from: assoc.source) else { continue }
            let key = NameDuplicateCheck.normalizedKey(name)
            if let existing = byName[key] {
                existing.thingFigureAssociations.append(assoc)
            } else {
                let source = Source(name: name, sourceType: .ancientText, author: "", language: "", period: "", sourceDescription: "", publicationInfo: "", url: "")
                context.insert(source)
                source.thingFigureAssociations.append(assoc)
                byName[key] = source
            }
            assoc.sourceRef = byName[key]
            changed = true
        }

        // Thing ↔ Place
        for assoc in (try? context.fetch(FetchDescriptor<ThingPlaceAssociation>())) ?? [] where assoc.sourceRef == nil {
            guard let name = Self.primarySourceName(from: assoc.source) else { continue }
            let key = NameDuplicateCheck.normalizedKey(name)
            if let existing = byName[key] {
                existing.thingPlaceAssociations.append(assoc)
            } else {
                let source = Source(name: name, sourceType: .ancientText, author: "", language: "", period: "", sourceDescription: "", publicationInfo: "", url: "")
                context.insert(source)
                source.thingPlaceAssociations.append(assoc)
                byName[key] = source
            }
            assoc.sourceRef = byName[key]
            changed = true
        }

        // Thing ↔ Event
        for assoc in (try? context.fetch(FetchDescriptor<ThingEventAssociation>())) ?? [] where assoc.sourceRef == nil {
            guard let name = Self.primarySourceName(from: assoc.source) else { continue }
            let key = NameDuplicateCheck.normalizedKey(name)
            if let existing = byName[key] {
                existing.thingEventAssociations.append(assoc)
            } else {
                let source = Source(name: name, sourceType: .ancientText, author: "", language: "", period: "", sourceDescription: "", publicationInfo: "", url: "")
                context.insert(source)
                source.thingEventAssociations.append(assoc)
                byName[key] = source
            }
            assoc.sourceRef = byName[key]
            changed = true
        }

        if changed { try? context.save() }
    }

    package static func primarySourceName(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 3 else { return nil }
        let first = trimmed.split(separator: ",").first.map(String.init) ?? trimmed
        let name = first.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.count >= 3 ? name : nil
    }

    /// Back-links free-text `CellSource`s on comparison-table cells to matching
    /// `Source` rows using lenient matching (e.g. "An=Anum" -> "Lexical God
    /// List An = Anum (Tablet IV)"). Additive and idempotent; links are set via
    /// the annotated side (`Source.cellListSources`).
    package static func ensureCellSourceLinksExist(context: ModelContext) {
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let cellSources = (try? context.fetch(FetchDescriptor<CellSource>())) ?? []
        var changed = false
        for cellSource in cellSources where cellSource.sourceRef == nil {
            guard let match = Source.bestMatch(forCandidate: cellSource.source, among: sources) else { continue }
            if match.cellListSources.contains(where: { $0 === cellSource }) { continue }
            match.cellListSources.append(cellSource)
            cellSource.sourceRef = match
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Replaces the plain-text state values ("friendly"/"neutral"/"hostile") in the
    /// "Mesopotamian City Matrix" comparison table with their emoji equivalents
    /// (🤝/😐/⚔️) so the state column reads at a glance. Additive + idempotent: only
    /// a cell whose ENTIRE trimmed value equals a known state word (case-insensitive)
    /// is touched — emoji and any non-state text are left alone, so re-running never
    /// double-applies and never clobbers other cell content.
    package static func ensureComparisonStateEmoji(context: ModelContext) {
        let stateToEmoji: [String: String] = [
            "friendly": "\u{1F91D}",
            "neutral": "\u{1F610}",
            "hostile": "\u{2694}\u{FE0F}",
        ]
        let tables = (try? context.fetch(FetchDescriptor<PopupTable>())) ?? []
        guard let matrix = tables.first(where: { $0.name.caseInsensitiveCompare("Mesopotamian City Matrix") == .orderedSame }) else { return }
        var changed = false
        for cell in matrix.cells {
            guard let raw = cell.value else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let emoji = stateToEmoji[trimmed.lowercased()] else { continue }
            cell.value = emoji
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Backfills the standard Mesopotamian god list "An = Anum" as a Source row
    /// so comparison-table cells can cite it as a verified work. Additive and
    /// check-by-name: never duplicates an existing source. No URL (the text is
    /// not freely available online), which keeps `sourceWithoutURL` from firing.
    package static func ensureAnAnumGodListSourceExists(context: ModelContext) {
        let name = "Lexical God List An = Anum (Tablet IV)"
        let existing = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        guard !existing.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return }

        let source = Source(
            name: name,
            sourceType: .tablet,
            author: "",
            language: "Sumerian/Akkadian",
            period: "Old Babylonian",
            sourceDescription: "The An = Anum god list enumerates the chief Mesopotamian deities and their summus deus theology.",
            publicationInfo: "Tablet IV",
            url: ""
        )
        context.insert(source)
        try? context.save()
    }

    /// Cleans up debris produced by junk free-text source strings. A typo like
    /// `"d"` on a relationship's `source` field used to materialize a bare
    /// `Source` row via `ensureRelationshipSources`; deleting that row only
    /// nullified the link while the string survived, so every launch recreated
    /// it. Blank any sub-3-character source strings (detaching via the
    /// annotated side), then delete sources that are pure machine debris:
    /// sub-3-character name, all metadata empty, no citations/attachments/
    /// relationships. Anything with real metadata or references is never
    /// touched. Additive + idempotent.
    package static func ensureJunkSourceStringsCleaned(context: ModelContext) {
        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        var changed = false
        for relationship in relationships {
            let trimmed = relationship.source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count < 3 else { continue }
            if let source = relationship.sourceRef {
                source.relationships.removeAll { $0 == relationship }
            }
            relationship.source = ""
            changed = true
        }

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        for source in sources where source.name.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            let isDebris = source.author.isEmpty
                && source.language.isEmpty
                && source.period.isEmpty
                && source.sourceDescription.isEmpty
                && source.publicationInfo.isEmpty
                && source.url.isEmpty
                && source.citations.isEmpty
                && source.attachments.isEmpty
                && source.relationships.isEmpty
            if isDebris {
                context.delete(source)
                changed = true
            }
        }

        if changed { try? context.save() }
    }

    /// Tag every entity that has no tags yet using `TagEngine`'s rule-based
    /// suggestions (derived from type, gender, domain, era, source, description).
    /// Additive + idempotent — entities that already have any tag are never touched,
    /// so user curation is never overridden and a deleted auto-tag stays gone.
    /// New `Tag` rows get a deterministic palette color from the tag name.
    package static func ensureAutoTags(context: ModelContext) {
        let existingTags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        var tagByName = existingTags.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }

        func tag(named name: String) -> Tag {
            let key = name.lowercased()
            if let existing = tagByName[key] { return existing }
            let newTag = Tag(name: name, colorHex: TagEngine.colorHex(for: name))
            context.insert(newTag)
            tagByName[key] = newTag
            return newTag
        }

        var changed = false

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in figures where figure.tags.isEmpty {
            let names = TagEngine.tags(for: figure).sorted()
            guard !names.isEmpty else { continue }
            for name in names {
                figure.tags.append(tag(named: name))
            }
            changed = true
        }

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        for place in places where place.tags.isEmpty {
            let names = TagEngine.tags(for: place).sorted()
            guard !names.isEmpty else { continue }
            for name in names {
                place.tags.append(tag(named: name))
            }
            changed = true
        }

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        for event in events where event.tags.isEmpty {
            let names = TagEngine.tags(for: event).sorted()
            guard !names.isEmpty else { continue }
            for name in names {
                event.tags.append(tag(named: name))
            }
            changed = true
        }

        let things = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        for thing in things where thing.tags.isEmpty {
            let names = TagEngine.tags(for: thing).sorted()
            guard !names.isEmpty else { continue }
            for name in names {
                thing.tags.append(tag(named: name))
            }
            changed = true
        }

        if changed { try? context.save() }
    }

    /// Follow-up to `ensureAutoTags`: the old `domainTags` kept each comma-separated
    /// domain phrase whole, producing fragment tags like `"and the underworld"` or
    /// `"steward and scribe"`. `TagEngine.domainTags` now emits single words with
    /// connectors stripped. This pass removes exactly those legacy fragment links
    /// and backfills the refined single-word facets. Idempotent and additive — only
    /// tags matching a legacy domain phrase that no longer survives the new engine
    /// are removed; curated/type/tradition tags are untouched and `Tag` entities
    /// (shared across entities) are never deleted.
    package static func ensureRefinedDomainTags(context: ModelContext) {
        let existingTags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        var tagByName = existingTags.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }

        func tag(named name: String) -> Tag {
            let key = name.lowercased()
            if let existing = tagByName[key] { return existing }
            let newTag = Tag(name: name, colorHex: TagEngine.colorHex(for: name))
            context.insert(newTag)
            tagByName[key] = newTag
            return newTag
        }

        var changed = false
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in figures where !figure.domain.isEmpty {
            let obsolete = Set(legacyDomainTagPhrases(figure.domain)).subtracting(TagEngine.domainTags(figure.domain))
            guard !obsolete.isEmpty else { continue }

            var hasChange = false
            let before = figure.tags.count
            figure.tags.removeAll { obsolete.contains($0.name.lowercased()) }
            hasChange = figure.tags.count != before

            for tagName in TagEngine.domainTags(figure.domain).sorted() {
                guard !figure.tags.contains(where: { $0.name.lowercased() == tagName }) else { continue }
                figure.tags.append(tag(named: tagName))
                hasChange = true
            }

            if hasChange { changed = true }
        }

        if changed { try? context.save() }
    }

    package static func legacyDomainTagPhrases(_ domain: String) -> [String] {
        let phrases = domain.split(whereSeparator: { $0 == "," || $0 == ";" })
        var result: [String] = []
        for phrase in phrases {
            let cleaned = TagEngine.cleanedToken(String(phrase))
            guard !cleaned.isEmpty, cleaned != "and", cleaned != "of", cleaned != "the" else { continue }
            result.append(cleaned)
        }
        return result
    }

}
