import SwiftUI
import SwiftData

/// Input screen for managing places.
struct PlaceListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query private var places: [Place]
    @State private var showingAddSheet = false
    @State private var editingPlace: Place?
    @State private var selectedPlaceID: PersistentIdentifier?
    @State private var sortOrder: PlaceSortOrder = .name
    @State private var imageDetailImage: ImageAsset?
    @AppStorage("placeDetailWidth") private var detailWidth: Double = 320
    @State private var showDeleteConfirm = false
    @Query(sort: \PlaceType.name) private var placeTypes: [PlaceType]

    enum PlaceSortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
    }

    private var selectedPlace: Place? {
        guard let id = selectedPlaceID else { return nil }
        return sortedPlaces.first { $0.persistentModelID == id }
    }

    private var backLabel: String? {
        guard let history = coordinator?.history, history.count >= 2 else { return nil }
        return history[history.count - 2].name
    }

    private var backAction: (() -> Void)? {
        guard let history = coordinator?.history, history.count >= 2 else { return nil }
        let index = history.count - 2
        return { self.coordinator?.navigateToHistory(at: index) }
    }

    private var sortedPlaces: [Place] {
        switch sortOrder {
        case .name: return places.sorted { sortName(for: $0.name) < sortName(for: $1.name) }
        case .type: return places.sorted { $0.placeType?.name ?? "" < $1.placeType?.name ?? "" }
        }
    }

    private var groupedPlaces: [(key: String, places: [Place])] {
        Dictionary(grouping: sortedPlaces) { place in
            switch sortOrder {
            case .name: String(sortName(for: place.name).uppercased().prefix(1))
            case .type: place.placeType?.name ?? "?"
            }
        }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, places: $0.value) }
    }

    private func selectPlace(_ id: PersistentIdentifier) {
        selectedPlaceID = id
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Places")
                        .font(.title2.bold())
                    Spacer()
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(PlaceSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .frame(width: 130)
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Place", systemImage: "plus")
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
                PlaceTypeLegend(types: placeTypes)
                    .padding(.horizontal)
                    .padding(.vertical, 4)

                Divider()

                if places.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "building.columns")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No places yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Add cities, temples, regions, and cosmic realms from the ancient world.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $selectedPlaceID) {
                        ForEach(groupedPlaces, id: \.key) { group in
                            placeGroupSection(group)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .onChange(of: selectedPlaceID) { _, newValue in
                        if let id = newValue { selectPlace(id) }
                    }
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            Group {
                if let place = selectedPlace {
                    // ResizableDivider(width: $detailWidth, range: 200...800)
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") {
                                editingPlace = place
                            }
                            IconActionButton(icon: "trash", color: .red, help: "Delete") {
                                showDeleteConfirm = true
                            }
                            Spacer()
                            Button(action: { selectedPlaceID = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22, height: 22)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
                            }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                    PlaceDetailView(
                            place: place,
                            onSelectFigure: { figure in
                                if let id = figure.persistentModelID as? PersistentIdentifier {
                                    coordinator?.pushHistory(id: place.persistentModelID, name: place.name, item: .places)
                                    coordinator?.navigateToFigure(id, name: figure.name, recordHistory: false)
                                }
                            },
                            onSelectEvent: { event in
                                if let id = event.persistentModelID as? PersistentIdentifier {
                                    coordinator?.pushHistory(id: place.persistentModelID, name: place.name, item: .places)
                                    coordinator?.navigateToEvent(id, name: event.name, recordHistory: false)
                                }
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
        .animation(.easeInOut(duration: 0.25), value: selectedPlaceID)
        .sheet(isPresented: $showingAddSheet) {
            PlaceFormView(place: nil)
        }
        .sheet(item: $editingPlace) { place in
            PlaceFormView(place: place)
        }

        .onChange(of: imageDetailImage) { _, newValue in
            if let image = newValue {
                openWindow(id: "image-detail", value: image.persistentModelID)
                imageDetailImage = nil
            }
        }
        .alert("Delete Place?", isPresented: $showDeleteConfirm, presenting: selectedPlace) { place in
            Button("Delete", role: .destructive) { deletePlace(place) }
            Button("Cancel", role: .cancel) {}
        } message: { place in
            Text("Delete \"\(place.name)\"? This cannot be undone.")
        }
        .onAppear {
            consumePendingNavigation()
        }
        .onChange(of: coordinator?.pendingPlaceID) { _, _ in
            consumePendingNavigation()
        }
    }

    private func consumePendingNavigation() {
        guard let id = coordinator?.consumePendingPlaceID() else { return }
        if places.contains(where: { $0.persistentModelID == id }) {
            selectPlace(id)
        }
    }

    private func placeGroupSection(_ group: (key: String, places: [Place])) -> some View {
        Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
            ForEach(group.places) { place in
                PlaceRow(place: place)
                    .tag(place.persistentModelID)
            }
        }
    }

    private func deletePlace(_ place: Place) {
        if selectedPlaceID == place.persistentModelID { selectedPlaceID = nil }
        withAnimation { modelContext.delete(place) }
    }
}

struct PlaceRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: place.placeType?.icon ?? "mappin")
                .font(.caption)
                .foregroundStyle(.teal)
                .frame(width: 16)
            Text(place.name)
                .fontWeight(.medium)
            Text(place.placeType?.name ?? "City")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.teal.opacity(0.12)))
            Text(place.modernLocation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if place.isConcept {
                Text("Concept")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(.orange.opacity(0.12)))
            }
            if place.stickies.contains(where: { !$0.isResolved }) {
                Circle()
                    .fill(.yellow)
                    .frame(width: 10, height: 10)
            }
            Spacer()
        }
    }
}

