import SwiftUI
import SwiftData

/// Input screen for managing figures (deities, humans, etc.)
struct FigureListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query private var figures: [Figure]
    @Query private var figureTypes: [FigureType]
    @Query private var allGroups: [FigureGroup]
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
    @AppStorage("figureDetailWidth") private var detailWidth: Double = 320

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

    /// IDs of the figures that should be drawn red (members of the selected dynasty).
    private var redFigureIDs: Set<PersistentIdentifier> {
        guard let selected = selectedDynastyGroup else { return [] }
        return Set(selected.figureAssociations.compactMap { $0.figure?.persistentModelID })
    }

    private var selectedFigure: Figure? {
        guard let id = selectedFigureID else { return nil }
        return filteredFigures.first { $0.persistentModelID == id }
    }

    private var filteredFigures: [Figure] {
        var result = figures
        if !selectedTypeFilters.isEmpty {
            result = result.filter { selectedTypeFilters.contains($0.figureType?.name ?? "") }
        }
        switch sortOrder {
        case .name: result.sort { sortName(for: $0.name) < sortName(for: $1.name) }
        case .type: result.sort { (a: Figure, b: Figure) in (a.figureType?.name ?? "") < (b.figureType?.name ?? "") }
        case .domain: result.sort { $0.domain < $1.domain }
        }
        return result
    }

    private var groupedFigures: [(key: String, figures: [Figure])] {
        Dictionary(grouping: filteredFigures) { figure in
            switch sortOrder {
            case .name: String(sortName(for: figure.name).uppercased().prefix(1))
            case .type: figure.figureType?.name ?? "?"
            case .domain: figure.domain.isEmpty ? "?" : figure.domain
            }
        }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, figures: $0.value.sorted { sortName(for: $0.name) < sortName(for: $1.name) }) }
    }

    private func selectFigure(_ id: PersistentIdentifier) {
        selectedFigureID = id
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: list
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

                if filteredFigures.isEmpty {
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
                            ForEach(groupedFigures, id: \.key) { group in
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

            // Right: detail panel
            Group {
                if let figure = selectedFigure {
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
                                ToolbarButton(icon: "tree", color: .green, help: "Show in inline lineage tree") {
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
    }

    private func consumePendingNavigation() {
        guard let id = coordinator?.consumePendingFigureID() else { return }
        if figures.contains(where: { $0.persistentModelID == id }) {
            Task { @MainActor in
                selectFigure(id)
            }
        }
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

    private func figureGroupSection(_ group: (key: String, figures: [Figure])) -> some View {
        Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
            ForEach(group.figures) { figure in
                FigureRow(figure: figure, isRed: redFigureIDs.contains(figure.persistentModelID))
                    .tag(figure.persistentModelID)
                    .id(figure.persistentModelID)
            }
        }
    }

    private func deleteFigure(_ figure: Figure) {
        if selectedFigureID == figure.persistentModelID {
            selectedFigureID = nil
        }
        Task { @MainActor in
            modelContext.delete(figure)
        }
    }
}

/// A single row in the figures list.
struct FigureRow: View {
    let figure: Figure
    var isRed: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.horizontal.3")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .onDrag {
                    NSItemProvider(object: figure.name as NSString)
                } preview: {
                    Circle()
                        .fill(figure.figureType?.color ?? .gray)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: figure.figureType?.icon ?? "questionmark")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                        .padding(8)
                        .background(.ultraThickMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            Circle()
                .fill(figure.figureType?.color ?? .gray)
                .frame(width: 8, height: 8)
            Text(figure.gender.symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(figure.name)
                    .fontWeight(isRed ? .bold : .medium)
                    .foregroundStyle(isRed ? .red : .primary)
                if let disambiguation = figure.disambiguation, !disambiguation.isEmpty {
                    Text(disambiguation)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(figure.figureType?.name ?? "Unknown")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(figure.figureType?.color.opacity(0.12) ?? .gray.opacity(0.12))
                )
            Text(figure.domain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if figure.isConcept {
                Text("Concept")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(.orange.opacity(0.12)))
            }
            if figure.stickies.contains(where: { !$0.isResolved }) {
                Circle()
                    .fill(.yellow)
                    .frame(width: 10, height: 10)
            }
            Spacer()
            Text(figure.birthDate.displayLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}


