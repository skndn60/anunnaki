import SwiftUI
import SwiftData

struct EnochView: View {
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext
    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @Query(sort: \FigureType.name) private var figureTypes: [FigureType]

    @State private var selectedID: PersistentIdentifier?
    @State private var editingFigure: Figure?
    @State private var editingPlace: Place?
    @State private var imageDetailImage: ImageAsset?
    @State private var showDeleteConfirm = false

    private var enochFigures: [Figure] {
        figures.filter { $0.source.contains("Enoch") }
    }

    private var enochPlaces: [Place] {
        places.filter { $0.source.contains("Enoch") }
    }

    private var hasData: Bool { !enochFigures.isEmpty || !enochPlaces.isEmpty }

    private var groupedFigures: [(name: String, figures: [Figure])] {
        let sectionNames: [String] = ["Commanders", "Watchers", "Archangels", "Righteous"]
        var groups: [(String, [Figure])] = []
        for sectionName in sectionNames {
            let typeName: String
            switch sectionName {
            case "Commanders": typeName = "Commander"
            case "Watchers": typeName = "Igigi"
            case "Archangels": typeName = "Archangel"
            case "Righteous": typeName = "Human"
            default: continue
            }
            let matching = enochFigures.filter { $0.figureType?.name == typeName }
            if !matching.isEmpty {
                groups.append((sectionName, matching))
            }
        }
        return groups
    }

    private var selectedFigure: Figure? {
        guard let id = selectedID else { return nil }
        return enochFigures.first { $0.persistentModelID == id }
    }

    private var selectedPlace: Place? {
        guard let id = selectedID else { return nil }
        return enochPlaces.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Divider()
                if !hasData {
                    emptyState
                } else {
                    entityList
                }
            }
            .frame(minWidth: 500, maxWidth: .infinity)

            if let figure = selectedFigure {
                Divider()
                figureDetailPanel(figure: figure)
                    .frame(width: 320)
            } else if let place = selectedPlace {
                Divider()
                placeDetailPanel(place: place)
                    .frame(width: 320)
            }
        }
        .onChange(of: selectedID) { _, newValue in
            if newValue == nil { selectedID = nil }
        }
        .alert("Delete Figure?", isPresented: $showDeleteConfirm, presenting: selectedFigure) { figure in
            Button("Delete", role: .destructive) { deleteFigure(figure) }
            Button("Cancel", role: .cancel) {}
        } message: { figure in
            Text("Delete \"\(figure.name)\"? This cannot be undone.")
        }
        .sheet(item: $editingFigure) { figure in
            FigureFormView(figure: figure)
        }
        .sheet(item: $editingPlace) { place in
            PlaceFormView(place: place)
        }
    }

    private var header: some View {
        HStack {
            Text("Book of Enoch")
                .font(.title2.bold())
            Spacer()
            HStack(spacing: 12) {
                Text("\(enochFigures.count) figures")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(enochPlaces.count) places")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "book.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Enochic data")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("The database has not been seeded with Book of Enoch figures yet.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var entityList: some View {
        List(selection: $selectedID) {
            ForEach(groupedFigures, id: \.name) { section in
                Section {
                    ForEach(section.figures, id: \.persistentModelID) { figure in
                        EnochFigureRow(figure: figure)
                            .tag(figure.persistentModelID)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(section.name)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Text("\(section.figures.count) figures")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !enochPlaces.isEmpty {
                Section {
                    ForEach(enochPlaces, id: \.persistentModelID) { place in
                        PlaceRow(place: place)
                            .tag(place.persistentModelID)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text("Places")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Text("\(enochPlaces.count) places")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func figureDetailPanel(figure: Figure) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                IconActionButton(icon: "pencil", color: .accentColor) { editingFigure = figure }
                IconActionButton(icon: "trash", color: .red) {
                    showDeleteConfirm = true
                }
                Spacer()
                Button(action: { selectedID = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            FigureDetailView(figure: figure, onSelectFigure: { selected in
                coordinator?.pushHistory(id: selected.persistentModelID, name: selected.name, item: .figures)
                selectedID = selected.persistentModelID
            }, onSelectPlace: { place in
                selectedID = place.persistentModelID
            }, onSelectEvent: { event in
                coordinator?.navigateToEvent(event.persistentModelID, name: event.name)
            }, onSelectImage: { imageDetailImage = $0 })
        }
    }

    private func placeDetailPanel(place: Place) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                IconActionButton(icon: "pencil", color: .accentColor) { editingPlace = place }
                Spacer()
                Button(action: { selectedID = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            PlaceDetailView(place: place, onSelectFigure: { figure in
                selectedID = figure.persistentModelID
            }, onSelectEvent: { event in
                coordinator?.navigateToEvent(event.persistentModelID, name: event.name)
            }, onSelectImage: { imageDetailImage = $0 })
        }
    }

    private func deleteFigure(_ figure: Figure) {
        if selectedID == figure.persistentModelID {
            selectedID = nil
        }
        withAnimation { modelContext.delete(figure) }
    }
}

private struct EnochFigureRow: View {
    let figure: Figure

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .font(.system(size: 10))
                .foregroundStyle(figure.figureType?.color ?? .secondary)
                .frame(width: 14)
            Text(figure.name)
                .fontWeight(.medium)
        }
    }
}
