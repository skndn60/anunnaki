import Foundation
import SwiftData

/// A single cell in a PopupTable — the intersection of an attribute (row) and a figure (column).
@Model
package final class PopupTableCell: Identifiable {
    package var table: PopupTable?
    package var attribute: PopupTableAttribute?
    package var figure: Figure?
    /// The cell's text value. Optional for migration safety.
    package var value: String?

    package init(
        table: PopupTable? = nil,
        attribute: PopupTableAttribute? = nil,
        figure: Figure? = nil,
        value: String? = nil
    ) {
        self.table = table
        self.attribute = attribute
        self.figure = figure
        self.value = value
    }
}
