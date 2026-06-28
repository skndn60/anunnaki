import Foundation
import SwiftData

@Model
package final class ThingPlaceAssociation {
    package var thing: Thing?
    package var place: Place?
    package var roleType: ThingPlaceRoleType?
    package var source: String

    package init(
        thing: Thing? = nil,
        place: Place? = nil,
        roleType: ThingPlaceRoleType? = nil,
        source: String = ""
    ) {
        self.thing = thing
        self.place = place
        self.roleType = roleType
        self.source = source
    }
}
