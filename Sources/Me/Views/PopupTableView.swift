import SwiftUI
import SwiftData

private let defaultTableColumnWidth: CGFloat = 180
private let minTableColumnWidth: CGFloat = 60
private let maxTableColumnWidth: CGFloat = 560

/// Layout reserves of the app window that the table sheet must not cover. The
/// left reserve is the navigation sidebar (ideal width 260); the right reserve
/// is the list detail bar (320). The sheet's max width is the window content
/// area between them.
private let windowSidebarWidth: CGFloat = 260
private let windowDetailBarWidth: CGFloat = 320
private let windowEdgeMargin: CGFloat = 16

/// Per-attribute row heights measured from the data cells, so the frozen
/// row-label column aligns with its (content-sized) data rows.
private struct RowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [PersistentIdentifier: CGFloat] = [:]
    static func reduce(value: inout [PersistentIdentifier: CGFloat], nextValue: () -> [PersistentIdentifier: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}



/// Which dimension(s) the scale handle adjusts: uniform (both), width-only
/// (⇧-held), or height-only (⌃-held).
private enum GridScaleAxis {
    case horizontal
    case vertical
    case both
}

struct PopupTableView: View {
    let table: PopupTable
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var cellValues: [String: String] = [:]
    @State private var cellRichValues: [String: Data] = [:]
    @State private var cellComments: [String: String] = [:]
    @State private var cellRichComments: [String: Data] = [:]
    @State private var cellSourceNames: [String: [CellSourceEntry]] = [:]
    @State private var activeCell: ActiveCell?
    @State private var commentTarget: ActiveCell?
    @State private var liveColumnWidths: [PersistentIdentifier: CGFloat] = [:]
    @State private var storedColumnWidthPoints: [PersistentIdentifier: CGFloat] = [:]
    @State private var dragStartWidths: [PersistentIdentifier: CGFloat] = [:]
    @State private var resizingColumnID: PersistentIdentifier?
    @State private var hoveredColumnID: PersistentIdentifier?
    @State private var columnScale: CGFloat = 1.0
    @State private var rowScale: CGFloat = 1.0
    @State private var scaleAxisAtStart: GridScaleAxis = .both
    @State private var scaleStart: (column: CGFloat, row: CGFloat)?
    @State private var headerHeight: CGFloat = PopupTable.defaultHeaderHeight
    @State private var headerHeightStart: CGFloat?
    @State private var headerHovered = false
    @State private var rowHeights: [PersistentIdentifier: CGFloat] = [:]
    @State private var hostWindow: NSWindow?
    @State private var tableSize: CGSize = CGSize(width: 700, height: 400)

    private var rowHeaderWidth: CGFloat { (160 * columnScale).rounded() }
    private var rowHeight: CGFloat { (120 * rowScale).rounded() }

    private var sortedAttributes: [PopupTableAttribute] {
        table.attributes.sorted { ($0.orderIndex ?? Int.max) < ($1.orderIndex ?? Int.max) }
    }

    private var columns: [ColumnItem] {
        switch table.columnMode {
        case .figures:
            return table.figures.map(ColumnItem.figure)
        case .strings:
            return table.columns
                .sorted { ($0.orderIndex ?? Int.max) < ($1.orderIndex ?? Int.max) }
                .map(ColumnItem.column)
        }
    }

    private func cellKey(attributeID: PersistentIdentifier, columnID: PersistentIdentifier) -> String {
        "\(attributeID.hashValue)-\(columnID.hashValue)"
    }

    /// A single table footnote: a unique `name — location` cell source plus its
    /// URL (resolved from the linked `Source` row when available).
    private struct TableFootnote: Identifiable {
        let id: Int
        let sourceName: String
        let url: URL?
    }

    /// The table's footnote list, built in row-major order (rows of attributes,
    /// columns left to right), each unique `name — location` source numbered
    /// once at first appearance. The table-wide source is not numbered — it is
    /// already stated in the header.
    private var tableFootnotes: [TableFootnote] {
        var seen: [String: Int] = [:]
        var result: [TableFootnote] = []
        var next = 1
        for attribute in sortedAttributes {
            for column in columns {
                let key = cellKey(attributeID: attribute.persistentModelID, columnID: column.id)
                for entry in cellSourceNames[key] ?? [] {
                    let identity = entry.displayName
                    if seen[identity] == nil {
                        seen[identity] = next
                        result.append(TableFootnote(
                            id: next,
                            sourceName: identity,
                            url: entry.url.flatMap { $0.isEmpty ? nil : URL(string: $0) }
                        ))
                        next += 1
                    }
                }
            }
        }
        return result
    }

    /// Footnote numbers for a single cell key, in source order.
    private func footnoteNumbers(for key: String) -> [Int] {
        guard let entries = cellSourceNames[key], !entries.isEmpty else { return [] }
        let footnotes = tableFootnotes
        return entries.compactMap { entry in
            footnotes.first { $0.sourceName == entry.displayName }?.id
        }
    }

    /// Height (points) of the footnote block, if any, so the window can enclose
    /// it when the table is short enough to show it.
    private var footnoteBlockHeight: CGFloat {
        guard !tableFootnotes.isEmpty else { return 0 }
        return CGFloat(tableFootnotes.count) * 18 + 30
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            gridOrEmpty
            footerBar
        }
        .frame(width: tableSize.width, height: tableSize.height)
        .background(WindowAccessor { window in
            hostWindow = window
        })
        .onAppear {
            loadCells()
            loadColumnLayouts()
            DispatchQueue.main.async { fitHostWindowToTable() }
        }
        .popover(item: $activeCell, arrowEdge: .bottom) { cell in
            CellEditPopover(
                cell: cell,
                value: cellBinding(attributeID: cell.attributeID, columnID: cell.columnID),
                richValue: richValueBinding(attributeID: cell.attributeID, columnID: cell.columnID),
                comment: commentBinding(attributeID: cell.attributeID, columnID: cell.columnID),
                tableSource: table.source ?? "",
                tableSourceURL: table.sourceRef.flatMap { $0.url.isEmpty ? nil : URL(string: $0.url) },
                onEditComment: { commentTarget = cell },
                onUpdateSources: {
                    saveSources(attributeID: cell.attributeID, columnID: cell.columnID, sources: $0)
                },
                onClose: { activeCell = nil }
            )
        }
        .sheet(item: $commentTarget) { cell in
            CommentEditorSheet(
                cell: cell,
                comment: commentBinding(attributeID: cell.attributeID, columnID: cell.columnID),
                richComment: richCommentBinding(attributeID: cell.attributeID, columnID: cell.columnID),
                onClose: { commentTarget = nil }
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(table.name)
                .font(.title2)
            if !table.tableDescription.isEmpty {
                Text(table.tableDescription)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if let tableSource = table.source, !tableSource.isEmpty {
                SourceFootnoteView(
                    sourceName: tableSource,
                    url: table.sourceRef.flatMap { $0.url.isEmpty ? nil : URL(string: $0.url) }
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 3)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var gridOrEmpty: some View {
        if columns.isEmpty || sortedAttributes.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "tablecells")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(columns.isEmpty ? (table.columnMode == .strings ? "No columns in this table" : "No figures in this table") : "No attributes defined")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(table.columnMode == .strings ? "Add columns and attributes in the table settings" : "Add figures and attributes in the table settings")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        } else {
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    // Frozen row-label column: scrolls vertically with the rows
                    // but never horizontally, so the attribute names stay visible.
                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: rowHeaderWidth, height: headerHeight + 5)
                        ForEach(sortedAttributes) { attribute in
                            AttributeRowHeader(attribute: attribute)
                                .frame(width: rowHeaderWidth)
                                .frame(height: rowHeights[attribute.persistentModelID] ?? rowHeight)
                        }
                    }
                    .padding(1)
                    .background(Color(nsColor: .separatorColor))

                    // Data area: header row + cells, scrolls horizontally. The
                    // header row shares this scroll so it always lines up with
                    // the columns (the blank corner cell is its first slot).
                    ScrollView(.horizontal) {
                        VStack(spacing: 1) {
                            HStack(spacing: 1) {
                                ForEach(columns) { column in
                                    let width = columnWidth(for: column)
                                    ZStack(alignment: .trailing) {
                                        columnHeader(column)
                                            .frame(width: width, height: headerHeight)
                                        ColumnResizeHandle(
                                            isActive: resizingColumnID == column.id,
                                            isHovered: hoveredColumnID == column.id
                                        )
                                        .frame(width: 24, height: headerHeight)
                                        .gesture(columnResizeGesture(for: column))
                                        .onHover { hovering in
                                            if hovering {
                                                hoveredColumnID = column.id
                                                NSCursor.resizeLeftRight.set()
                                            } else if hoveredColumnID == column.id {
                                                hoveredColumnID = nil
                                                NSCursor.arrow.set()
                                            }
                                        }
                                    }
                                    .frame(width: width, height: headerHeight)
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor))

                            Rectangle()
                                .fill(headerHovered || headerHeightStart != nil ? Color.accentColor.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
                                .frame(height: 5)
                                .contentShape(Rectangle())
                                .gesture(headerHeightGesture())
                                .onHover { hovering in
                                    headerHovered = hovering
                                    if hovering || headerHeightStart != nil { NSCursor.resizeUpDown.set() }
                                    else { NSCursor.arrow.set() }
                                }
                                .help("Drag to resize the header row height")

                            ForEach(sortedAttributes) { attribute in
                                HStack(spacing: 1) {
                                    ForEach(columns) { column in
                                        let key = cellKey(attributeID: attribute.persistentModelID, columnID: column.id)
                                        CellView(
                                            value: cellBinding(attributeID: attribute.persistentModelID, columnID: column.id),
                                            sourceNumbers: footnoteNumbers(for: key),
                                            comment: cellComments[key] ?? "",
                                            onOpen: {
                                                activeCell = ActiveCell(
                                                    attributeID: attribute.persistentModelID,
                                                    columnID: column.id,
                                                    attributeName: attribute.name,
                                                    columnName: columnName(column),
                                                    sources: cellSourceNames[key] ?? []
                                                )
                                            },
                                            onEditComment: {
                                                commentTarget = ActiveCell(
                                                    attributeID: attribute.persistentModelID,
                                                    columnID: column.id,
                                                    attributeName: attribute.name,
                                                    columnName: columnName(column),
                                                    sources: cellSourceNames[key] ?? []
                                                )
                                            }
                                        )
                                        .frame(width: columnWidth(for: column))
                                        .frame(minHeight: rowHeight)
                                    }
                                }
                                .background(GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: RowHeightPreferenceKey.self,
                                        value: [attribute.persistentModelID: proxy.size.height]
                                    )
                                })
                            }
                        }
                        .padding(1)
                        .background(Color(nsColor: .separatorColor))
                    }
                }

                // Footnote block: numbered source references, under the grid.
                // Stays inside the vertical scroll so it scrolls with content.
                if !tableFootnotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                            .padding(.top, 6)
                        ForEach(tableFootnotes) { footnote in
                            HStack(spacing: 6) {
                                Text("\(footnote.id)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16, alignment: .trailing)
                                SourceFootnoteView(sourceName: footnote.sourceName, url: footnote.url)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
            }
            .onPreferenceChange(RowHeightPreferenceKey.self) { rowHeights = $0 }
        }
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
            GridScaleHandle(columnScale: columnScale, rowScale: rowScale, isDragging: scaleStart != nil)
                .gesture(gridScaleGesture())
                .help("Drag to scale the whole grid. Hold ⇧ for width only, ⌃ for height only.")
            Text("\(Int((columnScale * 100).rounded()))% × \(Int((rowScale * 100).rounded()))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 76, alignment: .leading)
            Button {
                resetGridScale()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(columnScale == 1.0 && rowScale == 1.0 && storedColumnWidthPoints.isEmpty)
            .help("Reset table to default width, scale, and size")
        }
        .padding()
    }

    @ViewBuilder
    private func columnHeader(_ column: ColumnItem) -> some View {
        switch column {
        case .figure(let figure):
            FigureColumnHeader(figure: figure)
        case .column(let col):
            StringColumnHeader(name: col.name)
        }
    }

    private func columnName(_ column: ColumnItem) -> String {
        switch column {
        case .figure(let figure): return figure.name
        case .column(let col): return col.name
        }
    }

    private func loadCells() {
        cellValues = [:]
        cellRichValues = [:]
        cellComments = [:]
        cellRichComments = [:]
        cellSourceNames = [:]
        for cell in table.cells {
            if let attrID = cell.attribute?.persistentModelID {
                if let figID = cell.figure?.persistentModelID {
                    loadCell(cell, key: cellKey(attributeID: attrID, columnID: figID))
                } else if let colID = cell.column?.persistentModelID {
                    loadCell(cell, key: cellKey(attributeID: attrID, columnID: colID))
                }
            }
        }
    }

    private func loadCell(_ cell: PopupTableCell, key: String) {
        cellValues[key] = cell.value ?? ""
        if let rich = cell.richValue { cellRichValues[key] = rich }
        cellComments[key] = cell.comment ?? ""
        if let rich = cell.richComment { cellRichComments[key] = rich }
        if !cell.cellSources.isEmpty {
            cellSourceNames[key] = cell.cellSources.map { source in
                CellSourceEntry(
                    name: source.source,
                    location: source.location,
                    url: source.sourceRef.flatMap { $0.url.isEmpty ? nil : $0.url }
                )
            }
        } else {
            cellSourceNames[key] = cell.effectiveCellSourceNames.map { name in
                CellSourceEntry(
                    name: name.name,
                    location: name.location,
                    url: cell.sourceRef.flatMap { $0.url.isEmpty ? nil : $0.url }
                )
            }
        }
    }

    private func loadColumnLayouts() {
        var widths: [PersistentIdentifier: CGFloat] = [:]
        for layout in table.columnLayouts {
            guard let width = layout.width else { continue }
            if let figure = layout.figure, layout.column == nil {
                widths[figure.persistentModelID] = CGFloat(width)
            } else if let column = layout.column, layout.figure == nil {
                widths[column.persistentModelID] = CGFloat(width)
            }
        }
        storedColumnWidthPoints = widths
        columnScale = table.columnScale
        rowScale = table.rowScale
        headerHeight = table.headerHeight
    }

    private func columnWidth(for column: ColumnItem) -> CGFloat {
        if let live = liveColumnWidths[column.id] { return live.rounded() }
        return ((storedColumnWidthPoints[column.id] ?? defaultTableColumnWidth) * columnScale).rounded()
    }

    private func columnResizeGesture(for column: ColumnItem) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragStartWidths[column.id] == nil {
                    dragStartWidths[column.id] = effectiveColumnWidth(for: column)
                }
                guard let start = dragStartWidths[column.id] else { return }
                liveColumnWidths[column.id] = quantizedColumnWidth(start, delta: value.translation.width)
                resizingColumnID = column.id
                NSCursor.resizeLeftRight.set()
            }
            .onEnded { value in
                defer {
                    liveColumnWidths[column.id] = nil
                    dragStartWidths[column.id] = nil
                    resizingColumnID = nil
                    NSCursor.arrow.set()
                }
                let start = dragStartWidths[column.id] ?? effectiveColumnWidth(for: column)
                let clamped = quantizedColumnWidth(start, delta: value.translation.width)
                storedColumnWidthPoints[column.id] = (clamped / columnScale).rounded()
                persistColumnWidth((clamped / columnScale).rounded(), for: column)
                fitHostWindowToTable()
            }
    }

    private func effectiveColumnWidth(for column: ColumnItem) -> CGFloat {
        if let live = liveColumnWidths[column.id] { return live }
        return ((storedColumnWidthPoints[column.id] ?? defaultTableColumnWidth) * columnScale).rounded()
    }

    /// Snap a dragged column width to a whole point so the Grid never renders at
    /// subpixel positions (the source of the jittery/jerky resize on retina).
    private func quantizedColumnWidth(_ start: CGFloat, delta: CGFloat) -> CGFloat {
        clampColumnWidth((start + delta).rounded())
    }

    private func clampColumnWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minTableColumnWidth * columnScale), maxTableColumnWidth * columnScale)
    }

    private func headerHeightGesture() -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if headerHeightStart == nil {
                    headerHeightStart = headerHeight
                }
                guard let start = headerHeightStart else { return }
                headerHeight = clampHeaderHeight(start + value.translation.height)
                NSCursor.resizeUpDown.set()
            }
            .onEnded { value in
                defer {
                    headerHeightStart = nil
                    NSCursor.arrow.set()
                }
                let start = headerHeightStart ?? headerHeight
                let clamped = clampHeaderHeight(start + value.translation.height)
                headerHeight = clamped
                table.headerHeight = clamped
                try? modelContext.save()
                fitHostWindowToTable()
            }
    }

    private func clampHeaderHeight(_ height: CGFloat) -> CGFloat {
        min(max((height).rounded(), 28), 200)
    }

    /// The grid's natural content extent in points (header column + all columns,
    /// all rows + the window chrome around the grid). Drives both the SwiftUI
    /// `tableSize` frame and the sheet's window frame.
    private var tableNaturalContentSize: CGSize {
        let spacing: CGFloat = 1
        let gridWidth = rowHeaderWidth
            + columns.reduce(CGFloat(0)) { $0 + columnWidth(for: $1) }
            + spacing * CGFloat(columns.count)
            + 2
        let rows = CGFloat(sortedAttributes.count + 1)
        let gridHeight = headerHeight + rowHeight * CGFloat(sortedAttributes.count) + (rows - 1) * spacing + 2
        return CGSize(width: gridWidth + 4, height: gridHeight + footnoteBlockHeight + verticalChrome)
    }

    private var verticalChrome: CGFloat {
        var chromeHeight: CGFloat = 32
        chromeHeight += 24
        if !table.tableDescription.isEmpty { chromeHeight += 22 }
        if let source = table.source, !source.isEmpty { chromeHeight += 28 }
        chromeHeight += 2
        chromeHeight += 56
        chromeHeight += 1
        return chromeHeight
    }

    /// Encloses the sheet to the table's natural content size. Called on open and
    /// on drag release (never during a drag, so the window stays put mid-gesture).
    /// `tableSize` is set from the SAME clamped size used for the window frame, so
    /// SwiftUI's content frame and the NSWindow frame can never disagree — which is
    /// what stopped the window from fighting back and snapping.
    private func fitHostWindowToTable() {
        let natural = tableNaturalContentSize
        let parent: NSWindow? = hostWindow?.sheetParent
        let maxSize: CGSize
        if let parent {
            // Stay within the content region: don't grow over the left sidebar or
            // the right detail bar. Floored at the table's 700pt min so narrow
            // windows still give the grid enough room (it scrolls past that).
            let contentMaxWidth = max(
                700,
                parent.frame.width - windowSidebarWidth - windowDetailBarWidth - windowEdgeMargin
            )
            maxSize = CGSize(width: contentMaxWidth, height: parent.frame.height - 36)
        } else {
            maxSize = CGSize(width: 2400, height: 1600)
        }
        let width = min(max(natural.width, 700), maxSize.width)
        let height = min(max(natural.height, 400), maxSize.height)
        tableSize = CGSize(width: width, height: height)
        guard let window = hostWindow, parent != nil else { return }
        let target = window.frameRect(forContentRect: NSRect(origin: .zero, size: tableSize))
        if abs(target.width - window.frame.width) < 1 && abs(target.height - window.frame.height) < 1 { return }
        window.setFrame(NSRect(origin: window.frame.origin, size: target.size), display: false)
    }

    private func persistColumnWidth(_ width: CGFloat, for column: ColumnItem) {
        switch column {
        case .figure(let figure):
            table.setColumnLayoutWidth(width, forFigure: figure, context: modelContext)
        case .column(let popupColumn):
            table.setColumnLayoutWidth(width, forColumn: popupColumn, context: modelContext)
        }
        try? modelContext.save()
    }

    private func gridScaleGesture() -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if scaleStart == nil {
                    scaleStart = (columnScale, rowScale)
                    scaleAxisAtStart = currentScaleAxis()
                    updateDragCursor(for: scaleAxisAtStart)
                    liveColumnWidths = [:]
                }
                guard let start = scaleStart else { return }
                applyScale(start: start, translation: value.translation)
            }
            .onEnded { value in
                defer {
                    scaleStart = nil
                    scaleAxisAtStart = .both
                    NSCursor.arrow.set()
                }
                guard let start = scaleStart else { return }
                applyScale(start: start, translation: value.translation)
                liveColumnWidths = [:]
                persistGridScale(columnScale, rowScale)
                fitHostWindowToTable()
            }
    }

    private func updateDragCursor(for axis: GridScaleAxis) {
        switch axis {
        case .horizontal: NSCursor.resizeLeftRight.set()
        case .vertical: NSCursor.resizeUpDown.set()
        case .both: break
        }
    }

    private func currentScaleAxis() -> GridScaleAxis {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) { return .horizontal }
        if flags.contains(.control) { return .vertical }
        return .both
    }

    private func applyScale(start: (column: CGFloat, row: CGFloat), translation: CGSize) {
        let delta: CGFloat
        let factor: CGFloat
        switch scaleAxisAtStart {
        case .horizontal:
            delta = translation.width
            factor = 1 + delta / 300
            columnScale = clampGridScale(start.column * factor)
        case .vertical:
            delta = translation.height
            factor = 1 + delta / 300
            rowScale = clampGridScale(start.row * factor)
        case .both:
            delta = (translation.width + translation.height) / 2
            factor = 1 + delta / 300
            columnScale = clampGridScale(start.column * factor)
            rowScale = clampGridScale(start.row * factor)
        }
    }

    private func clampGridScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, 0.5), 2.5)
    }

    private func roundedGridScale(_ scale: CGFloat) -> CGFloat {
        (scale * 100).rounded() / 100
    }

    private func persistGridScale(_ columnScale: CGFloat, _ rowScale: CGFloat) {
        table.columnScale = roundedGridScale(columnScale)
        table.rowScale = roundedGridScale(rowScale)
        try? modelContext.save()
    }

    private func resetGridScale() {
        columnScale = 1.0
        rowScale = 1.0
        liveColumnWidths = [:]
        storedColumnWidthPoints = [:]
        table.removeAllColumnLayouts(context: modelContext)
        persistGridScale(1.0, 1.0)
        fitHostWindowToTable()
    }

    /// Finds or creates the cell for this attribute/column intersection.
    private func ensureCell(attributeID: PersistentIdentifier, columnID: PersistentIdentifier) -> PopupTableCell? {
        if let existing = table.cells.first(where: { cell in
            cell.attribute?.persistentModelID == attributeID &&
            (cell.figure?.persistentModelID ?? cell.column?.persistentModelID) == columnID
        }) {
            return existing
        }

        guard let attribute = table.attributes.first(where: { $0.persistentModelID == attributeID }) else { return nil }
        let cell: PopupTableCell
        switch table.columnMode {
        case .figures:
            guard let figure = table.figures.first(where: { $0.persistentModelID == columnID }) else { return nil }
            cell = PopupTableCell(attribute: attribute, figure: figure)
        case .strings:
            guard let column = table.columns.first(where: { $0.persistentModelID == columnID }) else { return nil }
            cell = PopupTableCell(attribute: attribute, column: column)
        }
        table.cells.append(cell)
        modelContext.insert(cell)
        return cell
    }

    private func saveSources(attributeID: PersistentIdentifier, columnID: PersistentIdentifier, sources: [CellSourceEntry]) {
        guard let cell = ensureCell(attributeID: attributeID, columnID: columnID) else { return }

        for cellSource in cell.cellSources {
            cell.removeCellSource(cellSource)
            modelContext.delete(cellSource)
        }
        for entry in sources {
            cell.addCellSource(named: entry.name, location: entry.location, context: modelContext)
        }
        try? modelContext.save()
        loadCells()
    }

    private func cellBinding(attributeID: PersistentIdentifier, columnID: PersistentIdentifier) -> Binding<String> {
        let key = cellKey(attributeID: attributeID, columnID: columnID)
        return Binding(
            get: { cellValues[key] ?? "" },
            set: { newValue in
                cellValues[key] = newValue
                saveCell(attributeID: attributeID, columnID: columnID, value: newValue)
            }
        )
    }

    private func saveCell(attributeID: PersistentIdentifier, columnID: PersistentIdentifier, value: String) {
        guard let cell = ensureCell(attributeID: attributeID, columnID: columnID) else { return }
        cell.value = value.isEmpty ? nil : value
        try? modelContext.save()
    }

    private func richValueBinding(attributeID: PersistentIdentifier, columnID: PersistentIdentifier) -> Binding<Data?> {
        let key = cellKey(attributeID: attributeID, columnID: columnID)
        return Binding(
            get: { cellRichValues[key] },
            set: { newValue in
                if let newValue {
                    cellRichValues[key] = newValue
                } else {
                    cellRichValues[key] = nil
                }
                saveRichValue(attributeID: attributeID, columnID: columnID, rich: newValue)
            }
        )
    }

    private func saveRichValue(attributeID: PersistentIdentifier, columnID: PersistentIdentifier, rich: Data?) {
        guard let cell = ensureCell(attributeID: attributeID, columnID: columnID) else { return }
        cell.richValue = rich
        try? modelContext.save()
    }

    private func commentBinding(attributeID: PersistentIdentifier, columnID: PersistentIdentifier) -> Binding<String> {
        let key = cellKey(attributeID: attributeID, columnID: columnID)
        return Binding(
            get: { cellComments[key] ?? "" },
            set: { newValue in
                cellComments[key] = newValue
                saveComment(attributeID: attributeID, columnID: columnID, comment: newValue)
            }
        )
    }

    private func saveComment(attributeID: PersistentIdentifier, columnID: PersistentIdentifier, comment: String) {
        guard let cell = ensureCell(attributeID: attributeID, columnID: columnID) else { return }
        cell.comment = comment.isEmpty ? nil : comment
        try? modelContext.save()
    }

    private func richCommentBinding(attributeID: PersistentIdentifier, columnID: PersistentIdentifier) -> Binding<Data?> {
        let key = cellKey(attributeID: attributeID, columnID: columnID)
        return Binding(
            get: { cellRichComments[key] },
            set: { newValue in
                if let newValue {
                    cellRichComments[key] = newValue
                } else {
                    cellRichComments[key] = nil
                }
                saveRichComment(attributeID: attributeID, columnID: columnID, rich: newValue)
            }
        )
    }

    private func saveRichComment(attributeID: PersistentIdentifier, columnID: PersistentIdentifier, rich: Data?) {
        guard let cell = ensureCell(attributeID: attributeID, columnID: columnID) else { return }
        cell.richComment = rich
        try? modelContext.save()
    }
}

