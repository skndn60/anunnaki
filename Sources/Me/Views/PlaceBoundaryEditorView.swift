import SwiftUI
import SwiftData
import AppKit

/// Reconciled freehand territory-drawing editor used for both places and eras.
/// Wraps `DynastyHistoricalMapView` in draw mode; the finished ring is handed to
/// `onSave` (callers persist it into the entity's stored boundary GeoJSON).
struct BoundaryDrawEditorView: View {
    let title: String
    let subtitle: String
    let mappable: [DynastyMapPlace]
    let capitalIndex: Int?
    let boundaryColorHex: String
    let currentBoundaryGeoJSON: String?
    let canClear: Bool
    let mapID: AnyHashable?
    let onSave: ([[Double]]) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @AppStorage("dynastyMapHistoricalStartupZoom") private var historicalStartupZoom = 5.0
    @AppStorage("dynastyMapHistoricalTheme") private var historicalThemeRaw = HistoricalMapTheme.historical.rawValue
    @AppStorage("dynastyMapHistoricalLanguage") private var historicalLanguageRaw = HistoricalMapLanguage.english.rawValue
    @AppStorage("dynastyMapLabelSize") private var labelSizeRaw = MapLabelSize.medium.rawValue

    @State private var drawMode = false
    @State private var drawStyle: BoundaryDrawStyle = .freehand
    @State private var pendingRing: [[Double]]?
    @State private var pendingRiverPolyline: [[Double]]?
    @State private var zoomController = MapZoomController()

    @State private var blobRadiusKm = 40.0
    @State private var blobLonStretch = 1.0
    @State private var blobRoughness = 0.35
    @State private var blobVertices = 24
    @State private var blobSeed = Int.random(in: 0..<1_000_000)
    @State private var riverWidthKm = 6.0

    private var blobCenter: (lon: Double, lat: Double) {
        if let first = mappable.first { return (first.longitude, first.latitude) }
        return (44.4, 33.3)
    }

    private func syncBlob() {
        guard drawStyle == .blob, drawMode else { return }
        pendingRing = BoundaryGeometry.blobRing(
            center: blobCenter,
            radiusKm: blobRadiusKm,
            lonStretch: blobLonStretch,
            vertices: blobVertices,
            roughness: blobRoughness,
            seed: blobSeed
        )
    }

    private func rebufferRiver() {
        guard drawStyle == .river, let polyline = pendingRiverPolyline else { return }
        pendingRing = BoundaryGeometry.bufferPolyline(polyline, widthKm: riverWidthKm)
    }

