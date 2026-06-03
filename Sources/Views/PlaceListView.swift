import SwiftUI
import SwiftData

/// Input screen for managing places.
struct PlaceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var places: [Place]
    @State private var showingAddSheet = false
    @State private var editingPlace: Place?
    @State private var selectedPlaceID: PersistentIdentifier?
    @State private var sortOrder: PlaceSortOrder = .name
    @State private var breadcrumbs: [(id: PersistentIdentifier, name: String)] = []

    enum PlaceSortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
    }

    private var selectedPlace: Place? {
        guard let id = selectedPlaceID else { return nil }
        return sortedPlaces.first { $0.persistentModelID == id }
    }

    private var sortedPlaces: [Place] {
        switch sortOrder {
        case .name: return places.sorted { $0.name < $1.name }
        case .type: return places.sorted { $0.placeType.rawValue < $1.placeType.rawValue }
        }
    }

    private func selectPlace(_ id: PersistentIdentifier) {
        if let place = places.first(where: { $0.persistentModelID == id }) {
            if breadcrumbs.last?.id != id {
                breadcrumbs.append((id: id, name: place.name))
                if breadcrumbs.count > 12 { breadcrumbs.removeFirst() }
            }
        }
        selectedPlaceID = id
    }

    private func navigateToBreadcrumb(at index: Int) {
        let crumb = breadcrumbs[index]
        breadcrumbs = Array(breadcrumbs.prefix(index + 1))
        selectedPlaceID = crumb.id
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
                if !breadcrumbs.isEmpty {
                    BreadcrumbBar(breadcrumbs: breadcrumbs, onNavigate: navigateToBreadcrumb, onClear: { breadcrumbs.removeAll() })
                }

                PlaceTypeLegend()
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
                    List(sortedPlaces, selection: $selectedPlaceID) { place in
                        PlaceRow(place: place)
                            .tag(place.persistentModelID)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .onChange(of: selectedPlaceID) { _, newValue in
                        if let id = newValue { selectPlace(id) }
                    }
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            if let place = selectedPlace {
                Divider()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        IconActionButton(icon: "pencil", color: .accentColor) {
                            editingPlace = place
                        }
                        IconActionButton(icon: "trash", color: .red) {
                            deletePlace(place)
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
                    .padding(8)
                    PlaceDetailView(place: place)
                }
                .frame(width: 320)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            PlaceFormView(place: nil)
        }
        .sheet(item: $editingPlace) { place in
            PlaceFormView(place: place)
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
            Image(systemName: place.placeType.icon)
                .font(.caption)
                .foregroundStyle(.teal)
                .frame(width: 16)
            Text(place.name)
                .fontWeight(.medium)
            Text(place.placeType.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.teal.opacity(0.12)))
            Text(place.modernLocation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
    }
}

// MARK: - Place Form

struct PlaceFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let place: Place?

    @State private var name = ""
    @State private var placeType: Place.PlaceType = .city
    @State private var modernLocation = ""
    @State private var placeDescription = ""
    @State private var source = ""
    @State private var latitudeStr = ""
    @State private var longitudeStr = ""

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
                        ForEach(Place.PlaceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
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
        } else {
            let newPlace = Place(
                name: name, placeType: placeType,
                modernLocation: modernLocation,
                placeDescription: placeDescription, source: source,
                latitude: Double(latitudeStr),
                longitude: Double(longitudeStr)
            )
            modelContext.insert(newPlace)
        }
        dismiss()
    }
}