/// One column of a PopupTable grid — either a Figure or a flat string label.
private enum ColumnItem: Identifiable {
    case figure(Figure)
    case column(PopupTableColumn)

    var id: PersistentIdentifier {
        switch self {
        case .figure(let figure): return figure.persistentModelID
        case .column(let column): return column.persistentModelID
        }
    }
}

private struct FigureColumnHeader: View {
    let figure: Figure
    var body: some View {
        HStack(spacing: 4) {
            if let mugshot = figure.mugshotImage {
                MugshotView(imageURL: mugshot.fileURL, cropRect: figure.mugshotCropRect.flatMap { ImageCropRect(encoded: $0) }, size: 18, fallbackColor: figure.figureType.map { Color(hex: $0.colorHex) } ?? .gray, fallbackIcon: figure.figureType?.icon ?? "person.circle", identification: figure.mugshotIdentification)
            } else {
                Circle()
                    .fill(figure.figureType.map { Color(hex: $0.colorHex) } ?? .gray)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: figure.figureType?.icon ?? "person.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(.white)
                    )
            }
            Text(figure.name)
                .font(.body.bold())
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct StringColumnHeader: View {
    let name: String
    var body: some View {
        Text(name)
            .font(.body.bold())
            .lineLimit(2)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct AttributeRowHeader: View {
    let attribute: PopupTableAttribute
    var body: some View {
        Text(attribute.name)
            .font(.body.bold())
            .lineLimit(2)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct CellSourceEntry: Hashable {
    var name: String
    var location: String?
    var url: String?

    var displayName: String {
        if let location, !location.isEmpty { return "\(name) \u{2014} \(location)" }
        return name
    }
}

/// The canonical source-reference footnote used by the free-text prose blocks:
/// `[book.and.wrench] Source: <name> (click to see…)`. The table-wide source
/// reference and in-cell source references reuse this same layout.
private struct SourceFootnoteView: View {
    let sourceName: String
    let url: URL?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "book.and.wrench")
                .font(.caption2)
                .foregroundStyle(.teal)
            Text("Source: \(sourceName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let url {
                Link("(click to see, note: may open browser window)", destination: url)
                    .font(.caption2)
            }
        }
    }
}

private struct ActiveCell: Identifiable {
    let attributeID: PersistentIdentifier
    let columnID: PersistentIdentifier
    let attributeName: String
    let columnName: String
    let sources: [CellSourceEntry]

    var id: String { "\(attributeID.hashValue)-\(columnID.hashValue)" }
}

private struct CellEditPopover: View {
    let cell: ActiveCell
    @Binding var value: String
    @Binding var richValue: Data?
    @Binding var comment: String
    let tableSource: String
    let tableSourceURL: URL?
    var onEditComment: (() -> Void)? = nil
    var onUpdateSources: ([CellSourceEntry]) -> Void
    var onClose: () -> Void
    @State private var sourceEntries: [CellSourceEntry] = []
    @State private var newSource: String = ""
    @State private var newLocation: String = ""
    @State private var loaded = false
    @Query private var allSources: [Source]

    private var hasComment: Bool { !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var commentPreview: String { let t = comment.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? "" : (t.count > 60 ? String(t.prefix(60)) + "…" : t) }

    private var availableSourceNames: [String] {
        var names = Set(allSources.map(\.name))
        names.formUnion(sourceEntries.map(\.name))
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(cell.attributeName)
                    .font(.headline)
                Text(cell.columnName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Value")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                RichTextEditorSection(richData: $richValue, plainText: $value)
                    .frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Comment")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button {
                    onEditComment?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .foregroundStyle(hasComment ? Color.accentColor : .secondary)
                        Text(hasComment ? (commentPreview.isEmpty ? "Edit comment\u{2026}" : commentPreview) : "Add comment\u{2026}")
                            .foregroundStyle(hasComment ? Color.primary : .accentColor)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35)))
                }
                .buttonStyle(.plain)
                .help(hasComment ? "Edit this cell's comment" : "Add a comment to this cell")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Sources")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if sourceEntries.isEmpty {
                    if tableSource.isEmpty {
                        Text("No source recorded")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        SourceFootnoteView(sourceName: tableSource, url: tableSourceURL)
                    }
                } else {
                    ForEach(sourceEntries, id: \.self) { entry in
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.displayName)
                                .font(.caption)
                            Spacer()
                            Button {
                                sourceEntries.removeAll { $0 == entry }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Picker("", selection: $newSource) {
                        Text("Add source\u{2026}").tag("")
                        ForEach(availableSourceNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        let name = newSource.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty && !sourceEntries.contains(where: { $0.name == name && $0.location == (newLocation.isEmpty ? nil : newLocation) }) {
                            sourceEntries.append(CellSourceEntry(name: name, location: newLocation.isEmpty ? nil : newLocation))
                        }
                        newSource = ""
                        newLocation = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 6) {
                    TextField("Location (such as Tablet V, lines 120\u{2013}143)", text: $newLocation)
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                Spacer()
                Button("Done") {
                    onUpdateSources(sourceEntries)
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(width: 460, height: 560)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            sourceEntries = cell.sources
        }
    }
}

/// A dedicated sheet for editing a comparison-table cell's long-form comment.
/// Kept separate from the value/source `CellEditPopover` so notes get a roomy,
/// multiline editor. The comment binding saves live as you type.
private struct CommentEditorSheet: View {
    let cell: ActiveCell
    @Binding var comment: String
    @Binding var richComment: Data?
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Comment: \(cell.attributeName)")
                        .font(.headline)
                    Text(cell.columnName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            RichTextEditorSection(richData: $richComment, plainText: $comment)
                .frame(maxHeight: .infinity)
            HStack {
                Spacer()
                Button("Done") { onClose() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 640, height: 460)
    }
}

/// The last 24pt of a column header, ending at the column's right edge. An
/// unconditional empty anchor pins the rule to the strip's trailing edge (the
/// column boundary) so the visible line and the grab zone always coincide. The
/// zone fills with an accent highlight on hover or while resizing.
private struct ColumnResizeHandle: View {
    var isActive: Bool
    var isHovered: Bool

    /// macOS-friendly grab zone: no on-drawn rule (the grid's own thin column
    /// separator stays visible); it only glows faintly on hover/active, and the
    /// ↔ resize cursor (set by the caller's onHover/gesture) signals draggability.
    var body: some View {
        ZStack(alignment: .trailing) {
            Color.clear
                .frame(width: 24)
            if isActive || isHovered {
                Rectangle()
                    .fill(Color.accentColor.opacity(isActive ? 0.12 : 0.08))
                    .frame(width: 24)
            }
        }
        .frame(width: 24)
        .contentShape(Rectangle())
    }
}

/// Grip in the footer bar: drag to scale every column width and row height by a
/// uniform factor; hold ⇧ for width only, ⌃ for height only.
private struct GridScaleHandle: View {
    var columnScale: CGFloat
    var rowScale: CGFloat
    var isDragging: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isDragging ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
                )
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isDragging ? Color.accentColor : Color.secondary)
        }
        .contentShape(Rectangle())
    }
}

private struct CellView: View {
    @Binding var value: String
    var sourceNumbers: [Int] = []
    var comment: String = ""
    var onOpen: (() -> Void)? = nil
    var onEditComment: (() -> Void)? = nil

