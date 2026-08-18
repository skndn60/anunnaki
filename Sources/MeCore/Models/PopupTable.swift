import Foundation
import SwiftData

/// A comparison table for contrasting figures across custom attributes.
/// Example: comparing canal/water deities (Ennugi, Enbilulu, Enkimdu) across
/// "Primary Domain", "Administrative Title", "Key Mythological Role", etc.
@Model
package final class PopupTable: Identifiable {
    package var name: String
    package var tableDescription: String

    @Relationship(deleteRule: .cascade, inverse: \PopupTableAttribute.table)
    package var attributes: [PopupTableAttribute] = []

    @Relationship(deleteRule: .cascade, inverse: \PopupTableCell.table)
    package var cells: [PopupTableCell] = []

    @Relationship(deleteRule: .nullify, inverse: \Figure.popupTables)
    package var figures: [Figure] = []

    package init(name: String = "", tableDescription: String = "") {
        self.name = name
        self.tableDescription = tableDescription
    }
}
