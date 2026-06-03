import Foundation
import SwiftData

// MARK: - Codable Seed Structs

private struct SeedDate: Codable {
    let year: Int?
    let era: String
    let isApproximate: Bool

    func toMythologicalDate() -> MythologicalDate {
        MythologicalDate(year: year, era: era, isApproximate: isApproximate)
    }
}

private struct SeedFigure: Codable {
    let name: String
    let title: String
    let figureType: String
    let gender: String
    let domain: String
    let figureDescription: String
    let birthDate: SeedDate
    let deathDate: SeedDate
    let source: String
}

private struct SeedRelationship: Codable {
    let fromFigureName: String
    let toFigureName: String
    let relationshipType: String
    let source: String
}

private struct SeedEra: Codable {
    let name: String
    let orderIndex: Int
    let eraDescription: String
    let startDate: SeedDate
    let endDate: SeedDate
}

private struct SeedPlace: Codable {
    let name: String
    let placeType: String
    let modernLocation: String
    let placeDescription: String
    let source: String
    let latitude: Double?
    let longitude: Double?
}

private struct SeedEvent: Codable {
    let name: String
    let eventType: String
    let eventDescription: String
    let date: SeedDate
    let era: String
    let source: String
    let involvedFigureNames: [String]
    let placeName: String?
}

private struct SeedSource: Codable {
    let name: String
    let sourceType: String
    let author: String
    let language: String
    let period: String
    let sourceDescription: String
    let publicationInfo: String
    let url: String
}

private struct SeedCitation: Codable {
    let sourceName: String
    let location: String
    let entityType: String
    let entityName: String
    let note: String
}

private struct SeedAlternateName: Codable {
    let figureName: String
    let name: String
    let tradition: String
    let nameType: String
    let note: String
}

private struct SeedAttachment: Codable {
    let sourceName: String
    let title: String
    let url: String
    let attachmentType: String
    let note: String?
}

private struct SeedFigurePlaceAssociation: Codable {
    let figureName: String
    let placeName: String
    let role: String
    let source: String
}

private struct SeedPlacePlaceAssociation: Codable {
    let fromPlaceName: String
    let toPlaceName: String
    let role: String
    let source: String
}

private struct SeedEventEventAssociation: Codable {
    let fromEventName: String
    let toEventName: String
    let role: String
    let source: String
}

private struct SeedDataRoot: Codable {
    let eras: [SeedEra]
    let figures: [SeedFigure]
    let relationships: [SeedRelationship]
    let places: [SeedPlace]
    let events: [SeedEvent]
    let sources: [SeedSource]
    let attachments: [SeedAttachment]
    let citations: [SeedCitation]
    let alternateNames: [SeedAlternateName]
    let figurePlaceAssociations: [SeedFigurePlaceAssociation]?
    let placePlaceAssociations: [SeedPlacePlaceAssociation]?
    let eventEventAssociations: [SeedEventEventAssociation]?
}

// MARK: - Seed Data Loader

