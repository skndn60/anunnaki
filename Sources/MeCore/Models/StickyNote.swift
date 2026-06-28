import Foundation
import SwiftData

@Model
package final class StickyNote {
    package var text: String
    package var createdAt: Date
    package var isResolved: Bool

    package var figure: Figure?

    package var place: Place?

    package var event: Event?

    package var thing: Thing?

    package init(text: String = "", createdAt: Date = .now, isResolved: Bool = false, figure: Figure? = nil, place: Place? = nil, event: Event? = nil, thing: Thing? = nil) {
        self.text = text
        self.createdAt = createdAt
        self.isResolved = isResolved
        self.figure = figure
        self.place = place
        self.event = event
        self.thing = thing
    }
}
