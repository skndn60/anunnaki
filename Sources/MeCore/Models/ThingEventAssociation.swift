import Foundation
import SwiftData

@Model
package final class ThingEventAssociation {
    package var thing: Thing?
    package var event: Event?
    package var roleType: ThingEventRoleType?
    package var source: String
    package var sourceRef: Source?

    package init(
        thing: Thing? = nil,
        event: Event? = nil,
        roleType: ThingEventRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil
    ) {
        self.thing = thing
        self.event = event
        self.roleType = roleType
        self.source = source
        self.sourceRef = sourceRef
    }
}