// MARK: - Place Form

struct PlaceFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let place: Place?
    @Query(sort: \PlaceType.name) private var placeTypes: [PlaceType]

    @State private var name = ""
    @State private var placeType: PlaceType? = nil
    @State private var modernLocation = ""
    @State private var placeDescription = ""
    @State private var source = ""
    @State private var latitudeStr = ""
    @State private var longitudeStr = ""
    @State private var selectedTags: [Tag] = []
    @State private var foundedDate: MythologicalDate = .unknown

    private var isEditing: Bool { place != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Place" : "Add Place")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Place Details") {
                    TextField("Name", text: $name, prompt: Text("e.g. Uruk, Eridu, Kur"))
                    Picker("Type", selection: $placeType) {
                        ForEach(placeTypes, id: \.persistentModelID) { type in
                            Text(type.name).tag(type as PlaceType?)
                        }
                    }
                    TextField("Modern Location", text: $modernLocation, prompt: Text("e.g. Southern Iraq, Warka"))
                    TextField("Source", text: $source, prompt: Text("e.g. Sumerian King List"))
                }

                Section("Coordinates") {
                    TextField("Latitude", text: $latitudeStr, prompt: Text("e.g. 31.322"))
                    TextField("Longitude", text: $longitudeStr, prompt: Text("e.g. 45.637"))
                }

                Section("Description") {
                    TextEditor(text: $placeDescription)
                        .frame(minHeight: 80)
                }

                MythologicalDateEditor(label: "Founded", date: $foundedDate)

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
        .frame(width: 480, height: 420)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let place else { return }
        name = place.name
        placeType = place.placeType
        modernLocation = place.modernLocation
        placeDescription = place.placeDescription
        source = place.source
        latitudeStr = place.latitude.map { String($0) } ?? ""
        longitudeStr = place.longitude.map { String($0) } ?? ""
        selectedTags = place.tags
        foundedDate = place.foundedDate ?? .unknown
    }

    private func save() {
        if let place {
            place.name = name
            place.placeType = placeType
            place.modernLocation = modernLocation
            place.placeDescription = placeDescription
            place.source = source
            place.latitude = Double(latitudeStr)
            place.longitude = Double(longitudeStr)
            place.isConcept = false
            place.tags = selectedTags
            place.foundedDate = foundedDate
            RecentEditStore.trackEdit(entityType: "Place", entityName: place.name)
        } else {
            let newPlace = Place(
                name: name, placeType: placeType,
                modernLocation: modernLocation,
                placeDescription: placeDescription, source: source,
                latitude: Double(latitudeStr),
                longitude: Double(longitudeStr)
            )
            newPlace.tags = selectedTags
            newPlace.foundedDate = foundedDate
            modelContext.insert(newPlace)
            RecentEditStore.trackEdit(entityType: "Place", entityName: newPlace.name)
        }
        dismiss()
    }
}
