import Foundation
import SwiftData

/// A named row dimension in a PopupTable (e.g. "Primary Domain", "Key Mythological Role").
@Model
package final class PopupTableAttribute: Identifiable {
    package var table: PopupTable?
    package var name: String
    /// Explicit position within the table. Nil = no explicit position. Optional for migration safety.
    package var orderIndex: Int?

    @Relationship(deleteRule: .cascade, inverse: \PopupTableCell.attribute)
    package var cells: [PopupTableCell] = []

    package init(table: PopupTable? = nil, name: String = "", orderIndex: Int? = nil) {
        self.table = table
        self.name = name
        self.orderIndex = orderIndex
    }
}
