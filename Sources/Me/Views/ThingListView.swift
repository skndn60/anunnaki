import SwiftUI
import SwiftData

struct ThingListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.userSession) private var userSession
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Thing.name) private var things: [Thing]
    @State private var showingAddSheet = false
    @State private var editingThing: Thing?
    @State private var selectedThingID: PersistentIdentifier?
    @AppStorage("thingDetailWidth") private var detailWidth: Double = 320
    @State private var showDeleteConfirm = false
    @State private var showingAddFigureAssociation = false
    @State private var showingAddPlaceAssociation = false
    @State private var showingAddEventAssociation = false
    @State private var associationToDelete: (any PersistentModel)?
    @State private var showDeleteAssociationConfirm = false
    @State private var imageDetailImage: ImageAsset?
    @State private var selectedTypeFilters: Set<String> = []
    @State private var sortOrder: ThingSortOrder = .name
    @Query(sort: \ThingType.name) private var thingTypes: [ThingType]
    @State private var showDescriptionEditor = false
    @State private var editRichDescription: Data? = nil
    @State private var editPlainDescription = ""

    enum ThingSortOrder: String, CaseIterable {
        case name = "Name"
        case source = "Source"
    }

    private var filteredThings: [Thing] {
        var result = things
        if !selectedTypeFilters.isEmpty {
            result = result.filter { selectedTypeFilters.contains($0.thingType?.name ?? "") }
        }
        switch sortOrder {
        case .name: result.sort { sortName(for: $0.name) < sortName(for: $1.name) }
        case .source: result.sort { $0.source < $1.source }
        }
        return result
    }

    private var groupedThings: [(key: String, things: [Thing])] {
        Dictionary(grouping: filteredThings) { thing in
            switch sortOrder {
            case .name: String(sortName(for: thing.name).uppercased().prefix(1))
            case .source: thing.source.isEmpty ? "?" : thing.source
            }
        }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, things: $0.value.sorted { sortName(for: $0.name) < sortName(for: $1.name) }) }
    }

    private var selectedThing: Thing? {
        guard let id = selectedThingID else { return nil }
        return filteredThings.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Things")
                        .font(.title2.bold())
                    Spacer()
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(ThingSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .frame(width: 120)
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Thing", systemImage: "plus")
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

                if !thingTypes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(thingTypes) { type in
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

                if filteredThings.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        if things.isEmpty {
                            Image(systemName: "cube.box")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No things defined")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("Add local color items, objects, or artifacts from the mythology.")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 300)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("No matching things")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $selectedThingID) {
                        ForEach(groupedThings, id: \.key) { group in
                            thingGroupSection(group)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .frame(minWidth: 450, maxWidth: .infinity)
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            Group {
                if let thing = selectedThing {
                    // ResizableDivider(width: $detailWidth, range: 200...800)
                    VStack(spacing: 0) {
                        DetailToolbar(
                            onEdit: { editingThing = thing },
                            onDelete: { showDeleteConfirm = true },
                            onClose: { selectedThingID = nil },
                            onEditDescription: {
                                editRichDescription = thing.richDescription
                                editPlainDescription = thing.thingDescription
                                showDescriptionEditor = true
                            }
                        )
                    ThingDetailView(
                            thing: thing,
                            onAddFigure: { showingAddFigureAssociation = true },
                            onAddPlace: { showingAddPlaceAssociation = true },
                            onAddEvent: { showingAddEventAssociation = true },
                            onDeleteAssociation: { model in
                                associationToDelete = model
                                showDeleteAssociationConfirm = true
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
            .animation(.easeInOut(duration: 0.25), value: selectedThingID)
        }
        .sheet(isPresented: $showingAddSheet) {
            ThingFormView(thing: nil)
        }
        .sheet(item: $editingThing) { thing in
            ThingFormView(thing: thing)
        }
        .sheet(isPresented: $showDescriptionEditor) {
            if let thing = selectedThing {
                DescriptionEditorSheet(
                    entityName: thing.name,
                    richDescription: $editRichDescription,
                    plainDescription: $editPlainDescription,
                    onSave: {
                        thing.richDescription = editRichDescription
                        thing.thingDescription = editPlainDescription
                        try? modelContext.save()
                    }
                )
            }
        }
        .sheet(isPresented: $showingAddFigureAssociation) {
            if let thing = selectedThing {
                AddThingFigureAssociationForm(thing: thing)
            }
        }
        .sheet(isPresented: $showingAddPlaceAssociation) {
            if let thing = selectedThing {
                AddThingPlaceAssociationForm(thing: thing)
            }
        }
        .sheet(isPresented: $showingAddEventAssociation) {
            if let thing = selectedThing {
                AddThingEventAssociationForm(thing: thing)
            }
        }
        .alert("Delete Thing?", isPresented: $showDeleteConfirm, presenting: selectedThing) { thing in
            Button("Delete", role: .destructive) { deleteThing(thing) }
            Button("Cancel", role: .cancel) {}
        } message: { thing in
            Text("Delete \"\(thing.name)\"? This cannot be undone.")
        }
        .alert("Delete Association?", isPresented: $showDeleteAssociationConfirm, presenting: associationToDelete as? AnyHashable) { _ in
            Button("Delete", role: .destructive) {
                if let model = associationToDelete {
                    modelContext.delete(model)
                    associationToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                associationToDelete = nil
            }
        } message: { _ in
            Text("Remove this association?")
        }
        .onAppear { consumePendingNavigation() }
        .onChange(of: coordinator?.pendingThingID) { _, _ in consumePendingNavigation() }
        .onChange(of: selectedThingID) { _, newValue in
            if let id = newValue, let thing = things.first(where: { $0.persistentModelID == id }) {
                coordinator?.pushHistory(id: id, name: thing.name, item: .things)
            }
        }
        .onChange(of: imageDetailImage) { _, newValue in
            if let image = newValue {
                openWindow(id: "image-detail", value: image.persistentModelID)
                imageDetailImage = nil
            }
        }
    }

    private func consumePendingNavigation() {
        guard let id = coordinator?.consumePendingThingID() else { return }
        Task { @MainActor in
            selectedThingID = id
        }
    }

    private func typeFilterButton(_ type: ThingType) -> some View {
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

    private func thingGroupSection(_ group: (key: String, things: [Thing])) -> some View {
        Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
            ForEach(group.things) { thing in
                ThingRow(thing: thing)
                    .tag(thing.persistentModelID)
                    .contextMenu {
                        Button("Edit") {
                            editingThing = thing
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            selectedThingID = thing.persistentModelID
                            showDeleteConfirm = true
                        }
                    }
            }
        }
    }

    private func deleteThing(_ thing: Thing) {
        if selectedThingID == thing.persistentModelID { selectedThingID = nil }
        ActivityLogger.record(action: .deleted, entityType: "Thing", entityName: thing.name, context: modelContext, session: userSession)
        withAnimation { modelContext.delete(thing) }
    }
}

struct ThingRow: View {
    let thing: Thing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.box")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 20)
            Text(thing.name)
                .fontWeight(.medium)
            if !thing.thingDescription.isEmpty {
                Text(thing.thingDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            if !thing.source.isEmpty {
                Text(thing.source)
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
    }
}

// MARK: - Thing Detail

struct ThingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let thing: Thing
    var onAddFigure: (() -> Void)?
    var onAddPlace: (() -> Void)?
    var onAddEvent: (() -> Void)?
    var onDeleteAssociation: ((any PersistentModel) -> Void)?
    var onSelectImage: ((ImageAsset) -> Void)?
    @State private var showDescriptionEditor = false
    @State private var editRichDescription: Data? = nil
    @State private var editPlainDescription = ""
    @State private var showAddAttribution = false
    @State private var editingAttribution: ContentAttribution?

    private var thingAttributions: [ContentAttribution] {
        let all: [ContentAttribution] = modelContext.fetchAll()
        return all.filter { $0.thing == thing }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    if let type = thing.thingType {
                        Image(systemName: type.icon)
                            .foregroundStyle(type.color)
                        Text(type.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(thing.name)
                        .font(.title2.bold())

                    Spacer()

                    Button {
                        editRichDescription = thing.richDescription
                        editPlainDescription = thing.thingDescription
                        showDescriptionEditor = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit description")
                }
                .sheet(isPresented: $showDescriptionEditor) {
                    DescriptionEditorSheet(
                        entityName: thing.name,
                        richDescription: $editRichDescription,
                        plainDescription: $editPlainDescription
                    )
                    .onDisappear {
                        thing.richDescription = editRichDescription
                        thing.thingDescription = editPlainDescription
                        try? modelContext.save()
                    }
                }

                if !thing.thingDescription.isEmpty || thing.richDescription != nil {
                    AttributedPropertyView(attributions: thingAttributions, propertyName: "thingDescription") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LinkedDescription(text: thing.thingDescription, richData: thing.richDescription)
                                .font(.body)
                        }
                    }
                }

                // Attributions
                ContentAttributionSection(
                    attributions: thingAttributions,
                    onAdd: { showAddAttribution = true },
                    onEdit: { editingAttribution = $0 },
                    onDelete: { attribution in
                        modelContext.delete(attribution)
                        try? modelContext.save()
                    }
                )

                if !thing.source.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(thing.source)
                            .font(.body)
                    }
                }

                // Stickies
                StickyNoteSection(stickies: thing.stickies) { text in
                    let note = StickyNote(text: text, thing: thing)
                    modelContext.insert(note)
                }

                Divider()

                // Associated Figures
                AssociationSection(
                    title: "Associated Figures",
                    icon: "person.fill",
                    color: .blue,
                    isEmpty: thing.figureAssociations.isEmpty,
                    onAdd: { onAddFigure?() }
                ) {
                    ForEach(thing.figureAssociations) { assoc in
                        AssociationRow(
                            icon: assoc.roleType?.icon ?? "person",
                            color: assoc.roleType?.color ?? .blue,
                            label: assoc.displayName.map { "\(assoc.figure?.name ?? "?") as \($0)" } ?? (assoc.figure?.name ?? "?"),
                            role: assoc.roleType?.name,
                            source: assoc.source
                        ) {
                            onDeleteAssociation?(assoc)
                        }
                    }
                }

                Divider()

                // Associated Places
                AssociationSection(
                    title: "Associated Places",
                    icon: "building.columns",
                    color: .teal,
                    isEmpty: thing.placeAssociations.isEmpty,
                    onAdd: { onAddPlace?() }
                ) {
                    ForEach(thing.placeAssociations) { assoc in
                        AssociationRow(
                            icon: assoc.roleType?.icon ?? "mappin",
                            color: assoc.roleType?.color ?? .teal,
                            label: assoc.place?.name ?? "?",
                            role: assoc.roleType?.name,
                            source: assoc.source
                        ) {
                            onDeleteAssociation?(assoc)
                        }
                    }
                }

                Divider()

                // Associated Events
                AssociationSection(
                    title: "Associated Events",
                    icon: "bolt.fill",
                    color: .orange,
                    isEmpty: thing.eventAssociations.isEmpty,
                    onAdd: { onAddEvent?() }
                ) {
                    ForEach(thing.eventAssociations) { assoc in
                        AssociationRow(
                            icon: assoc.roleType?.icon ?? "bolt",
                            color: assoc.roleType?.color ?? .orange,
                            label: assoc.event?.name ?? "?",
                            role: assoc.roleType?.name,
                            source: assoc.source
                        ) {
                            onDeleteAssociation?(assoc)
                        }
                    }
                }

                // Tags
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TagEditorView(tags: Binding(
                        get: { thing.tags },
                        set: { thing.tags = $0 }
                    ))
                }

                // Images
                Divider()
                ImageGallery(
                    title: "Images",
                    images: thing.images,
                    onLinkImage: { asset in
                        thing.images.append(asset)
                    },
                    onSelectImage: onSelectImage
                )

                // Groups
                EntityGroupsSection(
                    associations: thing.groupAssociations,
                    onCreateAssociation: { group in
                        let assoc = FigureGroupAssociation(thing: thing)
                        modelContext.insert(assoc)
                        thing.groupAssociations.append(assoc)
                        group.figureAssociations.append(assoc)
                        try? modelContext.save()
                    }
                )

                Spacer()
            }
            .padding(20)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showAddAttribution) {
            ContentAttributionFormView(attribution: nil)
        }
        .sheet(item: $editingAttribution) { attribution in
            ContentAttributionFormView(attribution: attribution)
        }
    }
}

// MARK: - Association Section

struct AssociationSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let isEmpty: Bool
    let onAdd: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Add \(title.lowercased())")
            }

            if isEmpty {
                Text("None")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                content
            }
        }
    }
}

