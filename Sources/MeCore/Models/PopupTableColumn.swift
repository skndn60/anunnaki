import Foundation
import SwiftData

/// A named column dimension in a PopupTable when the table's column mode is
/// `.strings` — a flat text label (e.g. "Sacrifice", "Prayer") instead of a Figure.
@Model
package final class PopupTableColumn: Identifiable {
    package var table: PopupTable?
    package var name: String
    /// Explicit position within the table. Nil = no explicit position. Optional for migration safety.
    package var orderIndex: Int?

    @Relationship(deleteRule: .cascade, inverse: \PopupTableCell.column)
    package var cells: [PopupTableCell] = []

    package init(table: PopupTable? = nil, name: String = "", orderIndex: Int? = nil) {
        self.table = table
        self.name = name
        self.orderIndex = orderIndex
    }
}
