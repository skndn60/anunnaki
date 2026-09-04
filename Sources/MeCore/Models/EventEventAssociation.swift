import Foundation
import SwiftData

/// A relationship between two events.
/// E.g. Death of Enkidu motivated Gilgamesh Seeks Immortality.
@Model
package final class EventEventAssociation {
    package var fromEvent: Event?
    package var toEvent: Event?
    package var roleType: EventEventRoleType?
    package var source: String
    package var sourceRef: Source?

    package init(
        fromEvent: Event? = nil,
        toEvent: Event? = nil,
        roleType: EventEventRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil
    ) {
        self.fromEvent = fromEvent
        self.toEvent = toEvent
        self.roleType = roleType
        self.source = source
        self.sourceRef = sourceRef
    }
}
