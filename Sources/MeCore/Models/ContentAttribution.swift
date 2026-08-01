import Foundation
import SwiftData

@Model
package final class ContentAttribution {
    package var figure: Figure?
    package var place: Place?
    package var event: Event?
    package var thing: Thing?
    package var source: Source?
    package var propertyName: String?
    package var url: String?
    package var contentPreview: String
    package var note: String
    /// Override the display name for the linked entity (e.g. "Noah" for Ziusudra)
    package var figureDisplayName: String?

    package init(
        figure: Figure? = nil,
        place: Place? = nil,
        event: Event? = nil,
        thing: Thing? = nil,
        source: Source? = nil,
        propertyName: String? = nil,
        url: String? = nil,
        contentPreview: String = "",
        note: String = "",
        figureDisplayName: String? = nil
    ) {
        self.figure = figure
        self.place = place
        self.event = event
        self.thing = thing
        self.source = source
        self.propertyName = propertyName
        self.url = url
        self.contentPreview = contentPreview
        self.note = note
        self.figureDisplayName = figureDisplayName
    }
}
