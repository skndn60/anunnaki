import Foundation
import SwiftUI
import SwiftData

/// A pantheon: a cultural/religious family of gods (Mesopotamian, Greek, Hebrew, ...).
/// A figure can belong to many pantheons (many-to-many via `Figure.pantheons`).
@Model
package final class Pantheon {
    package var name: String
    package var pantheonDescription: String
    package var icon: String
    package var colorHex: String

    @Relationship
    package var figures: [Figure] = []

    /// Per-figure display-name overrides (e.g. Enki appearing as "Ptah" in this pantheon).
    @Relationship(deleteRule: .cascade, inverse: \FigurePantheonAssociation.pantheon)
    package var figureAssociations: [FigurePantheonAssociation]? = nil

    package var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    package init(name: String, pantheonDescription: String = "", icon: String = "building.columns.circle.fill", colorHex: String = "8E8E93") {
        self.name = name
        self.pantheonDescription = pantheonDescription
        self.icon = icon
        self.colorHex = colorHex
    }
}