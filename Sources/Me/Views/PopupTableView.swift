import SwiftUI
import SwiftData

struct PopupTableView: View {
    let table: PopupTable
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var cellValues: [String: String] = [:]
    @State private var cellSources: [String: String] = [:]
    @State private var isEditing = false
    @State private var editingCell: PopupTableCell?

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
                    .font(.title3)
                if !table.tableDescription.isEmpty {
                    Text(table.tableDescription)
                        .font(.body)
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
                                        isEditing: isEditing,
                                        hasOwnSource: !(cellSources[key] ?? "").isEmpty,
                                        onOpenEditor: {
                                            openCellEditor(attributeID: attribute.persistentModelID, columnID: column.id)
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
                Button(action: { isEditing.toggle() }) {
                    Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                }
                .buttonStyle(.bordered)
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear { loadCells() }
        .sheet(item: $editingCell) { cell in
            TableCellEditor(cell: cell, tableSource: table.source ?? "") {
                loadCells()
            }
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

    private func loadCells() {
        cellValues = [:]
        cellSources = [:]
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
        cellSources[key] = cell.source ?? ""
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

    private func openCellEditor(attributeID: PersistentIdentifier, columnID: PersistentIdentifier) {
        editingCell = ensureCell(attributeID: attributeID, columnID: columnID)
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

private struct CellView: View {
    @Binding var value: String
    let isEditing: Bool
    var hasOwnSource: Bool = false
    var onOpenEditor: () -> Void = {}

    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $value)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, 6)
            } else {
                Text(value.isEmpty ? "—" : value)
                    .font(.body)
                    .foregroundStyle(value.isEmpty ? .tertiary : .primary)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .topTrailing) {
            if !isEditing && hasOwnSource {
                Image(systemName: "doc.text")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(3)
                    .help("Has its own source (double-click to view)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpenEditor)
    }
}

private struct TableCellEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let cell: PopupTableCell
    let tableSource: String
    var onSaved: () -> Void
    @State private var value: String = ""
    @State private var sourceSelection: String = ""
    @State private var loaded = false
    @Query private var allSources: [Source]

    private var availableSourceNames: [String] {
        var names = Set(allSources.map(\.name))
        if !sourceSelection.isEmpty { names.insert(sourceSelection) }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cell.attribute?.name ?? "Cell")
                    .font(.headline)
                Text(inheritedHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VALUE")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Value", text: $value, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("SOURCE")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Picker("Source", selection: $sourceSelection) {
                        Text(tableSource.isEmpty ? "None" : "Inherit table (\(tableSource))").tag("")
                        ForEach(availableSourceNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 420, height: 300)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            value = cell.value ?? ""
            sourceSelection = cell.source ?? ""
        }
    }

    private var inheritedHint: String {
        if tableSource.isEmpty { return "No table-wide source set." }
        return "Cells without their own source inherit the table's source: \(tableSource)"
    }

    private func save() {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        cell.value = trimmedValue.isEmpty ? nil : trimmedValue
        cell.setSourceText(sourceSelection.isEmpty ? nil : sourceSelection, context: modelContext)
        try? modelContext.save()
        onSaved()
        dismiss()
    }
}
