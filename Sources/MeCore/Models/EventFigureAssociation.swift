import Foundation
import SwiftData

@Model
package final class EventFigureAssociation {
    package var event: Event?
    package var figure: Figure?
    package var roleType: EventFigureRoleType?
    /// Override the display name for this figure in this event's context (e.g. "Noah" for Ziusudra)
    package var displayName: String?

    package init(
        event: Event? = nil,
        figure: Figure? = nil,
        roleType: EventFigureRoleType? = nil,
        displayName: String? = nil
    ) {
        self.event = event
        self.figure = figure
        self.roleType = roleType
        self.displayName = displayName
    }
}
