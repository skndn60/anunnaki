import SwiftUI
import SwiftData
import MapKit

struct SumerianDynastyMapView: View {
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var places: [Place]
    @Query private var figures: [Figure]

    @State private var selectedDynastyIndex: Int = 0
    @State private var detailFigure: Figure?
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.3, longitude: 44.4),
        span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
    ))

    private var eraOrder: [String: Int] {
        Dictionary(uniqueKeysWithValues: eras.map { ($0.name, $0.orderIndex) })
    }

    private var sklFigures: [Figure] {
        figures.filter { $0.source.contains("Sumerian King List") }
    }

    private var timeline: [SKLDatePropagator.DynastyTimeline] {
        SKLDatePropagator.compute(figures: sklFigures, eraOrder: eraOrder)
    }

    private var selectedDynasty: SKLDatePropagator.DynastyTimeline? {
        guard timeline.indices.contains(selectedDynastyIndex) else { return nil }
        return timeline[selectedDynastyIndex]
    }

    private var allPlaces: [Place] {
        places.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var mappablePlaces: [Place] {
        allPlaces
    }

    private func capitalName(for dynastyName: String) -> String? {
        for place in allPlaces where dynastyName.contains(place.name) {
            return place.name
        }
        return nil
    }

    private let dynastyColors: [Color] = [
        Color(red: 0.85, green: 0.40, blue: 0.20),
        Color(red: 0.20, green: 0.50, blue: 0.70),
        Color(red: 0.80, green: 0.60, blue: 0.15),
        Color(red: 0.60, green: 0.25, blue: 0.55),
        Color(red: 0.25, green: 0.65, blue: 0.40),
        Color(red: 0.70, green: 0.30, blue: 0.30),
        Color(red: 0.40, green: 0.35, blue: 0.75),
        Color(red: 0.75, green: 0.55, blue: 0.35),
        Color(red: 0.30, green: 0.60, blue: 0.60),
        Color(red: 0.80, green: 0.45, blue: 0.10),
    ]

    private func dynastyColor(for index: Int) -> Color {
        dynastyColors[index % dynastyColors.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if allPlaces.isEmpty || timeline.isEmpty {
                emptyState
            } else {
                HSplitView {
                    mapPanel
                    infoPanel
                }
            }
        }
        .sheet(item: $detailFigure) { figure in
            NavigationStack {
                FigureQuicklookView(figure: figure)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { detailFigure = nil }
                        }
                    }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Dynasty Map")
                    .font(.title2.bold())
                Spacer()
                Text("\(allPlaces.count) cities, \(timeline.count) dynasties")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !timeline.isEmpty {
                dynastyPicker
            }
        }
        .padding()
    }

    private var dynastyPicker: some View {
        Picker("Dynasty", selection: $selectedDynastyIndex) {
            ForEach(Array(timeline.enumerated()), id: \.offset) { idx, dynasty in
                HStack {
                    Circle()
                        .fill(dynastyColor(for: idx))
                        .frame(width: 8, height: 8)
                    Text(dynasty.name)
                }
                .tag(idx)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 400)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No map data")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Seed the database with --reseed to load places.")
                .font(.body)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Map Panel

    private var capital: String? {
        selectedDynasty.flatMap { capitalName(for: $0.name) }
    }

    private var mapPanel: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            ForEach(allPlaces, id: \.persistentModelID) { place in
                let coord = CLLocationCoordinate2D(
                    latitude: place.latitude!,
                    longitude: place.longitude!
                )
                if place.name == capital {
                    Marker(place.name, coordinate: coord)
                        .tint(dynastyColor(for: selectedDynastyIndex))
                } else {
                    Marker(place.name, coordinate: coord)
                        .tint(place.placeType?.color ?? Color(white: 0.6))
                }
            }
        }
        .mapStyle(.standard)
        .mapControlVisibility(.hidden)
        .onChange(of: selectedDynastyIndex) { _, _ in
            if let cap = capital, let place = allPlaces.first(where: { $0.name == cap }) {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: place.latitude!, longitude: place.longitude!),
                    span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
                ))
            }
        }
        .onAppear {
            if let cap = capital, let place = allPlaces.first(where: { $0.name == cap }) {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: place.latitude!, longitude: place.longitude!),
                    span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
                ))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 4) {
                zoomButton(icon: "plus", delta: -0.3)
                zoomButton(icon: "minus", delta: 0.3)
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private func zoomButton(icon: String, delta: Double) -> some View {
        Button {
            if let r = position.region {
                let lat = max(r.span.latitudeDelta * (1 + delta), 0.1)
                let lon = max(r.span.longitudeDelta * (1 + delta), 0.1)
                position = .region(MKCoordinateRegion(
                    center: r.center,
                    span: MKCoordinateSpan(latitudeDelta: lat, longitudeDelta: lon)
                ))
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info Panel

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let dynasty = selectedDynasty {
                Text(dynasty.name)
                    .font(.title3.bold())
                    .foregroundColor(dynastyColor(for: selectedDynastyIndex))

                if let s = dynasty.startBCE, let e = dynasty.endBCE {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("c. \(abs(s))–\(abs(e)) BC")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(dynasty.reigns.count) kings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if dynasty.totalYears > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Duration: \(dynasty.totalYears.formatted()) years")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let capital = selectedDynasty.flatMap({ capitalName(for: $0.name) }) {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Capital")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 6) {
                            Image(systemName: "building.columns")
                                .font(.caption)
                                .foregroundColor(dynastyColor(for: selectedDynastyIndex))
                            Text(capital)
                                .font(.headline)
                        }
                    }
                }

                Divider()

                Text("Rulers")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(dynasty.reigns, id: \.figure.persistentModelID) { reign in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(dynastyColor(for: selectedDynastyIndex).opacity(0.5))
                                    .frame(width: 4, height: 4)
                                Button(action: { detailFigure = reign.figure }) {
                                    Text(reign.figure.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                                .pointingHand()
                                Spacer()
                                if !reign.display.isEmpty {
                                    Text(reign.display)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Select a dynasty")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 250)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.thinMaterial)
    }
}


