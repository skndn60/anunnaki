import SwiftUI
import SwiftData

/// Dedicated management view for alternate names and cross-cultural equivalents.
struct AlternateNameListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var alternateNames: [AlternateName]
    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @State private var showingAddSheet = false
    @State private var editingAltName: AlternateName?
    @State private var filterTradition: AlternateName.Tradition?
    @State private var selectedAltNameID: PersistentIdentifier?
    @State private var showDeleteConfirm = false
    @State private var altNameToDelete: AlternateName?
    @State private var filterEntityText = ""
    @State private var filterEntityType: AltEntityType?

    private enum AltEntityType: String, CaseIterable {
        case figure = "Figure"
        case place = "Place"
    }

    private var filteredNames: [AlternateName] {
        var result = alternateNames
        if let tradition = filterTradition {
            result = result.filter { $0.tradition == tradition }
        }
        if let type = filterEntityType {
            switch type {
            case .figure: result = result.filter { $0.figure != nil }
            case .place: result = result.filter { $0.place != nil }
            }
        }
        if !filterEntityText.isEmpty {
            result = result.filter {
                ($0.figure?.name.localizedCaseInsensitiveContains(filterEntityText) ?? false) ||
                ($0.place?.name.localizedCaseInsensitiveContains(filterEntityText) ?? false)
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    private var groupedNames: [(key: String, names: [AlternateName])] {
        Dictionary(grouping: filteredNames) { name in
            name.name.uppercased().prefix(1).description
        }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, names: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Alternate Names")
                    .font(.title2.bold())
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Label("Add Name", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(figures.isEmpty && places.isEmpty)
            }
            .padding()

            // Filters
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("Tradition:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $filterTradition) {
                        Text("All").tag(nil as AlternateName.Tradition?)
                        ForEach(AlternateName.Tradition.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t as AlternateName.Tradition?)
                        }
                    }
                    .frame(width: 140)
                }

                HStack(spacing: 6) {
                    Text("Type:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $filterEntityType) {
                        Text("All").tag(nil as AltEntityType?)
                        ForEach(AltEntityType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t as AltEntityType?)
                        }
                    }
                    .frame(width: 100)
                }

                HStack(spacing: 6) {
                    Text("Entity:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Filter by name\u{2026}", text: $filterEntityText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .overlay(alignment: .trailing) {
                            if !filterEntityText.isEmpty {
                                Button(action: { filterEntityText = "" }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 4)
                                .help("Clear filter")
                            }
                        }
                }

                Spacer()

                Text("\(filteredNames.count) names")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            if alternateNames.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "textformat.abc")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No alternate names yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Track alternate spellings, translations, and cross-cultural identifications for figures and places.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    Spacer()
                }
            } else if filteredNames.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No results for filter")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $selectedAltNameID) {
                    ForEach(groupedNames, id: \.key) { group in
                        Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
                            ForEach(group.names) { altName in
                                AlternateNameRow(
                                    altName: altName,
                                    onEdit: { editingAltName = altName },
                                    onDelete: {
                                        altNameToDelete = altName
                                        showDeleteConfirm = true
                                    }
                                )
                                .tag(altName.persistentModelID)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AlternateNameFormView(alternateName: nil)
        }
        .sheet(item: $editingAltName) { altName in
            AlternateNameFormView(alternateName: altName)
        }
        .alert("Delete Alternate Name?", isPresented: $showDeleteConfirm, presenting: altNameToDelete) { altName in
            Button("Delete", role: .destructive) {
                withAnimation { modelContext.delete(altName) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { altName in
            Text("Delete \"\(altName.name)\" (\(altName.tradition.rawValue)) from \(entityLabel(for: altName))?")
        }
    }

    private func entityLabel(for altName: AlternateName) -> String {
        altName.figure?.name ?? altName.place?.name ?? "—"
    }

}

// MARK: - Alternate Name Form

struct AlternateNameFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    @Query private var places: [Place]

    let alternateName: AlternateName?
    var preSelectedFigure: Figure?
    var preSelectedPlace: Place?

    private enum LinkType: String, CaseIterable {
        case figure = "Figure"
        case place = "Place"
    }

    @State private var linkType: LinkType = .figure
    @State private var selectedFigure: Figure?
    @State private var selectedPlace: Place?
    @State private var name = ""
    @State private var tradition: AlternateName.Tradition = .akkadian
    @State private var nameType: AlternateName.NameType = .translation
    @State private var note = ""
    @State private var entitySearchText = ""

    private var filteredFigures: [FigureSearchResult] {
        guard !entitySearchText.isEmpty else { return [] }
        let figs = figures.filter { selectedFigure == nil || $0.persistentModelID != selectedFigure!.persistentModelID }
        return searchFigures(figs, query: entitySearchText)
    }

    private var filteredPlaces: [Place] {
        guard !entitySearchText.isEmpty else { return [] }
        return places.filter { pl in
            (selectedPlace == nil || pl.persistentModelID != selectedPlace!.persistentModelID) &&
            pl.name.localizedCaseInsensitiveContains(entitySearchText)
        }
    }

    private var isEditing: Bool { alternateName != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Alternate Name" : "Add Alternate Name")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Linked To") {
                    Picker("Type", selection: $linkType) {
                        ForEach(LinkType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isEditing)

                    switch linkType {
                    case .figure: figureLinkSection
                    case .place: placeLinkSection
                    }
                }

                Section("Alternate Name") {
                    TextField("Name", text: $name, prompt: Text("Ea, Ptah, Ishtar"))
                    Picker("Tradition", selection: $tradition) {
                        ForEach(AlternateName.Tradition.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    Picker("Type", selection: $nameType) {
                        ForEach(AlternateName.NameType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }

                Section("Note") {
                    TextField("Note", text: $note, prompt: Text("Identified by Herodotus"))
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || (selectedFigure == nil && selectedPlace == nil))
            }
            .padding()
        }
        .frame(width: 480, height: 560)
        .onAppear { loadIfEditing() }
    }

    @ViewBuilder
    private var figureLinkSection: some View {
        if let fig = selectedFigure {
            HStack(spacing: 6) {
                Text("\(fig.gender.symbol) \(fig.name)")
                    .fontWeight(.medium)
                Spacer()
                Button { selectedFigure = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear selection")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.3))
            .cornerRadius(6)
        }
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Search figures\u{2026}", text: $entitySearchText)
                .textFieldStyle(.roundedBorder)
        }
        if !entitySearchText.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if filteredFigures.isEmpty {
                        Text("No figures match \"\(entitySearchText)\"")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(filteredFigures, id: \.id) { result in
                            Button {
                                selectedFigure = result.figure
                                entitySearchText = ""
                            } label: {
                                Text("\(result.figure.gender.symbol) \(result.displayName)")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    @ViewBuilder
    private var placeLinkSection: some View {
        if let pl = selectedPlace {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: pl.placeType?.icon ?? "mappin")
                        .font(.caption)
                        .foregroundStyle(.teal)
                    Text(pl.name)
                        .fontWeight(.medium)
                }
                Spacer()
                Button { selectedPlace = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear selection")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.3))
            .cornerRadius(6)
        }
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Search places\u{2026}", text: $entitySearchText)
                .textFieldStyle(.roundedBorder)
        }
        if !entitySearchText.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if filteredPlaces.isEmpty {
                        Text("No places match \"\(entitySearchText)\"")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(filteredPlaces) { pl in
                            Button {
                                selectedPlace = pl
                                entitySearchText = ""
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: pl.placeType?.icon ?? "mappin")
                                        .font(.caption2)
                                        .foregroundStyle(.teal)
                                    Text(pl.name)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    private func loadIfEditing() {
        if let alternateName {
            selectedFigure = alternateName.figure
            selectedPlace = alternateName.place
            if alternateName.place != nil { linkType = .place }
            name = alternateName.name
            tradition = alternateName.tradition
            nameType = alternateName.nameType
            note = alternateName.note
        } else if let place = preSelectedPlace {
            linkType = .place
            selectedPlace = place
        } else if let figure = preSelectedFigure {
            linkType = .figure
            selectedFigure = figure
        }
    }

    private func save() {
        if let alternateName {
            alternateName.figure = selectedFigure
            alternateName.place = selectedPlace
            alternateName.name = name
            alternateName.tradition = tradition
            alternateName.nameType = nameType
            alternateName.note = note
        } else {
            let manager = RelationshipManager(context: modelContext)
            if let figure = selectedFigure {
                manager.addAlternateName(to: figure, name: name, tradition: tradition, nameType: nameType, note: note, dedupe: false)
            } else if let place = selectedPlace {
                manager.addAlternateName(to: place, name: name, tradition: tradition, nameType: nameType, note: note, dedupe: false)
            }
        }
        dismiss()
    }
}

// MARK: - Alternate Name Row

struct AlternateNameRow: View {
    let altName: AlternateName
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(altName.name)
                        .fontWeight(.medium)
                    Text(altName.tradition.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(altName.tradition.color.opacity(0.12))
                        )
                    Text(altName.nameType.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    Image(systemName: altName.figure != nil ? "person.fill" : "mappin")
                        .font(.system(size: 9))
                        .foregroundStyle(altName.figure != nil ? Color.blue : Color.teal)
                    Text(entityLabel(for: altName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !altName.note.isEmpty {
                        Text(altName.note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            HStack(spacing: 4) {
                IconActionButton(icon: "pencil", color: .accentColor, help: "Edit", action: onEdit)
                IconActionButton(icon: "trash", color: .red, help: "Delete", action: onDelete)
            }
        }
        .padding(.vertical, 2)
    }

    private func entityLabel(for altName: AlternateName) -> String {
        altName.figure?.name ?? altName.place?.name ?? "\u{2014}"
    }
}
