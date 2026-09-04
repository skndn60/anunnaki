import Foundation
import SwiftData

@Model
package final class ThingFigureAssociation {
    package var thing: Thing?
    package var figure: Figure?
    package var roleType: ThingFigureRoleType?
    package var source: String
    package var sourceRef: Source?
    /// Override the display name for this figure in this thing's context (e.g. "Noah" for Ziusudra)
    package var displayName: String?

    package init(
        thing: Thing? = nil,
        figure: Figure? = nil,
        roleType: ThingFigureRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil,
        displayName: String? = nil
    ) {
        self.thing = thing
        self.figure = figure
        self.roleType = roleType
        self.source = source
        self.sourceRef = sourceRef
        self.displayName = displayName
    }
}