    /// A cell value that is a genuine emoji/status icon (a short run containing
    /// emoji scalars) renders large and centered. Plain non-ASCII text — e.g.
    /// cuneiform in a description, or any word — stays regular title3 size, so
    /// it never gets blown up.
    private var isEmojiValue: Bool {
        guard !value.isEmpty, value != "\u{2014}" else { return false }
        let scalars = value.unicodeScalars
        guard scalars.count <= 4 else { return false }
        return scalars.contains { $0.properties.isEmoji }
    }

    private var hasOwnSource: Bool { !sourceNumbers.isEmpty }

    @ViewBuilder
    private var valueText: some View {
        if isEmojiValue {
            Text(value)
                .font(.system(size: 40))
                .lineLimit(1)
        } else {
            Text(value.isEmpty ? "\u{2014}" : value)
                .font(.title3)
                .foregroundStyle(value.isEmpty ? .tertiary : .primary)
        }
    }

    private var trimComment: String { comment.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var helpText: String {
        var parts: [String] = []
        if hasOwnSource { parts.append("Source footnote(s): \(sourceNumbers.map(String.init).joined(separator: ", "))") }
        if !trimComment.isEmpty { parts.append("Comment: \(trimComment)") }
        return parts.isEmpty ? "" : "\(parts.joined(separator: " · ")). Click to open editor."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: isEmojiValue ? .center : .top, spacing: 1) {
                valueText
                if !sourceNumbers.isEmpty && !value.isEmpty {
                    Text(sourceNumbers.map { "\($0)" }.joined(separator: ","))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .baselineOffset(4)
                }
                if !trimComment.isEmpty {
                    Button {
                        onEditComment?()
                    } label: {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit comment")
                }
                if !isEmojiValue {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isEmojiValue ? .center : .topLeading)
        .contentShape(Rectangle())
        .background(Color(nsColor: .windowBackgroundColor))
        .help(helpText)
        .onTapGesture { onOpen?() }
    }
}

/// Reports the hosting `NSWindow` so the sheet can be re-fitted to enclose the
/// table on drag release.
private struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onWindow(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onWindow(nsView.window) }
    }
}



