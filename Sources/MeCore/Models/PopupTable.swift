import Foundation
import SwiftData

/// How a PopupTable's columns are provided: real `Figure` entities, or flat
/// text labels (e.g. worship activities like "Sacrifice"/"Prayer").
package enum PopupTableColumnMode: String {
    case figures
    case strings

    package var displayName: String {
        switch self {
        case .figures: return "Figures"
        case .strings: return "Text labels"
        }
    }
}

/// A comparison table for contrasting figures across custom attributes.
/// Example: comparing canal/water deities (Ennugi, Enbilulu, Enkimdu) across
/// "Primary Domain", "Administrative Title", "Key Mythological Role", etc.
@Model
package final class PopupTable: Identifiable {
    package var name: String
    package var tableDescription: String
    /// "figures" or "strings"; nil = figures (backward compat). Optional for migration safety.
    package var columnModeRawValue: String?

    @Relationship(deleteRule: .cascade, inverse: \PopupTableAttribute.table)
    package var attributes: [PopupTableAttribute] = []

    @Relationship(deleteRule: .cascade, inverse: \PopupTableCell.table)
    package var cells: [PopupTableCell] = []

    @Relationship(deleteRule: .nullify, inverse: \Figure.popupTables)
    package var figures: [Figure] = []

    @Relationship(deleteRule: .cascade, inverse: \PopupTableColumn.table)
    package var columns: [PopupTableColumn] = []

    package var columnMode: PopupTableColumnMode {
        get { PopupTableColumnMode(rawValue: columnModeRawValue ?? "") ?? .figures }
        set { columnModeRawValue = newValue.rawValue }
    }

    package init(name: String = "", tableDescription: String = "") {
        self.name = name
        self.tableDescription = tableDescription
    }
}
