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

    private var figures: [Figure] {
        table.figures
    }

    private func cellKey(attributeID: PersistentIdentifier, figureID: PersistentIdentifier) -> String {
        "\(attributeID.hashValue)-\(figureID.hashValue)"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(table.name)
                    .font(.headline)
                if !table.tableDescription.isEmpty {
                    Text(table.tableDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            if figures.isEmpty || sortedAttributes.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tablecells")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(figures.isEmpty ? "No figures in this table" : "No attributes defined")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Add figures and attributes in the table settings")
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
                            ForEach(figures) { figure in
                                FigureColumnHeader(figure: figure)
                                    .frame(width: 180, height: 120)
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor))

                        ForEach(sortedAttributes) { attribute in
                            GridRow {
                                AttributeRowHeader(attribute: attribute)
                                    .frame(width: 160, height: 120)
                                ForEach(figures) { figure in
                                    CellView(
                                        value: cellBinding(attributeID: attribute.persistentModelID, figureID: figure.persistentModelID),
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

    private func loadCells() {
        for cell in table.cells {
            if let attrID = cell.attribute?.persistentModelID,
               let figID = cell.figure?.persistentModelID {
                cellValues[cellKey(attributeID: attrID, figureID: figID)] = cell.value ?? ""
            }
        }
    }

    private func cellBinding(attributeID: PersistentIdentifier, figureID: PersistentIdentifier) -> Binding<String> {
        let key = cellKey(attributeID: attributeID, figureID: figureID)
        return Binding(
            get: { cellValues[key] ?? "" },
            set: { newValue in
                cellValues[key] = newValue
                saveCell(attributeID: attributeID, figureID: figureID, value: newValue)
            }
        )
    }

    private func saveCell(attributeID: PersistentIdentifier, figureID: PersistentIdentifier, value: String) {
        guard let attribute = table.attributes.first(where: { $0.persistentModelID == attributeID }),
              let figure = table.figures.first(where: { $0.persistentModelID == figureID }) else { return }

        if let existing = table.cells.first(where: { cell in
            cell.attribute?.persistentModelID == attributeID && cell.figure?.persistentModelID == figureID
        }) {
            existing.value = value.isEmpty ? nil : value
        } else {
            let cell = PopupTableCell(attribute: attribute, figure: figure, value: value.isEmpty ? nil : value)
            table.cells.append(cell)
            modelContext.insert(cell)
        }
        try? modelContext.save()
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
