import Foundation
import SwiftData

/// Represents a mythological or historical event.
@Model
final class Event {
    var name: String
    var eventType: EventType
    var eventDescription: String
    var date: MythologicalDate
    var era: String
    var source: String

    /// Figures involved in this event
    @Relationship
    var involvedFigures: [Figure] = []

    /// Place where the event occurred
    @Relationship
    var place: Place?

    enum EventType: String, Codable, CaseIterable, Hashable {
        case creation = "Creation"
        case battle = "Battle"
        case flood = "Flood"
        case descent = "Descent"
        case quest = "Quest"
        case founding = "City Founding"
        case death = "Death"
        case ascension = "Ascension"
        case decree = "Divine Decree"
        case other = "Other"
    }

    init(
        name: String = "",
        eventType: EventType = .other,
        eventDescription: String = "",
        date: MythologicalDate = .unknown,
        era: String = "",
        source: String = "",
        involvedFigures: [Figure] = [],
        place: Place? = nil
    ) {
        self.name = name
        self.eventType = eventType
        self.eventDescription = eventDescription
        self.date = date
        self.era = era
        self.source = source
        self.involvedFigures = involvedFigures
        self.place = place
    }
}
