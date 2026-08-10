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
    @State private var selectedTypeFilters: Set<String> = []
    @Query(sort: \PlaceType.name) private var placeTypes: [PlaceType]
    @State private var showDescriptionEditor = false
    @State private var editRichDescription: Data? = nil
    @State private var editPlainDescription = ""

    enum PlaceSortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
    }

    private var selectedPlace: Place? {
        guard let id = selectedPlaceID else { return nil }
        return filteredPlaces.first { $0.persistentModelID == id }
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

    private func effectiveSortName(_ place: Place) -> String {
        place.sortName.map { sortName(for: $0) } ?? sortName(for: place.name)
    }

    private var filteredPlaces: [Place] {
        var result = places
        if !selectedTypeFilters.isEmpty {
            result = result.filter { selectedTypeFilters.contains($0.placeType?.name ?? "") }
        }
        switch sortOrder {
        case .name: return result.sorted { effectiveSortName($0) < effectiveSortName($1) }
        case .type: return result.sorted { $0.placeType?.name ?? "" < $1.placeType?.name ?? "" }
        }
    }

    private var groupedPlaces: [(key: String, places: [Place])] {
        Dictionary(grouping: filteredPlaces) { place in
            switch sortOrder {
            case .name: String(effectiveSortName(place).uppercased().prefix(1))
            case .type: place.placeType?.name ?? "?"
            }
        }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, places: $0.value.sorted { effectiveSortName($0) < effectiveSortName($1) }) }
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
                if !placeTypes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(placeTypes) { type in
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
                    ScrollViewReader { proxy in
                        List(selection: $selectedPlaceID) {
                            ForEach(groupedPlaces, id: \.key) { group in
                                placeGroupSection(group)
                            }
                        }
                        .listStyle(.inset(alternatesRowBackgrounds: true))
                        .onChange(of: selectedPlaceID) { _, newValue in
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

            Group {
                if let place = selectedPlace {
                    // ResizableDivider(width: $detailWidth, range: 200...800)
                    VStack(spacing: 0) {
                        DetailToolbar(
                            onEdit: { editingPlace = place },
                            onDelete: { showDeleteConfirm = true },
                            onClose: { selectedPlaceID = nil },
                            onEditDescription: {
                                editRichDescription = place.richDescription
                                editPlainDescription = place.placeDescription
                                showDescriptionEditor = true
                            }
                        )
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
            .animation(.easeInOut(duration: 0.25), value: selectedPlaceID)
        }
        .sheet(isPresented: $showingAddSheet) {
            PlaceFormView(place: nil)
        }
        .sheet(item: $editingPlace) { place in
            PlaceFormView(place: place)
        }
        .sheet(isPresented: $showDescriptionEditor) {
            if let place = selectedPlace {
                DescriptionEditorSheet(
                    entityName: place.name,
                    richDescription: $editRichDescription,
                    plainDescription: $editPlainDescription,
                    onSave: {
                        place.richDescription = editRichDescription
                        place.placeDescription = editPlainDescription
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
            Task { @MainActor in
                selectPlace(id)
            }
        }
    }

    private func typeFilterButton(_ type: PlaceType) -> some View {
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

    private func placeGroupSection(_ group: (key: String, places: [Place])) -> some View {
        Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
            ForEach(group.places) { place in
                PlaceRow(place: place)
                    .tag(place.persistentModelID)
                    .id(place.persistentModelID)
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
