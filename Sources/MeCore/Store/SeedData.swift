import Foundation
import SwiftData

// MARK: - Codable Seed Structs

package struct SeedDate: Codable {
    package let startYear: Int?
    package let endYear: Int?
    package let era: String
    package let isApproximate: Bool

    package func toMythologicalDate() -> MythologicalDate {
        MythologicalDate(startYear: startYear, endYear: endYear, era: era, isApproximate: isApproximate)
    }

    package init(startYear: Int? = nil, endYear: Int? = nil, era: String = "", isApproximate: Bool = false) {
        self.startYear = startYear
        self.endYear = endYear
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
    package let foundedDate: SeedDate?

    package init(id: String = "", name: String = "", placeType: String = "", modernLocation: String = "", placeDescription: String = "", source: String = "", latitude: Double? = nil, longitude: Double? = nil, foundedDate: SeedDate? = nil) {
        self.id = id
        self.name = name
        self.placeType = placeType
        self.modernLocation = modernLocation
        self.placeDescription = placeDescription
        self.source = source
        self.latitude = latitude
        self.longitude = longitude
        self.foundedDate = foundedDate
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
    package let sortName: String?
    package let involvedFigureIds: [String]
    package let placeId: String?

    package init(id: String = "", name: String = "", eventType: String = "", eventDescription: String = "", date: SeedDate = .init(), era: String = "", source: String = "", sortName: String? = nil, involvedFigureIds: [String] = [], placeId: String? = nil) {
        self.id = id
        self.name = name
        self.eventType = eventType
        self.eventDescription = eventDescription
        self.date = date
        self.era = era
        self.source = source
        self.sortName = sortName
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
    package let figureId: String?
    package let placeId: String?
    package let name: String
    package let tradition: String
    package let nameType: String
    package let note: String

    package init(figureId: String? = nil, placeId: String? = nil, name: String = "", tradition: String = "", nameType: String = "", note: String = "") {
        self.figureId = figureId
        self.placeId = placeId
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
    package let imageDescription: String
    package let figureIds: [String]
    package let placeIds: [String]
    package let eventIds: [String]
    package let thingIds: [String]

    package init(id: String = "", filename: String = "", caption: String = "", source: String = "", imageDescription: String = "", figureIds: [String] = [], placeIds: [String] = [], eventIds: [String] = [], thingIds: [String] = []) {
        self.id = id
        self.filename = filename
        self.caption = caption
        self.source = source
        self.imageDescription = imageDescription
        self.figureIds = figureIds
        self.placeIds = placeIds
        self.eventIds = eventIds
        self.thingIds = thingIds
    }
}

package struct SeedThing: Codable {
    package let id: String
    package let name: String
    package let thingDescription: String
    package let source: String

    package init(id: String = "", name: String = "", thingDescription: String = "", source: String = "") {
        self.id = id
        self.name = name
        self.thingDescription = thingDescription
        self.source = source
    }
}

package struct SeedThingFigureAssociation: Codable {
    package let thingId: String
    package let figureId: String
    package let role: String
    package let source: String

    package init(thingId: String = "", figureId: String = "", role: String = "", source: String = "") {
        self.thingId = thingId
        self.figureId = figureId
        self.role = role
        self.source = source
    }
}

package struct SeedThingPlaceAssociation: Codable {
    package let thingId: String
    package let placeId: String
    package let role: String
    package let source: String

    package init(thingId: String = "", placeId: String = "", role: String = "", source: String = "") {
        self.thingId = thingId
        self.placeId = placeId
        self.role = role
        self.source = source
    }
}

package struct SeedThingEventAssociation: Codable {
    package let thingId: String
    package let eventId: String
    package let role: String
    package let source: String

    package init(thingId: String = "", eventId: String = "", role: String = "", source: String = "") {
        self.thingId = thingId
        self.eventId = eventId
        self.role = role
        self.source = source
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
    package let thingIds: [String]

    package init(id: String = "", name: String = "", colorHex: String? = nil, figureIds: [String] = [], placeIds: [String] = [], eventIds: [String] = [], imageIds: [String] = [], thingIds: [String] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.figureIds = figureIds
        self.placeIds = placeIds
        self.eventIds = eventIds
        self.imageIds = imageIds
        self.thingIds = thingIds
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
    package var things: [SeedThing]
    package var thingFigureAssociations: [SeedThingFigureAssociation]?
    package var thingPlaceAssociations: [SeedThingPlaceAssociation]?
    package var thingEventAssociations: [SeedThingEventAssociation]?

    package init(eras: [SeedEra] = [], figures: [SeedFigure] = [], relationships: [SeedRelationship] = [], places: [SeedPlace] = [], events: [SeedEvent] = [], sources: [SeedSource] = [], attachments: [SeedAttachment] = [], citations: [SeedCitation] = [], alternateNames: [SeedAlternateName] = [], figureTypes: [SeedFigureType]? = nil, placeTypes: [SeedPlaceType]? = nil, eventTypes: [SeedEventType]? = nil, figurePlaceAssociations: [SeedFigurePlaceAssociation]? = nil, placePlaceAssociations: [SeedPlacePlaceAssociation]? = nil, eventPlaceAssociations: [SeedEventPlaceAssociation]? = nil, eventEventAssociations: [SeedEventEventAssociation]? = nil, imageAssets: [SeedImageAsset]? = nil, tags: [SeedTag]? = nil, things: [SeedThing] = [], thingFigureAssociations: [SeedThingFigureAssociation]? = nil, thingPlaceAssociations: [SeedThingPlaceAssociation]? = nil, thingEventAssociations: [SeedThingEventAssociation]? = nil) {
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
        self.things = things
        self.thingFigureAssociations = thingFigureAssociations
        self.thingPlaceAssociations = thingPlaceAssociations
        self.thingEventAssociations = thingEventAssociations
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
            ensureEnochDataExists(context: context)
            Migration.ensureDeitiesImportExist(context: context)
            Migration.ensureDumuziFamilyExists(context: context)
            Migration.fixEraOrderIndices(context: context)
            return
        }

        // Load primary seed data
        let seedURL: URL? = {
            if let url = Bundle.module.url(forResource: "seed_data", withExtension: "json") { return url }
            return Bundle.main.url(forResource: "seed_data", withExtension: "json")
        }()
        guard let url = seedURL,
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            return
        }

        importFrom(root: seed, context: context)
        Migration.ensureDeitiesImportExist(context: context)
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
            if seedFigure.source.contains("Sumerian King List") {
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
        let relTypes: [RelationshipType] = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        for seedRel in root.relationships {
            guard let from = figuresById[seedRel.fromFigureId],
                  let to = figuresById[seedRel.toFigureId] else { continue }
            let rel = Relationship(
                fromFigure: from,
                toFigure: to,
                relationshipType: relTypes.first(where: { $0.name.lowercased() == seedRel.relationshipType.lowercased() }),
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
            place.foundedDate = seedPlace.foundedDate?.toMythologicalDate()
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
                sortName: seedEvent.sortName,
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
            let figure = seedAltName.figureId.flatMap { figuresById[$0] }
            let place = seedAltName.placeId.flatMap { placesById[$0] }
            guard figure != nil || place != nil else { continue }
            let altName = AlternateName(
                figure: figure,
                place: place,
                name: seedAltName.name,
                tradition: AlternateName.Tradition(rawValue: seedAltName.tradition) ?? .sumerian,
                nameType: AlternateName.NameType(rawValue: seedAltName.nameType) ?? .spelling,
                note: seedAltName.note
            )
            context.insert(altName)
        }

        // MARK: - Figure-Place Associations
        if let associations = root.figurePlaceAssociations {
            let allRoleTypes: [FigurePlaceRoleType] = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
            for seedAssoc in associations {
                guard let figure = figuresById[seedAssoc.figureId],
                      let place = placesById[seedAssoc.placeId] else { continue }
                let roleType = allRoleTypes.first(where: { $0.name == seedAssoc.role })
                let assoc = FigurePlaceAssociation(
                    figure: figure,
                    place: place,
                    roleType: roleType,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Place-Place Associations
        if let placeAssocs = root.placePlaceAssociations {
            let allRoleTypes: [PlacePlaceRoleType] = (try? context.fetch(FetchDescriptor<PlacePlaceRoleType>())) ?? []
            for seedAssoc in placeAssocs {
                guard let from = placesById[seedAssoc.fromPlaceId],
                      let to = placesById[seedAssoc.toPlaceId] else { continue }
                let roleType = allRoleTypes.first(where: { $0.name == seedAssoc.role })
                let assoc = PlacePlaceAssociation(
                    fromPlace: from,
                    toPlace: to,
                    roleType: roleType,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Event-Place Associations
        if let eventPlaceAssocs = root.eventPlaceAssociations {
            let allRoleTypes: [EventPlaceRoleType] = (try? context.fetch(FetchDescriptor<EventPlaceRoleType>())) ?? []
            for seedAssoc in eventPlaceAssocs {
                guard let event = eventsById[seedAssoc.eventId],
                      let place = placesById[seedAssoc.placeId] else { continue }
                let roleType = allRoleTypes.first(where: { $0.name == seedAssoc.role })
                let assoc = EventPlaceAssociation(
                    event: event,
                    place: place,
                    roleType: roleType,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Event-Event Associations
        if let eventAssocs = root.eventEventAssociations {
            let allRoleTypes: [EventEventRoleType] = (try? context.fetch(FetchDescriptor<EventEventRoleType>())) ?? []
            for seedAssoc in eventAssocs {
                guard let from = eventsById[seedAssoc.fromEventId],
                      let to = eventsById[seedAssoc.toEventId] else { continue }
                let roleType = allRoleTypes.first(where: { $0.name == seedAssoc.role })
                let assoc = EventEventAssociation(
                    fromEvent: from,
                    toEvent: to,
                    roleType: roleType,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Things
        var thingsById: [String: Thing] = [:]
        for seedThing in root.things {
            let thing = Thing(
                name: seedThing.name,
                thingDescription: seedThing.thingDescription,
                source: seedThing.source
            )
            context.insert(thing)
            thingsById[seedThing.id] = thing
        }

        // MARK: - Thing-Figure Associations
        if let assocs = root.thingFigureAssociations {
            let allRoleTypes: [ThingFigureRoleType] = (try? context.fetch(FetchDescriptor<ThingFigureRoleType>())) ?? []
            for seedAssoc in assocs {
                guard let thing = thingsById[seedAssoc.thingId],
                      let figure = figuresById[seedAssoc.figureId] else { continue }
                let roleType = allRoleTypes.first(where: { $0.name == seedAssoc.role })
                let assoc = ThingFigureAssociation(
                    thing: thing,
                    figure: figure,
                    roleType: roleType,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Thing-Place Associations
        if let assocs = root.thingPlaceAssociations {
            let allRoleTypes: [ThingPlaceRoleType] = (try? context.fetch(FetchDescriptor<ThingPlaceRoleType>())) ?? []
            for seedAssoc in assocs {
                guard let thing = thingsById[seedAssoc.thingId],
                      let place = placesById[seedAssoc.placeId] else { continue }
                let roleType = allRoleTypes.first(where: { $0.name == seedAssoc.role })
                let assoc = ThingPlaceAssociation(
                    thing: thing,
                    place: place,
                    roleType: roleType,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Thing-Event Associations
        if let assocs = root.thingEventAssociations {
            let allRoleTypes: [ThingEventRoleType] = (try? context.fetch(FetchDescriptor<ThingEventRoleType>())) ?? []
            for seedAssoc in assocs {
                guard let thing = thingsById[seedAssoc.thingId],
                      let event = eventsById[seedAssoc.eventId] else { continue }
                let roleType = allRoleTypes.first(where: { $0.name == seedAssoc.role })
                let assoc = ThingEventAssociation(
                    thing: thing,
                    event: event,
                    roleType: roleType,
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
                    things: si.thingIds.compactMap { thingsById[$0] },
                    filename: si.filename,
                    caption: si.caption,
                    source: si.source,
                    imageDescription: si.imageDescription
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
                    tag.things = st.thingIds.compactMap { thingsById[$0] }
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
        for entity in (try? context.fetch(FetchDescriptor<ThingEventAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<ThingPlaceAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<ThingFigureAssociation>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Tag>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<DataVersion>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<ContentAttribution>())) ?? [] { context.delete(entity) }
        for entity in (try? context.fetch(FetchDescriptor<Thing>())) ?? [] { context.delete(entity) }
    }

    static func ensureTypesExist(context: ModelContext) {
        let figureTypeCount = (try? context.fetchCount(FetchDescriptor<FigureType>())) ?? 0
        if figureTypeCount == 0 {
            let typeConfig: [(name: String, icon: String, colorHex: String)] = [
                ("Archangel", "star.fill", "FBBF24"),
                ("Deity", "star.fill", "007AFF"),
                ("Semi-Divine", "star.leadinghalf.filled", "FF9500"),
                ("Human", "person.fill", "34C759"),
                ("Primordial", "sparkles", "AF52DE"),
                ("Igigi", "moon.stars", "8B5CF6"),
                ("Commander", "chevron.left.forwardslash.chevron.right", "EF4444"),
                ("Divine Collective", "person.3.fill", "8B5CF6"),
            ]
            for config in typeConfig {
                let type = FigureType(name: config.name, icon: config.icon, colorHex: config.colorHex)
                context.insert(type)
            }
        }

        Migration.ensureCommanderFigureTypeExists(context: context)

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
                ("Foundation", "building.columns.fill", "F59E0B"),
                ("Destruction", "flame.fill", "FF3B30"),
            ]
            for config in eventTypeConfig {
                let type = EventType(name: config.name, icon: config.icon, colorHex: config.colorHex)
                context.insert(type)
            }
        }

        let thingTypeCount = (try? context.fetchCount(FetchDescriptor<ThingType>())) ?? 0
        if thingTypeCount == 0 {
            let thingTypeConfig: [(name: String, icon: String, colorHex: String)] = [
                ("Artifact", "cube.box", "8B5CF6"),
                ("Monument", "building.columns", "F59E0B"),
                ("Text", "doc.text", "3B82F6"),
                ("Tool", "hammer", "EF4444"),
                ("Weapon", "shield.righthalf.filled", "EF4444"),
                ("Jewelry", "circle.dotted", "EC4899"),
            ]
            for config in thingTypeConfig {
                let type = ThingType(name: config.name, icon: config.icon, colorHex: config.colorHex)
                context.insert(type)
            }
        }

        Migration.ensureRelationTypesExist(context: context)
        Migration.ensurePlacePlaceRoleTypesExist(context: context)
        Migration.ensureEventEventRoleTypesExist(context: context)
        Migration.ensureEventPlaceRoleTypesExist(context: context)
        Migration.ensureFigurePlaceRoleTypesExist(context: context)
        Migration.ensureThingFigureRoleTypesExist(context: context)
        Migration.ensureThingPlaceRoleTypesExist(context: context)
        Migration.ensureThingEventRoleTypesExist(context: context)
        Migration.fixAllyIcon(context: context)
        try? context.save()
    }

    static func ensureEnochDataExists(context: ModelContext) {
        Migration.ensureArchangelsExist(context: context)

        let placePredicate = #Predicate<Place> { $0.name == "Mount Hermon" }
        let mountHermonCount = (try? context.fetchCount(FetchDescriptor<Place>(predicate: placePredicate))) ?? 0
        guard mountHermonCount == 0 else { return }

        let sourcePredicate = #Predicate<Source> { $0.name == "Book of Enoch (1 Enoch)" }
        let sourceCount = (try? context.fetchCount(FetchDescriptor<Source>(predicate: sourcePredicate))) ?? 0
        if sourceCount == 0 {
            let source = Source(
                name: "Book of Enoch (1 Enoch)",
                sourceType: .ancientText,
                author: "Unknown (attributed to Enoch; Second Temple period Jewish scribes)",
                language: "Ge'ez (Ethiopic); original Aramaic fragments from Qumran",
                period: "3rd\u{2013}1st century BCE (Book of the Watchers: ~300\u{2013}200 BCE)",
                sourceDescription: "An ancient Jewish apocryphal work, fully preserved only in the Ethiopic Ge'ez canon of the Orthodox Tewahedo Church. The Book of the Watchers (chapters 1\u{2013}36) describes the descent of 200 angelic Watchers to Mount Hermon, their taking of human wives, the birth of the Nephilim giants, and the forbidden knowledge they taught humanity. Aramaic fragments from Qumran Cave 4 confirm a pre-Christian origin.",
                publicationInfo: "Multiple manuscripts: Ethiopic Ge'ez tradition; Aramaic fragments 4QEn ar (4Q201, 4Q202, 4Q204, 4Q206) from Qumran; Greek excerpts by George Syncellus",
                url: "https://en.wikipedia.org/wiki/Book_of_Enoch"
            )
            context.insert(source)
        }

        let placeTypes = (try? context.fetch(FetchDescriptor<PlaceType>())) ?? []
        let placeTypesByName = Dictionary(uniqueKeysWithValues: placeTypes.map { ($0.name, $0) })

        let placeConfigs: [(name: String, typeName: String, modernLocation: String, description: String, source: String, lat: Double?, lon: Double?)] = [
            ("Mount Hermon", "Mountain", "Anti-Lebanon mountain range, on the border between Syria and Lebanon",
             "The mountain where the 200 Watchers descended and swore an oath under Samyaza's leadership to take human wives. Considered the site of the Watchers' rebellion.",
             "Book of Enoch (1 Enoch), ch. 6", 33.416, 35.857),
            ("Dudael", "Region", "Desert wilderness (location uncertain; possibly near the Dead Sea)",
             "The desert pit where the archangel Raphael bound Azazel hand and foot, covering him with rugged and sharp rocks. Azazel was imprisoned here until the day of judgment.",
             "Book of Enoch (1 Enoch), ch. 10:4-5", nil, nil),
            ("Sheol", "Underworld", "",
             "The underworld realm of the dead, described in Enoch's vision as a place with hollows and compartments where the spirits of the dead await judgment. Includes the place of punishment for the fallen angels, with a great burning fire.",
             "Book of Enoch (1 Enoch), ch. 22", nil, nil),
            ("Paradise", "Cosmic Realm", "",
             "The Garden of Righteousness, a heavenly realm where the tree of life stands. In Enoch's vision, it is located among seven magnificent mountains in the north-west. The dwelling place of the righteous after death, reserved for those who have not been corrupted by the Watchers' teachings.",
             "Book of Enoch (1 Enoch), ch. 24-25, 32", nil, nil),
        ]
        for config in placeConfigs {
            let place = Place(
                name: config.name,
                placeType: placeTypesByName[config.typeName],
                modernLocation: config.modernLocation,
                placeDescription: config.description,
                source: config.source,
                latitude: config.lat,
                longitude: config.lon
            )
            context.insert(place)
        }

        let eventTypes = (try? context.fetch(FetchDescriptor<EventType>())) ?? []
        let eventTypesByName = Dictionary(uniqueKeysWithValues: eventTypes.map { ($0.name, $0) })

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figuresByName = Dictionary(grouping: allFigures, by: { $0.name }).compactMapValues(\.first)

        let eventConfigs: [(name: String, typeName: String, description: String, era: String, source: String, sortName: String?, figureNames: [String])] = [
            ("The Fall of the Watchers", "Descent",
             "Two hundred Watcher angels under the leadership of Samyaza descended on Mount Hermon, swore an oath to bind themselves together, and took human wives. They fathered the Nephilim, giants who consumed the labor of mankind. The Watchers also taught humanity forbidden knowledge: sorcery, weapon-making, cosmetics, astrology, and divination.",
             "Age of the Watchers", "Book of Enoch (1 Enoch), ch. 6-8", nil,
             ["Samyaza", "Azazel"]),
            ("The Binding of Azazel", "Battle",
             "God commanded Raphael to bind Azazel hand and foot, cast him into the darkness of Dudael, and cover him with rugged and sharp rocks. Azazel was to remain there until the great day of judgment, when he would be cast into the fire.",
             "Age of the Watchers", "Book of Enoch (1 Enoch), ch. 10:4-8", nil,
             ["Azazel", "Raphael"]),
            ("The Binding of the Watchers", "Battle",
             "God commanded Michael to bind Samyaza and his associates under the hills of the earth for seventy generations until the day of judgment. The Watchers were to be cast into the abyss of fire for eternity. Their sons, the Nephilim, were destroyed by being set against each other with the sword.",
             "Age of the Watchers", "Book of Enoch (1 Enoch), ch. 10:11-12", nil,
             ["Samyaza", "Michael"]),
            ("Enoch's Heavenly Journeys", "Ascension",
             "Enoch was taken by the angels and shown the mysteries of heaven and earth. He visited the heavenly temple and saw God's throne of glory, the dwelling places of the righteous, the places of punishment for the wicked, the tree of life, the seven mountains, and the storehouses of the winds and luminaries. The archangel Uriel revealed to him the movements of the sun, moon, and stars.",
             "Age of the Watchers", "Book of Enoch (1 Enoch), ch. 17-36", nil,
             ["Enoch", "Uriel"]),
            ("The Deluge Judgment", "Flood",
             "God decreed the destruction of all flesh by the Great Flood as judgment for the corruption brought by the Watchers and the Nephilim. Uriel was sent to warn Noah to build an ark. The Flood cleansed the earth, preserving only Noah and his family. The Watchers were already bound and awaiting final judgment.",
             "The Great Flood", "Book of Enoch (1 Enoch), ch. 10:1-3, 106-107", "Flood",
             ["Noah", "Uriel"]),
        ]
        for config in eventConfigs {
            let figures = config.figureNames.compactMap { figuresByName[$0] }
            let event = Event(
                name: config.name,
                eventType: eventTypesByName[config.typeName],
                eventDescription: config.description,
                date: MythologicalDate(year: nil, era: config.era, isApproximate: true),
                era: config.era,
                source: config.source,
                sortName: config.sortName,
                involvedFigures: figures
            )
            context.insert(event)
        }

        try? context.save()
    }
}
