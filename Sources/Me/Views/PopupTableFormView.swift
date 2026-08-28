import SwiftUI
import SwiftData

struct PopupTableFormView: View {
    var table: PopupTable?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Figure.name) private var allFigures: [Figure]

    @State private var workingTable: PopupTable?
    @State private var name: String = ""
    @State private var tableDescription: String = ""
    @State private var sourceSelection: String = ""
    @Query private var allSources: [Source]

    private var availableSourceNames: [String] {
        var names = Set(allSources.map(\.name))
        if !sourceSelection.isEmpty { names.insert(sourceSelection) }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    @State private var selectedFigureIDs: Set<PersistentIdentifier> = []
    @State private var attributeName: String = ""
    @State private var searchText: String = ""
    @State private var columnMode: PopupTableColumnMode = .figures
    @State private var columnName: String = ""
    @State private var columnLabels: [String] = []

    private var currentTable: PopupTable? { workingTable ?? table }

    private var filteredFigures: [FigureSearchResult] {
        searchFigures(allFigures, query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(table == nil ? "New Comparison Table" : "Edit Comparison Table")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(table == nil ? "Create" : "Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            Form {
                Section("Table") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $tableDescription, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Source", selection: $sourceSelection) {
                        Text("None").tag("")
                        ForEach(availableSourceNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .help("Attributes all cell values to one source. Individual cells can override this with their own source.")
                }

                Section("Columns") {
                    Picker("Column mode", selection: $columnMode) {
                        ForEach([PopupTableColumnMode.figures, .strings], id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("Figures uses deities across the top; Text labels uses flat strings (e.g. worship activities).")
                }

                if columnMode == .figures {
                    Section {
                        FigurePickerSection(
                            allFigures: allFigures,
                            filteredFigures: filteredFigures,
                            selectedFigureIDs: $selectedFigureIDs,
                            searchText: $searchText
                        )
                    } header: {
                        Text("Figures (\(selectedFigureIDs.count) selected)")
                    }
                } else {
                    Section("Text Columns") {
                        HStack {
                            TextField("New column label", text: $columnName)
                                .textFieldStyle(.roundedBorder)
                            Button(action: addColumnLabel) {
                                Image(systemName: "plus")
                            }
                            .disabled(columnName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        if !columnLabels.isEmpty {
                            ForEach(columnLabels.indices, id: \.self) { index in
                                HStack {
                                    Image(systemName: "textformat")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 12)
                                    Text(columnLabels[index])
                                    Spacer()
                                    Button(action: { columnLabels.remove(at: index) }) {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .onMove { from, to in
                                columnLabels.move(fromOffsets: from, toOffset: to)
                            }
                        } else if columnName.isEmpty {
                            Text("No columns yet")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Attributes") {
                    HStack {
                        TextField("New attribute name", text: $attributeName)
                            .textFieldStyle(.roundedBorder)
                        Button(action: addAttribute) {
                            Image(systemName: "plus")
                        }
                        .disabled(attributeName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let tbl = currentTable, !tbl.attributes.isEmpty {
                        ForEach(tbl.attributes.sorted { ($0.orderIndex ?? Int.max) < ($1.orderIndex ?? Int.max) }) { attr in
                            HStack {
                                Text(attr.name)
                                Spacer()
                                Button(action: { removeAttribute(attr) }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onMove { from, to in
                            moveAttributes(from: from, to: to)
                        }
                    } else if attributeName.isEmpty {
                        Text("No attributes yet")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 520, height: 580)
        .onAppear { load() }
    }

    private func load() {
        if let table {
            workingTable = table
            name = table.name
            tableDescription = table.tableDescription
            sourceSelection = table.source ?? ""
            columnMode = table.columnMode
            columnLabels = table.columns
                .sorted { ($0.orderIndex ?? Int.max) < ($1.orderIndex ?? Int.max) }
                .map(\.name)
            selectedFigureIDs = Set(table.figures.map(\.persistentModelID))
        } else {
            let newTable = PopupTable()
            modelContext.insert(newTable)
            workingTable = newTable
        }
    }

    private func save() {
        guard let tbl = currentTable else { return }
        let isNew = workingTable == nil
        if isNew { modelContext.insert(tbl) }
        tbl.name = name.trimmingCharacters(in: .whitespaces)
        tbl.tableDescription = tableDescription.trimmingCharacters(in: .whitespaces)
        tbl.setSourceText(sourceSelection.isEmpty ? nil : sourceSelection, context: modelContext)
        tbl.columnMode = columnMode

        switch columnMode {
        case .figures:
            removeStringColumns(from: tbl)
            syncFigureColumns(in: tbl)
        case .strings:
            removeFigureColumns(from: tbl)
            syncStringColumns(in: tbl)
        }

        try? modelContext.save()
        dismiss()
    }

    private func removeStringColumns(from tbl: PopupTable) {
        tbl.removeStringColumnLayouts(context: modelContext)
        for column in tbl.columns {
            let doomed = tbl.cells.filter { $0.column?.persistentModelID == column.persistentModelID }
            for cell in doomed {
                tbl.cells.removeAll { $0.persistentModelID == cell.persistentModelID }
                modelContext.delete(cell)
            }
            tbl.columns.removeAll { $0.persistentModelID == column.persistentModelID }
            modelContext.delete(column)
        }
    }

    private func removeFigureColumns(from tbl: PopupTable) {
        tbl.removeFigureColumnLayouts(context: modelContext)
        tbl.figures = []
        let figureCells = tbl.cells.filter { $0.figure != nil }
        for cell in figureCells {
            tbl.cells.removeAll { $0.persistentModelID == cell.persistentModelID }
            modelContext.delete(cell)
        }
    }

    private func syncFigureColumns(in tbl: PopupTable) {
        let currentFigureIDs = selectedFigureIDs
        tbl.removeFigureColumnLayouts(except: currentFigureIDs, context: modelContext)
        let currentFigures = allFigures.filter { currentFigureIDs.contains($0.persistentModelID) }
        tbl.figures = currentFigures

        let existingCells = tbl.cells

        for cell in existingCells {
            if let figID = cell.figure?.persistentModelID, !currentFigureIDs.contains(figID) {
                tbl.cells.removeAll { $0.persistentModelID == cell.persistentModelID }
                modelContext.delete(cell)
            }
        }

        for figID in currentFigureIDs {
            guard let figure = allFigures.first(where: { $0.persistentModelID == figID }) else { continue }
            for attr in tbl.attributes {
                let alreadyHasCell = tbl.cells.contains { cell in
                    cell.attribute?.persistentModelID == attr.persistentModelID &&
                    cell.figure?.persistentModelID == figID
                }
                if !alreadyHasCell {
                    let cell = PopupTableCell(attribute: attr, figure: figure)
                    tbl.cells.append(cell)
                    modelContext.insert(cell)
                }
            }
        }
    }

    private func syncStringColumns(in tbl: PopupTable) {
        let currentLabels = columnLabels.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let existingByName = Dictionary(tbl.columns.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        for column in tbl.columns where !currentLabels.contains(column.name) {
            let doomed = tbl.cells.filter { $0.column?.persistentModelID == column.persistentModelID }
            for cell in doomed {
                tbl.cells.removeAll { $0.persistentModelID == cell.persistentModelID }
                modelContext.delete(cell)
            }
            tbl.columns.removeAll { $0.persistentModelID == column.persistentModelID }
            modelContext.delete(column)
        }

        for (index, label) in currentLabels.enumerated() {
            if let existing = existingByName[label] {
                existing.orderIndex = index
            } else {
                let column = PopupTableColumn(name: label, orderIndex: index)
                tbl.columns.append(column)
                modelContext.insert(column)
            }
        }

        for attr in tbl.attributes {
            for column in tbl.columns {
                let alreadyHasCell = tbl.cells.contains { cell in
                    cell.attribute?.persistentModelID == attr.persistentModelID &&
                    cell.column?.persistentModelID == column.persistentModelID
                }
                if !alreadyHasCell {
                    let cell = PopupTableCell(attribute: attr, column: column)
                    tbl.cells.append(cell)
                    modelContext.insert(cell)
                }
            }
        }
    }

    private func addColumnLabel() {
        let label = columnName.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, !columnLabels.contains(label) else { return }
        columnLabels.append(label)
        columnName = ""
    }

    private func addAttribute() {
        guard let table = currentTable, !attributeName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let maxIndex = table.attributes.compactMap(\.orderIndex).max() ?? -1
        let attr = PopupTableAttribute(name: attributeName.trimmingCharacters(in: .whitespaces), orderIndex: maxIndex + 1)
        table.attributes.append(attr)
        modelContext.insert(attr)
        attributeName = ""

        for cell in table.cells where cell.attribute == nil {
            cell.attribute = attr
        }

        switch columnMode {
        case .figures:
            for figID in selectedFigureIDs {
                let alreadyHasCell = table.cells.contains { cell in
                    cell.attribute?.persistentModelID == attr.persistentModelID &&
                    cell.figure?.persistentModelID == figID
                }
                if !alreadyHasCell, let figure = allFigures.first(where: { $0.persistentModelID == figID }) {
                    let cell = PopupTableCell(attribute: attr, figure: figure)
                    table.cells.append(cell)
                    modelContext.insert(cell)
                }
            }
        case .strings:
            for column in table.columns {
                let alreadyHasCell = table.cells.contains { cell in
                    cell.attribute?.persistentModelID == attr.persistentModelID &&
                    cell.column?.persistentModelID == column.persistentModelID
                }
                if !alreadyHasCell {
                    let cell = PopupTableCell(attribute: attr, column: column)
                    table.cells.append(cell)
                    modelContext.insert(cell)
                }
            }
        }

        try? modelContext.save()
    }

    private func removeAttribute(_ attr: PopupTableAttribute) {
        for cell in attr.cells { modelContext.delete(cell) }
        modelContext.delete(attr)
        try? modelContext.save()
    }

    private func moveAttributes(from source: IndexSet, to destination: Int) {
        guard let table = currentTable else { return }
        var attrs = table.attributes.sorted { ($0.orderIndex ?? Int.max) < ($1.orderIndex ?? Int.max) }
        attrs.move(fromOffsets: source, toOffset: destination)
        for (index, attr) in attrs.enumerated() {
            attr.orderIndex = index
        }
        try? modelContext.save()
    }
}

private struct FigurePickerSection: View {
    let allFigures: [Figure]
    let filteredFigures: [FigureSearchResult]
    @Binding var selectedFigureIDs: Set<PersistentIdentifier>
    @Binding var searchText: String

    private var selectedFigures: [Figure] {
        allFigures.filter { selectedFigureIDs.contains($0.persistentModelID) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !selectedFigures.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(selectedFigures, id: \.persistentModelID) { figure in
                        HStack(spacing: 4) {
                            if let type = figure.figureType {
                                Image(systemName: type.icon)
                                    .font(.system(size: 9))
                                    .foregroundStyle(type.color)
                            }
                            Text(figure.name)
                                .font(.caption)
                            Button {
                                selectedFigureIDs.remove(figure.persistentModelID)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                }
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search figures...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredFigures) { result in
                        let figure = result.figure
                        let isSelected = selectedFigureIDs.contains(figure.persistentModelID)
                        Button(action: {
                            if isSelected {
                                selectedFigureIDs.remove(figure.persistentModelID)
                            } else {
                                selectedFigureIDs.insert(figure.persistentModelID)
                                searchText = ""
                            }
                        }) {
                            HStack(spacing: 6) {
                                if let type = figure.figureType {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 10))
                                        .foregroundStyle(type.color)
                                        .frame(width: 16)
                                }
                                Text(result.displayName)
                                    .font(.callout)
                                    .foregroundStyle(isSelected ? .primary : .secondary)
                                if let disambiguation = figure.disambiguation, !disambiguation.isEmpty {
                                    Text(disambiguation)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
}