// MARK: - Association Row

struct AssociationRow: View {
    let icon: String
    let color: Color
    let label: String
    let role: String?
    let source: String
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(label)
                .font(.callout)
                .fontWeight(.medium)
            if let role {
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !source.isEmpty {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Remove association")
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Thing↔Figure Association Form

struct AddThingFigureAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let thing: Thing
    @Query(sort: \Figure.name) private var figures: [Figure]
    @Query(sort: \ThingFigureRoleType.name) private var roleTypes: [ThingFigureRoleType]
    @Query(sort: \Source.name) private var sources: [Source]

    @State private var selectedFigure: FigureSearchResult?
    @State private var selectedRoleType: ThingFigureRoleType?
    @State private var selectedSource: Source?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Figure Association")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Figure") {
                    TextField("Search figures\u{2026}", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    let filtered = searchFigures(figures, query: searchText)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(filtered) { result in
                                Button(action: { selectedFigure = result }) {
                                    HStack(spacing: 8) {
                                        if selectedFigure?.figure.persistentModelID == result.figure.persistentModelID {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        } else {
                                            Color.clear.frame(width: 14, height: 14)
                                        }
                                        Text("\(result.figure.gender.symbol) \(result.displayName)")
                                            .foregroundStyle(.primary)
                                        if let type = result.figure.figureType?.name {
                                            Text(type)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }

                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as ThingFigureRoleType?)
                        ForEach(roleTypes) { rt in
                            HStack {
                                Image(systemName: rt.icon)
                                Text(rt.name)
                            }.tag(rt as ThingFigureRoleType?)
                        }
                    }
                }

                Section("Source") {
                    SourcePickerView(selection: $selectedSource, sources: sources)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedFigure == nil)
            }
            .padding()
        }
        .frame(width: 450, height: 480)
    }

