import SwiftUI
import SwiftData

private let defaultTableColumnWidth: CGFloat = 180
private let minTableColumnWidth: CGFloat = 60
private let maxTableColumnWidth: CGFloat = 560

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
    @State private var cellSourceNames: [String: [CellSourceEntry]] = [:]
    @State private var activeCell: ActiveCell?
    @State private var liveColumnWidths: [PersistentIdentifier: CGFloat] = [:]
    @State private var storedColumnWidthPoints: [PersistentIdentifier: CGFloat] = [:]
    @State private var dragStartWidths: [PersistentIdentifier: CGFloat] = [:]
    @State private var resizingColumnID: PersistentIdentifier?
    @State private var hoveredColumnID: PersistentIdentifier?
    @State private var columnScale: CGFloat = 1.0
    @State private var rowScale: CGFloat = 1.0
    @State private var scaleAxisAtStart: GridScaleAxis = .both
    @State private var scaleStart: (column: CGFloat, row: CGFloat)?

    private var rowHeaderWidth: CGFloat { 160 * columnScale }
    private var rowHeight: CGFloat { 120 * rowScale }

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

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(table.name)
                    .font(.title2)
                if !table.tableDescription.isEmpty {
                    Text(table.tableDescription)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                if !table.tableDescription.isEmpty,
                   let tableSource = table.source, !tableSource.isEmpty {
                    Divider()
                        .padding(.top, 5)
                }
                if let tableSource = table.source, !tableSource.isEmpty {
                    Label(tableSource, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

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
                ScrollView([.horizontal, .vertical]) {
                    Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 1) {
                        GridRow {
                            Color.clear
                                .frame(width: rowHeaderWidth, height: rowHeight)
                            ForEach(columns) { column in
                                let width = columnWidth(for: column)
                                ZStack(alignment: .trailing) {
                                    columnHeader(column)
                                        .frame(width: width, height: rowHeight)
                                    ColumnResizeHandle(
                                        isActive: resizingColumnID == column.id,
                                        isHovered: hoveredColumnID == column.id
                                    )
                                    .frame(width: 24, height: rowHeight)
                                    .gesture(columnResizeGesture(for: column))
                                    .onHover { hovering in
                                        if hovering {
                                            hoveredColumnID = column.id
                                        } else if hoveredColumnID == column.id {
                                            hoveredColumnID = nil
                                        }
                                    }
                                }
                                .frame(width: width, height: rowHeight)
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor))

                        ForEach(sortedAttributes) { attribute in
                            GridRow {
                                AttributeRowHeader(attribute: attribute)
                                    .frame(width: rowHeaderWidth, height: rowHeight)
                                ForEach(columns) { column in
                                    let key = cellKey(attributeID: attribute.persistentModelID, columnID: column.id)
                                    CellView(
                                        value: cellBinding(attributeID: attribute.persistentModelID, columnID: column.id),
                                        hasOwnSource: !(cellSourceNames[key] ?? []).isEmpty,
                                        onOpen: {
                                            activeCell = ActiveCell(
                                                attributeID: attribute.persistentModelID,
                                                columnID: column.id,
                                                attributeName: attribute.name,
                                                columnName: columnName(column),
                                                sources: cellSourceNames[key] ?? []
                                            )
                                        }
                                    )
                                    .frame(width: columnWidth(for: column), height: rowHeight)
                                }
                            }
                        }
                    }
                    .padding(1)
                    .background(Color(nsColor: .separatorColor))
                }
            }

            Divider()

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
                .disabled(columnScale == 1.0 && rowScale == 1.0)
                .help("Reset scale to 100%")
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear {
            loadCells()
            loadColumnLayouts()
        }
        .popover(item: $activeCell, arrowEdge: .bottom) { cell in
            CellEditPopover(
                cell: cell,
                value: cellBinding(attributeID: cell.attributeID, columnID: cell.columnID),
                tableSource: table.source ?? "",
                onUpdateSources: {
                    saveSources(attributeID: cell.attributeID, columnID: cell.columnID, sources: $0)
                },
                onClose: { activeCell = nil }
            )
        }
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
        cellSourceNames[key] = cell.effectiveCellSourceNames.map { name in
            CellSourceEntry(name: name.name, location: name.location)
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
    }

    private func columnWidth(for column: ColumnItem) -> CGFloat {
        if let live = liveColumnWidths[column.id] { return live }
        return (storedColumnWidthPoints[column.id] ?? defaultTableColumnWidth) * columnScale
    }

    private func columnResizeGesture(for column: ColumnItem) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragStartWidths[column.id] == nil {
                    dragStartWidths[column.id] = effectiveColumnWidth(for: column)
                }
                guard let start = dragStartWidths[column.id] else { return }
                liveColumnWidths[column.id] = clampColumnWidth(start + value.translation.width)
                resizingColumnID = column.id
            }
            .onEnded { value in
                let start = dragStartWidths[column.id] ?? effectiveColumnWidth(for: column)
                let clamped = clampColumnWidth(start + value.translation.width)
                storedColumnWidthPoints[column.id] = clamped / columnScale
                persistColumnWidth(clamped / columnScale, for: column)
                liveColumnWidths[column.id] = nil
                dragStartWidths[column.id] = nil
                resizingColumnID = nil
            }
    }

    private func effectiveColumnWidth(for column: ColumnItem) -> CGFloat {
        if let live = liveColumnWidths[column.id] { return live }
        return (storedColumnWidthPoints[column.id] ?? defaultTableColumnWidth) * columnScale
    }

    private func clampColumnWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minTableColumnWidth * columnScale), maxTableColumnWidth * columnScale)
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
                    liveColumnWidths = [:]
                }
                guard let start = scaleStart else { return }
                applyScale(start: start, translation: value.translation)
            }
            .onEnded { value in
                defer {
                    scaleStart = nil
                    scaleAxisAtStart = .both
                }
                guard let start = scaleStart else { return }
                applyScale(start: start, translation: value.translation)
                liveColumnWidths = [:]
                persistGridScale(columnScale, rowScale)
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
        persistGridScale(1.0, 1.0)
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

    var displayName: String {
        if let location, !location.isEmpty { return "\(name) \u{2014} \(location)" }
        return name
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
    let tableSource: String
    var onUpdateSources: ([CellSourceEntry]) -> Void
    var onClose: () -> Void
    @State private var sourceEntries: [CellSourceEntry] = []
    @State private var newSource: String = ""
    @State private var newLocation: String = ""
    @State private var loaded = false
    @Query private var allSources: [Source]

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
            TextEditor(text: $value)
                .font(.title3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                Text("SOURCES")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if sourceEntries.isEmpty {
                    Text(tableSource.isEmpty ? "Inheriting table source" : "Inheriting table (\(tableSource))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    TextField("Location (e.g. Tablet V, lines 120\u{2013}143)", text: $newLocation)
                        .textFieldStyle(.roundedBorder)
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
        .frame(width: 440, height: 460)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            sourceEntries = cell.sources
        }
    }
}

/// The last 24pt of a column header, ending at the column's right edge. An
/// unconditional empty anchor pins the rule to the strip's trailing edge (the
/// column boundary) so the visible line and the grab zone always coincide. The
/// zone fills with an accent highlight on hover or while resizing.
private struct ColumnResizeHandle: View {
    var isActive: Bool
    var isHovered: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.clear
                .frame(width: 24)
            if isActive || isHovered {
                Rectangle()
                    .fill(Color.accentColor.opacity(isActive ? 0.18 : 0.12))
                    .frame(width: 24)
            }
            Rectangle()
                .fill(
                    isActive
                        ? Color.accentColor
                        : (isHovered ? Color.accentColor.opacity(0.8) : Color(nsColor: .systemGray).opacity(0.65))
                )
                .frame(width: isActive || isHovered ? 3 : 2)
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
    var hasOwnSource: Bool = false
    var onOpen: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 1) {
            Text(value.isEmpty ? "—" : value)
                .font(.title3)
                .foregroundStyle(value.isEmpty ? .tertiary : .primary)
                .lineLimit(4)
            if hasOwnSource && !value.isEmpty {
                Text("*")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(Color(nsColor: .windowBackgroundColor))
        .help(hasOwnSource ? "Has its own source (*). Click to open editor." : "")
        .onTapGesture { onOpen?() }
    }
}

