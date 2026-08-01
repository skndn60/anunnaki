import Foundation
import SwiftData

/// A direct association between a figure and a place, with a specific role.
/// E.g. Nanna/Sin is the patron deity of Ur, Gilgamesh is the ruler of Uruk.
@Model
package final class FigurePlaceAssociation {
    package var figure: Figure?
    package var place: Place?
    package var roleType: FigurePlaceRoleType?
    package var source: String
    package var comments: String?
    /// Override the display name for this figure in this place's context (e.g. "Noah" for Ziusudra)
    package var displayName: String?

    package init(
        figure: Figure? = nil,
        place: Place? = nil,
        roleType: FigurePlaceRoleType? = nil,
        source: String = "",
        comments: String? = nil,
        displayName: String? = nil
    ) {
        self.figure = figure
        self.place = place
        self.roleType = roleType
        self.source = source
        self.comments = comments
        self.displayName = displayName
    }
}