    private func save() {
        guard let figure = selectedFigure?.figure else { return }
        let assoc = ThingFigureAssociation(
            thing: thing,
            figure: figure,
            roleType: selectedRoleType,
            source: selectedSource?.name ?? "",
            displayName: selectedFigure?.matchedAlternateName
        )
        modelContext.insert(assoc)
        dismiss()
    }
}

// MARK: - Add Thing↔Place Association Form

struct AddThingPlaceAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let thing: Thing
    @Query(sort: \Place.name) private var places: [Place]
    @Query(sort: \ThingPlaceRoleType.name) private var roleTypes: [ThingPlaceRoleType]
    @Query(sort: \Source.name) private var sources: [Source]

    @State private var selectedPlace: Place?
    @State private var selectedRoleType: ThingPlaceRoleType?
    @State private var selectedSource: Source?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Place Association")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Place") {
                    TextField("Search places\u{2026}", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    let filtered = places.filter {
                        searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(filtered) { place in
                                Button(action: { selectedPlace = place }) {
                                    HStack(spacing: 8) {
                                        if selectedPlace?.persistentModelID == place.persistentModelID {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        } else {
                                            Color.clear.frame(width: 14, height: 14)
                                        }
                                        Text(place.name)
                                            .foregroundStyle(.primary)
                                        if let type = place.placeType?.name {
                                            Text(type)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }

                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as ThingPlaceRoleType?)
                        ForEach(roleTypes) { rt in
                            HStack {
                                Image(systemName: rt.icon)
                                Text(rt.name)
                            }.tag(rt as ThingPlaceRoleType?)
                        }
                    }
                }

                Section("Source") {
                    SourcePickerView(selection: $selectedSource, sources: sources)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedPlace == nil)
            }
            .padding()
        }
        .frame(width: 450, height: 480)
    }

    private func save() {
        guard let place = selectedPlace else { return }
        let assoc = ThingPlaceAssociation(
            thing: thing,
            place: place,
            roleType: selectedRoleType,
            source: selectedSource?.name ?? ""
        )
        modelContext.insert(assoc)
        dismiss()
    }
}

