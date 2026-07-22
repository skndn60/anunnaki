import SwiftUI
import SwiftData

struct SumerianKingPlaceListView: View {
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query private var places: [Place]
    @Query(sort: \Era.orderIndex) private var eras: [Era]

    @AppStorage("sklPlaceDetailWidth") private var detailWidth: Double = 320
    @State private var selectedPlaceID: PersistentIdentifier?
    @State private var imageDetailImage: ImageAsset?
    @State private var showDeleteConfirm = false
    @State private var editingPlace: Place?

    private var sklPlaces: [Place] {
        places.filter { $0.source.contains("Sumerian King List") }
    }

    private var selectedPlace: Place? {
        guard let id = selectedPlaceID else { return nil }
        return sklPlaces.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Divider()
                if sklPlaces.isEmpty {
                    emptyState
                } else {
                    placeList
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            Group {
                if let place = selectedPlace {
                    // ResizableDivider(width: $detailWidth, range: 200...800)
                    detailPanel(place: place)
                    .frame(width: detailWidth)
                    .frame(maxHeight: .infinity)
                    .background(.thinMaterial)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.25), value: selectedPlaceID)
        .onChange(of: selectedPlaceID) { _, newValue in
            if newValue == nil { selectedPlaceID = nil }
        }
        .alert("Delete Place?", isPresented: $showDeleteConfirm, presenting: selectedPlace) { place in
            Button("Delete", role: .destructive) { deletePlace(place) }
            Button("Cancel", role: .cancel) {}
        } message: { place in
            Text("Delete \"\(place.name)\"? This cannot be undone.")
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
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("SKL Capitals")
                .font(.title2.bold())
            Spacer()
            Text("\(sklPlaces.count) cities")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "building.columns")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No SKL place data")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Seed the database with --reseed to load the Sumerian King List places.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Place List

    private var placeList: some View {
        List(selection: $selectedPlaceID) {
            ForEach(sklPlaces, id: \.persistentModelID) { place in
                PlaceRow(place: place)
                    .tag(place.persistentModelID)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Detail Panel

    private func detailPanel(place: Place) -> some View {
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
                .help("Close")
            }
            .padding(.vertical, 8)
            PlaceDetailView(
                place: place,
                onSelectFigure: { figure in
                    coordinator?.pushHistory(id: place.persistentModelID, name: place.name, item: .places)
                    coordinator?.navigateToFigure(figure.persistentModelID, name: figure.name, recordHistory: false)
                },
                onSelectEvent: { event in
                    coordinator?.pushHistory(id: place.persistentModelID, name: place.name, item: .places)
                    coordinator?.navigateToEvent(event.persistentModelID, name: event.name, recordHistory: false)
                },
                onSelectImage: { imageDetailImage = $0 },
                backLabel: nil,
                onBack: nil
            )
        }
    }

    private func deletePlace(_ place: Place) {
        if selectedPlaceID == place.persistentModelID {
            selectedPlaceID = nil
        }
        withAnimation { modelContext.delete(place) }
    }
}
