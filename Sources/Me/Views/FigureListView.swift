import SwiftUI
import SwiftData

/// Snapshot of a figure's row presentation, precomputed off the render path so
/// list rows never fault a live `Figure` (or its relationships) during a layout
/// pass — the macOS 26 SwiftData assert-on-fault class of crash that a merge or
/// delete can trigger while the sidebar figures list is visible.
private struct FigureRowDisplay: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let disambiguation: String?
    let domain: String
    let typeName: String
    let typeColor: Color
    let typeIcon: String
    let genderSymbol: String
    let isConcept: Bool
    let hasUnresolvedSticky: Bool
    let birthDateLabel: String
    let isRed: Bool
    let popupTableIDs: [PersistentIdentifier]
    let popupTableNames: [String]
}

/// Input screen for managing figures (deities, humans, etc.)
struct FigureListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.userSession) private var userSession
    @Environment(\.openWindow) private var openWindow
    @Query private var figures: [Figure]
    @Query private var figureTypes: [FigureType]
    @Query private var allGroups: [FigureGroup]
    @Query(sort: \PopupTable.name) private var popupTables: [PopupTable]
    @State private var showingAddSheet = false
    @State private var editingFigure: Figure?
    @State private var selectedFigureID: PersistentIdentifier?
    @State private var sortOrder: FigureSortOrder = .name
    @State private var imageDetailImage: ImageAsset?
    @State private var showDeleteConfirm = false
    @State private var selectedTypeFilters: Set<String> = []
    @State private var showDescriptionEditor = false
    @State private var editRichDescription: Data? = nil
    @State private var editPlainDescription = ""
    @State private var selectedDynastyGroup: FigureGroup?
    @State private var rows: [FigureRowDisplay] = []
    @State private var openTable: PopupTable?
    @DetailWidth(.figure) private var detailWidth

    enum FigureSortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
        case domain = "Domain"
    }

    /// The dynasties available in the dropdown: the direct subgroups of the Sumerian King List group(s).
    private var dynasties: [FigureGroup] {
        allGroups
            .filter { $0.kind == .skl }
            .flatMap { $0.subgroups ?? [] }
            .sorted { ($0.orderIndex, $0.name) < ($1.orderIndex, $1.name) }
    }

    private var selectedFigure: Figure? {
        guard let id = selectedFigureID,
              rows.contains(where: { $0.id == id }) else { return nil }
        return figures.first { $0.persistentModelID == id }
    }

    private var filteredRows: [FigureRowDisplay] {
        var result = rows
        if !selectedTypeFilters.isEmpty {
            result = result.filter { selectedTypeFilters.contains($0.typeName) }
        }
        switch sortOrder {
        case .name: result.sort { sortName(for: $0.name) < sortName(for: $1.name) }
        case .type: result.sort { $0.typeName < $1.typeName }
        case .domain: result.sort { $0.domain < $1.domain }
        }
        return result
    }

    private var groupedRows: [(key: String, rows: [FigureRowDisplay])] {
        Dictionary(grouping: filteredRows) { row in
            switch sortOrder {
            case .name: String(sortName(for: row.name).uppercased().prefix(1))
            case .type: row.typeName.isEmpty ? "?" : row.typeName
            case .domain: row.domain.isEmpty ? "?" : row.domain
            }
        }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, rows: $0.value.sorted { sortName(for: $0.name) < sortName(for: $1.name) }) }
    }

    private func selectFigure(_ id: PersistentIdentifier) {
        selectedFigureID = id
    }

    var body: some View {
        HStack(spacing: 0) {
            leftPane
            detailPane
        }
        .sheet(isPresented: $showingAddSheet) {
            FigureFormView(figure: nil)
        }
        .sheet(item: $editingFigure) { figure in
            FigureFormView(figure: figure)
        }
        .sheet(isPresented: $showDescriptionEditor) {
            if let figure = selectedFigure {
                DescriptionEditorSheet(
                    entityName: figure.name,
                    richDescription: $editRichDescription,
                    plainDescription: $editPlainDescription,
                    onSave: {
                        figure.richDescription = editRichDescription
                        figure.figureDescription = editPlainDescription
                        try? modelContext.save()
                    }
                )
            }
        }
        .sheet(item: $openTable) { table in
            PopupTableView(table: table)
        }

        .onChange(of: imageDetailImage) { _, newValue in
            if let image = newValue {
                openWindow(id: "image-detail", value: image.persistentModelID)
                imageDetailImage = nil
            }
        }
        .alert("Delete Figure?", isPresented: $showDeleteConfirm, presenting: selectedFigure) { figure in
            Button("Delete", role: .destructive) { deleteFigure(figure) }
            Button("Cancel", role: .cancel) {}
        } message: { figure in
            Text("Delete \"\(figure.name)\"? This cannot be undone.")
        }
        .onAppear {
            consumePendingNavigation()
        }
        .onChange(of: coordinator?.pendingFigureID) { _, _ in
            consumePendingNavigation()
        }
        .task {
            rebuildRows()
        }
        .onChange(of: figures.map(\.persistentModelID)) { _, _ in
            rebuildRows()
        }
        .onChange(of: popupTables.map(\.persistentModelID)) { _, _ in
            rebuildRows()
        }
        .onChange(of: selectedDynastyGroup?.persistentModelID) { _, _ in
            rebuildRows()
        }
        .onChange(of: showingAddSheet) { _, _ in
            rebuildRows()
        }
        .onChange(of: editingFigure?.persistentModelID) { _, _ in
            rebuildRows()
        }
        .onChange(of: showDescriptionEditor) { _, _ in
            rebuildRows()
        }
    }

    private var leftPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Figures")
                    .font(.title2.bold())
                Spacer()
                Picker("Highlight dynasty", selection: $selectedDynastyGroup) {
                    Text("None").tag(FigureGroup?.none)
                    ForEach(dynasties) { dynasty in
                        Text(dynasty.name).tag(dynasty as FigureGroup?)
                    }
                }
                .frame(width: 180)
                .help("Select a dynasty to draw its rulers red in this list.")
                Picker("Sort", selection: $sortOrder) {
                    ForEach(FigureSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .frame(width: 130)
                Button(action: { showingAddSheet = true }) {
                    Label("Add Figure", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Breadcrumbs
            let coordinatorHistory = coordinator?.history ?? []
            if !coordinatorHistory.isEmpty {
                BreadcrumbBar(
                    breadcrumbs: coordinatorHistory.map { Breadcrumb(id: $0.id, name: $0.name, icon: $0.item.icon) },
                    onNavigate: { index in coordinator?.navigateToHistory(at: index) },
                    onClear: { coordinator?.history.removeAll() }
                )
            }
            if !figureTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(figureTypes) { type in
                            typeFilterButton(type)
                        }
                        if !selectedTypeFilters.isEmpty {
                            Button("Clear") { selectedTypeFilters.removeAll() }
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }

            Divider()

            if filteredRows.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    if figures.isEmpty {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No figures yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("No figures to display")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(selection: $selectedFigureID) {
                        ForEach(groupedRows, id: \.key) { group in
                            figureGroupSection(group)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .onChange(of: selectedFigureID) { _, newValue in
                        if let id = newValue {
                            DispatchQueue.main.async {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 450, maxWidth: .infinity)
    }

    private var detailPane: some View {
        Group {
            if let figure = selectedFigure {
                let isCollectiveFigure = figure.figureType?.name.localizedCaseInsensitiveContains("Collective") ?? false
                // ResizableDivider(width: $detailWidth, range: 200...800)
                VStack(spacing: 0) {
                    DetailToolbar(
                        onEdit: { editingFigure = figure },
                        onDelete: { showDeleteConfirm = true },
                        onClose: { selectedFigureID = nil },
                        onEditDescription: {
                            editRichDescription = figure.richDescription
                            editPlainDescription = figure.figureDescription
                            showDescriptionEditor = true
                        },
                        leadingButtons: [
                            ToolbarButton(icon: "tree", color: .green, help: "Show in inline lineage tree", isEnabled: !isCollectiveFigure) {
                                coordinator?.navigateToLineageFigure(figure.persistentModelID)
                            }
                        ]
                    )
                    FigureDetailView(
                        figure: figure,
                        onSelectFigure: { selected in
                            coordinator?.pushHistory(id: figure.persistentModelID, name: figure.name, item: .figures)
                            coordinator?.navigateToFigure(selected.persistentModelID, name: selected.name, recordHistory: false)
                        },
                        onSelectPlace: { place in
                            coordinator?.pushHistory(id: figure.persistentModelID, name: figure.name, item: .figures)
                            coordinator?.navigateToPlace(place.persistentModelID, name: place.name, recordHistory: false)
                        },
                        onSelectEvent: { event in
                            coordinator?.pushHistory(id: figure.persistentModelID, name: figure.name, item: .figures)
                            coordinator?.navigateToEvent(event.persistentModelID, name: event.name, recordHistory: false)
                        },
                        onSelectImage: { imageDetailImage = $0 }
                    )
                }
                .frame(width: detailWidth)
                .frame(maxHeight: .infinity)
                .background(.thinMaterial)
            }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.25), value: selectedFigureID)
    }

    private func consumePendingNavigation() {
        guard let id = coordinator?.consumePendingFigureID() else { return }
        if figures.contains(where: { $0.persistentModelID == id }) {
            Task { @MainActor in
                selectFigure(id)
            }
        }
    }

    /// Rebuilds the value-snapshot rows from the live models. Runs only on
    /// change triggers (never during a body render), so rows can't fault a
    /// model that a concurrent merge or delete removed mid-layout.
    private func rebuildRows() {
        let redIDs = redFigureIDs()
        let tablesByFigureID = popupTablesByFigureID()
        rows = figures.map { figure in
            let id = figure.persistentModelID
            let tables = tablesByFigureID[id] ?? []
            return FigureRowDisplay(
                id: id,
                name: figure.name,
                disambiguation: figure.disambiguation,
                domain: figure.domain,
                typeName: figure.figureType?.name ?? "",
                typeColor: figure.figureType?.color ?? .gray,
                typeIcon: figure.figureType?.icon ?? "questionmark",
                genderSymbol: figure.gender.symbol,
                isConcept: figure.isConcept,
                hasUnresolvedSticky: figure.stickies.contains(where: { !$0.isResolved }),
                birthDateLabel: figure.birthDate.displayLabel,
                isRed: redIDs.contains(id),
                popupTableIDs: tables.map(\.id),
                popupTableNames: tables.map(\.name)
            )
        }
        if let selected = selectedFigureID, !rows.contains(where: { $0.id == selected }) {
            selectedFigureID = nil
        }
    }

    private func popupTablesByFigureID() -> [PersistentIdentifier: [(name: String, id: PersistentIdentifier)]] {
        var result: [PersistentIdentifier: [(String, PersistentIdentifier)]] = [:]
        for table in popupTables {
            for figure in table.figures {
                result[figure.persistentModelID, default: []].append((table.name, table.persistentModelID))
            }
        }
        return result
    }

    private func redFigureIDs() -> Set<PersistentIdentifier> {
        guard let selected = selectedDynastyGroup else { return [] }
        return Set(selected.figureAssociations.compactMap { $0.figure?.persistentModelID })
    }

    private func typeFilterButton(_ type: FigureType) -> some View {
        Button(action: {
            if selectedTypeFilters.contains(type.name) {
                selectedTypeFilters.remove(type.name)
            } else {
                selectedTypeFilters.insert(type.name)
            }
        }) {
            HStack(spacing: 4) {
                Circle().fill(type.color).frame(width: 7, height: 7)
                Text(type.name).font(.caption)
                if selectedTypeFilters.contains(type.name) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTypeFilters.contains(type.name) ? type.color.opacity(0.2) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedTypeFilters.contains(type.name) ? type.color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func figureGroupSection(_ group: (key: String, rows: [FigureRowDisplay])) -> some View {
        Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
            ForEach(group.rows) { row in
                FigureRow(display: row, onOpenTable: { id in
                    openTable = modelContext.model(for: id) as? PopupTable
                })
                    .tag(row.id)
                    .id(row.id)
                    .contextMenu {
                        Button("Edit") {
                            if let figure = modelContext.model(for: row.id) as? Figure {
                                editingFigure = figure
                            }
                        }
                        Button("Show in Lineage Tree") {
                            coordinator?.navigateToLineageFigure(row.id)
                        }
                        .disabled(row.typeName.localizedCaseInsensitiveContains("Collective"))
                        Divider()
                        Button("Delete", role: .destructive) {
                            selectedFigureID = row.id
                            showDeleteConfirm = true
                        }
                    }
            }
        }
    }

    private func deleteFigure(_ figure: Figure) {
        if selectedFigureID == figure.persistentModelID {
            selectedFigureID = nil
        }
        Task { @MainActor in
            ActivityLogger.record(action: .deleted, entityType: "Figure", entityName: figure.name, context: modelContext, session: userSession)
            modelContext.delete(figure)
        }
    }
}

/// A single row in the figures list. Renders only precomputed display values —
/// never a live `Figure` — so it cannot fault during a layout pass.
fileprivate struct FigureRow: View {
    let display: FigureRowDisplay
    var onOpenTable: ((PersistentIdentifier) -> Void)?
    @State private var showTablePicker = false

    private var hasTables: Bool { !display.popupTableIDs.isEmpty }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.horizontal.3")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .onDrag {
                    NSItemProvider(object: display.name as NSString)
                } preview: {
                    Circle()
                        .fill(display.typeColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: display.typeIcon)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                        .padding(8)
                        .background(.ultraThickMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            Circle()
                .fill(display.typeColor)
                .frame(width: 8, height: 8)
            Text(display.genderSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(display.name)
                    .fontWeight(display.isRed ? .bold : .medium)
                    .foregroundStyle(display.isRed ? .red : .primary)
                if let disambiguation = display.disambiguation, !disambiguation.isEmpty {
                    Text(disambiguation)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(display.typeName.isEmpty ? "Unknown" : display.typeName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(display.typeColor.opacity(0.12))
                )
            Text(display.domain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if display.isConcept {
                Text("Concept")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(.orange.opacity(0.12)))
            }
            if display.hasUnresolvedSticky {
                Circle()
                    .fill(.yellow)
                    .frame(width: 10, height: 10)
            }
            if hasTables {
                Button {
                    if display.popupTableIDs.count == 1 {
                        onOpenTable?(display.popupTableIDs[0])
                    } else {
                        showTablePicker = true
                    }
                } label: {
                    Image(systemName: "tablecells")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showTablePicker) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comparison Tables")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 6)
                        ForEach(display.popupTableIDs.indices, id: \.self) { index in
                            Button {
                                showTablePicker = false
                                onOpenTable?(display.popupTableIDs[index])
                            } label: {
                                Label(display.popupTableNames[index], systemImage: "tablecells")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                        }
                        Spacer(minLength: 4)
                    }
                    .frame(minWidth: 160)
                }
            }
            Spacer()
            Text(display.birthDateLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
