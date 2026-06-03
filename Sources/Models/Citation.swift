import Foundation
import SwiftData

/// A citation linking any entity (figure, event, place, relationship) to a specific
/// location within a source. This is the glue between data and evidence.
@Model
final class Citation {
    var source: Source?
    var location: String?
    var note: String?
    var entityType: EntityType?
    var entityName: String?

    enum EntityType: String, Codable, CaseIterable, Hashable {
        case figure = "Figure"
        case event = "Event"
        case place = "Place"
        case relationship = "Relationship"
        case era = "Era"
    }

    /// Safe accessors that never crash on nil
    var safeLocation: String { location ?? "" }
    var safeNote: String { note ?? "" }
    var safeEntityName: String { entityName ?? "" }
    var safeEntityType: EntityType { entityType ?? .figure }

    init(
        source: Source? = nil,
        location: String = "",
        note: String = "",
        entityType: EntityType = .figure,
        entityName: String = ""
    ) {
        self.source = source
        self.location = location
        self.note = note
        self.entityType = entityType
        self.entityName = entityName
    }
}
