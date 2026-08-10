import Foundation
import SwiftData

@Model
package final class FigurePantheonAssociation {
    package var figure: Figure?
    package var pantheon: Pantheon?
    /// Override the display name for this figure in this pantheon's context (e.g. "Ptah" for Enki, "Poseidon" for Ea)
    package var displayName: String?

    package init(
        figure: Figure? = nil,
        pantheon: Pantheon? = nil,
        displayName: String? = nil
    ) {
        self.figure = figure
        self.pantheon = pantheon
        self.displayName = displayName
    }
}