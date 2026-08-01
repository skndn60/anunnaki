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

    package init(
        figure: Figure? = nil,
        place: Place? = nil,
        event: Event? = nil,
        thing: Thing? = nil,
        group: FigureGroup? = nil,
        note: String = ""
    ) {
        self.figure = figure
        self.place = place
        self.event = event
        self.thing = thing
        self.group = group
        self.note = note
    }
}
