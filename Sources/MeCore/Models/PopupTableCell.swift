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
    /// Rich-text (RTF) form of the value, rendered with the app's
    /// `RichTextEditor`. Optional for migration safety; nil = plain `value`.
    package var richValue: Data?
    /// A free-text comment/note on this cell's value ("cross-checked against
    /// Tablet IV", "disputed reading", …). Optional for migration safety.
    package var comment: String?
    /// Rich-text (RTF) form of the comment, rendered with the app's
    /// `RichTextEditor`. Optional for migration safety; nil = plain `comment`.
    package var richComment: Data?
    /// Free-text source attribution for this cell's value ("Enuma Elish", "SKL", …).
    /// Optional for migration safety. Linked to `sourceRef` when a matching
    /// Source row exists (case-insensitive); never auto-creates one.
    package var source: String?
    package var sourceRef: Source?

    /// Multiple per-cell source attributions. Set links via this annotated side
    /// per the codebase convention. Backed by `CellSource` rows.
    @Relationship(deleteRule: .cascade, inverse: \CellSource.cell)
    package var cellSources: [CellSource] = []

    package init(
        table: PopupTable? = nil,
        attribute: PopupTableAttribute? = nil,
        figure: Figure? = nil,
        column: PopupTableColumn? = nil,
        value: String? = nil,
        richValue: Data? = nil,
        comment: String? = nil,
        richComment: Data? = nil,
        source: String? = nil
    ) {
        self.table = table
        self.attribute = attribute
        self.figure = figure
        self.column = column
        self.value = value
        self.richValue = richValue
        self.comment = comment
        self.richComment = richComment
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

    /// The per-cell source attributions (`name` + optional `location`), falling
    /// back to the legacy single `source` string when none are recorded yet.
    package var effectiveCellSourceNames: [(name: String, location: String?)] {
        if !cellSources.isEmpty {
            return cellSources.map { (name: $0.source, location: $0.location) }
        }
        let legacy = (source ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return legacy.isEmpty ? [] : [(name: legacy, location: nil)]
    }

    /// Adds a single source attribution from a free-text work name and an
    /// optional location within it, optionally linking a matching `Source` row
    /// (case-insensitive, never auto-created). Returns the created `CellSource`,
    /// or nil when the name is blank. The `CellSource` is inserted into the
    /// supplied context so SwiftData can resolve the relationship.
    @discardableResult
    package func addCellSource(named name: String, location: String? = nil, context: ModelContext) -> CellSource? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cellSource = CellSource(source: trimmed, location: location)
        context.insert(cellSource)
        cellSources.append(cellSource)

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        if let match = Source.bestMatch(forCandidate: trimmed, among: sources) {
            match.cellListSources.append(cellSource)
            cellSource.sourceRef = match
        }
        return cellSource
    }

    /// Removes a per-cell source attribution and cleans up its link.
    /// Per the codebase convention, links are set/detached via the annotated
    /// side (`cellSources`).
    package func removeCellSource(_ cellSource: CellSource) {
        if let src = cellSource.sourceRef {
            src.cellListSources.removeAll { $0 == cellSource }
        }
        cellSources.removeAll { $0 == cellSource }
    }
}
