import SwiftUI
import SwiftData

struct PopupTableView: View {
    let table: PopupTable
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var cellValues: [String: String] = [:]
    @State private var cellSourceNames: [String: [CellSourceEntry]] = [:]
    @State private var activeCell: ActiveCell?

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
                                .frame(width: 160, height: 120)
                            ForEach(columns) { column in
                                columnHeader(column)
                                    .frame(width: 180, height: 120)
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor))

                        ForEach(sortedAttributes) { attribute in
                            GridRow {
                                AttributeRowHeader(attribute: attribute)
                                    .frame(width: 160, height: 120)
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
                                    .frame(width: 180, height: 120)
                                }
                            }
                        }
                    }
                    .padding(1)
                    .background(Color(nsColor: .separatorColor))
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear { loadCells() }
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
        HStack(spacing: 6) {
            if let mugshot = figure.mugshotImage {
                MugshotView(imageURL: mugshot.fileURL, cropRect: figure.mugshotCropRect.flatMap { ImageCropRect(encoded: $0) }, size: 32, fallbackColor: figure.figureType.map { Color(hex: $0.colorHex) } ?? .gray, fallbackIcon: figure.figureType?.icon ?? "person.circle", identification: figure.mugshotIdentification)
            } else {
                Circle()
                    .fill(figure.figureType.map { Color(hex: $0.colorHex) } ?? .gray)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: figure.figureType?.icon ?? "person.circle")
                            .font(.caption)
                            .foregroundStyle(.white)
                    )
            }
            Text(figure.name)
                .font(.body.bold())
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct StringColumnHeader: View {
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "textformat")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(name)
                .font(.body.bold())
                .lineLimit(2)
        }
        .padding(.horizontal, 8)
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

