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
    /// Default source attribution for the whole table ("all values from X").
    /// Cells may override with their own source. Optional for migration safety.
    package var source: String?
    package var sourceRef: Source?

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

    /// Updates the table's free-text source and its Source-row link. Matching is
    /// case-insensitive by name against EXISTING sources only — junk strings
    /// stay inert text, nothing is ever created. Links are established via the
    /// annotated side (`Source.popupTables`) per the codebase convention.
    package func setSourceText(_ raw: String?, context: ModelContext) {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = sourceRef {
            existing.popupTables.removeAll { $0 == self }
        }
        sourceRef = nil
        source = trimmed.isEmpty ? nil : trimmed
        guard !trimmed.isEmpty else { return }

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        if let match = sources.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            match.popupTables.append(self)
            sourceRef = match
        }
    }
}
