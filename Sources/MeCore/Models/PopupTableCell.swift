import Foundation
import SwiftData

/// A single cell in a PopupTable — the intersection of an attribute (row) and a
/// figure or string column. Exactly one of `figure`/`column` is set per table mode.
@Model
package final class PopupTableCell: Identifiable {
    package var table: PopupTable?
    package var attribute: PopupTableAttribute?
    package var figure: Figure?
    package var column: PopupTableColumn?
    /// The cell's text value. Optional for migration safety.
    package var value: String?
    /// Free-text source attribution for this cell's value ("Enuma Elish", "SKL", …).
    /// Optional for migration safety. Linked to `sourceRef` when a matching
    /// Source row exists (case-insensitive); never auto-creates one.
    package var source: String?
    package var sourceRef: Source?

    package init(
        table: PopupTable? = nil,
        attribute: PopupTableAttribute? = nil,
        figure: Figure? = nil,
        column: PopupTableColumn? = nil,
        value: String? = nil,
        source: String? = nil
    ) {
        self.table = table
        self.attribute = attribute
        self.figure = figure
        self.column = column
        self.value = value
        self.source = source
    }

    /// Updates the cell's free-text source and its Source-row link. Matching is
    /// case-insensitive by name against EXISTING sources only — junk strings
    /// stay inert text, nothing is ever created. Links are established via the
    /// annotated side (`Source.popupTableCells`) per the codebase convention.
    package func setSourceText(_ raw: String?, context: ModelContext) {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = sourceRef {
            existing.popupTableCells.removeAll { $0 == self }
        }
        sourceRef = nil
        source = trimmed.isEmpty ? nil : trimmed
        guard !trimmed.isEmpty else { return }

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        if let match = sources.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            match.popupTableCells.append(self)
            sourceRef = match
        }
    }
}
