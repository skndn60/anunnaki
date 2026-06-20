import Foundation
import SwiftData

// MARK: - Codable Seed Structs

package struct SeedDate: Codable {
    package let year: Int?
    package let era: String
    package let isApproximate: Bool

    package func toMythologicalDate() -> MythologicalDate {
        MythologicalDate(year: year, era: era, isApproximate: isApproximate)
    }

    package init(year: Int? = nil, era: String = "", isApproximate: Bool = false) {
        self.year = year
        self.era = era
        self.isApproximate = isApproximate
    }
}

package struct SeedFigureType: Codable {
    package let id: String
    package let name: String
    package let icon: String
    package let colorHex: String

    package init(id: String = "", name: String = "", icon: String = "", colorHex: String = "") {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}

package struct SeedPlaceType: Codable {
    package let id: String
    package let name: String
    package let icon: String
    package let colorHex: String

    package init(id: String = "", name: String = "", icon: String = "", colorHex: String = "") {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}

package struct SeedEventType: Codable {
    package let id: String
    package let name: String
    package let icon: String
    package let colorHex: String

    package init(id: String = "", name: String = "", icon: String = "", colorHex: String = "") {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}

package struct SeedFigure: Codable {
    package let id: String
    package let name: String
    package let disambiguation: String
    package let title: String
    package let figureType: String
    package let gender: String
    package let domain: String
    package let figureDescription: String
    package let birthDate: SeedDate
    package let deathDate: SeedDate
    package let source: String

    package init(id: String = "", name: String = "", disambiguation: String = "", title: String = "", figureType: String = "", gender: String = "", domain: String = "", figureDescription: String = "", birthDate: SeedDate = .init(), deathDate: SeedDate = .init(), source: String = "") {
        self.id = id
        self.name = name
        self.disambiguation = disambiguation
        self.title = title
        self.figureType = figureType
        self.gender = gender
        self.domain = domain
        self.figureDescription = figureDescription
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.source = source
    }
}

package struct SeedRelationship: Codable {
    package let fromFigureId: String
    package let toFigureId: String
    package let relationshipType: String
    package let source: String

    package init(fromFigureId: String = "", toFigureId: String = "", relationshipType: String = "", source: String = "") {
        self.fromFigureId = fromFigureId
        self.toFigureId = toFigureId
        self.relationshipType = relationshipType
        self.source = source
    }
}

package struct SeedEra: Codable {
    package let id: String
    package let name: String
    package let orderIndex: Int
    package let eraDescription: String
    package let startDate: SeedDate
    package let endDate: SeedDate

    package init(id: String = "", name: String = "", orderIndex: Int = 0, eraDescription: String = "", startDate: SeedDate = .init(), endDate: SeedDate = .init()) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.eraDescription = eraDescription
        self.startDate = startDate
        self.endDate = endDate
    }
}

package struct SeedPlace: Codable {
    package let id: String
    package let name: String
    package let placeType: String
    package let modernLocation: String
    package let placeDescription: String
    package let source: String
    package let latitude: Double?
    package let longitude: Double?

    package init(id: String = "", name: String = "", placeType: String = "", modernLocation: String = "", placeDescription: String = "", source: String = "", latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.name = name
        self.placeType = placeType
        self.modernLocation = modernLocation
        self.placeDescription = placeDescription
        self.source = source
        self.latitude = latitude
        self.longitude = longitude
    }
}

package struct SeedEvent: Codable {
    package let id: String
    package let name: String
    package let eventType: String
    package let eventDescription: String
    package let date: SeedDate
    package let era: String
    package let source: String
    package let involvedFigureIds: [String]
    package let placeId: String?

    package init(id: String = "", name: String = "", eventType: String = "", eventDescription: String = "", date: SeedDate = .init(), era: String = "", source: String = "", involvedFigureIds: [String] = [], placeId: String? = nil) {
        self.id = id
        self.name = name
        self.eventType = eventType
        self.eventDescription = eventDescription
        self.date = date
        self.era = era
        self.source = source
        self.involvedFigureIds = involvedFigureIds
        self.placeId = placeId
    }
}

package struct SeedSource: Codable {
    package let id: String
    package let name: String
    package let sourceType: String
    package let author: String
    package let language: String
    package let period: String
    package let sourceDescription: String
    package let publicationInfo: String
    package let url: String

    package init(id: String = "", name: String = "", sourceType: String = "", author: String = "", language: String = "", period: String = "", sourceDescription: String = "", publicationInfo: String = "", url: String = "") {
        self.id = id
        self.name = name
        self.sourceType = sourceType
        self.author = author
        self.language = language
        self.period = period
        self.sourceDescription = sourceDescription
        self.publicationInfo = publicationInfo
        self.url = url
    }
}

package struct SeedCitation: Codable {
    package let sourceId: String
    package let location: String
    package let entityType: String
    package let entityId: String
    package let note: String

    package init(sourceId: String = "", location: String = "", entityType: String = "", entityId: String = "", note: String = "") {
        self.sourceId = sourceId
        self.location = location
        self.entityType = entityType
        self.entityId = entityId
        self.note = note
    }
}

package struct SeedAlternateName: Codable {
    package let figureId: String
    package let name: String
    package let tradition: String
    package let nameType: String
    package let note: String

    package init(figureId: String = "", name: String = "", tradition: String = "", nameType: String = "", note: String = "") {
        self.figureId = figureId
        self.name = name
        self.tradition = tradition
        self.nameType = nameType
        self.note = note
    }
}

package struct SeedAttachment: Codable {
    package let sourceId: String
    package let title: String
    package let url: String
    package let attachmentType: String
    package let note: String?

    package init(sourceId: String = "", title: String = "", url: String = "", attachmentType: String = "", note: String? = nil) {
        self.sourceId = sourceId
        self.title = title
        self.url = url
        self.attachmentType = attachmentType
        self.note = note
    }
}

package struct SeedFigurePlaceAssociation: Codable {
    package let figureId: String
    package let placeId: String
    package let role: String
    package let source: String

    package init(figureId: String = "", placeId: String = "", role: String = "", source: String = "") {
        self.figureId = figureId
        self.placeId = placeId
        self.role = role
        self.source = source
    }
}

package struct SeedPlacePlaceAssociation: Codable {
    package let fromPlaceId: String
    package let toPlaceId: String
    package let role: String
    package let source: String

    package init(fromPlaceId: String = "", toPlaceId: String = "", role: String = "", source: String = "") {
        self.fromPlaceId = fromPlaceId
        self.toPlaceId = toPlaceId
        self.role = role
        self.source = source
    }
}

package struct SeedEventEventAssociation: Codable {
    package let fromEventId: String
    package let toEventId: String
    package let role: String
    package let source: String

    package init(fromEventId: String = "", toEventId: String = "", role: String = "", source: String = "") {
        self.fromEventId = fromEventId
        self.toEventId = toEventId
        self.role = role
        self.source = source
    }
}

package struct SeedImageAsset: Codable {
    package let id: String
    package let filename: String
    package let caption: String
    package let source: String
    package let figureIds: [String]
    package let placeIds: [String]
    package let eventIds: [String]

    package init(id: String = "", filename: String = "", caption: String = "", source: String = "", figureIds: [String] = [], placeIds: [String] = [], eventIds: [String] = []) {
        self.id = id
        self.filename = filename
        self.caption = caption
        self.source = source
        self.figureIds = figureIds
        self.placeIds = placeIds
        self.eventIds = eventIds
    }
}

package struct SeedTag: Codable {
    package let id: String
    package let name: String
    package let colorHex: String?
    package let figureIds: [String]
    package let placeIds: [String]
    package let eventIds: [String]
    package let imageIds: [String]

    package init(id: String = "", name: String = "", colorHex: String? = nil, figureIds: [String] = [], placeIds: [String] = [], eventIds: [String] = [], imageIds: [String] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.figureIds = figureIds
        self.placeIds = placeIds
        self.eventIds = eventIds
        self.imageIds = imageIds
    }
}

package struct SeedEventPlaceAssociation: Codable {
    package let eventId: String
    package let placeId: String
    package let role: String
    package let source: String

    package init(eventId: String = "", placeId: String = "", role: String = "", source: String = "") {
        self.eventId = eventId
        self.placeId = placeId
        self.role = role
        self.source = source
    }
}

package struct SeedDataRoot: Codable {
    package var eras: [SeedEra]
    package var figures: [SeedFigure]
    package var relationships: [SeedRelationship]
    package var places: [SeedPlace]
    package var events: [SeedEvent]
    package var sources: [SeedSource]
    package var attachments: [SeedAttachment]
    package var citations: [SeedCitation]
    package var alternateNames: [SeedAlternateName]
    package var figurePlaceAssociations: [SeedFigurePlaceAssociation]?
    package var placePlaceAssociations: [SeedPlacePlaceAssociation]?
    package var eventPlaceAssociations: [SeedEventPlaceAssociation]?
    package var figureTypes: [SeedFigureType]?
    package var placeTypes: [SeedPlaceType]?
    package var eventTypes: [SeedEventType]?
    package var eventEventAssociations: [SeedEventEventAssociation]?
    package var imageAssets: [SeedImageAsset]?
    package var tags: [SeedTag]?

    package init(eras: [SeedEra] = [], figures: [SeedFigure] = [], relationships: [SeedRelationship] = [], places: [SeedPlace] = [], events: [SeedEvent] = [], sources: [SeedSource] = [], attachments: [SeedAttachment] = [], citations: [SeedCitation] = [], alternateNames: [SeedAlternateName] = [], figureTypes: [SeedFigureType]? = nil, placeTypes: [SeedPlaceType]? = nil, eventTypes: [SeedEventType]? = nil, figurePlaceAssociations: [SeedFigurePlaceAssociation]? = nil, placePlaceAssociations: [SeedPlacePlaceAssociation]? = nil, eventPlaceAssociations: [SeedEventPlaceAssociation]? = nil, eventEventAssociations: [SeedEventEventAssociation]? = nil, imageAssets: [SeedImageAsset]? = nil, tags: [SeedTag]? = nil) {
        self.eras = eras
        self.figures = figures
        self.relationships = relationships
        self.places = places
        self.events = events
        self.sources = sources
        self.attachments = attachments
        self.citations = citations
        self.alternateNames = alternateNames
        self.figurePlaceAssociations = figurePlaceAssociations
        self.placePlaceAssociations = placePlaceAssociations
        self.eventPlaceAssociations = eventPlaceAssociations
        self.figureTypes = figureTypes
        self.placeTypes = placeTypes
        self.eventTypes = eventTypes
        self.eventEventAssociations = eventEventAssociations
        self.imageAssets = imageAssets
        self.tags = tags
    }
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

        // Load primary seed data
        guard let url = Bundle.module.url(forResource: "seed_data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
               let seed = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            assertionFailure("Failed to load seed_data.json from bundle")
            return
        }

        importFrom(root: seed, context: context)
    }

    package static func importFrom(root: SeedDataRoot, context: ModelContext) {
        // MARK: - Eras
        var erasById: [String: Era] = [:]
        for seedEra in root.eras {
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
        if let seedTypes = root.figureTypes, !seedTypes.isEmpty {
            for st in seedTypes {
                let type = FigureType(name: st.name, icon: st.icon, colorHex: st.colorHex)
                context.insert(type)
            }
        } else {
            ensureTypesExist(context: context)
        }
        let typesByName: [String: FigureType] = {
            let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
            return Dictionary(uniqueKeysWithValues: types.map { ($0.name, $0) })
        }()

        // MARK: - Figures
        var figuresById: [String: Figure] = [:]
        var sklEraIndex: [String: Int] = [:]
        for seedFigure in root.figures {
            let orderIndex: Int
            if seedFigure.source == "Sumerian King List" {
                let era = seedFigure.birthDate.era.isEmpty ? "Antediluvian" : seedFigure.birthDate.era
                orderIndex = sklEraIndex[era, default: 0]
                sklEraIndex[era] = orderIndex + 1
            } else {
                orderIndex = 0
            }
            let figure = Figure(
                name: seedFigure.name,
                disambiguation: seedFigure.disambiguation,
                title: seedFigure.title,
                figureType: typesByName[seedFigure.figureType],
                gender: Figure.Gender(rawValue: seedFigure.gender) ?? .unknown,
                domain: seedFigure.domain,
                figureDescription: seedFigure.figureDescription,
                birthDate: seedFigure.birthDate.toMythologicalDate(),
                deathDate: seedFigure.deathDate.toMythologicalDate(),
                source: seedFigure.source,
                orderIndex: orderIndex
            )
            context.insert(figure)
            figuresById[seedFigure.id] = figure
        }

        // MARK: - Relationships
        for seedRel in root.relationships {
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
        if let seedTypes = root.placeTypes, !seedTypes.isEmpty {
            for st in seedTypes {
                let type = PlaceType(name: st.name, icon: st.icon, colorHex: st.colorHex)
                context.insert(type)
            }
        }
        let placeTypesByName: [String: PlaceType] = {
            let types = (try? context.fetch(FetchDescriptor<PlaceType>())) ?? []
            return Dictionary(uniqueKeysWithValues: types.map { ($0.name, $0) })
        }()

        // MARK: - Places
        var placesById: [String: Place] = [:]
        for seedPlace in root.places {
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
        if let seedTypes = root.eventTypes, !seedTypes.isEmpty {
            for st in seedTypes {
                let type = EventType(name: st.name, icon: st.icon, colorHex: st.colorHex)
                context.insert(type)
            }
        }
        let eventTypesByName: [String: EventType] = {
            let types = (try? context.fetch(FetchDescriptor<EventType>())) ?? []
            return Dictionary(uniqueKeysWithValues: types.map { ($0.name, $0) })
        }()

        // MARK: - Events
        var eventsById: [String: Event] = [:]
        for seedEvent in root.events {
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
        for seedSource in root.sources {
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
        for seedAttachment in root.attachments {
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
        for seedCitation in root.citations {
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
        for seedAltName in root.alternateNames {
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
        if let associations = root.figurePlaceAssociations {
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
        if let placeAssocs = root.placePlaceAssociations {
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
        if let eventPlaceAssocs = root.eventPlaceAssociations {
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
        if let eventAssocs = root.eventEventAssociations {
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

        // MARK: - Image Assets
        if let images = root.imageAssets {
            var imagesById: [String: ImageAsset] = [:]
            for si in images {
                let image = ImageAsset(
                    figures: si.figureIds.compactMap { figuresById[$0] },
                    places: si.placeIds.compactMap { placesById[$0] },
                    events: si.eventIds.compactMap { eventsById[$0] },
                    filename: si.filename,
                    caption: si.caption,
                    source: si.source
                )
                context.insert(image)
                imagesById[si.id] = image
            }

            // MARK: - Tags
            if let tags = root.tags {
                for st in tags {
                    let tag = Tag(
                        name: st.name,
                        colorHex: st.colorHex
                    )
                    tag.figures = st.figureIds.compactMap { figuresById[$0] }
                    tag.places = st.placeIds.compactMap { placesById[$0] }
                    tag.events = st.eventIds.compactMap { eventsById[$0] }
                    tag.images = st.imageIds.compactMap { imagesById[$0] }
                    context.insert(tag)
                }
            }
        }

        // Save
        try? context.save()
    }

    package static func reseed(context: ModelContext) {
        clearAll(context: context)
        try? context.save()
        seedIfEmpty(context: context)
    }

    static func clearAll(context: ModelContext) {
        for entity in (try? context.fetch(FetchDescriptor<EventEventAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<EventPlaceAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<PlacePlaceAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<ImageAsset>())) ?? [] { context.delete(entity) }
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
        for entity in (try? context.fetch(FetchDescriptor<PlaceType>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<EventType>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Tag>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<DataVersion>())) ?? [] { context.delete(entity) }
    }

    static func ensureTypesExist(context: ModelContext) {
        let figureTypeCount = (try? context.fetchCount(FetchDescriptor<FigureType>())) ?? 0
        if figureTypeCount == 0 {
            let typeConfig: [(name: String, icon: String, colorHex: String)] = [
                ("Deity", "star.fill", "007AFF"),
                ("Semi-Divine", "star.leadinghalf.filled", "FF9500"),
                ("Human", "person.fill", "34C759"),
                ("Primordial", "sparkles", "AF52DE"),
                ("Igigi", "moon.stars", "8B5CF6"),
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
