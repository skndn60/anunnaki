import Foundation
import SwiftData

/// A group of entities sharing the same name (case-insensitive) that are likely
/// accidental duplicates. `ids.first` is the proposed keeper.
package struct DuplicateGroup: Identifiable, Hashable {
    package enum EntityKind: String, CaseIterable, Identifiable {
        case figure = "Figure"
        case place = "Place"
        case event = "Event"
        case thing = "Thing"
        case source = "Source"

        package var id: String { rawValue }
    }

    package let kind: EntityKind
    package let name: String
    package let ids: [PersistentIdentifier]

    package var id: String { "\(kind.rawValue):\(name.lowercased())" }
}

/// Merges duplicate entities: every link pointing at a duplicate is re-pointed
/// to the keeper, the duplicate's owned content is folded into the keeper, and
/// the duplicate is then deleted. All operations run inside a transaction with
/// the duplicate's observed arrays emptied before deletion (macOS 26 safety).
package enum DuplicateMerger {
    // MARK: - Discovery

    package static func findGroups(in context: ModelContext) throws -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        groups += find(Figure.self, kind: .figure, name: { $0.name }, in: context)
        groups += find(Place.self, kind: .place, name: { $0.name }, in: context)
        groups += find(Event.self, kind: .event, name: { $0.name }, in: context)
        groups += find(Thing.self, kind: .thing, name: { $0.name }, in: context)
        groups += find(Source.self, kind: .source, name: { $0.name }, in: context)
        return groups.sorted {
            if $0.kind.rawValue != $1.kind.rawValue { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func find<T: PersistentModel>(
        _ type: T.Type,
        kind: DuplicateGroup.EntityKind,
        name: (T) -> String,
        in context: ModelContext
    ) -> [DuplicateGroup] {
        let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
        var buckets: [String: (display: String, ids: [PersistentIdentifier])] = [:]
        for entity in all {
            let display = name(entity)
            let key = normalizationKey(display)
            guard !key.isEmpty else { continue }
            if buckets[key] == nil {
                buckets[key] = (display, [])
            }
            buckets[key]?.ids.append(entity.persistentModelID)
        }
        return buckets.compactMap { _, bucket in
            guard bucket.ids.count > 1 else { return nil }
            return DuplicateGroup(kind: kind, name: bucket.display, ids: bucket.ids)
        }
    }

    /// Normalizes a display name into a grouping key for duplicate detection:
    /// lowercase, whitespace collapsed, and punctuation (hyphens, en/em dashes,
    /// apostrophes, dots) removed, so "Atra-Hasis" and "Atrahasis" group together.
    private static func normalizationKey(_ display: String) -> String {
        let lower = display.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        let punctuation = "-‐‑‒–—―'’."
        var processed = ""
        for ch in lower {
            if ch.isWhitespace {
                processed.append(" ")
            } else if punctuation.contains(ch) {
                continue
            } else {
                processed.append(ch)
            }
        }
        return processed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    // MARK: - Merges

    package static func mergeFigures(_ keeper: Figure, _ duplicate: Figure, in context: ModelContext) throws {
        try context.transaction {
            let outgoing = duplicate.outgoingRelationships
            for rel in outgoing where rel.fromFigure === duplicate {
                if rel.toFigure === keeper {
                    context.delete(rel)
                } else {
                    keeper.outgoingRelationships.append(rel)
                }
            }
            let incoming = duplicate.incomingRelationships
            for rel in incoming where rel.toFigure === duplicate {
                if rel.fromFigure === keeper || rel.fromFigure === duplicate {
                    context.delete(rel)
                } else {
                    keeper.incomingRelationships.append(rel)
                }
            }

            for alt in duplicate.alternateNames where alt.figure === duplicate {
                let exists = keeper.alternateNames.contains {
                    $0.name.caseInsensitiveCompare(alt.name) == .orderedSame && $0.tradition == alt.tradition
                }
                if exists { context.delete(alt) } else { keeper.alternateNames.append(alt) }
            }

            for assoc in duplicate.placeAssociations where assoc.figure === duplicate {
                let exists = keeper.placeAssociations.contains { $0.place == assoc.place && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.placeAssociations.append(assoc) }
            }

            for assoc in duplicate.thingAssociations where assoc.figure === duplicate {
                let exists = keeper.thingAssociations.contains { $0.thing == assoc.thing && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.thingAssociations.append(assoc) }
            }

            for assoc in duplicate.groupAssociations where assoc.figure === duplicate {
                let exists = keeper.groupAssociations.contains { $0.group == assoc.group }
                if exists { context.delete(assoc) } else { keeper.groupAssociations.append(assoc) }
            }

            for note in duplicate.stickies where note.figure === duplicate {
                keeper.stickies.append(note)
            }

            for image in duplicate.images where !keeper.images.contains(where: { $0 === image }) {
                keeper.images.append(image)
            }

            if keeper.mugshotImage == nil, duplicate.mugshotImage != nil {
                keeper.mugshotImage = duplicate.mugshotImage
                keeper.mugshotCropRect = duplicate.mugshotCropRect
                keeper.mugshotIdentification = duplicate.mugshotIdentification
            }

            for tag in duplicate.tags where !keeper.tags.contains(where: { $0 === tag }) {
                keeper.tags.append(tag)
            }

            for event in duplicate.events where !keeper.events.contains(where: { $0 === event }) {
                keeper.events.append(event)
            }

            for pantheon in duplicate.pantheons where !keeper.pantheons.contains(where: { $0 === pantheon }) {
                keeper.pantheons.append(pantheon)
            }

            let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
            for event in allEvents {
                for efa in event.figureAssociations ?? [] where efa.figure === duplicate {
                    efa.figure = keeper
                }
            }

            for assoc in duplicate.pantheonAssociations ?? [] where assoc.figure === duplicate {
                keeper.pantheonAssociations = (keeper.pantheonAssociations ?? []) + [assoc]
            }

            for attribution in duplicate.contentAttributions ?? [] where attribution.figure === duplicate {
                keeper.contentAttributions = (keeper.contentAttributions ?? []) + [attribution]
            }

            if keeper.era == nil { keeper.era = duplicate.era }

            adoptString(&keeper.title, duplicate.title)
            adoptString(&keeper.domain, duplicate.domain)
            adoptString(&keeper.figureDescription, duplicate.figureDescription)
            if keeper.richDescription == nil { keeper.richDescription = duplicate.richDescription }
            adoptString(&keeper.source, duplicate.source)
            adoptOptional(&keeper.disambiguation, duplicate.disambiguation)
            adoptOptional(&keeper.epithet, duplicate.epithet)
            adoptOptional(&keeper.causeOfDeath, duplicate.causeOfDeath)
            adoptOptional(&keeper.reignStartYear, duplicate.reignStartYear)
            adoptOptional(&keeper.reignEndYear, duplicate.reignEndYear)
            adoptOptional(&keeper.reignYears, duplicate.reignYears)
            adoptOptional(&keeper.coverageExempt, duplicate.coverageExempt)
            adoptOptional(&keeper.coverageReviewedAt, duplicate.coverageReviewedAt)
            if keeper.figureType == nil { keeper.figureType = duplicate.figureType }
            if keeper.gender == .unknown { keeper.gender = duplicate.gender }
            if keeper.birthDate == .unknown { keeper.birthDate = duplicate.birthDate }
            if keeper.deathDate == .unknown { keeper.deathDate = duplicate.deathDate }

            duplicate.outgoingRelationships = []
            duplicate.incomingRelationships = []
            duplicate.alternateNames = []
            duplicate.placeAssociations = []
            duplicate.thingAssociations = []
            duplicate.groupAssociations = []
            duplicate.stickies = []
            duplicate.images = []
            duplicate.tags = []
            duplicate.events = []
            duplicate.pantheons = []
            duplicate.pantheonAssociations = nil
            duplicate.contentAttributions = nil

            context.delete(duplicate)
        }
        try context.save()
    }

    package static func mergePlaces(_ keeper: Place, _ duplicate: Place, in context: ModelContext) throws {
        try context.transaction {
            for assoc in duplicate.figureAssociations where assoc.place === duplicate {
                let exists = keeper.figureAssociations.contains { $0.figure == assoc.figure && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.figureAssociations.append(assoc) }
            }
            for assoc in duplicate.eventAssociations where assoc.place === duplicate {
                let exists = keeper.eventAssociations.contains { $0.event == assoc.event && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.eventAssociations.append(assoc) }
            }
            for assoc in duplicate.thingAssociations where assoc.place === duplicate {
                let exists = keeper.thingAssociations.contains { $0.thing == assoc.thing && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.thingAssociations.append(assoc) }
            }
            for alt in duplicate.alternateNames where alt.place === duplicate {
                let exists = keeper.alternateNames.contains {
                    $0.name.caseInsensitiveCompare(alt.name) == .orderedSame && $0.tradition == alt.tradition
                }
                if exists { context.delete(alt) } else { keeper.alternateNames.append(alt) }
            }
            for assoc in duplicate.groupAssociations where assoc.place === duplicate {
                let exists = keeper.groupAssociations.contains { $0.group == assoc.group }
                if exists { context.delete(assoc) } else { keeper.groupAssociations.append(assoc) }
            }
            for note in duplicate.stickies where note.place === duplicate {
                keeper.stickies.append(note)
            }
            for image in duplicate.images where !keeper.images.contains(where: { $0 === image }) {
                keeper.images.append(image)
            }
            for tag in duplicate.tags where !keeper.tags.contains(where: { $0 === tag }) {
                keeper.tags.append(tag)
            }
            for attribution in duplicate.contentAttributions ?? [] where attribution.place === duplicate {
                keeper.contentAttributions = (keeper.contentAttributions ?? []) + [attribution]
            }

            let allPPA = (try? context.fetch(FetchDescriptor<PlacePlaceAssociation>())) ?? []
            for assoc in allPPA {
                let fromDup = assoc.fromPlace === duplicate
                let toDup = assoc.toPlace === duplicate
                guard fromDup || toDup else { continue }
                if fromDup { assoc.fromPlace = keeper }
                if toDup { assoc.toPlace = keeper }
                if assoc.fromPlace === assoc.toPlace { context.delete(assoc) }
            }

            adoptString(&keeper.modernLocation, duplicate.modernLocation)
            adoptString(&keeper.placeDescription, duplicate.placeDescription)
            if keeper.richDescription == nil { keeper.richDescription = duplicate.richDescription }
            adoptString(&keeper.source, duplicate.source)
            adoptOptional(&keeper.sortName, duplicate.sortName)
            adoptOptional(&keeper.foundedDate, duplicate.foundedDate)
            if keeper.placeType == nil { keeper.placeType = duplicate.placeType }
            if keeper.latitude == nil { keeper.latitude = duplicate.latitude }
            if keeper.longitude == nil { keeper.longitude = duplicate.longitude }

            duplicate.figureAssociations = []
            duplicate.eventAssociations = []
            duplicate.thingAssociations = []
            duplicate.alternateNames = []
            duplicate.groupAssociations = []
            duplicate.stickies = []
            duplicate.images = []
            duplicate.tags = []
            duplicate.contentAttributions = nil

            context.delete(duplicate)
        }
        try context.save()
    }

    package static func mergeEvents(_ keeper: Event, _ duplicate: Event, in context: ModelContext) throws {
        try context.transaction {
            for assoc in duplicate.figureAssociations ?? [] where assoc.event === duplicate {
                let exists = (keeper.figureAssociations ?? []).contains { $0.figure == assoc.figure && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.figureAssociations = (keeper.figureAssociations ?? []) + [assoc] }
            }
            for assoc in duplicate.placeAssociations where assoc.event === duplicate {
                let exists = keeper.placeAssociations.contains { $0.place == assoc.place && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.placeAssociations.append(assoc) }
            }
            for assoc in duplicate.thingAssociations where assoc.event === duplicate {
                let exists = keeper.thingAssociations.contains { $0.thing == assoc.thing && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.thingAssociations.append(assoc) }
            }
            for tag in duplicate.tags where !keeper.tags.contains(where: { $0 === tag }) {
                keeper.tags.append(tag)
            }
            for image in duplicate.images where !keeper.images.contains(where: { $0 === image }) {
                keeper.images.append(image)
            }
            for note in duplicate.stickies where note.event === duplicate {
                keeper.stickies.append(note)
            }
            for assoc in duplicate.groupAssociations where assoc.event === duplicate {
                let exists = keeper.groupAssociations.contains { $0.group == assoc.group }
                if exists { context.delete(assoc) } else { keeper.groupAssociations.append(assoc) }
            }
            for attribution in duplicate.contentAttributions ?? [] where attribution.event === duplicate {
                keeper.contentAttributions = (keeper.contentAttributions ?? []) + [attribution]
            }

            let allEEA = (try? context.fetch(FetchDescriptor<EventEventAssociation>())) ?? []
            for assoc in allEEA {
                let fromDup = assoc.fromEvent === duplicate
                let toDup = assoc.toEvent === duplicate
                guard fromDup || toDup else { continue }
                if fromDup { assoc.fromEvent = keeper }
                if toDup { assoc.toEvent = keeper }
                if assoc.fromEvent === assoc.toEvent { context.delete(assoc) }
            }

            adoptString(&keeper.eventDescription, duplicate.eventDescription)
            if keeper.richDescription == nil { keeper.richDescription = duplicate.richDescription }
            adoptString(&keeper.era, duplicate.era)
            adoptString(&keeper.source, duplicate.source)
            adoptOptional(&keeper.sortName, duplicate.sortName)
            if keeper.eventType == nil { keeper.eventType = duplicate.eventType }
            if keeper.date == .unknown { keeper.date = duplicate.date }

            duplicate.figureAssociations = nil
            duplicate.placeAssociations = []
            duplicate.thingAssociations = []
            duplicate.tags = []
            duplicate.images = []
            duplicate.stickies = []
            duplicate.groupAssociations = []
            duplicate.contentAttributions = nil

            context.delete(duplicate)
        }
        try context.save()
    }

    package static func mergeThings(_ keeper: Thing, _ duplicate: Thing, in context: ModelContext) throws {
        try context.transaction {
            for assoc in duplicate.figureAssociations where assoc.thing === duplicate {
                let exists = keeper.figureAssociations.contains { $0.figure == assoc.figure && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.figureAssociations.append(assoc) }
            }
            for assoc in duplicate.placeAssociations where assoc.thing === duplicate {
                let exists = keeper.placeAssociations.contains { $0.place == assoc.place && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.placeAssociations.append(assoc) }
            }
            for assoc in duplicate.eventAssociations where assoc.thing === duplicate {
                let exists = keeper.eventAssociations.contains { $0.event == assoc.event && $0.roleType == assoc.roleType }
                if exists { context.delete(assoc) } else { keeper.eventAssociations.append(assoc) }
            }
            for image in duplicate.images where !keeper.images.contains(where: { $0 === image }) {
                keeper.images.append(image)
            }
            for tag in duplicate.tags where !keeper.tags.contains(where: { $0 === tag }) {
                keeper.tags.append(tag)
            }
            for note in duplicate.stickies where note.thing === duplicate {
                keeper.stickies.append(note)
            }
            for assoc in duplicate.groupAssociations where assoc.thing === duplicate {
                let exists = keeper.groupAssociations.contains { $0.group == assoc.group }
                if exists { context.delete(assoc) } else { keeper.groupAssociations.append(assoc) }
            }
            for attribution in duplicate.contentAttributions ?? [] where attribution.thing === duplicate {
                keeper.contentAttributions = (keeper.contentAttributions ?? []) + [attribution]
            }

            adoptString(&keeper.thingDescription, duplicate.thingDescription)
            if keeper.richDescription == nil { keeper.richDescription = duplicate.richDescription }
            adoptString(&keeper.source, duplicate.source)
            if keeper.thingType == nil { keeper.thingType = duplicate.thingType }

            duplicate.figureAssociations = []
            duplicate.placeAssociations = []
            duplicate.eventAssociations = []
            duplicate.images = []
            duplicate.tags = []
            duplicate.stickies = []
            duplicate.groupAssociations = []
            duplicate.contentAttributions = nil

            context.delete(duplicate)
        }
        try context.save()
    }

    package static func mergeSources(_ keeper: Source, _ duplicate: Source, in context: ModelContext) throws {
        try context.transaction {
            for cit in duplicate.citations where cit.source === duplicate {
                let exists = keeper.citations.contains { $0.safeEntityName == cit.safeEntityName && $0.safeEntityType == cit.safeEntityType && $0.safeLocation == cit.safeLocation }
                if exists { context.delete(cit) } else { keeper.citations.append(cit) }
            }
            for att in duplicate.attachments where att.source === duplicate {
                keeper.attachments.append(att)
            }
            for rel in duplicate.relationships where rel.sourceRef === duplicate {
                keeper.relationships.append(rel)
            }
            for cell in duplicate.popupTableCells where cell.sourceRef === duplicate {
                keeper.popupTableCells.append(cell)
            }
            for table in duplicate.popupTables where table.sourceRef === duplicate {
                keeper.popupTables.append(table)
            }
            for cellSource in duplicate.cellListSources where cellSource.sourceRef === duplicate {
                keeper.cellListSources.append(cellSource)
            }

            adoptString(&keeper.sourceDescription, duplicate.sourceDescription)
            adoptString(&keeper.author, duplicate.author)
            adoptString(&keeper.language, duplicate.language)
            adoptString(&keeper.period, duplicate.period)
            adoptString(&keeper.publicationInfo, duplicate.publicationInfo)
            adoptString(&keeper.url, duplicate.url)
            adoptOptional(&keeper.sortName, duplicate.sortName)

            duplicate.citations = []
            duplicate.attachments = []
            duplicate.relationships = []
            duplicate.popupTableCells = []
            duplicate.popupTables = []
            duplicate.cellListSources = []

            context.delete(duplicate)
        }
        try context.save()
    }

    // MARK: - Helpers

    private static func adoptString(_ target: inout String, _ source: String) {        if target.isEmpty { target = source }
    }

    private static func adoptOptional<T: Equatable>(_ target: inout T?, _ source: T?) {
        if target == nil, let source { target = source }
    }
}
