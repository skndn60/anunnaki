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
        return result
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
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 4)
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
            } else {
                Table(filteredNames, selection: $selectedAltNameID) {
                    TableColumn("Entity") { altName in
                        Text(entityLabel(for: altName))
                            .fontWeight(.medium)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Alternate Name") { altName in
                        Text(altName.name)
                            .fontWeight(.medium)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Tradition") { altName in
                        Text(altName.tradition.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(traditionColor(altName.tradition).opacity(0.12))
                            )
                    }
                    .width(100)

                    TableColumn("Type") { altName in
                        Text(altName.nameType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 100, ideal: 130)

                    TableColumn("Note") { altName in
                        Text(altName.note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                    .width(min: 140, ideal: 200)

                    TableColumn("") { altName in
                        HStack(spacing: 4) {
                            IconActionButton(icon: "pencil", color: .accentColor) {
                                editingAltName = altName
                            }
                            IconActionButton(icon: "trash", color: .red) {
                                altNameToDelete = altName
                                showDeleteConfirm = true
                            }
                        }
                    }
                    .width(60)
                }
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

    private func traditionColor(_ tradition: AlternateName.Tradition) -> Color { tradition.color }
}

// MARK: - Alternate Name Form

struct AlternateNameFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    @Query private var places: [Place]

    let alternateName: AlternateName?

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

    private var filteredFigures: [Figure] {
        guard !entitySearchText.isEmpty else { return [] }
        return figures.filter { fig in
            (selectedFigure == nil || fig.persistentModelID != selectedFigure!.persistentModelID) &&
            fig.name.localizedCaseInsensitiveContains(entitySearchText)
        }
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
                    TextField("Name", text: $name, prompt: Text("e.g. Ea, Ptah, Ishtar"))
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
                    TextField("Note", text: $note, prompt: Text("e.g. Identified by Herodotus"))
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
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
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
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.quaternary.opacity(0.15))
        .cornerRadius(6)
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
                        ForEach(filteredFigures) { fig in
                            Button {
                                selectedFigure = fig
                                entitySearchText = ""
                            } label: {
                                Text("\(fig.gender.symbol) \(fig.name)")
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
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
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
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.quaternary.opacity(0.15))
        .cornerRadius(6)
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
        guard let alternateName else { return }
        selectedFigure = alternateName.figure
        selectedPlace = alternateName.place
        if alternateName.place != nil { linkType = .place }
        name = alternateName.name
        tradition = alternateName.tradition
        nameType = alternateName.nameType
        note = alternateName.note
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
            let newAltName = AlternateName(
                figure: selectedFigure,
                place: selectedPlace,
                name: name, tradition: tradition,
                nameType: nameType, note: note
            )
            modelContext.insert(newAltName)
        }
        dismiss()
    }
}
