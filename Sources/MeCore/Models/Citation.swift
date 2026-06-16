import Foundation
import SwiftData

@Model
package final class Citation {
    package var source: Source?
    package var location: String
    package var note: String
    package var entityType: EntityType?
    package var linkedEntityName: String

    package enum EntityType: String, Codable, CaseIterable, Hashable {
        case figure = "Figure"
        case event = "Event"
        case place = "Place"
        case relationship = "Relationship"
        case era = "Era"
    }

    package var safeLocation: String { location }
    package var safeNote: String { note }
    package var safeEntityName: String { linkedEntityName }
    package var safeEntityType: EntityType { entityType ?? .figure }

    package init(
        source: Source? = nil,
        location: String = "",
        note: String = "",
        entityType: EntityType = .figure,
        linkedEntityName: String = ""
    ) {
        self.source = source
        self.location = location
        self.note = note
        self.entityType = entityType
        self.linkedEntityName = linkedEntityName
    }
}
