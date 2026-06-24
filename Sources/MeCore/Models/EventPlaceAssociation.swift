import Foundation
import SwiftData

@Model
package final class EventPlaceAssociation {
    package var event: Event?
    package var place: Place?
    package var roleType: EventPlaceRoleType?
    package var source: String

    package init(
        event: Event? = nil,
        place: Place? = nil,
        roleType: EventPlaceRoleType? = nil,
        source: String = ""
    ) {
        self.event = event
        self.place = place
        self.roleType = roleType
        self.source = source
    }
}
