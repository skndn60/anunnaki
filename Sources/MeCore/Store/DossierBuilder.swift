import Foundation
import SwiftData

// MARK: - Dossier Types

package struct FigureDossier {
    package let figure: Figure
    package let parents: [Figure]
    package let children: [Figure]
    package let spouses: [Figure]
    package let createdBy: [Figure]
    package let created: [Figure]
    package let events: [Event]
    package let places: [Place]
    package let placeAssociations: [FigurePlaceAssociation]
    package let citations: [Citation]
    package let matchedAliasName: String?
}

package struct PlaceDossier {
    package let place: Place
    package let events: [Event]
    package let figures: [Figure]
}

package struct EventDossier {
    package let event: Event
    package let figures: [Figure]
    package let places: [Place]
}

// MARK: - Dossier Builders

extension ModelContext {
    package func buildFigureDossier(_ figure: Figure, matchedAlias: String? = nil) -> FigureDossier {
        let relationships: [Relationship] = fetchAll()
        let events: [Event] = fetchAll()
        let citations: [Citation] = fetchAll()

        let parents = relationships
            .filter { $0.relationshipType?.category == "parent" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }

        let children = relationships
            .filter { $0.relationshipType?.category == "parent" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }

        let spouses = relationships
            .filter { $0.relationshipType?.category == "partner" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }

        let createdBy = relationships
            .filter { $0.relationshipType?.category == "creator" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }

        let created = relationships
            .filter { $0.relationshipType?.category == "creator" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }

        let figureEvents = events.filter { $0.involvedFigures.contains(where: { $0.persistentModelID == figure.persistentModelID }) }

        let figurePlaces = Array(Set(figureEvents.flatMap { $0.placeAssociations.compactMap { $0.place } }))

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

    package func buildPlaceDossier(_ place: Place) -> PlaceDossier {
        let placeEvents = place.eventAssociations.compactMap { $0.event }
        let figures = Array(Set(placeEvents.flatMap { $0.involvedFigures }))
        return PlaceDossier(place: place, events: placeEvents, figures: figures)
    }

    package func buildEventDossier(_ event: Event) -> EventDossier {
        let places = event.placeAssociations.compactMap { $0.place }
        return EventDossier(event: event, figures: event.involvedFigures, places: places)
    }
}
