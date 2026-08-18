import Foundation
import SwiftData

@Model
package final class FigureGroupAssociation {
    package var figure: Figure?
    package var place: Place?
    package var event: Event?
    package var thing: Thing?
    package var group: FigureGroup?
    package var note: String
    /// Override the display name for this member in this group's context (e.g. "Noah" for Ziusudra)
    package var displayName: String?
    /// Explicit position of this member within its group when the group uses manual ordering.
    /// Nil means "no explicit position" (falls back to alphabetical). Optional for migration safety.
    package var orderIndex: Int?
    /// Name of the event that caused this association to be auto-created (event propagation).
    /// Nil means the member was added manually. Optional for migration safety.
    package var propagatedFromEventName: String?

    package init(
        figure: Figure? = nil,
        place: Place? = nil,
        event: Event? = nil,
        thing: Thing? = nil,
        group: FigureGroup? = nil,
        note: String = "",
        displayName: String? = nil,
        orderIndex: Int? = nil,
        propagatedFromEventName: String? = nil
    ) {
        self.figure = figure
        self.place = place
        self.event = event
        self.thing = thing
        self.group = group
        self.note = note
        self.displayName = displayName
        self.orderIndex = orderIndex
        self.propagatedFromEventName = propagatedFromEventName
    }
}
