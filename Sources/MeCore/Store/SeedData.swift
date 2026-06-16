import Foundation
import SwiftData

// MARK: - Codable Seed Structs

private struct SeedDate: Codable {
    package let year: Int?
    package let era: String
    package let isApproximate: Bool

    package func toMythologicalDate() -> MythologicalDate {
        MythologicalDate(year: year, era: era, isApproximate: isApproximate)
    }
}

private struct SeedFigure: Codable {
    package let id: String
    package let name: String
    package let title: String
    package let figureType: String
    package let gender: String
    package let domain: String
    package let figureDescription: String
    package let birthDate: SeedDate
    package let deathDate: SeedDate
    package let source: String
}

private struct SeedRelationship: Codable {
    package let fromFigureId: String
    package let toFigureId: String
    package let relationshipType: String
    package let source: String
}

private struct SeedEra: Codable {
    package let id: String
    package let name: String
    package let orderIndex: Int
    package let eraDescription: String
    package let startDate: SeedDate
    package let endDate: SeedDate
}

private struct SeedPlace: Codable {
    package let id: String
    package let name: String
    package let placeType: String
    package let modernLocation: String
    package let placeDescription: String
    package let source: String
    package let latitude: Double?
    package let longitude: Double?
}

private struct SeedEvent: Codable {
    package let id: String
    package let name: String
    package let eventType: String
    package let eventDescription: String
    package let date: SeedDate
    package let era: String
    package let source: String
    package let involvedFigureIds: [String]
    package let placeId: String?
}

private struct SeedSource: Codable {
    package let id: String
    package let name: String
    package let sourceType: String
    package let author: String
    package let language: String
    package let period: String
    package let sourceDescription: String
    package let publicationInfo: String
    package let url: String
}

private struct SeedCitation: Codable {
    package let sourceId: String
    package let location: String
    package let entityType: String
    package let entityId: String
    package let note: String
}

private struct SeedAlternateName: Codable {
    package let figureId: String
    package let name: String
    package let tradition: String
    package let nameType: String
    package let note: String
}

private struct SeedAttachment: Codable {
    package let sourceId: String
    package let title: String
    package let url: String
    package let attachmentType: String
    package let note: String?
}

private struct SeedFigurePlaceAssociation: Codable {
    package let figureId: String
    package let placeId: String
    package let role: String
    package let source: String
}

private struct SeedPlacePlaceAssociation: Codable {
    package let fromPlaceId: String
    package let toPlaceId: String
    package let role: String
    package let source: String
}

private struct SeedEventEventAssociation: Codable {
    package let fromEventId: String
    package let toEventId: String
    package let role: String
    package let source: String
}

private struct SeedEventPlaceAssociation: Codable {
    package let eventId: String
    package let placeId: String
    package let role: String
    package let source: String
}

private struct SeedDataRoot: Codable {
    package let eras: [SeedEra]
    package let figures: [SeedFigure]
    package let relationships: [SeedRelationship]
    package let places: [SeedPlace]
    package let events: [SeedEvent]
    package let sources: [SeedSource]
    package let attachments: [SeedAttachment]
    package let citations: [SeedCitation]
    package let alternateNames: [SeedAlternateName]
    package let figurePlaceAssociations: [SeedFigurePlaceAssociation]?
    package let placePlaceAssociations: [SeedPlacePlaceAssociation]?
    package let eventPlaceAssociations: [SeedEventPlaceAssociation]?
    package let eventEventAssociations: [SeedEventEventAssociation]?
}

// MARK: - Seed Data Loader

