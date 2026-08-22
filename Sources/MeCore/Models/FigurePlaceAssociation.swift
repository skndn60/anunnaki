import Foundation
import SwiftData

/// A direct association between a figure and a place, with a specific role.
/// E.g. Nanna/Sin is the patron deity of Ur, Gilgamesh is the ruler of Uruk.
@Model
package final class FigurePlaceAssociation {
    package enum Confidence: String, Codable, CaseIterable, Hashable {
        case possible
        case disputed

        package var label: String {
            switch self {
            case .possible: return "possible"
            case .disputed: return "disputed"
            }
        }
    }

    package var figure: Figure?
    package var place: Place?
    package var roleType: FigurePlaceRoleType?
    package var source: String
    package var comments: String?
    /// Override the display name for this figure in this place's context (e.g. "Noah" for Ziusudra)
    package var displayName: String?
    /// Epistemic qualifier: sources hedge the claim ("possibly had a temple there").
    /// nil = plainly asserted, no qualifier shown.
    package var confidence: Confidence?

    package init(
        figure: Figure? = nil,
        place: Place? = nil,
        roleType: FigurePlaceRoleType? = nil,
        source: String = "",
        comments: String? = nil,
        displayName: String? = nil,
        confidence: Confidence? = nil
    ) {
        self.figure = figure
        self.place = place
        self.roleType = roleType
        self.source = source
        self.comments = comments
        self.displayName = displayName
        self.confidence = confidence
    }
}