// MARK: - Add Thing↔Event Association Form

struct AddThingEventAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let thing: Thing
    @Query(sort: \Event.name) private var events: [Event]
    @Query(sort: \ThingEventRoleType.name) private var roleTypes: [ThingEventRoleType]
    @Query(sort: \Source.name) private var sources: [Source]

    @State private var selectedEvent: Event?
    @State private var selectedRoleType: ThingEventRoleType?
    @State private var selectedSource: Source?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Event Association")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Event") {
                    TextField("Search events\u{2026}", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    let filtered = events.filter {
                        searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(filtered) { event in
                                Button(action: { selectedEvent = event }) {
                                    HStack(spacing: 8) {
                                        if selectedEvent?.persistentModelID == event.persistentModelID {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        } else {
                                            Color.clear.frame(width: 14, height: 14)
                                        }
                                        Text(event.name)
                                            .foregroundStyle(.primary)
                                        if let type = event.eventType?.name {
                                            Text(type)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }

                Section("Role") {
                    Picker("Role", selection: $selectedRoleType) {
                        Text("Select").tag(nil as ThingEventRoleType?)
                        ForEach(roleTypes) { rt in
                            HStack {
                                Image(systemName: rt.icon)
                                Text(rt.name)
                            }.tag(rt as ThingEventRoleType?)
                        }
                    }
                }

                Section("Source") {
                    SourcePickerView(selection: $selectedSource, sources: sources)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedEvent == nil)
            }
            .padding()
        }
        .frame(width: 450, height: 480)
    }

    private func save() {
        guard let event = selectedEvent else { return }
        let assoc = ThingEventAssociation(
            thing: thing,
            event: event,
            roleType: selectedRoleType,
            source: selectedSource?.name ?? ""
        )
        modelContext.insert(assoc)
        dismiss()
    }
}
