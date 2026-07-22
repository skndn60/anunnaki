import SwiftUI
import SwiftData

struct ThingListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
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
    @State private var searchText = ""
    @State private var sortOrder: ThingSortOrder = .name

    enum ThingSortOrder: String, CaseIterable {
        case name = "Name"
        case source = "Source"
    }

    private var filteredThings: [Thing] {
        var result = things
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.thingDescription.lowercased().contains(query) ||
                $0.source.lowercased().contains(query)
            }
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
        .map { (key: $0.key, things: $0.value) }
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
                    TextField("🔍 Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .overlay(alignment: .trailing) {
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 6)
                                .help("Clear search")
                            }
                        }
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
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            Group {
                if let thing = selectedThing {
                    // ResizableDivider(width: $detailWidth, range: 200...800)
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") {
                                editingThing = thing
                            }
                            IconActionButton(icon: "trash", color: .red, help: "Delete") {
                                showDeleteConfirm = true
                            }
                            Spacer()
                            Button(action: { selectedThingID = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22, height: 22)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
                            }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
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
        }
        .animation(.easeInOut(duration: 0.25), value: selectedThingID)
        .sheet(isPresented: $showingAddSheet) {
            ThingFormView(thing: nil)
        }
        .sheet(item: $editingThing) { thing in
            ThingFormView(thing: thing)
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
        selectedThingID = id
    }

    private func thingGroupSection(_ group: (key: String, things: [Thing])) -> some View {
        Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
            ForEach(group.things) { thing in
                ThingRow(thing: thing)
                    .tag(thing.persistentModelID)
            }
        }
    }

    private func deleteThing(_ thing: Thing) {
        if selectedThingID == thing.persistentModelID { selectedThingID = nil }
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
                }

                if !thing.thingDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(thing.thingDescription)
                            .font(.body)
                    }
                }

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
                            label: assoc.figure?.name ?? "?",
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
                        asset.things.append(thing)
                    },
                    onSelectImage: onSelectImage
                )

                Spacer()
            }
            .padding(20)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Thing Form

struct ThingFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let thing: Thing?

    @Query private var thingTypes: [ThingType]

    @State private var name = ""
    @State private var thingDescription = ""
    @State private var source = ""
    @State private var selectedThingType: ThingType? = nil

    private var isEditing: Bool { thing != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Thing" : "Add Thing")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Thing Details") {
                    TextField("Name", text: $name, prompt: Text("e.g. Tablet of Destinies"))

                    if !thingTypes.isEmpty {
                        Picker("Type", selection: $selectedThingType) {
                            Text("None").tag(nil as ThingType?)
                            ForEach(thingTypes) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.name)
                                }.tag(type as ThingType?)
                            }
                        }
                    }
                }

                Section("Description") {
                    TextEditor(text: $thingDescription)
                        .frame(minHeight: 80)
                }

                Section("Source") {
                    TextField("Source", text: $source, prompt: Text("e.g. Enuma Elish"))
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
        .frame(width: 500, height: 400)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let thing else { return }
        name = thing.name
        thingDescription = thing.thingDescription
        source = thing.source
        selectedThingType = thing.thingType
    }

    private func save() {
        if let thing {
            thing.name = name
            thing.thingDescription = thingDescription
            thing.source = source
            thing.thingType = selectedThingType
            RecentEditStore.trackEdit(entityType: "Thing", entityName: thing.name)
        } else {
            let newThing = Thing(name: name, thingDescription: thingDescription, source: source)
            newThing.thingType = selectedThingType
            modelContext.insert(newThing)
            RecentEditStore.trackEdit(entityType: "Thing", entityName: newThing.name)
        }
        dismiss()
    }
}

// MARK: - Add Thing↔Figure Association Form

struct AddThingFigureAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let thing: Thing
    @Query(sort: \Figure.name) private var figures: [Figure]
    @Query(sort: \ThingFigureRoleType.name) private var roleTypes: [ThingFigureRoleType]

    @State private var selectedFigure: Figure?
    @State private var selectedRoleType: ThingFigureRoleType?
    @State private var source = ""
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Figure Association")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Figure") {
                    TextField("Search figures\u{2026}", text: $searchText)
                        .textFieldStyle(.plain)

                    let filtered = figures.filter {
                        searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(filtered) { figure in
                                Button(action: { selectedFigure = figure }) {
                                    HStack(spacing: 8) {
                                        if selectedFigure?.persistentModelID == figure.persistentModelID {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        } else {
                                            Color.clear.frame(width: 14, height: 14)
                                        }
                                        Text("\(figure.gender.symbol) \(figure.name)")
                                            .foregroundStyle(.primary)
                                        if let type = figure.figureType?.name {
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
                    TextField("Source", text: $source, prompt: Text("e.g. Enuma Elish"))
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
        guard let figure = selectedFigure else { return }
        let assoc = ThingFigureAssociation(
            thing: thing,
            figure: figure,
            roleType: selectedRoleType,
            source: source
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

    @State private var selectedPlace: Place?
    @State private var selectedRoleType: ThingPlaceRoleType?
    @State private var source = ""
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Place Association")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Place") {
                    TextField("Search places\u{2026}", text: $searchText)
                        .textFieldStyle(.plain)

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
                    TextField("Source", text: $source, prompt: Text("e.g. Enuma Elish"))
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
            source: source
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

    @State private var selectedEvent: Event?
    @State private var selectedRoleType: ThingEventRoleType?
    @State private var source = ""
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Event Association")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Event") {
                    TextField("Search events\u{2026}", text: $searchText)
                        .textFieldStyle(.plain)

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
                    TextField("Source", text: $source, prompt: Text("e.g. Enuma Elish"))
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
            source: source
        )
        modelContext.insert(assoc)
        dismiss()
    }
}