/// Seeds the database with canonical Mesopotamian figures, relationships, and eras
/// on first launch (when the database is empty).
struct SeedData {
    static func seedIfEmpty(context: ModelContext) {
        // Check if already seeded
        let figureCount = (try? context.fetchCount(FetchDescriptor<Figure>())) ?? 0
        guard figureCount == 0 else { return }

        // Load JSON from bundle
        guard let url = Bundle.main.url(forResource: "seed_data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            assertionFailure("Failed to load seed_data.json from bundle")
            return
        }

        // MARK: - Eras
        for seedEra in seed.eras {
            let era = Era(
                name: seedEra.name,
                orderIndex: seedEra.orderIndex,
                eraDescription: seedEra.eraDescription,
                startDate: seedEra.startDate.toMythologicalDate(),
                endDate: seedEra.endDate.toMythologicalDate()
            )
            context.insert(era)
        }

        // MARK: - Figures
        var figuresByName: [String: Figure] = [:]
        for seedFigure in seed.figures {
            let figure = Figure(
                name: seedFigure.name,
                title: seedFigure.title,
                figureType: Figure.FigureType(rawValue: seedFigure.figureType) ?? .deity,
                gender: Figure.Gender(rawValue: seedFigure.gender) ?? .unknown,
                domain: seedFigure.domain,
                figureDescription: seedFigure.figureDescription,
                birthDate: seedFigure.birthDate.toMythologicalDate(),
                deathDate: seedFigure.deathDate.toMythologicalDate(),
                source: seedFigure.source
            )
            context.insert(figure)
            figuresByName[seedFigure.name] = figure
        }

        // MARK: - Relationships
        for seedRel in seed.relationships {
            guard let from = figuresByName[seedRel.fromFigureName],
                  let to = figuresByName[seedRel.toFigureName] else { continue }
            let rel = Relationship(
                fromFigure: from,
                toFigure: to,
                relationshipType: Relationship.RelationshipType(rawValue: seedRel.relationshipType) ?? .father,
                source: seedRel.source
            )
            context.insert(rel)
        }

        // MARK: - Places
        var placesByName: [String: Place] = [:]
        for seedPlace in seed.places {
            let place = Place(
                name: seedPlace.name,
                placeType: Place.PlaceType(rawValue: seedPlace.placeType) ?? .city,
                modernLocation: seedPlace.modernLocation,
                placeDescription: seedPlace.placeDescription,
                source: seedPlace.source,
                latitude: seedPlace.latitude,
                longitude: seedPlace.longitude
            )
            context.insert(place)
            placesByName[seedPlace.name] = place
        }

        // MARK: - Events
        var eventsByName: [String: Event] = [:]
        for seedEvent in seed.events {
            let figures = seedEvent.involvedFigureNames.compactMap { figuresByName[$0] }
            let place = seedEvent.placeName.flatMap { placesByName[$0] }
            let event = Event(
                name: seedEvent.name,
                eventType: Event.EventType(rawValue: seedEvent.eventType) ?? .other,
                eventDescription: seedEvent.eventDescription,
                date: seedEvent.date.toMythologicalDate(),
                era: seedEvent.era,
                source: seedEvent.source,
                involvedFigures: figures,
                place: place
            )
            context.insert(event)
            eventsByName[seedEvent.name] = event
        }

        // MARK: - Sources
        var sourcesByName: [String: Source] = [:]
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
            sourcesByName[seedSource.name] = source
        }

        // MARK: - Attachments
        for seedAttachment in seed.attachments {
            guard let source = sourcesByName[seedAttachment.sourceName] else { continue }
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
            guard let source = sourcesByName[seedCitation.sourceName] else { continue }
            let citation = Citation(
                source: source,
                location: seedCitation.location,
                note: seedCitation.note,
                entityType: Citation.EntityType(rawValue: seedCitation.entityType) ?? .figure,
                entityName: seedCitation.entityName
            )
            context.insert(citation)
        }

        // MARK: - Alternate Names
        for seedAltName in seed.alternateNames {
            guard let figure = figuresByName[seedAltName.figureName] else { continue }
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
                guard let figure = figuresByName[seedAssoc.figureName],
                      let place = placesByName[seedAssoc.placeName] else { continue }
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
                guard let from = placesByName[seedAssoc.fromPlaceName],
                      let to = placesByName[seedAssoc.toPlaceName] else { continue }
                let assoc = PlacePlaceAssociation(
                    fromPlace: from,
                    toPlace: to,
                    role: PlacePlaceAssociation.Role(rawValue: seedAssoc.role) ?? .locatedWithin,
                    source: seedAssoc.source
                )
                context.insert(assoc)
            }
        }

        // MARK: - Event-Event Associations
        if let eventAssocs = seed.eventEventAssociations {
            for seedAssoc in eventAssocs {
                guard let from = eventsByName[seedAssoc.fromEventName],
                      let to = eventsByName[seedAssoc.toEventName] else { continue }
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
}
