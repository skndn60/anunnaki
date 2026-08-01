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

    package init(
        figure: Figure? = nil,
        place: Place? = nil,
        event: Event? = nil,
        thing: Thing? = nil,
        group: FigureGroup? = nil,
        note: String = "",
        displayName: String? = nil
    ) {
        self.figure = figure
        self.place = place
        self.event = event
        self.thing = thing
        self.group = group
        self.note = note
        self.displayName = displayName
    }
}
