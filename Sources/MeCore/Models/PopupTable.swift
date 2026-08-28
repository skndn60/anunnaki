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
    /// Uniform grid scale (applies to every column width and row height).
    /// Nil = 1.0. Optional for migration safety.
    package var gridScaleRaw: Double?
    /// Extra vertical scale over `gridScale` — independent row-height factor.
    /// Nil = 1.0. Optional for migration safety.
    package var rowScaleRaw: Double?
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

    @Relationship(deleteRule: .cascade, inverse: \PopupTableColumnLayout.table)
    package var columnLayouts: [PopupTableColumnLayout] = []

    package var columnMode: PopupTableColumnMode {
        get { PopupTableColumnMode(rawValue: columnModeRawValue ?? "") ?? .figures }
        set { columnModeRawValue = newValue.rawValue }
    }

    /// Column/width scale (columns + row-header column width). 1.0 default;
    /// nil stored when exactly 1.0.
    package var columnScale: CGFloat {
        get { CGFloat(gridScaleRaw ?? 1.0) }
        set { gridScaleRaw = newValue == 1.0 ? nil : Double(newValue) }
    }

    /// Row/height scale (every row height). 1.0 default; nil stored when exactly 1.0.
    package var rowScale: CGFloat {
        get { CGFloat(rowScaleRaw ?? 1.0) }
        set { rowScaleRaw = newValue == 1.0 ? nil : Double(newValue) }
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

    // MARK: - Column layout (widths)

    /// Persisted width for a figures-mode column, or nil for the table default.
    package func columnLayoutWidth(forFigure figure: Figure) -> Double? {
        columnLayouts.first(where: { $0.figure == figure && $0.column == nil })?.width
    }

    /// Persisted width for a strings-mode column, or nil for the table default.
    package func columnLayoutWidth(forColumn column: PopupTableColumn) -> Double? {
        columnLayouts.first(where: { $0.figure == nil && $0.column == column })?.width
    }

    /// Stores (or overwrites) the width for a figures-mode column.
    /// Links are established via the annotated side (`columnLayouts`).
    package func setColumnLayoutWidth(_ width: Double, forFigure figure: Figure, context: ModelContext) {
        ensureColumnLayout(context: context, figure: figure).width = width
    }

    /// Stores (or overwrites) the width for a strings-mode column.
    package func setColumnLayoutWidth(_ width: Double, forColumn column: PopupTableColumn, context: ModelContext) {
        ensureColumnLayout(context: context, column: column).width = width
    }

    /// Removes every figures-mode layout row (used when switching to strings mode).
    package func removeFigureColumnLayouts(context: ModelContext) {
        removeColumnLayouts(where: { $0.figure != nil && $0.column == nil }, context: context)
    }

    /// Removes figures-mode layout rows whose figure is no longer in the table.
    package func removeFigureColumnLayouts(except keepIDs: Set<PersistentIdentifier>, context: ModelContext) {
        removeColumnLayouts(where: { layout in
            guard let fig = layout.figure, layout.column == nil else { return false }
            return !keepIDs.contains(fig.persistentModelID)
        }, context: context)
    }

    /// Removes every strings-mode layout row (used when switching to figures mode).
    package func removeStringColumnLayouts(context: ModelContext) {
        removeColumnLayouts(where: { $0.figure == nil && $0.column != nil }, context: context)
    }

    private func removeColumnLayouts(where predicate: (PopupTableColumnLayout) -> Bool, context: ModelContext) {
        for layout in columnLayouts where predicate(layout) {
            columnLayouts.removeAll { $0 == layout }
            context.delete(layout)
        }
    }

    private func ensureColumnLayout(context: ModelContext, figure: Figure? = nil, column: PopupTableColumn? = nil) -> PopupTableColumnLayout {
        if let existing = columnLayouts.first(where: { $0.figure == figure && $0.column == column }) {
            return existing
        }
        let layout = PopupTableColumnLayout(figure: figure, column: column)
        context.insert(layout)
        columnLayouts.append(layout)
        return layout
    }
}
