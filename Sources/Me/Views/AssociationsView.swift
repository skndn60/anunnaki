import SwiftUI
import SwiftData

/// Overview of all associations defined in the system, with add/delete.
struct AssociationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var figurePlaceAssocs: [FigurePlaceAssociation]
    @Query private var placePlaceAssocs: [PlacePlaceAssociation]
    @Query private var eventEventAssocs: [EventEventAssociation]
    @Query private var eventPlaceAssocs: [EventPlaceAssociation]
    @Query private var relationships: [Relationship]

    @State private var selectedTab = 0
    @State private var showingAddFigurePlace = false
    @State private var showingAddPlacePlace = false
    @State private var showingAddEventEvent = false
    @State private var showingAddEventPlace = false
    @State private var showingAddRelationship = false
    @State private var editingFigurePlaceAssoc: FigurePlaceAssociation?
    @State private var editingPlacePlaceAssoc: PlacePlaceAssociation?
    @State private var editingEventEventAssoc: EventEventAssociation?
    @State private var editingEventPlaceAssoc: EventPlaceAssociation?
    @State private var editingRelationship: Relationship?
    @State private var showDeleteRelConfirm = false
    @State private var relToDelete: Relationship?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Associations")
                    .font(.title2.bold())
                Spacer()
                HStack(spacing: 16) {
                    countBadge("Figure↔Figure", relationships.count, .blue)
                    countBadge("Figure↔Place", figurePlaceAssocs.count, .teal)
                    countBadge("Place↔Place", placePlaceAssocs.count, .green)
                    countBadge("Event↔Place", eventPlaceAssocs.count, .indigo)
                    countBadge("Event↔Event", eventEventAssocs.count, .orange)
                }
            }
            .padding()

            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Figure ↔ Figure (\(relationships.count))").tag(0)
                    Text("Figure ↔ Place (\(figurePlaceAssocs.count))").tag(1)
                    Text("Place ↔ Place (\(placePlaceAssocs.count))").tag(2)
                    Text("Event ↔ Place (\(eventPlaceAssocs.count))").tag(3)
                    Text("Event ↔ Event (\(eventEventAssocs.count))").tag(4)
                }
                .pickerStyle(.segmented)

                Button(action: { addForCurrentTab() }) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            switch selectedTab {
            case 0: figureRelationshipsList
            case 1: figurePlaceList
            case 2: placePlaceList
            case 3: eventPlaceList
            case 4: eventEventList
            default: EmptyView()
            }
        }
        .sheet(isPresented: $showingAddFigurePlace) {
            AddFigurePlaceAssociationForm()
        }
        .sheet(isPresented: $showingAddPlacePlace) {
            AddPlacePlaceAssociationForm()
        }
        .sheet(isPresented: $showingAddEventPlace) {
            AddEventPlaceAssociationForm()
        }
        .sheet(isPresented: $showingAddEventEvent) {
            AddEventEventAssociationForm()
        }
        .sheet(isPresented: $showingAddRelationship) {
            RelationshipFormView()
        }
        .sheet(item: $editingFigurePlaceAssoc) { assoc in
            EditFigurePlaceAssociationForm(assoc: assoc)
        }
        .sheet(item: $editingPlacePlaceAssoc) { assoc in
            EditPlacePlaceAssociationForm(assoc: assoc)
        }
        .sheet(item: $editingEventEventAssoc) { assoc in
            EditEventEventAssociationForm(assoc: assoc)
        }
        .sheet(item: $editingEventPlaceAssoc) { assoc in
            EditEventPlaceAssociationForm(assoc: assoc)
        }
        .sheet(item: $editingRelationship) { rel in
            EditRelationshipForm(relationship: rel)
        }
        .alert("Delete Relationship?", isPresented: $showDeleteRelConfirm, presenting: relToDelete) { rel in
            Button("Delete", role: .destructive) {
                modelContext.delete(rel)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { rel in
            Text("Delete relationship between \(rel.fromFigure?.name ?? "?") and \(rel.toFigure?.name ?? "?")?")
        }
    }

    private func addForCurrentTab() {
        switch selectedTab {
        case 0: showingAddRelationship = true
        case 1: showingAddFigurePlace = true
        case 2: showingAddPlacePlace = true
        case 3: showingAddEventPlace = true
        case 4: showingAddEventEvent = true
        default: break
        }
    }

    // MARK: - Figure ↔ Figure

    private var figureRelationshipsList: some View {
        Group {
            if relationships.isEmpty {
                emptyState("No figure relationships", "Add family connections between figures.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(relationships.enumerated()), id: \.element.id) { index, rel in
                            HStack(spacing: 10) {
                                Text(rel.fromFigure?.name ?? "?").fontWeight(.medium)
                                Image(systemName: rel.relationshipType?.icon ?? "questionmark").font(.caption).foregroundStyle(rel.relationshipType?.color ?? .gray)
                                Text(rel.relationshipType?.name ?? "").font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 3).fill((rel.relationshipType?.color ?? .gray).opacity(0.12)))
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                                Text(rel.toFigure?.name ?? "?").fontWeight(.medium)
                                Spacer()
                                Text(rel.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                                IconActionButton(icon: "pencil", color: .accentColor, help: "Edit", action: { editingRelationship = rel })
                                IconActionButton(icon: "trash", color: .red, help: "Delete", action: {
                                    relToDelete = rel
                                    showDeleteRelConfirm = true
                                })
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .alternatingRowBackground(index: index)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Figure ↔ Place

    private var figurePlaceList: some View {
        Group {
            if figurePlaceAssocs.isEmpty {
                emptyState("No figure-place associations", "Add patron deity, ruler, or other connections.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(figurePlaceAssocs.enumerated()), id: \.element.id) { index, assoc in
                            HStack(spacing: 10) {
                                Circle().fill(assoc.figure?.figureType?.color ?? .gray).frame(width: 8, height: 8)
                                Text(assoc.displayName.map { "\(assoc.figure?.name ?? "?") as \($0)" } ?? (assoc.figure?.name ?? "?")).fontWeight(.medium)
                                Text(assoc.roleType?.name ?? "—").font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.teal.opacity(0.12)))
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                                Image(systemName: assoc.place?.placeType?.icon ?? "mappin").font(.caption).foregroundStyle(.teal)
                                Text(assoc.place?.name ?? "?").fontWeight(.medium)
                                Spacer()
                                Text(assoc.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                                IconActionButton(icon: "pencil", color: .accentColor, help: "Edit", action: { editingFigurePlaceAssoc = assoc })
                                IconActionButton(icon: "trash", color: .red, help: "Delete", action: { Task { @MainActor in modelContext.delete(assoc) } })
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .alternatingRowBackground(index: index)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Place ↔ Place

    private var placePlaceList: some View {
        Group {
            if placePlaceAssocs.isEmpty {
                emptyState("No place-place associations", "Add containment or proximity relationships.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(placePlaceAssocs.enumerated()), id: \.element.id) { index, assoc in
                            HStack(spacing: 10) {
                                Image(systemName: assoc.fromPlace?.placeType?.icon ?? "mappin").font(.caption).foregroundStyle(.teal)
                                Text(assoc.fromPlace?.name ?? "?").fontWeight(.medium)
                                Text(assoc.roleType?.name ?? "—").font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.green.opacity(0.12)))
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                                Image(systemName: assoc.toPlace?.placeType?.icon ?? "mappin").font(.caption).foregroundStyle(.teal)
                                Text(assoc.toPlace?.name ?? "?").fontWeight(.medium)
                                Spacer()
                                Text(assoc.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                                IconActionButton(icon: "pencil", color: .accentColor, help: "Edit", action: { editingPlacePlaceAssoc = assoc })
                                IconActionButton(icon: "trash", color: .red, help: "Delete", action: { Task { @MainActor in modelContext.delete(assoc) } })
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .alternatingRowBackground(index: index)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Event ↔ Place

    private var eventPlaceList: some View {
        Group {
            if eventPlaceAssocs.isEmpty {
                emptyState("No event-place associations", "Add location associations to events.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(eventPlaceAssocs.enumerated()), id: \.element.id) { index, assoc in
                            HStack(spacing: 10) {
                                Image(systemName: assoc.event?.eventType?.icon ?? "bolt").font(.caption).foregroundStyle(assoc.event?.eventType?.color ?? .gray)
                                Text(assoc.event?.name ?? "?").fontWeight(.medium)
                                Text(assoc.roleType?.name ?? "—").font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.indigo.opacity(0.12)))
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                                Image(systemName: assoc.place?.placeType?.icon ?? "mappin").font(.caption).foregroundStyle(.teal)
                                Text(assoc.place?.name ?? "?").fontWeight(.medium)
                                Spacer()
                                Text(assoc.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                                IconActionButton(icon: "pencil", color: .accentColor, help: "Edit", action: { editingEventPlaceAssoc = assoc })
                                IconActionButton(icon: "trash", color: .red, help: "Delete", action: { Task { @MainActor in modelContext.delete(assoc) } })
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .alternatingRowBackground(index: index)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Event ↔ Event

    private var eventEventList: some View {
        Group {
            if eventEventAssocs.isEmpty {
                emptyState("No event-event associations", "Add causal or sequential links between events.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(eventEventAssocs.enumerated()), id: \.element.id) { index, assoc in
                            HStack(spacing: 10) {
                                Image(systemName: assoc.fromEvent?.eventType?.icon ?? "bolt").font(.caption).foregroundStyle(assoc.fromEvent?.eventType?.color ?? .gray)
                                Text(assoc.fromEvent?.name ?? "?").fontWeight(.medium)
                                Text(assoc.roleType?.name ?? "—").font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.12)))
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                                Image(systemName: assoc.toEvent?.eventType?.icon ?? "bolt").font(.caption).foregroundStyle(assoc.toEvent?.eventType?.color ?? .gray)
                                Text(assoc.toEvent?.name ?? "?").fontWeight(.medium)
                                Spacer()
                                Text(assoc.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                                IconActionButton(icon: "pencil", color: .accentColor, help: "Edit", action: { editingEventEventAssoc = assoc })
                                IconActionButton(icon: "trash", color: .red, help: "Delete", action: { Task { @MainActor in modelContext.delete(assoc) } })
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .alternatingRowBackground(index: index)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func countBadge(_ label: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)").font(.caption).fontWeight(.semibold).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func emptyState(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Text(title).font(.callout).foregroundStyle(.secondary)
            Text(subtitle).font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Forms

struct AddFigurePlaceAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @Query(sort: \FigurePlaceRoleType.name) private var roleTypes: [FigurePlaceRoleType]

    @State private var selectedFigure: FigureSearchResult?
    @State private var selectedPlace: Place?
    @State private var selectedRoleType: FigurePlaceRoleType?
    @State private var confidence: FigurePlaceAssociation.Confidence?
    @State private var source = ""
    @State private var comments = ""
    @State private var figureSearchText = ""
    @State private var placeSearchText = ""

    private var filteredFigures: [FigureSearchResult] {
        guard !figureSearchText.isEmpty else { return [] }
        let figs = figures.filter { selectedFigure == nil || $0.persistentModelID != selectedFigure!.figure.persistentModelID }
        return searchFigures(figs, query: figureSearchText)
    }

    private var filteredPlaces: [Place] {
        guard !placeSearchText.isEmpty else { return [] }
        return places.filter { p in
            (selectedPlace == nil || p.persistentModelID != selectedPlace!.persistentModelID) &&
            p.name.localizedCaseInsensitiveContains(placeSearchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Figure ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                Section("Figure") {
                    if let fig = selectedFigure {
                        HStack(spacing: 6) {
                            Text("\(fig.figure.gender.symbol) \(fig.displayName)")
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
                        TextField("Search figures\u{2026}", text: $figureSearchText)
                            .textFieldStyle(.roundedBorder)
                    }
                    if !figureSearchText.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                if filteredFigures.isEmpty {
                                    Text("No figures match \"\(figureSearchText)\"")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                } else {
                                    ForEach(filteredFigures, id: \.id) { result in
                                        Button {
                                            selectedFigure = result
                                            figureSearchText = ""
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

                Section("Place") {
                    if let place = selectedPlace {
                        HStack(spacing: 6) {
                            Text(place.name)
                                .fontWeight(.medium)
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
                        TextField("Search places\u{2026}", text: $placeSearchText)
                            .textFieldStyle(.roundedBorder)
                    }
                    if !placeSearchText.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                if filteredPlaces.isEmpty {
                                    Text("No places match \"\(placeSearchText)\"")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                } else {
                                    ForEach(filteredPlaces) { p in
                                        Button {
                                            selectedPlace = p
                                            placeSearchText = ""
                                        } label: {
                                            Text(p.name)
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

                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as FigurePlaceRoleType?)
                        ForEach(roleTypes) { rt in
                            Text(rt.name).tag(rt as FigurePlaceRoleType?)
                        }
                    }
                }

                Section("Confidence") {
                    Picker("Confidence", selection: $confidence) {
                        Text("Asserted").tag(nil as FigurePlaceAssociation.Confidence?)
                        ForEach(FigurePlaceAssociation.Confidence.allCases, id: \.self) { c in
                            Text(c.label).tag(c)
                        }
                    }
                }

                Section("Source") {
                    TextField("Source", text: $source)
                }

                Section("Comments") {
                    TextField("e.g. first antediluvian king", text: $comments)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }.keyboardShortcut(.defaultAction).disabled(selectedFigure == nil || selectedPlace == nil)
            }.padding()
        }
        .frame(width: 450, height: 540)
    }

    private func save() {
        let assoc = FigurePlaceAssociation(figure: selectedFigure?.figure, place: selectedPlace, roleType: selectedRoleType, source: source, comments: comments.isEmpty ? nil : comments, displayName: selectedFigure?.matchedAlternateName, confidence: confidence)
        modelContext.insert(assoc)
        dismiss()
    }
}

struct SearchableEntityList<Entity: PersistentModel>: View {
    let filtered: [Entity]
    let label: (Entity) -> Text
    let select: (Entity) -> Void

    var body: some View {
        if filtered.isEmpty {
            Text("No matches").font(.caption).foregroundStyle(.tertiary)
                .padding(.horizontal, 8).padding(.vertical, 6)
        } else {
            ForEach(filtered, id: \.persistentModelID) { entity in
                Button {
                    select(entity)
                } label: {
                    label(entity)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.05)).cornerRadius(4)
            }
        }
    }
}

struct SearchSection<Entity: PersistentModel>: View {
    let title: String
    let entities: [Entity]
    let selected: Binding<Entity?>
    let label: (Entity) -> Text
    @Binding var searchText: String
    let filter: (Entity, String) -> Bool

    private var filtered: [Entity] {
        guard !searchText.isEmpty else { return [] }
        return entities.filter { e in
            (selected.wrappedValue == nil || e.persistentModelID != selected.wrappedValue!.persistentModelID) &&
            filter(e, searchText)
        }
    }

    var body: some View {
        Section(title) {
            if let entity = selected.wrappedValue {
                HStack(spacing: 6) {
                    label(entity).fontWeight(.medium)
                    Spacer()
                    Button { selected.wrappedValue = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                    .help("Clear selection")
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(.quaternary.opacity(0.3)).cornerRadius(6)
            }
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                TextField("Search\u{2026}", text: $searchText).textFieldStyle(.roundedBorder)
            }
            if !searchText.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        SearchableEntityList(
                            filtered: filtered,
                            label: label,
                            select: { entity in
                                selected.wrappedValue = entity
                                searchText = ""
                            }
                        )
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }
}

struct AddPlacePlaceAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var places: [Place]
    @Query(sort: \PlacePlaceRoleType.name) private var roleTypes: [PlacePlaceRoleType]
    @Query(sort: \Source.name) private var sources: [Source]

    @State private var fromPlace: Place?
    @State private var toPlace: Place?
    @State private var selectedRoleType: PlacePlaceRoleType?
    @State private var selectedSource: Source?
    @State private var fromSearchText = ""
    @State private var toSearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Place ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                SearchSection(
                    title: "From Place",
                    entities: places,
                    selected: $fromPlace,
                    label: { Text($0.name) },
                    searchText: $fromSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as PlacePlaceRoleType?)
                        ForEach(roleTypes) { rt in Text(rt.name).tag(rt as PlacePlaceRoleType?) }
                    }
                }
                SearchSection(
                    title: "To Place",
                    entities: places,
                    selected: $toPlace,
                    label: { Text($0.name) },
                    searchText: $toSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Source") {
                    SourcePickerView(selection: $selectedSource, sources: sources)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }.keyboardShortcut(.defaultAction).disabled(fromPlace == nil || toPlace == nil)
            }.padding()
        }
        .frame(width: 450, height: 420)
    }

    private func save() {
        let assoc = PlacePlaceAssociation(fromPlace: fromPlace, toPlace: toPlace, roleType: selectedRoleType, source: selectedSource?.name ?? "")
        modelContext.insert(assoc)
        dismiss()
    }
}

struct AddEventEventAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var events: [Event]
    @Query(sort: \EventEventRoleType.name) private var roleTypes: [EventEventRoleType]

    @State private var fromEvent: Event?
    @State private var toEvent: Event?
    @State private var selectedRoleType: EventEventRoleType?
    @State private var source = ""
    @State private var fromSearchText = ""
    @State private var toSearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Event ↔ Event Association")
                .font(.title3.bold())
                .padding()
            Form {
                SearchSection(
                    title: "From Event",
                    entities: events,
                    selected: $fromEvent,
                    label: { Text($0.name) },
                    searchText: $fromSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as EventEventRoleType?)
                        ForEach(roleTypes) { rt in Text(rt.name).tag(rt as EventEventRoleType?) }
                    }
                }
                SearchSection(
                    title: "To Event",
                    entities: events,
                    selected: $toEvent,
                    label: { Text($0.name) },
                    searchText: $toSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Source") {
                    TextField("Source", text: $source)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }.keyboardShortcut(.defaultAction).disabled(fromEvent == nil || toEvent == nil)
            }.padding()
        }
        .frame(width: 450, height: 420)
    }

    private func save() {
        let assoc = EventEventAssociation(fromEvent: fromEvent, toEvent: toEvent, roleType: selectedRoleType, source: source)
        modelContext.insert(assoc)
        dismiss()
    }
}


// MARK: - Edit Forms

struct EditFigurePlaceAssociationForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @Query(sort: \FigurePlaceRoleType.name) private var roleTypes: [FigurePlaceRoleType]
    let assoc: FigurePlaceAssociation

    @State private var selectedFigure: FigureSearchResult?
    @State private var selectedPlace: Place?
    @State private var selectedRoleType: FigurePlaceRoleType?
    @State private var confidence: FigurePlaceAssociation.Confidence?
    @State private var source = ""
    @State private var comments = ""
    @State private var figureSearchText = ""
    @State private var placeSearchText = ""

    private var filteredFigures: [FigureSearchResult] {
        guard !figureSearchText.isEmpty else { return [] }
        let figs = figures.filter { selectedFigure == nil || $0.persistentModelID != selectedFigure!.figure.persistentModelID }
        return searchFigures(figs, query: figureSearchText)
    }

    private var filteredPlaces: [Place] {
        guard !placeSearchText.isEmpty else { return [] }
        return places.filter { p in
            (selectedPlace == nil || p.persistentModelID != selectedPlace!.persistentModelID) &&
            p.name.localizedCaseInsensitiveContains(placeSearchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Figure ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                Section("Figure") {
                    if let fig = selectedFigure {
                        HStack(spacing: 6) {
                            Text("\(fig.figure.gender.symbol) \(fig.displayName)")
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
                        TextField("Search figures\u{2026}", text: $figureSearchText)
                            .textFieldStyle(.roundedBorder)
                    }
                    if !figureSearchText.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                if filteredFigures.isEmpty {
                                    Text("No figures match \"\(figureSearchText)\"")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                } else {
                                    ForEach(filteredFigures, id: \.id) { result in
                                        Button {
                                            selectedFigure = result
                                            figureSearchText = ""
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

                Section("Place") {
                    if let place = selectedPlace {
                        HStack(spacing: 6) {
                            Text(place.name)
                                .fontWeight(.medium)
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
                        TextField("Search places\u{2026}", text: $placeSearchText)
                            .textFieldStyle(.roundedBorder)
                    }
                    if !placeSearchText.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                if filteredPlaces.isEmpty {
                                    Text("No places match \"\(placeSearchText)\"")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                } else {
                                    ForEach(filteredPlaces) { p in
                                        Button {
                                            selectedPlace = p
                                            placeSearchText = ""
                                        } label: {
                                            Text(p.name)
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

                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as FigurePlaceRoleType?)
                        ForEach(roleTypes) { rt in
                            Text(rt.name).tag(rt as FigurePlaceRoleType?)
                        }
                    }
                }
                Section("Confidence") {
                    Picker("Confidence", selection: $confidence) {
                        Text("Asserted").tag(nil as FigurePlaceAssociation.Confidence?)
                        ForEach(FigurePlaceAssociation.Confidence.allCases, id: \.self) { c in
                            Text(c.label).tag(c)
                        }
                    }
                }
                Section("Source") {
                    TextField("Source", text: $source)
                }

                Section("Comments") {
                    TextField("e.g. first antediluvian king", text: $comments)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()

        }
        .frame(width: 450, height: 560)
        .onAppear {
            if let fig = assoc.figure {
                selectedFigure = FigureSearchResult(figure: fig, matchedAlternateName: assoc.displayName)
            }
            selectedPlace = assoc.place
            selectedRoleType = assoc.roleType
            confidence = assoc.confidence
            source = assoc.source
            comments = assoc.comments ?? ""
        }
    }

    private func save() {
        assoc.figure = selectedFigure?.figure
        assoc.displayName = selectedFigure?.matchedAlternateName
        assoc.place = selectedPlace
        assoc.roleType = selectedRoleType
        assoc.confidence = confidence
        assoc.source = source
        assoc.comments = comments.isEmpty ? nil : comments
        dismiss()
    }
}

struct EditPlacePlaceAssociationForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var places: [Place]
    @Query(sort: \PlacePlaceRoleType.name) private var roleTypes: [PlacePlaceRoleType]
    @Query(sort: \Source.name) private var sources: [Source]
    let assoc: PlacePlaceAssociation

    @State private var fromPlace: Place?
    @State private var toPlace: Place?
    @State private var selectedRoleType: PlacePlaceRoleType?
    @State private var selectedSource: Source?
    @State private var fromSearchText = ""
    @State private var toSearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Place ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                SearchSection(
                    title: "From Place",
                    entities: places,
                    selected: $fromPlace,
                    label: { Text($0.name) },
                    searchText: $fromSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as PlacePlaceRoleType?)
                        ForEach(roleTypes) { rt in Text(rt.name).tag(rt as PlacePlaceRoleType?) }
                    }
                }
                SearchSection(
                    title: "To Place",
                    entities: places,
                    selected: $toPlace,
                    label: { Text($0.name) },
                    searchText: $toSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Source") {
                    SourcePickerView(selection: $selectedSource, sources: sources)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 450, height: 420)
        .onAppear {
            fromPlace = assoc.fromPlace
            toPlace = assoc.toPlace
            selectedRoleType = assoc.roleType
            selectedSource = sources.first { $0.name.compare(assoc.source, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        }
    }

    private func save() {
        assoc.fromPlace = fromPlace
        assoc.toPlace = toPlace
        assoc.roleType = selectedRoleType
        assoc.source = selectedSource?.name ?? ""
        dismiss()
    }
}

struct EditEventEventAssociationForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var events: [Event]
    @Query(sort: \EventEventRoleType.name) private var roleTypes: [EventEventRoleType]
    let assoc: EventEventAssociation

    @State private var fromEvent: Event?
    @State private var toEvent: Event?
    @State private var selectedRoleType: EventEventRoleType?
    @State private var source = ""
    @State private var fromSearchText = ""
    @State private var toSearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Event ↔ Event Association")
                .font(.title3.bold())
                .padding()
            Form {
                SearchSection(
                    title: "From Event",
                    entities: events,
                    selected: $fromEvent,
                    label: { Text($0.name) },
                    searchText: $fromSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as EventEventRoleType?)
                        ForEach(roleTypes) { rt in Text(rt.name).tag(rt as EventEventRoleType?) }
                    }
                }
                SearchSection(
                    title: "To Event",
                    entities: events,
                    selected: $toEvent,
                    label: { Text($0.name) },
                    searchText: $toSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Source") {
                    TextField("Source", text: $source)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 450, height: 420)
        .onAppear {
            fromEvent = assoc.fromEvent
            toEvent = assoc.toEvent
            selectedRoleType = assoc.roleType
            source = assoc.source
        }
    }

    private func save() {
        assoc.fromEvent = fromEvent
        assoc.toEvent = toEvent
        assoc.roleType = selectedRoleType
        assoc.source = source
        dismiss()
    }
}


struct EditRelationshipForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    let relationship: Relationship

    @State private var fromFigure: FigureSearchResult?
    @State private var toFigure: FigureSearchResult?
    @State private var fromSearchText = ""
    @State private var toSearchText = ""
    @Query private var allRelationTypes: [RelationshipType]
    @State private var selectedType: RelationshipType?
    @Query(sort: \Source.name) private var sources: [Source]
    @State private var selectedSource: Source?

    private var filteredFromFigures: [FigureSearchResult] {
        guard !fromSearchText.isEmpty else { return [] }
        let figs = figures.filter { fromFigure == nil || $0.persistentModelID != fromFigure!.figure.persistentModelID }
        return searchFigures(figs, query: fromSearchText)
    }

    private var filteredToFigures: [FigureSearchResult] {
        guard !toSearchText.isEmpty else { return [] }
        let figs = figures.filter { toFigure == nil || $0.persistentModelID != toFigure!.figure.persistentModelID }
        return searchFigures(figs, query: toSearchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Relationship")
                .font(.title3.bold())
                .padding()
            Form {
                Section("From") {
                    FigureSearchSelector(
                        selection: $fromFigure,
                        searchText: $fromSearchText,
                        figures: figures,
                        filteredFigures: filteredFromFigures,
                        placeholder: "Search from figure\u{2026}"
                    )
                }
                Section("Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(allRelationTypes, id: \.self) { t in Text(t.name).tag(t as RelationshipType?) }
                    }
                }
                Section("To") {
                    FigureSearchSelector(
                        selection: $toFigure,
                        searchText: $toSearchText,
                        figures: figures,
                        filteredFigures: filteredToFigures,
                        placeholder: "Search to figure\u{2026}"
                    )
                }
                Section("Source") {
                    SourcePickerView(selection: $selectedSource, sources: sources)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 450, height: 520)
        .onAppear {
            if let fig = relationship.fromFigure {
                fromFigure = FigureSearchResult(figure: fig, matchedAlternateName: nil)
            }
            if let fig = relationship.toFigure {
                toFigure = FigureSearchResult(figure: fig, matchedAlternateName: nil)
            }
            selectedType = relationship.relationshipType
            selectedSource = relationship.sourceRef ?? sources.first { $0.name.compare(relationship.source, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        }
        .onChange(of: fromFigure) { _, _ in inferType() }
    }

    private func save() {
        relationship.fromFigure = fromFigure?.figure
        relationship.toFigure = toFigure?.figure
        relationship.relationshipType = selectedType
        let oldSource = relationship.sourceRef
        if oldSource != selectedSource {
            if let old = oldSource {
                old.relationships.removeAll { $0.persistentModelID == relationship.persistentModelID }
            }
            relationship.sourceRef = nil
            if let newSource = selectedSource {
                newSource.relationships.append(relationship)
            }
        }
        relationship.source = selectedSource?.name ?? ""
        dismiss()
    }

    private func inferType() {
        switch fromFigure?.figure.gender {
        case .female: selectedType = allRelationTypes.first(where: { $0.name == "Mother" })
        case .male: selectedType = allRelationTypes.first(where: { $0.name == "Father" })
        default: break
        }
    }
}

// MARK: - Event ↔ Place Forms

struct AddEventPlaceAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var events: [Event]
    @Query private var places: [Place]
    @Query(sort: \EventPlaceRoleType.name) private var roleTypes: [EventPlaceRoleType]

    @State private var selectedEvent: Event?
    @State private var selectedPlace: Place?
    @State private var selectedRoleType: EventPlaceRoleType?
    @State private var source = ""
    @State private var eventSearchText = ""
    @State private var placeSearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Event ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                SearchSection(
                    title: "Event",
                    entities: events,
                    selected: $selectedEvent,
                    label: { Text($0.name) },
                    searchText: $eventSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as EventPlaceRoleType?)
                        ForEach(roleTypes) { rt in Text(rt.name).tag(rt as EventPlaceRoleType?) }
                    }
                }
                SearchSection(
                    title: "Place",
                    entities: places,
                    selected: $selectedPlace,
                    label: { Text($0.name) },
                    searchText: $placeSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Source") {
                    TextField("Source", text: $source)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }.keyboardShortcut(.defaultAction).disabled(selectedEvent == nil || selectedPlace == nil)
            }.padding()
        }
        .frame(width: 450, height: 420)
    }

    private func save() {
        let assoc = EventPlaceAssociation(event: selectedEvent, place: selectedPlace, roleType: selectedRoleType, source: source)
        modelContext.insert(assoc)
        dismiss()
    }
}

struct EditEventPlaceAssociationForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var events: [Event]
    @Query private var places: [Place]
    @Query(sort: \EventPlaceRoleType.name) private var roleTypes: [EventPlaceRoleType]
    let assoc: EventPlaceAssociation

    @State private var selectedEvent: Event?
    @State private var selectedPlace: Place?
    @State private var selectedRoleType: EventPlaceRoleType?
    @State private var source = ""
    @State private var eventSearchText = ""
    @State private var placeSearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Event ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                SearchSection(
                    title: "Event",
                    entities: events,
                    selected: $selectedEvent,
                    label: { Text($0.name) },
                    searchText: $eventSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as EventPlaceRoleType?)
                        ForEach(roleTypes) { rt in Text(rt.name).tag(rt as EventPlaceRoleType?) }
                    }
                }
                SearchSection(
                    title: "Place",
                    entities: places,
                    selected: $selectedPlace,
                    label: { Text($0.name) },
                    searchText: $placeSearchText,
                    filter: { $0.name.localizedCaseInsensitiveContains($1) }
                )
                Section("Source") {
                    TextField("Source", text: $source)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 450, height: 420)
        .onAppear {
            selectedEvent = assoc.event
            selectedPlace = assoc.place
            selectedRoleType = assoc.roleType
            source = assoc.source
        }
    }

    private func save() {
        assoc.event = selectedEvent
        assoc.place = selectedPlace
        assoc.roleType = selectedRoleType
        assoc.source = source
        dismiss()
    }
}
