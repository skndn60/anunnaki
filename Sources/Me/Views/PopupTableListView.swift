import SwiftUI
import SwiftData

struct PopupTableListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PopupTable.name) private var tables: [PopupTable]
    @State private var showingAddSheet = false
    @State private var editingTable: PopupTable?
    @State private var selectedTableID: PersistentIdentifier?
    @State private var showingGrid: PopupTable?

    private var selectedTable: PopupTable? {
        guard let id = selectedTableID else { return nil }
        return tables.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Comparison Tables")
                        .font(.title2.bold())
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Table", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                Divider()

                if tables.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "tablecells")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No comparison tables")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Compare figures across custom attributes")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(tables, selection: $selectedTableID) { table in
                        PopupTableRow(table: table)
                            .tag(table.persistentModelID)
                            .contextMenu {
                                Button("Open Grid") { showingGrid = table }
                                Button("Edit") { editingTable = table }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    selectedTableID = nil
                                    modelContext.delete(table)
                                }
                            }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity)

            Group {
                if let table = selectedTable {
                    VStack(spacing: 0) {
                        DetailToolbar(
                            onEdit: { editingTable = table },
                            onDelete: {
                                selectedTableID = nil
                                modelContext.delete(table)
                            },
                            onClose: { selectedTableID = nil },
                            leadingButtons: [
                                ToolbarButton(icon: "tablecells", color: .accentColor, help: "Open grid") {
                                    showingGrid = table
                                }
                            ]
                        )
                        PopupTableDetailView(table: table)
                    }
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)
                    .background(.thinMaterial)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: selectedTableID)
        }
        .sheet(isPresented: $showingAddSheet) {
            PopupTableFormView(table: nil)
        }
        .sheet(item: $editingTable) { table in
            PopupTableFormView(table: table)
        }
        .sheet(item: $showingGrid) { table in
            PopupTableView(table: table)
        }
    }
}

private struct PopupTableRow: View {
    let table: PopupTable
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tablecells")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(table.name)
                    .font(.callout)
                    .lineLimit(1)
                Text(table.columnMode == .strings
                    ? "\(table.columns.count) columns, \(table.attributes.count) attributes"
                    : "\(table.figures.count) figures, \(table.attributes.count) attributes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct PopupTableDetailView: View {
    let table: PopupTable
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(table.name)
                    .font(.headline)
                if !table.tableDescription.isEmpty {
                    Text(table.tableDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let tableSource = table.source, !tableSource.isEmpty {
                    Label(tableSource, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Table-wide source; individual cells may override")
                }
                Divider()
                HStack(spacing: 16) {
                    if table.columnMode == .strings {
                        Label("\(table.columns.count) columns", systemImage: "textformat")
                    } else {
                        Label("\(table.figures.count) figures", systemImage: "person.2")
                    }
                    Label("\(table.attributes.count) attributes", systemImage: "list.bullet")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !table.attributes.isEmpty {
                    Divider()
                    Text("Attributes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(table.attributes.sorted { ($0.orderIndex ?? Int.max) < ($1.orderIndex ?? Int.max) }) { attr in
                        HStack(spacing: 6) {
                            Image(systemName: "text.alignleft")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(width: 12)
                            Text(attr.name)
                                .font(.callout)
                            Spacer()
                        }
                        .padding(.vertical, 1)
                    }
                }

                if table.columnMode == .strings {
                    if !table.columns.isEmpty {
                        Divider()
                        Text("Columns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        ForEach(table.columns.sorted { ($0.orderIndex ?? Int.max) < ($1.orderIndex ?? Int.max) }) { column in
                            HStack(spacing: 6) {
                                Image(systemName: "textformat")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 12)
                                Text(column.name)
                                    .font(.callout)
                                Spacer()
                            }
                            .padding(.vertical, 1)
                        }
                    }
                } else if !table.figures.isEmpty {
                    Divider()
                    Text("Figures")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(table.figures) { figure in
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(width: 12)
                            Text(figure.name)
                                .font(.callout)
                            Spacer()
                        }
                        .padding(.vertical, 1)
                    }
                }

                if (table.columnMode == .strings ? table.columns.isEmpty : table.figures.isEmpty) || table.attributes.isEmpty {
                    Divider()
                    Text(table.columnMode == .strings
                        ? "Add columns and attributes to start comparing"
                        : "Add figures and attributes to start comparing")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
            .padding()
        }
    }
}
