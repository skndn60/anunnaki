import Foundation
import SwiftData

@Model
package final class EventPlaceAssociation {
    package var event: Event?
    package var place: Place?
    package var role: Role
    package var source: String

    package enum Role: String, Codable, CaseIterable, Hashable {
        case occurredAt = "Occurred At"
        case startedAt = "Started At"
        case endedAt = "Ended At"
        case passedThrough = "Passed Through"
    }

    package init(
        event: Event? = nil,
        place: Place? = nil,
        role: Role = .occurredAt,
        source: String = ""
    ) {
        self.event = event
        self.place = place
        self.role = role
        self.source = source
    }
}