/// Seeds the database with canonical Mesopotamian figures, relationships, and eras
/// on first launch (when the database is empty).
package struct SeedData {
    package static func seedIfEmpty(context: ModelContext) {
        let force = CommandLine.arguments.contains("--reseed")
        let figureCount = (try? context.fetchCount(FetchDescriptor<Figure>())) ?? 0

        if force && figureCount > 0 {
            clearAll(context: context)
            try? context.save()
        }

        guard figureCount == 0 || force else {
            ensureTypesExist(context: context)
            return
        }

        // Load JSON from bundle
        guard let url = Bundle.module.url(forResource: "seed_data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            assertionFailure("Failed to load seed_data.json from bundle")
            return
        }

        // MARK: - Eras
        var erasById: [String: Era] = [:]
        for seedEra in seed.eras {
            let era = Era(
                name: seedEra.name,
                orderIndex: seedEra.orderIndex,
                eraDescription: seedEra.eraDescription,
                startDate: seedEra.startDate.toMythologicalDate(),
                endDate: seedEra.endDate.toMythologicalDate()
            )
            context.insert(era)
            erasById[seedEra.id] = era
        }

        // MARK: - Figure Types
        ensureTypesExist(context: context)
        let typeCount = (try? context.fetchCount(FetchDescriptor<FigureType>())) ?? 0
        guard typeCount > 0 else {
            assertionFailure("Failed to create figure types")
            return
        }
        let typesByName: [String: FigureType] = {
            let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
            return Dictionary(uniqueKeysWithValues: types.map { ($0.name, $0) })
        }()

        // MARK: - Figures
        var figuresById: [String: Figure] = [:]
        for seedFigure in seed.figures {
            let figure = Figure(
                name: seedFigure.name,
                title: seedFigure.title,
                figureType: typesByName[seedFigure.figureType],
                gender: Figure.Gender(rawValue: seedFigure.gender) ?? .unknown,
                domain: seedFigure.domain,
                figureDescription: seedFigure.figureDescription,
                birthDate: seedFigure.birthDate.toMythologicalDate(),
                deathDate: seedFigure.deathDate.toMythologicalDate(),
                source: seedFigure.source
            )
            context.insert(figure)
            figuresById[seedFigure.id] = figure
        }

        // MARK: - Relationships
        for seedRel in seed.relationships {
            guard let from = figuresById[seedRel.fromFigureId],
                  let to = figuresById[seedRel.toFigureId] else { continue }
            let rel = Relationship(
                fromFigure: from,
                toFigure: to,
                relationshipType: Relationship.RelationshipType(rawValue: seedRel.relationshipType) ?? .father,
                source: seedRel.source
            )
            context.insert(rel)
        }

        // MARK: - Place Types
        let placeTypesByName: [String: PlaceType] = {
            let types = (try? context.fetch(FetchDescriptor<PlaceType>())) ?? []
            return Dictionary(uniqueKeysWithValues: types.map { ($0.name, $0) })
        }()

        // MARK: - Places
        var placesById: [String: Place] = [:]
        for seedPlace in seed.places {
            let place = Place(
                name: seedPlace.name,
                placeType: placeTypesByName[seedPlace.placeType],
                modernLocation: seedPlace.modernLocation,
                placeDescription: seedPlace.placeDescription,
                source: seedPlace.source,
                latitude: seedPlace.latitude,
                longitude: seedPlace.longitude
            )
            context.insert(place)
            placesById[seedPlace.id] = place
        }

        // MARK: - Event Types
        let eventTypesByName: [String: EventType] = {
            let types = (try? context.fetch(FetchDescriptor<EventType>())) ?? []
            return Dictionary(uniqueKeysWithValues: types.map { ($0.name, $0) })
        }()

        // MARK: - Events
        var eventsById: [String: Event] = [:]
        for seedEvent in seed.events {
            let figures = seedEvent.involvedFigureIds.compactMap { figuresById[$0] }
            let event = Event(
                name: seedEvent.name,
                eventType: eventTypesByName[seedEvent.eventType],
                eventDescription: seedEvent.eventDescription,
                date: seedEvent.date.toMythologicalDate(),
                era: seedEvent.era,
                source: seedEvent.source,
                involvedFigures: figures
            )
            context.insert(event)
            eventsById[seedEvent.id] = event
        }

        // MARK: - Sources
        var sourcesById: [String: Source] = [:]
        for seedSource in seed.sources {
            let source = Source(
                name: seedSource.name,
                sourceType: Source.SourceType(rawValue: seedSource.sourceType) ?? .ancientText,
                author: seedSource.author,
                language: seedSource.language,
                period: seedSource.period,
                sourceDescription: seedSource.sourceDescription,
                publicationInfo: seedSource.publicationInfo,
                url: seedSource.url
            )
            context.insert(source)
            sourcesById[seedSource.id] = source
        }

        // MARK: - Attachments
        for seedAttachment in seed.attachments {
            guard let source = sourcesById[seedAttachment.sourceId] else { continue }
            let attachment = Attachment(
                source: source,
                title: seedAttachment.title,
                url: seedAttachment.url,
                attachmentType: Attachment.AttachmentType(rawValue: seedAttachment.attachmentType) ?? .onlineText,
                note: seedAttachment.note
            )
            context.insert(attachment)
        }

        // MARK: - Citations
        for seedCitation in seed.citations {
            guard let source = sourcesById[seedCitation.sourceId] else { continue }
            let citation = Citation(
                source: source,
                location: seedCitation.location,
                note: seedCitation.note,
                entityType: Citation.EntityType(rawValue: seedCitation.entityType) ?? .figure,
                linkedEntityName: seedCitation.entityId
            )
            context.insert(citation)
        }

        // MARK: - Alternate Names
        for seedAltName in seed.alternateNames {
            guard let figure = figuresById[seedAltName.figureId] else { continue }
            let altName = AlternateName(
                figure: figure,
                name: seedAltName.name,
                tradition: AlternateName.Tradition(rawValue: seedAltName.tradition) ?? .sumerian,
                nameType: AlternateName.NameType(rawValue: seedAltName.nameType) ?? .spelling,
                note: seedAltName.note
            )
            context.insert(altName)
        }

        // MARK: - Figure-Place Associations
        if let associations = seed.figurePlaceAssociations {
            for seedAssoc in associations {
                guard let figure = figuresById[seedAssoc.figureId],
                      let place = placesById[seedAssoc.placeId] else { continue }
                let assoc = FigurePlaceAssociation(
                    figure: figure,
                    place: place,
                    role: FigurePlaceAssociation.Role(rawValue: seedAssoc.role) ?? .patronDeity,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Place-Place Associations
        if let placeAssocs = seed.placePlaceAssociations {
            for seedAssoc in placeAssocs {
                guard let from = placesById[seedAssoc.fromPlaceId],
                      let to = placesById[seedAssoc.toPlaceId] else { continue }
                let assoc = PlacePlaceAssociation(
                    fromPlace: from,
                    toPlace: to,
                    role: PlacePlaceAssociation.Role(rawValue: seedAssoc.role) ?? .locatedWithin,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Event-Place Associations
        if let eventPlaceAssocs = seed.eventPlaceAssociations {
            for seedAssoc in eventPlaceAssocs {
                guard let event = eventsById[seedAssoc.eventId],
                      let place = placesById[seedAssoc.placeId] else { continue }
                let assoc = EventPlaceAssociation(
                    event: event,
                    place: place,
                    role: EventPlaceAssociation.Role(rawValue: seedAssoc.role) ?? .occurredAt,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Event-Event Associations
        if let eventAssocs = seed.eventEventAssociations {
            for seedAssoc in eventAssocs {
                guard let from = eventsById[seedAssoc.fromEventId],
                      let to = eventsById[seedAssoc.toEventId] else { continue }
                let assoc = EventEventAssociation(
                    fromEvent: from,
                    toEvent: to,
                    role: EventEventAssociation.Role(rawValue: seedAssoc.role) ?? .relatedTo,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // Save
        try? context.save()
    }

    static func clearAll(context: ModelContext) {
        for entity in (try? context.fetch(FetchDescriptor<EventEventAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<EventPlaceAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<PlacePlaceAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<FigureImage>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<AlternateName>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Citation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Attachment>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Relationship>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Event>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Place>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Figure>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Era>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Source>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<FigureType>())) ?? [] { context.delete(entity) }
    }

    static func ensureTypesExist(context: ModelContext) {
        let figureTypeCount = (try? context.fetchCount(FetchDescriptor<FigureType>())) ?? 0
        if figureTypeCount == 0 {
            let typeConfig: [(name: String, icon: String, colorHex: String)] = [
                ("Deity", "star.fill", "007AFF"),
                ("Semi-Divine", "star.leadinghalf.filled", "FF9500"),
                ("Human", "person.fill", "34C759"),
                ("Primordial", "sparkles", "AF52DE"),
            ]
            for config in typeConfig {
                let type = FigureType(name: config.name, icon: config.icon, colorHex: config.colorHex)
                context.insert(type)
            }
        }

        let placeTypeCount = (try? context.fetchCount(FetchDescriptor<PlaceType>())) ?? 0
        if placeTypeCount == 0 {
            let placeTypeConfig: [(name: String, icon: String, colorHex: String)] = [
                ("City", "building.2", "007AFF"),
                ("Temple", "building.columns", "FF9500"),
                ("Underworld", "arrow.down.circle", "5856D6"),
                ("Cosmic Realm", "sparkles", "AF52DE"),
                ("Region", "map", "34C759"),
                ("Mountain", "mountain.2", "8B8B8B"),
            ]
            for config in placeTypeConfig {
                let type = PlaceType(name: config.name, icon: config.icon, colorHex: config.colorHex)
                context.insert(type)
            }
        }

        let eventTypeCount = (try? context.fetchCount(FetchDescriptor<EventType>())) ?? 0
        if eventTypeCount == 0 {
            let eventTypeConfig: [(name: String, icon: String, colorHex: String)] = [
                ("Battle", "shield.righthalf.filled", "FF3B30"),
                ("Creation", "sparkles", "AF52DE"),
                ("Descent", "arrow.down.to.line", "5856D6"),
                ("Flood", "drop", "007AFF"),
                ("Quest", "magnifyingglass", "34C759"),
                ("Death", "cross.circle", "8B8B8B"),
                ("Ascension", "arrow.up.to.line", "FF9500"),
                ("City Founding", "building.2", "007AFF"),
            ]
            for config in eventTypeConfig {
                let type = EventType(name: config.name, icon: config.icon, colorHex: config.colorHex)
                context.insert(type)
            }
        }

        try? context.save()
    }
}