    /// The boundary shown in the editor: the last drawn ring while it is pending,
    /// otherwise the entity's current effective boundary.
    private var displayGeoJSON: String? {
        if let ring = pendingRing { return Migration.polygonGeoJSON(ring: ring) }
        return currentBoundaryGeoJSON
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            mapSection
            toolBar
            footer
        }
        .frame(width: 680, height: 600)
        .onChange(of: drawStyle) { _, newStyle in
            if newStyle == .blob { syncBlob() }
        }
        .onChange(of: drawMode) { _, active in
            if active && drawStyle == .blob { syncBlob() }
        }
        .onChange(of: blobRadiusKm) { _, _ in syncBlob() }
        .onChange(of: blobLonStretch) { _, _ in syncBlob() }
        .onChange(of: blobRoughness) { _, _ in syncBlob() }
        .onChange(of: blobVertices) { _, _ in syncBlob() }
        .onChange(of: blobSeed) { _, _ in syncBlob() }
        .onChange(of: riverWidthKm) { _, _ in rebufferRiver() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "scribble.variable")
                .foregroundStyle(Color(hex: boundaryColorHex))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
    }

    private var mapSection: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                DynastyHistoricalMapView(
                    places: mappable,
                    capitalIndex: capitalIndex,
                    focusToken: 0,
                    dynastyColorHex: boundaryColorHex,
                    startupZoom: historicalStartupZoom,
                    theme: HistoricalMapTheme(rawValue: historicalThemeRaw) ?? .historical,
                    language: historicalLanguageRaw,
                    labelSize: (MapLabelSize(rawValue: labelSizeRaw) ?? .medium).basePx,
                    dateString: nil,
                    boundaryGeoJSON: displayGeoJSON,
                    previewBoundaryGeoJSON: nil,
                    previewColorHex: "#E0432F",
                    defaultCenter: (44.4, 33.3),
                    onPlaceSelected: { index in
                        guard !drawMode, mappable.indices.contains(index) else { return }
                        let name = mappable[index].name
                        let descriptor = FetchDescriptor<Place>(predicate: #Predicate { $0.name == name })
                        if let place = (try? modelContext.fetch(descriptor))?.first {
                            openWindow(id: "place-quickview", value: place.persistentModelID)
                        }
                    },
                    zoomController: zoomController,
                    animateBoundaryTransitions: false,
                    drawMode: drawMode,
                    drawStyle: drawStyle,
                    minBoundaryPoints: drawStyle == .river ? 2 : 3,
                    onBoundaryDrawn: { ring in
                        if drawStyle == .river {
                            pendingRiverPolyline = ring
                            pendingRing = BoundaryGeometry.bufferPolyline(ring, widthKm: riverWidthKm)
                        } else {
                            pendingRing = ring
                        }
                    }
                )
                .id(mapID)

                MapZoomButtons(controller: zoomController)
                    .padding(8)
            }
        }
        .frame(minHeight: 260)
    }

    private var toolBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if drawStyle == .blob { blobControls }
                if drawStyle == .river { riverControls }
                if drawStyle == .edit { editControls }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .disabled(!drawMode)
        }
    }

    private var editControls: some View {
        HStack(spacing: 8) {
            Text("Edit").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text("Drag a dot to nudge that vertex; the ring stays closed around the gulf.").font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Button {
                let center = blobCenter
                pendingRing = BoundaryGeometry.blobRing(center: center, radiusKm: blobRadiusKm, lonStretch: blobLonStretch, vertices: blobVertices, roughness: blobRoughness, seed: blobSeed)
            } label: {
                Label("Re-trace as blob", systemImage: "arrow.counterclockwise.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Replace the current boundary with a fresh parametric silhouette centered on the place point")
        }
    }

    private var blobControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Blob").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("radius").font(.caption2).foregroundStyle(.tertiary)
                Slider(value: $blobRadiusKm, in: 5...200).controlSize(.small).frame(width: 140)
                Text("\(Int(blobRadiusKm)) km").font(.caption).monospacedDigit().frame(width: 44, alignment: .leading)
                Button {
                    blobSeed = Int.random(in: 0..<1_000_000)
                } label: {
                    Image(systemName: "dice")
                }
                .buttonStyle(.borderless)
                .help("Randomize the silhouette")
            }
            HStack(spacing: 8) {
                Text("wobble").font(.caption2).foregroundStyle(.tertiary)
                Slider(value: $blobRoughness, in: 0...0.8).controlSize(.small).frame(width: 140)
                Text(String(format: "%.2f", blobRoughness)).font(.caption).monospacedDigit().frame(width: 44, alignment: .leading)
                Text("elongate").font(.caption2).foregroundStyle(.tertiary)
                Slider(value: $blobLonStretch, in: 0.25...3).controlSize(.small).frame(width: 140)
                Text(String(format: "%.2f×", blobLonStretch)).font(.caption).monospacedDigit().frame(width: 44, alignment: .leading)
                Text("points").font(.caption2).foregroundStyle(.tertiary)
                Slider(
                    value: Binding(get: { Double(blobVertices) }, set: { blobVertices = Int($0.rounded()) }),
                    in: 8...48
                )
                .controlSize(.small)
                .frame(width: 90)
                .help("\(blobVertices) contour points")
            }
        }
    }

    private var riverControls: some View {
        HStack(spacing: 8) {
            Text("River").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text("width").font(.caption2).foregroundStyle(.tertiary)
            Slider(value: $riverWidthKm, in: 2...60).controlSize(.small).frame(width: 140)
            Text("\(Int(riverWidthKm)) km").font(.caption).monospacedDigit().frame(width: 44, alignment: .leading)
            Text("Click along the course, then").font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Button {
                zoomController.finishRiverStroke()
            } label: {
                Label("Finish stroke", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $drawMode) {
                Label("Draw mode", systemImage: "pencil.line")
            }
            .toggleStyle(.button)
            .help(drawModeHelp)

            Picker("Drawing style", selection: $drawStyle) {
                ForEach(BoundaryDrawStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)
            .disabled(!drawMode)

            Button {
                drawMode = false
                pendingRing = nil
                pendingRiverPolyline = nil
            } label: {
                Label("Discard stroke", systemImage: "xmark.circle")
            }
            .disabled(pendingRing == nil)

            Spacer()

            Button(role: .destructive) {
                onClear()
                dismiss()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(!canClear)

            Button(role: .cancel) {
                dismiss()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }

            Button {
                if let ring = pendingRing {
                    onSave(ring)
                }
                dismiss()
            } label: {
                Label("Save boundary", systemImage: "checkmark")
            }
            .keyboardShortcut(.defaultAction)
            .disabled(pendingRing == nil)
        }
        .padding(12)
    }

    private var drawModeHelp: String {
        switch drawStyle {
        case .freehand:
            return "Click and drag on the map to sketch a territory; release to finish."
        case .line:
            return "Click on the map to drop corner points. Hover near the first point and click to close."
        case .blob:
            return "Shape a wavy water-body silhouette with the sliders around the place point; no map interaction needed."
        case .river:
            return "Click points along the river course, then press Finish stroke to auto-buffer the corridor."
        case .edit:
            return "Drag any red dot to move that vertex of the existing boundary; release to drop it. Save to keep the adjustment."
        }
    }
}

/// Place flavor of the boundary editor: persists a drawn ring into
/// `Place.storedBoundaryGeoJSON` (stored wins over any inherited dynasty-era boundary).
struct PlaceBoundaryEditorView: View {
    let place: Place

    @Environment(\.modelContext) private var modelContext

    private var boundaryColorHex: String {
        "#\(place.placeType?.color.hex ?? "2A6F97")"
    }

    private var mappable: [DynastyMapPlace] {
        guard let latitude = place.latitude else { return [] }
        guard let longitude = place.longitude else { return [] }
        return [DynastyMapPlace(name: place.name, latitude: latitude, longitude: longitude, colorHex: boundaryColorHex)]
    }

    private var subtitle: String {
        if let source = place.boundarySourceEraName {
            return "Currently inherited from \(source) — drawing a new boundary will take precedence"
        }
        if place.storedBoundaryGeoJSON != nil {
            return "Currently showing a hand-drawn boundary"
        }
        return "No boundary yet"
    }

    var body: some View {
        BoundaryDrawEditorView(
            title: "Territory boundary — \(place.name)",
            subtitle: subtitle,
            mappable: mappable,
            capitalIndex: mappable.isEmpty ? nil : 0,
            boundaryColorHex: boundaryColorHex,
            currentBoundaryGeoJSON: place.boundaryGeoJSON,
            canClear: place.storedBoundaryGeoJSON != nil,
            mapID: place.persistentModelID,
            onSave: { ring in
                place.storedBoundaryGeoJSON = Migration.polygonGeoJSON(ring: ring)
                try? modelContext.save()
            },
            onClear: {
                place.storedBoundaryGeoJSON = nil
                try? modelContext.save()
            }
        )
    }
}

/// Era flavor of the boundary editor: persists a drawn ring into
/// `Era.boundaryGeoJSON`, shown by the dynasty maps. The era's group members'
/// places are marked on the map for context; drawing a new ring replaces the
/// authored dynasty territory for this era.
struct EraBoundaryEditorView: View {
    let era: Era

    @Environment(\.modelContext) private var modelContext
    @Query private var allGroups: [FigureGroup]

    private static var boundaryColorHex: String {
        "#" + Color.orange.hex
    }

    private var group: FigureGroup? {
        allGroups.first { $0.era?.persistentModelID == era.persistentModelID }
    }

    private var mappable: [DynastyMapPlace] {
        let color = Self.boundaryColorHex
        return (group?.directPlaces ?? []).compactMap { place in
            guard let latitude = place.latitude, let longitude = place.longitude else { return nil }
            return DynastyMapPlace(name: place.name, latitude: latitude, longitude: longitude, colorHex: color)
        }
    }

    private var subtitle: String {
        if era.boundaryGeoJSON != nil {
            return "Currently showing a drawn boundary — draw a new shape to replace it"
        }
        return mappable.isEmpty
            ? "No boundary yet — members of this era's dynasty group are marked for context"
            : "No boundary yet"
    }

    var body: some View {
        BoundaryDrawEditorView(
            title: "Territory boundary — \(era.name)",
            subtitle: subtitle,
            mappable: mappable,
            capitalIndex: mappable.isEmpty ? nil : 0,
            boundaryColorHex: Self.boundaryColorHex,
            currentBoundaryGeoJSON: era.boundaryGeoJSON,
            canClear: era.boundaryGeoJSON != nil,
            mapID: era.persistentModelID,
            onSave: { ring in
                era.boundaryGeoJSON = Migration.polygonGeoJSON(ring: ring)
                try? modelContext.save()
            },
            onClear: {
                era.boundaryGeoJSON = nil
                try? modelContext.save()
            }
        )
    }
}