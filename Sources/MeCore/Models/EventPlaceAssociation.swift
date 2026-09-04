import Foundation
import SwiftData

@Model
package final class EventPlaceAssociation {
    package var event: Event?
    package var place: Place?
    package var roleType: EventPlaceRoleType?
    package var source: String
    package var sourceRef: Source?

    package init(
        event: Event? = nil,
        place: Place? = nil,
        roleType: EventPlaceRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil
    ) {
        self.event = event
        self.place = place
        self.roleType = roleType
        self.source = source
        self.sourceRef = sourceRef
    }
}
