import SwiftUI
import SwiftData

/// Input screen for managing figures (deities, humans, etc.)
struct FigureListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var figures: [Figure]
    @State private var showingAddSheet = false
    @State private var editingFigure: Figure?
    @State private var selectedFigureID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var sortOrder: FigureSortOrder = .name
    @State private var breadcrumbs: [Breadcrumb] = []
    @State private var showingLineageExplorer = false

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
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.title.lowercased().contains(query) ||
                $0.domain.lowercased().contains(query) ||
                $0.figureType.rawValue.lowercased().contains(query) ||
                $0.alternateNames.contains { $0.name.lowercased().contains(query) }
            }
        }
        switch sortOrder {
        case .name: result.sort { $0.name < $1.name }
        case .type: result.sort { $0.figureType.rawValue < $1.figureType.rawValue }
        case .domain: result.sort { $0.domain < $1.domain }
        }
        return result
    }

    private func selectFigure(_ id: PersistentIdentifier) {
        // Add to breadcrumbs if it's a new selection (not navigating back)
        if let figure = figures.first(where: { $0.persistentModelID == id }) {
            // Don't duplicate the last entry
            if breadcrumbs.last?.id != id {
                breadcrumbs.append(Breadcrumb(id: id, name: figure.name))
                // Keep trail manageable
                if breadcrumbs.count > 12 {
                    breadcrumbs.removeFirst()
                }
            }
        }
        selectedFigureID = id
    }

    private func navigateToBreadcrumb(at index: Int) {
        let crumb = breadcrumbs[index]
        // Trim breadcrumbs to this point
        breadcrumbs = Array(breadcrumbs.prefix(index + 1))
        selectedFigureID = crumb.id
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
                if !breadcrumbs.isEmpty {
                    BreadcrumbBar(breadcrumbs: breadcrumbs, onNavigate: navigateToBreadcrumb, onClear: { breadcrumbs.removeAll() })
                }

                FigureTypeLegend()
                    .padding(.horizontal)
                    .padding(.bottom, 6)

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
                    List(filteredFigures, selection: $selectedFigureID) { figure in
                        FigureRow(figure: figure, searchText: searchText)
                            .tag(figure.persistentModelID)
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
                Divider()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        IconActionButton(icon: "pencil", color: .accentColor) {
                            editingFigure = figure
                        }
                        IconActionButton(icon: "trash", color: .red) {
                            deleteFigure(figure)
                        }
                        IconActionButton(icon: "tree", color: .green) {
                            showingLineageExplorer = true
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
                    FigureDetailView(figure: figure, onSelectFigure: { selected in
                        selectFigure(selected.persistentModelID)
                    })
                }
                .frame(width: 320)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            FigureFormView(figure: nil)
        }
        .sheet(item: $editingFigure) { figure in
            FigureFormView(figure: figure)
        }
        .sheet(isPresented: $showingLineageExplorer) {
            if let figure = selectedFigure {
                FigureLineageExplorer(initialFigure: figure)
            }
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
                        .fill(figure.figureType.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: figure.figureType.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                        .padding(8)
                        .background(.ultraThickMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            Circle()
                .fill(figure.figureType.color)
                .frame(width: 8, height: 8)
            Text(figure.gender.symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(figure.name)
                .fontWeight(.medium)
            Text(figure.figureType.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(figure.figureType.color.opacity(0.12))
                )
            Text(figure.domain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let alias = matchedAlias {
                Text("aka \(alias)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fontWeight(.medium)
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

    @State private var name = ""
    @State private var title = ""
    @State private var figureType: Figure.FigureType = .deity
    @State private var gender: Figure.Gender = .unknown
    @State private var domain = ""
    @State private var figureDescription = ""
    @State private var birthDate: MythologicalDate = .unknown
    @State private var deathDate: MythologicalDate = .unknown
    @State private var source = ""

    private var isEditing: Bool { figure != nil }

    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Figure" : "Add Figure")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                    TextField("Title", text: $title, prompt: Text("e.g. King of the Gods"))
                    Picker("Type", selection: $figureType) {
                        ForEach(Figure.FigureType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
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
        }
        .frame(width: 540, height: 680)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let figure else { return }
        name = figure.name
        title = figure.title
        figureType = figure.figureType
        gender = figure.gender
        domain = figure.domain
        figureDescription = figure.figureDescription
        birthDate = figure.birthDate
        deathDate = figure.deathDate
        source = figure.source
    }

    private func save() {
        if let figure {
            figure.name = name
            figure.title = title
            figure.figureType = figureType
            figure.gender = gender
            figure.domain = domain
            figure.figureDescription = figureDescription
            figure.birthDate = birthDate
            figure.deathDate = deathDate
            figure.source = source
        } else {
            let newFigure = Figure(
                name: name, title: title, figureType: figureType,
                gender: gender, domain: domain, figureDescription: figureDescription,
                birthDate: birthDate, deathDate: deathDate, source: source
            )
            modelContext.insert(newFigure)
        }
        dismiss()
    }
}
