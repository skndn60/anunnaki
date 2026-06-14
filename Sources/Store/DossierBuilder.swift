import Foundation
import SwiftData

// MARK: - Dossier Types

struct FigureDossier {
    let figure: Figure
    let parents: [Figure]
    let children: [Figure]
    let spouses: [Figure]
    let createdBy: [Figure]
    let created: [Figure]
    let events: [Event]
    let places: [Place]
    let placeAssociations: [FigurePlaceAssociation]
    let citations: [Citation]
    let matchedAliasName: String?
}

struct PlaceDossier {
    let place: Place
    let events: [Event]
    let figures: [Figure]
}

struct EventDossier {
    let event: Event
    let figures: [Figure]
    let place: Place?
}

// MARK: - Dossier Builders

extension ModelContext {
    func buildFigureDossier(_ figure: Figure, matchedAlias: String? = nil) -> FigureDossier {
        let relationships: [Relationship] = fetchAll()
        let events: [Event] = fetchAll()
        let citations: [Citation] = fetchAll()

        let parents = relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }

        let children = relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }

        let spouses = relationships
            .filter { $0.relationshipType == .spouse && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }

        let createdBy = relationships
            .filter { $0.relationshipType == .creator && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }

        let created = relationships
            .filter { $0.relationshipType == .creator && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }

        let figureEvents = events.filter { $0.involvedFigures.contains(where: { $0.persistentModelID == figure.persistentModelID }) }

        let figurePlaces = Array(Set(figureEvents.compactMap { $0.place }))

        let figureCitations = citations.filter { $0.safeEntityName == figure.name && $0.safeEntityType == .figure }

        return FigureDossier(
            figure: figure, parents: parents, children: children,
            spouses: spouses, createdBy: createdBy, created: created,
            events: figureEvents, places: figurePlaces,
            placeAssociations: figure.placeAssociations,
            citations: figureCitations,
            matchedAliasName: matchedAlias
        )
    }

    func buildPlaceDossier(_ place: Place) -> PlaceDossier {
        let events: [Event] = fetchAll()
        let placeEvents = events.filter { $0.place?.persistentModelID == place.persistentModelID }
        let figures = Array(Set(placeEvents.flatMap { $0.involvedFigures }))
        return PlaceDossier(place: place, events: placeEvents, figures: figures)
    }

    func buildEventDossier(_ event: Event) -> EventDossier {
        return EventDossier(event: event, figures: event.involvedFigures, place: event.place)
    }
}
