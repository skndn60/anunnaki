import SwiftUI
import SwiftData

/// Input screen for managing figures (deities, humans, etc.)
struct FigureListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query private var figures: [Figure]
    @Query private var figureTypes: [FigureType]
    @State private var showingAddSheet = false
    @State private var editingFigure: Figure?
    @State private var selectedFigureID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var sortOrder: FigureSortOrder = .name
    @State private var imageDetailImage: ImageAsset?
    @State private var showDeleteConfirm = false
    @State private var selectedTypeFilters: Set<String> = []
    @AppStorage("figureDetailWidth") private var detailWidth: Double = 320

    enum FigureSortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
        case domain = "Domain"
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
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.title.lowercased().contains(query) ||
                $0.domain.lowercased().contains(query) ||
                ($0.figureType?.name ?? "").lowercased().contains(query) ||
                $0.alternateNames.contains { $0.name.lowercased().contains(query) }
            }
        }
        switch sortOrder {
        case .name: result.sort { $0.name < $1.name }
        case .type: result.sort { (a: Figure, b: Figure) in (a.figureType?.name ?? "") < (b.figureType?.name ?? "") }
        case .domain: result.sort { $0.domain < $1.domain }
        }
        return result
    }

    private var groupedFigures: [(key: String, figures: [Figure])] {
        let sorted = filteredFigures
        var groups: [(key: String, figures: [Figure])] = []
        var currentKey: String?
        for figure in sorted {
            let key: String = {
                switch sortOrder {
                case .name: return String(figure.name.uppercased().prefix(1))
                case .type: return figure.figureType?.name ?? "?"
                case .domain: return figure.domain.isEmpty ? "?" : figure.domain
                }
            }()
            if key != currentKey {
                groups.append((key: key, figures: []))
                currentKey = key
            }
            groups[groups.count - 1].figures.append(figure)
        }
        return groups
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
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(FigureSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .frame(width: 130)
                    TextField("🔍 Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .overlay(alignment: .trailing) {
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 6)
                            }
                        }
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
                            Text("No results for \"\(searchText)\"")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $selectedFigureID) {
                        ForEach(groupedFigures, id: \.key) { group in
                            Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
                                ForEach(group.figures) { figure in
                                    FigureRow(figure: figure, searchText: searchText)
                                        .tag(figure.persistentModelID)
                                }
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .onChange(of: selectedFigureID) { _, newValue in
                        if let id = newValue {
                            selectFigure(id)
                        }
                    }
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            // Right: detail panel
            if let figure = selectedFigure {
                ResizableDivider(width: $detailWidth, range: 200...800)
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        IconActionButton(icon: "pencil", color: .accentColor) {
                            editingFigure = figure
                        }
                        IconActionButton(icon: "trash", color: .red) {
                            showDeleteConfirm = true
                        }
                        IconActionButton(icon: "tree", color: .green) {
                            openWindow(id: "lineage", value: figure.persistentModelID)
                        }
                        Spacer()
                        Button(action: { selectedFigureID = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
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
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            FigureFormView(figure: nil)
        }
        .sheet(item: $editingFigure) { figure in
            FigureFormView(figure: figure)
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
            selectFigure(id)
        }
    }

    private func deleteFigure(_ figure: Figure) {
        if selectedFigureID == figure.persistentModelID {
            selectedFigureID = nil
        }
        withAnimation { modelContext.delete(figure) }
    }
}

/// A single row in the figures list.
struct FigureRow: View {
    let figure: Figure
    var searchText: String = ""

    private var matchedAlias: String? {
        guard !searchText.isEmpty else { return nil }
        let q = searchText.lowercased()
        return figure.alternateNames.first(where: {
            let name = $0.name.lowercased()
            return name == q || name.contains(q) || q.contains(name)
        })?.name
    }

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
                    .fontWeight(.medium)
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
            if let alias = matchedAlias {
                Text("aka \(alias)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fontWeight(.medium)
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

// MARK: - Figure Form

struct FigureFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let figure: Figure?
    @Query private var figureTypes: [FigureType]

    @State private var name = ""
    @State private var disambiguation = ""
    @State private var title = ""
    @State private var selectedFigureType: FigureType? = nil
    @State private var gender: Figure.Gender = .unknown
    @State private var domain = ""
    @State private var figureDescription = ""
    @State private var birthDate: MythologicalDate = .unknown
    @State private var deathDate: MythologicalDate = .unknown
    @State private var source = ""
    @State private var selectedTags: [Tag] = []

    private var isEditing: Bool { figure != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Figure" : "Add Figure")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                    TextField("Disambiguation", text: $disambiguation, prompt: Text("e.g. Fourth dynasty of Kish"))
                    TextField("Title", text: $title, prompt: Text("e.g. King of the Gods"))
                    Picker("Type", selection: $selectedFigureType) {
                        Text("None").tag(nil as FigureType?)
                        ForEach(figureTypes) { type in
                            Text(type.name).tag(type as FigureType?)
                        }
                    }
                    Picker("Gender", selection: $gender) {
                        ForEach(Figure.Gender.allCases, id: \.self) { g in
                            Text("\(g.symbol) \(g.rawValue)").tag(g)
                        }
                    }
                    TextField("Domain", text: $domain, prompt: Text("e.g. Sky, Wisdom, War"))
                }

                MythologicalDateEditor(label: "Birth / Origin", date: $birthDate)
                MythologicalDateEditor(label: "Death / End", date: $deathDate)

                Section("Source & Notes") {
                    TextField("Source Text", text: $source, prompt: Text("e.g. Enuma Elish"))
                    TextEditor(text: $figureDescription)
                        .frame(minHeight: 60)
                }

                Section("Tags") {
                    TagEditorView(tags: $selectedTags)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 540, height: 680)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let figure else { return }
        name = figure.name
        disambiguation = figure.disambiguation ?? ""
        title = figure.title
        selectedFigureType = figure.figureType
        gender = figure.gender
        domain = figure.domain
        figureDescription = figure.figureDescription
        birthDate = figure.birthDate
        deathDate = figure.deathDate
        source = figure.source
        selectedTags = figure.tags
    }

    private func save() {
        if let figure {
            figure.name = name
            figure.disambiguation = disambiguation.isEmpty ? nil : disambiguation
            figure.title = title
            figure.figureType = selectedFigureType
            figure.gender = gender
            figure.domain = domain
            figure.figureDescription = figureDescription
            figure.birthDate = birthDate
            figure.deathDate = deathDate
            figure.source = source
            figure.isConcept = false
            figure.tags = selectedTags
            RecentEditStore.trackEdit(entityType: "Figure", entityName: figure.name)
        } else {
            let newFigure = Figure(
                name: name, disambiguation: disambiguation.isEmpty ? nil : disambiguation, title: title, figureType: selectedFigureType,
                gender: gender, domain: domain, figureDescription: figureDescription,
                birthDate: birthDate, deathDate: deathDate, source: source
            )
            newFigure.tags = selectedTags
            modelContext.insert(newFigure)
            RecentEditStore.trackEdit(entityType: "Figure", entityName: newFigure.name)
        }
        dismiss()
    }
}
