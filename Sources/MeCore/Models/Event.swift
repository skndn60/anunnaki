import Foundation
import SwiftData

/// Represents a mythological or historical event.
@Model
package final class Event {
    package var name: String
    package var eventType: EventType?
    package var eventDescription: String
    package var richDescription: Data?
    package var date: MythologicalDate
    package var era: String
    package var source: String
    package var isConcept: Bool
    /// Override for alphabetical sorting (e.g. "The Great Flood" → "Flood")
    package var sortName: String?

    /// Figures involved in this event
    @Relationship
    package var involvedFigures: [Figure] = []

    /// Figure associations with optional display name override
    @Relationship(deleteRule: .cascade, inverse: \EventFigureAssociation.event)
    package var figureAssociations: [EventFigureAssociation]? = nil

    /// Places where the event occurred
    @Relationship(deleteRule: .cascade, inverse: \EventPlaceAssociation.event)
    package var placeAssociations: [EventPlaceAssociation] = []

    /// Tags attached to this event
    @Relationship(deleteRule: .nullify, inverse: \Tag.events)
    package var tags: [Tag] = []

    /// Things associated with this event
    @Relationship(deleteRule: .cascade, inverse: \ThingEventAssociation.event)
    package var thingAssociations: [ThingEventAssociation] = []

    /// Images attached to this event
    @Relationship(deleteRule: .nullify, inverse: \ImageAsset.events)
    package var images: [ImageAsset] = []

    /// Sticky notes attached to this event
    @Relationship(deleteRule: .cascade, inverse: \StickyNote.event)
    package var stickies: [StickyNote] = []

    @Relationship(inverse: \ContentAttribution.event)
    package var contentAttributions: [ContentAttribution]? = nil

    package init(
        name: String = "",
        eventType: EventType? = nil,
        eventDescription: String = "",
        date: MythologicalDate = .unknown,
        era: String = "",
        source: String = "",
        isConcept: Bool = false,
        sortName: String? = nil,
        involvedFigures: [Figure] = [],
        placeAssociations: [EventPlaceAssociation] = []
    ) {
        self.name = name
        self.eventType = eventType
        self.eventDescription = eventDescription
        self.date = date
        self.era = era
        self.source = source
        self.isConcept = isConcept
        self.sortName = sortName
        self.involvedFigures = involvedFigures
        self.placeAssociations = placeAssociations
    }
}
