import Foundation
import SwiftData

@Model
final class Citation {
    var source: Source?
    var location: String
    var note: String
    var entityType: EntityType?
    var linkedEntityName: String

    enum EntityType: String, Codable, CaseIterable, Hashable {
        case figure = "Figure"
        case event = "Event"
        case place = "Place"
        case relationship = "Relationship"
        case era = "Era"
    }

    var safeLocation: String { location }
    var safeNote: String { note }
    var safeEntityName: String { linkedEntityName }
    var safeEntityType: EntityType { entityType ?? .figure }

    init(
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
