import SwiftUI
import SwiftData

struct PopupTableView: View {
    let table: PopupTable
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var cellValues: [String: String] = [:]
    @State private var isEditing = false

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
                                    CellView(
                                        value: cellBinding(attributeID: attribute.persistentModelID, columnID: column.id),
                                        isEditing: isEditing
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
        for cell in table.cells {
            if let attrID = cell.attribute?.persistentModelID {
                if let figID = cell.figure?.persistentModelID {
                    cellValues[cellKey(attributeID: attrID, columnID: figID)] = cell.value ?? ""
                } else if let colID = cell.column?.persistentModelID {
                    cellValues[cellKey(attributeID: attrID, columnID: colID)] = cell.value ?? ""
                }
            }
        }
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
        guard let attribute = table.attributes.first(where: { $0.persistentModelID == attributeID }) else { return }

        if let existing = table.cells.first(where: { cell in
            cell.attribute?.persistentModelID == attributeID &&
            (cell.figure?.persistentModelID ?? cell.column?.persistentModelID) == columnID
        }) {
            existing.value = value.isEmpty ? nil : value
        } else {
            switch table.columnMode {
            case .figures:
                guard let figure = table.figures.first(where: { $0.persistentModelID == columnID }) else { return }
                let cell = PopupTableCell(attribute: attribute, figure: figure, value: value.isEmpty ? nil : value)
                table.cells.append(cell)
                modelContext.insert(cell)
            case .strings:
                guard let column = table.columns.first(where: { $0.persistentModelID == columnID }) else { return }
                let cell = PopupTableCell(attribute: attribute, column: column, value: value.isEmpty ? nil : value)
                table.cells.append(cell)
                modelContext.insert(cell)
            }
        }
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
    }
}
