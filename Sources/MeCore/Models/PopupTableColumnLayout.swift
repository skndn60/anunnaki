import Foundation
import SwiftData

/// Per-table layout settings for a comparison-table column. Exactly one of
/// `figure` (figures mode) or `column` (strings mode) is set per row. All
/// properties optional for migration safety; nil width means the table default.
@Model
package final class PopupTableColumnLayout: Identifiable {
    package var table: PopupTable?
    package var figure: Figure?
    package var column: PopupTableColumn?
    package var width: Double?

    package init(
        table: PopupTable? = nil,
        figure: Figure? = nil,
        column: PopupTableColumn? = nil,
        width: Double? = nil
    ) {
        self.table = table
        self.figure = figure
        self.column = column
        self.width = width
    }
}