import SwiftUI
import SwiftData
import WebKit

/// One mappable place rendered on the dynasty map (color as hex for JS).
struct DynastyMapPlace {
    let name: String
    let latitude: Double
    let longitude: Double
    let colorHex: String
}

/// Gesture style used while drawing a territory boundary.
enum BoundaryDrawStyle: String, CaseIterable, Identifiable {
    /// Drag to sketch a continuous stroke (original behavior).
    case freehand
    /// Click to drop corner points; hover near the first point to close.
    case line
    /// Parametric water-body silhouette: sliders shape a wavy blob around the
    /// place's centroid — no map interaction is needed.
    case blob
    /// Click points along a river/canal course; the stroke is auto-buffered
    /// into a corridor polygon ("Finish stroke" reports the completed polyline).
    case river
    /// Show existing vertices as draggable dots; drag any vertex to reshape
    /// the boundary, then save.
    case edit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .freehand: return "Freehand"
        case .line: return "Line"
        case .blob: return "Blob"
        case .river: return "River"
        case .edit: return "Edit"
        }
    }
}

/// OpenHistoricalMap style theme used for the historical map version.
enum HistoricalMapTheme: String, CaseIterable, Identifiable {
    case historical, railway, woodblock, japaneseScroll
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .historical: "Historical"
        case .railway: "Railway"
        case .woodblock: "Woodblock"
        case .japaneseScroll: "Japanese Scroll"
        }
    }
    var styleURL: String {
        switch self {
        case .historical: "https://www.openhistoricalmap.org/map-styles/main/main.json"
        case .railway: "https://cdn.jsdelivr.net/npm/@openhistoricalmap/map-styles@0.9.8/dist/railway/railway.json"
        case .woodblock: "https://cdn.jsdelivr.net/npm/@openhistoricalmap/map-styles@0.9.8/dist/woodblock/woodblock.json"
        case .japaneseScroll: "https://cdn.jsdelivr.net/npm/@openhistoricalmap/map-styles@0.9.8/dist/japanese_scroll/japanese_scroll.json"
        }
    }
}

/// IETF language tag used for the historical map's name:<lang> label fields.
enum HistoricalMapLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case arabic = "ar"
    case ancientGreek = "grc"
    case latin = "la"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .english: "English"
        case .french: "French"
        case .german: "German"
        case .spanish: "Spanish"
        case .arabic: "Arabic"
        case .ancientGreek: "Ancient Greek"
        case .latin: "Latin"
        }
    }
}

/// Base label font size for the historical map's place markers.
enum MapLabelSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }
    var basePx: Double {
        switch self {
        case .small: 9
        case .medium: 11
        case .large: 14
        }
    }
}

struct SumerianDynastyMapView: View {
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var places: [Place]
    @Query private var figures: [Figure]

    /// Startup zoom for the historical map (see App Settings).
    @AppStorage("dynastyMapHistoricalStartupZoom") private var historicalStartupZoom = 5.0
    /// Historical map presentation settings (see App Settings).
    @AppStorage("dynastyMapHistoricalTheme") private var historicalThemeRaw = HistoricalMapTheme.historical.rawValue
    @AppStorage("dynastyMapHistoricalLanguage") private var historicalLanguageRaw = HistoricalMapLanguage.english.rawValue
    @AppStorage("dynastyMapLabelSize") private var labelSizeRaw = MapLabelSize.medium.rawValue
    @AppStorage("dynastyMapDateFilter") private var dateFilterEnabled = false
    @AppStorage("mapHideBasemapCities") private var hideBasemapCities = true
    /// User-selected color of the Sumer reference outline (hex, from the limited
    /// palette next to the dynasty dropdown).
    @AppStorage("dynastyMapSumerColor") private var sumerColorHex = "#8A6130"

    /// Limited palette offered for the Sumer outline color.
    private static let sumerPaletteHex: [String] = [
        "#8A6130", "#B0413E", "#3E63A6", "#2E6F5E",
        "#8B5E9E", "#9A6324", "#4B4453", "#5A7A3A",
    ]

    /// ISO-like year at the middle of the selected dynasty's span (negative = BCE),
    /// used by the OHM date filter. Nil when the filter is off or dates are missing.
    private var dynastyDateString: String? {
        guard dateFilterEnabled,
              let start = selectedDynasty?.startBCE,
              let end = selectedDynasty?.endBCE else { return nil }
        let midpoint = (start + end) / 2
        if midpoint < 0 { return String(format: "-%04d", -midpoint) }
        return String(format: "%04d", midpoint)
    }

    /// Index into `timeline` of the selected dynasty, or nil for the "No dynasty
    /// selected" overview mode.
    @State private var selectedDynastyIndex: Int? = nil
    /// The dynasty row currently hovered in the overview list, whose territory is
    /// previewed as a dashed outline on the map.
    @State private var hoveredDynastyIndex: Int? = nil
    @State private var detailFigure: Figure?
    @State private var detailPlace: Place?
    @State private var zoomController = MapZoomController()

    private var eraOrder: [String: Int] {
        Dictionary(eras.map { ($0.name, $0.orderIndex) }, uniquingKeysWith: { first, _ in first })
    }

    private var sklFigures: [Figure] {
        figures.filter { $0.source.contains("Sumerian King List") }
    }

    private var timeline: [SKLDatePropagator.DynastyTimeline] {
        SKLDatePropagator.compute(figures: sklFigures, eraOrder: eraOrder)
    }

    private var selectedDynasty: SKLDatePropagator.DynastyTimeline? {
        guard let selectedDynastyIndex, timeline.indices.contains(selectedDynastyIndex) else { return nil }
        return timeline[selectedDynastyIndex]
    }

    /// The authored territory polygon for a dynasty's era
    /// (`Era.boundaryGeoJSON`, backfilled by `Migration.ensureDynastyBoundaries`).
    private func boundaryGeoJSON(forDynastyNamed name: String) -> String? {
        eras.first { $0.name == name }?.boundaryGeoJSON
    }

    /// The authored territory polygon for the currently selected dynasty's era.
    private var selectedBoundaryGeoJSON: String? {
        guard let name = selectedDynasty?.name else { return nil }
        return boundaryGeoJSON(forDynastyNamed: name)
    }

    /// The authored territory polygon for the currently hovered dynasty's era.
    /// Only active in overview mode ("No dynasty selected") so a stale hover can
    /// never redraw a dashed outline over a selected dynasty's solid border.
    private var hoveredBoundaryGeoJSON: String? {
        guard selectedDynastyIndex == nil,
              let hoveredDynastyIndex,
              timeline.indices.contains(hoveredDynastyIndex) else { return nil }
        return boundaryGeoJSON(forDynastyNamed: timeline[hoveredDynastyIndex].name)
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
                    historicalMapPanel
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
        .sheet(item: $detailPlace) { place in
            NavigationStack {
                PlaceDetailView(place: place)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { detailPlace = nil }
                        }
                    }
            }
            .frame(width: 560, height: 600)
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
                HStack(spacing: 12) {
                    dynastyPicker
                    sumerColorPalette
                    Spacer()
                    Toggle(isOn: $hideBasemapCities) {
                        Text("Base map cities")
                            .font(.caption)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Hide city labels drawn by the base map")
                }
            }
        }
        .padding()
    }

    private var sumerColorPalette: some View {
        HStack(spacing: 6) {
            Text("Sumer")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Self.sumerPaletteHex, id: \.self) { hex in
                let selected = hex == sumerColorHex
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                    .overlay(Circle().stroke(Color.primary, lineWidth: selected ? 2 : 0))
                    .contentShape(Circle())
                    .onTapGesture { sumerColorHex = hex }
            }
        }
        .help("Sumer outline color")
    }

    private var dynastyPicker: some View {
        Picker("Dynasty", selection: $selectedDynastyIndex) {
            Text("No dynasty selected").tag(nil as Int?)
            Divider()
            ForEach(Array(timeline.enumerated()), id: \.offset) { idx, dynasty in
                HStack {
                    Circle()
                        .fill(dynastyColor(for: idx))
                        .frame(width: 8, height: 8)
                    Text(dynasty.name)
                }
                .tag(idx as Int?)
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

    private var capitalPlaceIndex: Int? {
        guard let cap = capital else { return nil }
        return allPlaces.firstIndex(where: { $0.name == cap })
    }

    private var mapPlaces: [DynastyMapPlace] {
        allPlaces.map { place in
            DynastyMapPlace(
                name: place.name,
                latitude: place.latitude!,
                longitude: place.longitude!,
                colorHex: colorHex(from: place.placeType?.color ?? Color(white: 0.6))
            )
        }
    }

    private var historicalMapPanel: some View {
        ZStack(alignment: .topTrailing) {
            DynastyHistoricalMapView(
                places: mapPlaces,
                capitalIndex: capitalPlaceIndex,
                focusToken: selectedDynastyIndex ?? -1,
                dynastyColorHex: dynastyColorHex(for: selectedDynastyIndex),
                startupZoom: historicalStartupZoom,
                theme: HistoricalMapTheme(rawValue: historicalThemeRaw) ?? .historical,
                language: historicalLanguageRaw,
                labelSize: (MapLabelSize(rawValue: labelSizeRaw) ?? .medium).basePx,
                dateString: dynastyDateString,
                hideBasemapCities: hideBasemapCities,
                boundaryGeoJSON: selectedBoundaryGeoJSON,
                previewBoundaryGeoJSON: hoveredBoundaryGeoJSON,
                previewColorHex: dynastyColorHex(for: hoveredDynastyIndex),
                defaultCenter: selectedDynasty == nil ? (44.4, 33.3) : nil,
                onPlaceSelected: { index in openPlace(at: index) },
                zoomController: zoomController,
                sumerBoundaryGeoJSON: DynastyHistoricalMapView.sumerBoundaryGeoJSON,
                sumerColorHex: sumerColorHex
            )
            MapZoomButtons(controller: zoomController)
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private func openPlace(at index: Int) {
        guard allPlaces.indices.contains(index) else { return }
        openPlace(allPlaces[index])
    }

    private func openPlace(_ place: Place) {
        detailPlace = place
    }

    private func dynastyColorHex(for index: Int?) -> String {
        guard let index, index >= 0 else { return "#999999" }
        return colorHex(from: dynastyColor(for: index))
    }

    private func colorHex(from color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "#999999" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - Info Panel

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let dynasty = selectedDynasty, let dynastyIndex = selectedDynastyIndex {
                Text(dynasty.name)
                    .font(.title3.bold())
                    .foregroundColor(dynastyColor(for: dynastyIndex))

                if let s = dynasty.startBCE, let e = dynasty.endBCE {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("c. \(abs(s))–\(abs(e)) BCE")
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
                                .foregroundColor(dynastyColor(for: dynastyIndex))
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
                                    .fill(dynastyColor(for: dynastyIndex).opacity(0.5))
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
                dynastyOverviewPanel
            }
        }
        .padding()
        .frame(width: 250)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.thinMaterial)
    }

    /// Overview mode ("No dynasty selected"): every dynasty listed in SKL ruling
    /// order. Hovering a row previews its territory as a dashed outline on the
    /// map; clicking selects it and shows the detail panel.
    private var dynastyOverviewPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dynasties")
                .font(.caption)
                .foregroundStyle(.tertiary)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timeline.enumerated()), id: \.offset) { idx, dynasty in
                        Button {
                            hoveredDynastyIndex = nil
                            selectedDynastyIndex = idx
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(dynastyColor(for: idx))
                                        .frame(width: 8, height: 8)
                                    Text(dynasty.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                if let s = dynasty.startBCE, let e = dynasty.endBCE {
                                    Text("\(abs(s))–\(abs(e)) BCE")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 14)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                            .background(
                                hoveredDynastyIndex == idx
                                    ? Color.accentColor.opacity(0.14)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                        .onHover { hovering in
                            if hovering {
                                hoveredDynastyIndex = idx
                            } else if hoveredDynastyIndex == idx {
                                hoveredDynastyIndex = nil
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Historical dynasty map (OpenHistoricalMap via MapLibre)

struct DynastyHistoricalMapView: NSViewRepresentable {
    @AppStorage("mapLabelRevealZoom") private var labelMinZoom = 8

    let places: [DynastyMapPlace]
    let capitalIndex: Int?
    let focusToken: Int
    let dynastyColorHex: String
    let startupZoom: Double
    let theme: HistoricalMapTheme
    let language: String
    let labelSize: Double
    let dateString: String?
    var hideBasemapCities: Bool = true
    /// GeoJSON territory polygon (one ring) to draw for the currently selected
    /// dynasty/era, colored with the dynasty color. When nil or empty the map
    /// shows no territory.
    let boundaryGeoJSON: String?
    /// GeoJSON territory polygon (one ring) previewed as a dashed outline
    /// (e.g. the dynasty row currently hovered in overview mode). When nil or
    /// empty no preview is drawn.
    let previewBoundaryGeoJSON: String?
    /// Color for the preview outline.
    let previewColorHex: String
    /// Fallback map center (lon, lat) used when `places` is empty, so a bare
    /// historical basemap can still be shown for a time period. Pass `nil` when
    /// `places` is always non-empty.
    let defaultCenter: (Double, Double)?
    let onPlaceSelected: (Int) -> Void
    let zoomController: MapZoomController
    /// When true, territory transitions grow the polygon from its centroid
    /// (ease-out over ~650 ms) instead of appearing instantly.
    var animateBoundaryTransitions: Bool = true
    /// GeoJSON Polygon outline of the Sumerian heartland, drawn as a subtle
    /// dashed reference ring beneath the (dynasty) `boundaryGeoJSON` layer.
    /// When nil or empty no reference ring is drawn.
    var sumerBoundaryGeoJSON: String?
    /// Color of the Sumer reference outline (line + slight fill tint).
    var sumerColorHex: String = "#8A6130"
    /// When true the map accepts territory drawing: the user captures a
    /// ring and it is reported via `onBoundaryDrawn`. Disables pan/zoom while active.
    var drawMode: Bool = false
    /// Drawing gesture style used while `drawMode` is active: `.freehand`
    /// (drag to sketch a stroke) or `.line` (click to drop corner points,
    /// hover near the first point to close).
    var drawStyle: BoundaryDrawStyle = .freehand
    /// Minimum number of points a drawn stroke must have before it is reported
    /// via `onBoundaryDrawn` — 3 for closed polygons, 2 for a river polyline
    /// that will be auto-buffered into a corridor.
    var minBoundaryPoints: Int = 3
    /// Callback delivering a drawn ring (`[[lon, lat], ...]`, unclosed) when the
    /// user finishes a stroke in draw mode.
    var onBoundaryDrawn: (([[Double]]) -> Void)? = nil

    /// Authored outer extent of the Sumerian heartland: the southern alluvium
    /// between the two rivers, enclosing Eridu, Ur, Uruk, Larsa, Umma, Adab,
    /// Nippur, Sippar, Kish and Babylon (roughly lon 43.9–47.0, lat 30.5–33.35).
    static var sumerBoundaryGeoJSON: String {
        let ring: [[Double]] = [
            [44.15, 33.30], [44.80, 33.35], [45.40, 33.20], [45.95, 32.90],
            [46.50, 32.30], [46.90, 31.90], [47.00, 31.20], [46.80, 30.60],
            [45.90, 30.50], [45.30, 30.60], [44.70, 30.80], [44.20, 31.10],
            [43.95, 31.60], [44.00, 32.20], [44.05, 32.85], [44.15, 33.30],
        ]
        let coords = ring.map { "[" + $0.map { String($0) }.joined(separator: ",") + "]" }.joined(separator: ",")
        return "{\"type\":\"Polygon\",\"coordinates\":[[" + coords + "]]}"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var lastSignature: String = ""
        var lastFocusToken: Int = -1
        var lastPreviewSignature: String = ""
        var onPlaceSelected: ((Int) -> Void)?
        var onBoundaryDrawn: (([[Double]]) -> Void)?
        var lastDrawMode: Bool = false
        var lastDrawStyle: BoundaryDrawStyle = .freehand
        var lastDefaultCenter: (Double, Double)?
        var lastDateString: String = ""
        var lastSumerColor: String = ""
        var lastBoundaryStr: String = ""
        var lastLabelMinZoom: Int = 8
        var lastHideBasemapCities: Bool = true
        var minBoundaryPoints: Int = 3

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "placeClicked":
                guard let index = (message.body as? NSNumber)?.intValue,
                      let handler = onPlaceSelected else { return }
                handler(index)
            case "boundaryDrawn":
                guard let handler = onBoundaryDrawn,
                      let body = message.body as? [[Any]] else { return }
                let ring: [[Double]] = body.compactMap { row in
                    guard let nums = row as? [NSNumber], nums.count == 2 else { return nil }
                    return [nums[0].doubleValue, nums[1].doubleValue]
                }
                guard ring.count >= minBoundaryPoints else { return }
                handler(ring)
            default:
                break
            }
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "placeClicked")
        contentController.add(context.coordinator, name: "boundaryDrawn")
        configuration.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.onPlaceSelected = onPlaceSelected
        context.coordinator.onBoundaryDrawn = onBoundaryDrawn
        context.coordinator.minBoundaryPoints = minBoundaryPoints
        zoomController.webView = webView
        context.coordinator.lastSignature = Self.signature(for: places)
        context.coordinator.lastFocusToken = focusToken
        context.coordinator.lastDefaultCenter = defaultCenter
        context.coordinator.lastDateString = dateString ?? ""
        context.coordinator.lastBoundaryStr = boundaryGeoJSON ?? ""
        context.coordinator.lastLabelMinZoom = labelMinZoom
        context.coordinator.lastHideBasemapCities = hideBasemapCities
        if let html = Self.mapHTML(for: places, capitalIndex: capitalIndex, capitalColorHex: dynastyColorHex, startupZoom: startupZoom, theme: theme, language: language, labelSize: labelSize, labelMinZoom: labelMinZoom, dateString: dateString, defaultCenter: defaultCenter, boundaryGeoJSON: boundaryGeoJSON, sumerBoundaryGeoJSON: sumerBoundaryGeoJSON, sumerColorHex: sumerColorHex, hideBasemapCities: hideBasemapCities) {
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.openhistoricalmap.org"))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onPlaceSelected = onPlaceSelected
        context.coordinator.onBoundaryDrawn = onBoundaryDrawn
        context.coordinator.minBoundaryPoints = minBoundaryPoints
        if drawMode != context.coordinator.lastDrawMode {
            context.coordinator.lastDrawMode = drawMode
            webView.evaluateJavaScript("setDrawMode(\(drawMode));", completionHandler: nil)
        }
        if drawStyle != context.coordinator.lastDrawStyle {
            context.coordinator.lastDrawStyle = drawStyle
            webView.evaluateJavaScript("setDrawStyle(\(Self.jsString(drawStyle.rawValue)));", completionHandler: nil)
        }
        let sig = Self.signature(for: places)
        let centerChanged = defaultCenter?.0 != context.coordinator.lastDefaultCenter?.0
            || defaultCenter?.1 != context.coordinator.lastDefaultCenter?.1
        if sig != context.coordinator.lastSignature || centerChanged {
            context.coordinator.lastSignature = sig
            context.coordinator.lastFocusToken = focusToken
            context.coordinator.lastPreviewSignature = ""
            context.coordinator.lastDefaultCenter = defaultCenter
            context.coordinator.lastSumerColor = sumerColorHex
            context.coordinator.lastDrawMode = false
            context.coordinator.lastDrawStyle = .freehand
            context.coordinator.lastBoundaryStr = boundaryGeoJSON ?? ""
            context.coordinator.lastLabelMinZoom = labelMinZoom
            context.coordinator.lastHideBasemapCities = hideBasemapCities
            if let html = Self.mapHTML(for: places, capitalIndex: capitalIndex, capitalColorHex: dynastyColorHex, startupZoom: startupZoom, theme: theme, language: language, labelSize: labelSize, labelMinZoom: labelMinZoom, dateString: dateString, defaultCenter: defaultCenter, boundaryGeoJSON: boundaryGeoJSON, sumerBoundaryGeoJSON: sumerBoundaryGeoJSON, sumerColorHex: sumerColorHex, hideBasemapCities: hideBasemapCities) {
                webView.loadHTMLString(html, baseURL: URL(string: "https://www.openhistoricalmap.org"))
            }
            return
        }
        if hideBasemapCities != context.coordinator.lastHideBasemapCities {
            context.coordinator.lastHideBasemapCities = hideBasemapCities
            webView.evaluateJavaScript("setHideBasemapCities(\(hideBasemapCities));", completionHandler: nil)
        }
        if labelMinZoom != context.coordinator.lastLabelMinZoom {
            context.coordinator.lastLabelMinZoom = labelMinZoom
            webView.evaluateJavaScript("setLabelMinZoom(\(labelMinZoom));", completionHandler: nil)
        }
        let previewSig = (previewBoundaryGeoJSON ?? "") + "|" + previewColorHex
        if previewSig != context.coordinator.lastPreviewSignature {
            context.coordinator.lastPreviewSignature = previewSig
            webView.evaluateJavaScript(
                "setPreviewBoundaryStr(\(Self.jsString(previewBoundaryGeoJSON ?? "")), \(Self.jsString(previewColorHex)));",
                completionHandler: nil
            )
        }
        let boundarySig = boundaryGeoJSON ?? ""
        if boundarySig != context.coordinator.lastBoundaryStr {
            context.coordinator.lastBoundaryStr = boundarySig
            webView.evaluateJavaScript("setBoundaryStr(\(Self.jsString(boundarySig)));", completionHandler: nil)
        }
        if (dateString ?? "") != context.coordinator.lastDateString {
context.coordinator.lastDateString = dateString ?? ""
        context.coordinator.lastSumerColor = sumerColorHex
            webView.evaluateJavaScript("setDate(\(Self.jsString(dateString ?? "")));", completionHandler: nil)
        }
        if sumerColorHex != context.coordinator.lastSumerColor {
            context.coordinator.lastSumerColor = sumerColorHex
            webView.evaluateJavaScript("setSumerColor(\(Self.jsString(sumerColorHex)));", completionHandler: nil)
        }
        guard focusToken != context.coordinator.lastFocusToken else { return }
        context.coordinator.lastFocusToken = focusToken
        guard let index = capitalIndex, places.indices.contains(index) else {
            webView.evaluateJavaScript(
                "setCapital(-1, '#999999'); \(Self.boundaryJS(for: boundaryGeoJSON, animate: animateBoundaryTransitions)) focusDefault();",
                completionHandler: nil
            )
            return
        }
        let place = places[index]
        webView.evaluateJavaScript(
            "setCapital(\(index), '\(dynastyColorHex)'); \(Self.boundaryJS(for: boundaryGeoJSON, animate: animateBoundaryTransitions)) focus(\(place.longitude), \(place.latitude), \(startupZoom)); setDate(\(Self.jsString(dateString ?? "")));",
            completionHandler: nil
        )
    }

    private static func boundaryJS(for geoJSON: String?, animate: Bool) -> String {
        let s = jsString(geoJSON ?? "")
        return animate ? "animateBoundaryTo(\(s), 650); " : "setBoundaryStr(\(s)); "
    }

    private static func signature(for places: [DynastyMapPlace]) -> String {
        places.map { "\($0.name)|\($0.latitude)|\($0.longitude)|\($0.colorHex)" }.joined(separator: ";")
    }

    private static func jsString(_ value: String) -> String {
        let data = (try? JSONEncoder().encode(value)) ?? Data("\"\"".utf8)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private static func mapHTML(for places: [DynastyMapPlace], capitalIndex: Int?, capitalColorHex: String, startupZoom: Double, theme: HistoricalMapTheme, language: String, labelSize: Double, labelMinZoom: Int = 8, dateString: String?, defaultCenter: (Double, Double)? = nil, boundaryGeoJSON: String? = nil, sumerBoundaryGeoJSON: String? = nil, sumerColorHex: String = "#8A6130", hideBasemapCities: Bool = true) -> String? {
        let fallback = defaultCenter ?? (44.4, 33.3)
        let centerPlace = capitalIndex.flatMap { places.indices.contains($0) ? places[$0] : nil } ?? places.first
        let centerLon = centerPlace?.longitude ?? fallback.0
        let centerLat = centerPlace?.latitude ?? fallback.1
        let initialIndex = capitalIndex ?? -1
        let initialColor = capitalIndex != nil ? capitalColorHex : "#999999"
        let rows = places.map { place in
            "{name: \(jsString(place.name)), lat: \(place.latitude), lon: \(place.longitude), color: \"\(place.colorHex)\"}"
        }.joined(separator: ",")
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script src="https://cdn.jsdelivr.net/npm/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/@openhistoricalmap/maplibre-gl-dates@1.3.0/index.js"></script>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/maplibre-gl@4.7.1/dist/maplibre-gl.css">
        <style>
            html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; }
            .place-marker { cursor: pointer; display: flex; align-items: center; gap: 3px; }
            .place-dot { width: 12px; height: 12px; border-radius: 50%; border: 1.5px solid rgba(255,255,255,0.95); box-shadow: 0 1px 2px rgba(0,0,0,0.4); transition: all 0.2s; }
            .place-label { font: 500 var(--place-label-size, 11px) -apple-system, 'Helvetica Neue', sans-serif; color: #222; text-shadow: 0 0 2px #fff, 0 0 2px #fff, 0 0 3px #fff; white-space: nowrap; pointer-events: none; }
        </style>
        </head>
        <body>
        <div id="map"></div>
        <script>
            var HOME_CENTER = [\(fallback.0), \(fallback.1)];
            var HOME_ZOOM = \(startupZoom);
            var INITIAL_INDEX = \(initialIndex);
            var HIDE_BASEMAP_CITIES = \(hideBasemapCities);
            var map = new maplibregl.Map({
                container: 'map',
                style: '\(theme.styleURL)',
                center: [\(centerLon), \(centerLat)],
                zoom: HOME_ZOOM,
                attributionControl: false
            });
            map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right');

            var places = [\(rows)];

            function spreadOverlapping(items) {
                var EPS = 0.0005;
                var OFFSET_METERS = 280;
                var clusters = [];
                for (var i = 0; i < items.length; i++) {
                    var found = false;
                    for (var c = 0; c < clusters.length; c++) {
                        var ref = items[clusters[c][0]];
                        if (Math.abs(items[i].lat - ref.lat) < EPS && Math.abs(items[i].lon - ref.lon) < EPS) {
                            clusters[c].push(i);
                            found = true;
                            break;
                        }
                    }
                    if (!found) clusters.push([i]);
                }
                var out = items.map(function(p) { return {lon: p.lon, lat: p.lat}; });
                clusters.forEach(function(group) {
                    if (group.length < 2) return;
                    var ref = items[group[0]];
                    var n = group.length;
                    for (var j = 0; j < n; j++) {
                        var angle = (2 * Math.PI * j / n) - Math.PI / 2;
                        var dLat = (OFFSET_METERS * Math.cos(angle)) / 111320;
                        var dLon = (OFFSET_METERS * Math.sin(angle)) / (111320 * Math.cos(ref.lat * Math.PI / 180));
                        out[group[j]].lat = ref.lat + dLat;
                        out[group[j]].lon = ref.lon + dLon;
                    }
                });
                return out;
            }

            var spreadCoords = spreadOverlapping(places);

            places.forEach(function(p, i) {
                var el = document.createElement('div');
                el.className = 'place-marker';
                var dot = document.createElement('span');
                dot.className = 'place-dot';
                dot.style.background = p.color;
                dot.id = 'dot-' + i;
                var label = document.createElement('span');
                label.className = 'place-label';
                label.textContent = p.name;
                label.id = 'label-' + i;
                el.appendChild(dot);
                el.appendChild(label);
                var coord = spreadCoords[i];
                var marker = new maplibregl.Marker({ element: el, anchor: 'left' })
                    .setLngLat([coord.lon, coord.lat])
                    .addTo(map);
                marker.getElement().addEventListener('click', function() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.placeClicked) {
                        window.webkit.messageHandlers.placeClicked.postMessage(i);
                    }
                });
            });

            var labelMinZoom = \(labelMinZoom);
            function applyLabelReveal() {
                var z = map.getZoom();
                var show = z >= labelMinZoom;
                places.forEach(function(p, k) {
                    var label = document.getElementById('label-' + k);
                    if (label) { label.style.display = show ? '' : 'none'; }
                });
            }
            function setLabelMinZoom(z) {
                labelMinZoom = z;
                applyLabelReveal();
            }

            function setCapital(i, color) {
                places.forEach(function(p, k) {
                    var dot = document.getElementById('dot-' + k);
                    var label = document.getElementById('label-' + k);
                    if (!dot || !label) { return; }
                    if (k === i) {
                        dot.style.background = color;
                        dot.style.width = '14px';
                        dot.style.height = '14px';
                        label.style.fontWeight = '700';
                    } else {
                        dot.style.background = p.color;
                        dot.style.width = '12px';
                        dot.style.height = '12px';
                        label.style.fontWeight = '500';
                    }
                });
                if (boundaryReady) {
                    map.setPaintProperty('boundary-fill', 'fill-color', color);
                    map.setPaintProperty('boundary-line', 'line-color', color);
                }
            }

            var originalFilters = {};
            var currentDate = \(jsString(dateString ?? ""));
            var labelBaseSize = \(labelSize);

            var emptyFC = { type: 'FeatureCollection', features: [] };
            var boundaryReady = false;
            var boundaryData = null;
            var boundaryStr = \(jsString(boundaryGeoJSON ?? ""));
            if (boundaryStr) { try { boundaryData = JSON.parse(boundaryStr); } catch(e) {} }
            if (!boundaryData || boundaryData.type !== 'Polygon') { boundaryData = emptyFC; }
            var sumerStr = \(jsString(sumerBoundaryGeoJSON ?? ""));
            var sumerColor = \(jsString(sumerColorHex));
            function setSumerColor(hex) {
                if (!boundaryReady) { return; }
                map.setPaintProperty('sumer-line', 'line-color', hex);
                map.setPaintProperty('sumer-fill', 'fill-color', hex);
            }
            function setupBoundary() {
                if (boundaryReady || !map.isStyleLoaded()) { return; }
                if (sumerStr) {
                    var sumerData = null;
                    try { sumerData = JSON.parse(sumerStr); } catch(e) {}
                    if (sumerData && sumerData.type === 'Polygon') {
                        map.addSource('sumer', { type: 'geojson', data: sumerData });
                        map.addLayer({
                            id: 'sumer-fill',
                            type: 'fill',
                            source: 'sumer',
                            paint: { 'fill-color': sumerColor, 'fill-opacity': 0.10 }
                        });
                        map.addLayer({
                            id: 'sumer-line',
                            type: 'line',
                            source: 'sumer',
                            layout: { 'line-cap': 'round', 'line-join': 'round', 'line-dasharray': [7, 5] },
                            paint: { 'line-color': sumerColor, 'line-width': 3, 'line-opacity': 0.9 }
                        });
                    }
                }
                map.addSource('boundary', { type: 'geojson', data: boundaryData });
                map.addLayer({
                    id: 'boundary-fill',
                    type: 'fill',
                    source: 'boundary',
                    paint: { 'fill-color': '\(capitalColorHex)', 'fill-opacity': 0.22 }
                });
                map.addLayer({
                    id: 'boundary-line',
                    type: 'line',
                    source: 'boundary',
                    paint: { 'line-color': '\(capitalColorHex)', 'line-width': 4, 'line-opacity': 0.95 }
                });
                map.addSource('boundary-preview', { type: 'geojson', data: emptyFC });
                map.addLayer({
                    id: 'boundary-preview-line',
                    type: 'line',
                    source: 'boundary-preview',
                    layout: { 'line-cap': 'round', 'line-join': 'round' },
                    paint: { 'line-color': '#E0432F', 'line-width': 4 }
                });
                map.addSource('boundary-vertices', { type: 'geojson', data: emptyFC });
                map.addLayer({
                    id: 'boundary-vertices-dots',
                    type: 'circle',
                    source: 'boundary-vertices',
                    paint: { 'circle-radius': 5, 'circle-color': '#E0432F', 'circle-stroke-width': 2, 'circle-stroke-color': '#FFFFFF' }
                });
                boundaryReady = true;
            }

            function setBoundary(ring) {
                if (!boundaryReady) { return; }
                var geo = (ring && ring.length >= 3) ? { type: 'Polygon', coordinates: [ring] } : emptyFC;
                map.getSource('boundary').setData(geo);
                if (geo.type === 'Polygon') { boundaryData = geo; }
            }

            function setBoundaryStr(s) {
                if (!boundaryReady) { pendingBoundary = s; pendingBoundaryAnimate = false; return; }
                var geo = null;
                try { geo = JSON.parse(s); } catch(e) {}
                if (!geo || geo.type !== 'Polygon' || !geo.coordinates || !geo.coordinates.length) { setBoundary(null); return; }
                setBoundary(geo.coordinates[0]);
            }

            var pendingBoundary = null;
            var pendingBoundaryAnimate = false;
            function animateBoundaryTo(s, duration) {
                var geo = null;
                try { geo = JSON.parse(s); } catch(e) {}
                if (!geo || geo.type !== 'Polygon' || !geo.coordinates || !geo.coordinates.length) { setBoundary(null); return; }
                if (!boundaryReady) { pendingBoundary = s; pendingBoundaryAnimate = true; return; }
                growRing(geo.coordinates[0], duration || 650);
            }
            function growRing(ring, duration) {
                var cx = 0, cy = 0;
                for (var i = 0; i < ring.length; i++) { cx += ring[i][0]; cy += ring[i][1]; }
                cx /= ring.length; cy /= ring.length;
                var start = performance.now();
                function frame(now) {
                    var t = Math.min(1, (now - start) / duration);
                    var e = 1 - Math.pow(1 - t, 3);
                    var scale = 0.001 + 0.999 * e;
                    var grown = [];
                    for (var i = 0; i < ring.length; i++) {
                        grown.push([cx + (ring[i][0] - cx) * scale, cy + (ring[i][1] - cy) * scale]);
                    }
                    setBoundary(grown);
                    if (t < 1) { requestAnimationFrame(frame); }
                }
                setBoundary([ring[0]]);
                requestAnimationFrame(frame);
            }

            function setPreviewBoundaryStr(s, color) {
                if (!boundaryReady) { pendingPreview = [s, color]; return; }
                var geo = null;
                try { geo = JSON.parse(s); } catch(e) {}
                if (!geo || geo.type !== 'Polygon' || !geo.coordinates || !geo.coordinates.length) {
                    map.getSource('boundary-preview').setData(emptyFC);
                    return;
                }
                map.getSource('boundary-preview').setData({ type: 'Polygon', coordinates: [geo.coordinates[0]] });
                map.setPaintProperty('boundary-preview-line', 'line-color', color || '#E0432F');
            }

            var drawActive = false;
            var drawPoints = [];
            var drawing = false;
            var drawStyle = 'freehand';
            var lineVertices = [];
            var editingVertexIndex = -1;
            var CLOSE_PX = 24;
            function setDrawStyle(style) {
                drawStyle = (style === 'line' || style === 'river' || style === 'blob' || style === 'edit') ? style : 'freehand';
                lineVertices = [];
                drawing = false;
                editingVertexIndex = -1;
                if (boundaryReady) {
                    map.getSource('boundary-vertices').setData(emptyFC);
                    if (drawStyle !== 'line') { map.getSource('boundary-preview').setData(emptyFC); }
                    if (drawStyle === 'edit') {
                        if (drawActive && boundaryData && boundaryData.type === 'Polygon') {
                            updateEditVertices(boundaryData.coordinates[0]);
                        }
                        map.setPaintProperty('boundary-vertices-dots', 'circle-radius', 7);
                        map.setPaintProperty('boundary-vertices-dots', 'circle-stroke-width', 3);
                    } else {
                        map.setPaintProperty('boundary-vertices-dots', 'circle-radius', 5);
                        map.setPaintProperty('boundary-vertices-dots', 'circle-stroke-width', 2);
                    }
                }
            }
            function updateEditVertices(ring) {
                if (!ring || ring.length < 3) { return; }
                var display = ring.slice(0, ring.length - 1);
                var features = display.map(function(v) {
                    return { type: 'Feature', geometry: { type: 'Point', coordinates: v } };
                });
                if (boundaryReady) {
                    map.getSource('boundary-vertices').setData({ type: 'FeatureCollection', features: features });
                }
            }
            function setDrawMode(on) {
                drawActive = !!on;
                if (drawActive) {
                    map.dragPan.disable();
                    map.doubleClickZoom.disable();
                    map.touchZoomRotate.disable();
                    map.getCanvas().style.cursor = 'crosshair';
                    if (drawStyle === 'edit' && boundaryData && boundaryData.type === 'Polygon') {
                        updateEditVertices(boundaryData.coordinates[0]);
                    }
                } else {
                    map.dragPan.enable();
                    map.doubleClickZoom.enable();
                    map.touchZoomRotate.enable();
                    map.getCanvas().style.cursor = '';
                    drawing = false;
                    drawPoints = [];
                    lineVertices = [];
                    editingVertexIndex = -1;
                    if (boundaryReady) {
                        map.getSource('boundary-preview').setData(emptyFC);
                        map.getSource('boundary-vertices').setData(emptyFC);
                    }
                }
            }
            function updateLinePreview(cursorLngLat, nearSnap) {
                if (lineVertices.length === 0) { return; }
                var coords = lineVertices.slice();
                if (nearSnap) {
                    coords.push(lineVertices[0]);
                } else if (cursorLngLat) {
                    coords.push(cursorLngLat);
                } else {
                    return;
                }
                map.getSource('boundary-preview').setData({ type: 'LineString', coordinates: coords });
                var features = lineVertices.map(function(v) {
                    return { type: 'Feature', geometry: { type: 'Point', coordinates: v } };
                });
                if (nearSnap) {
                    features.push({ type: 'Feature', geometry: { type: 'Point', coordinates: lineVertices[0] } });
                }
                map.getSource('boundary-vertices').setData({ type: 'FeatureCollection', features: features });
            }
            function isNearFirstVertex(screenPoint) {
                if (lineVertices.length < 3) return false;
                try {
                    var p0 = map.project(lineVertices[0]);
                    return Math.hypot(screenPoint.x - p0.x, screenPoint.y - p0.y) <= CLOSE_PX;
                } catch(_) { return false; }
            }
            function finishLine() {
                if (lineVertices.length >= 3) {
                    setBoundary(lineVertices);
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.boundaryDrawn) {
                        window.webkit.messageHandlers.boundaryDrawn.postMessage(lineVertices);
                    }
                }
                lineVertices = [];
                if (boundaryReady) {
                    map.getSource('boundary-preview').setData(emptyFC);
                    map.getSource('boundary-vertices').setData(emptyFC);
                }
            }
            function finishRiver() {
                if (lineVertices.length >= 2) {
                    var polyline = lineVertices.slice();
                    lineVertices = [];
                    if (boundaryReady) {
                        map.getSource('boundary-preview').setData(emptyFC);
                        map.getSource('boundary-vertices').setData(emptyFC);
                    }
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.boundaryDrawn) {
                        window.webkit.messageHandlers.boundaryDrawn.postMessage(polyline);
                    }
                }
            }
            map.on('mousedown', function(e) {
                if (!drawActive || !boundaryReady) { return; }
                if (drawStyle === 'edit') {
                    if (editingVertexIndex >= 0) { return; }
                    var ring = boundaryData && boundaryData.coordinates ? boundaryData.coordinates[0] : null;
                    if (!ring || ring.length < 3) { return; }
                    var best = -1;
                    var bestDist = CLOSE_PX;
                    for (var i = 0; i < ring.length - 1; i++) {
                        var p = map.project(ring[i]);
                        var d = Math.hypot(e.point.x - p.x, e.point.y - p.y);
                        if (d <= bestDist) { bestDist = d; best = i; }
                    }
                    if (best >= 0) {
                        e.preventDefault();
                        drawing = true;
                        editingVertexIndex = best;
                        map.getCanvas().style.cursor = 'grabbing';
                    }
                    return;
                }
                if (drawStyle !== 'freehand') { return; }
                e.preventDefault();
                drawing = true;
                drawPoints = [e.lngLat.toArray()];
            });
            map.on('mousemove', function(e) {
                if (!drawActive || !boundaryReady) { return; }
                if (drawStyle === 'freehand') {
                    if (!drawing) { return; }
                    drawPoints.push(e.lngLat.toArray());
                    map.getSource('boundary-preview').setData({ type: 'LineString', coordinates: drawPoints });
                    return;
                }
                if (drawStyle === 'edit') {
                    if (drawing && editingVertexIndex >= 0) {
                        var ring = boundaryData.coordinates[0];
                        ring[editingVertexIndex] = e.lngLat.toArray();
                        if (editingVertexIndex === 0) { ring[ring.length - 1] = ring[0].slice(); }
                        map.getSource('boundary').setData(boundaryData);
                        updateEditVertices(ring);
                        return;
                    }
                    var hoverRing = boundaryData && boundaryData.coordinates ? boundaryData.coordinates[0] : null;
                    if (hoverRing && hoverRing.length >= 3) {
                        var nearest = false;
                        for (var j = 0; j < hoverRing.length - 1; j++) {
                            var hp = map.project(hoverRing[j]);
                            if (Math.hypot(e.point.x - hp.x, e.point.y - hp.y) <= CLOSE_PX) { nearest = true; break; }
                        }
                        map.getCanvas().style.cursor = nearest ? 'grab' : 'crosshair';
                    }
                    return;
                }
                if ((drawStyle === 'line' || drawStyle === 'river') && lineVertices.length > 0) {
                    updateLinePreview(e.lngLat.toArray(), drawStyle === 'line' && isNearFirstVertex(e.point));
                }
            });
            map.on('click', function(e) {
                if (!drawActive || !boundaryReady || (drawStyle !== 'line' && drawStyle !== 'river')) { return; }
                if (drawStyle === 'river') {
                    lineVertices.push(e.lngLat.toArray());
                    updateLinePreview(e.lngLat.toArray(), false);
                    return;
                }
                if (lineVertices.length === 0) {
                    lineVertices = [e.lngLat.toArray()];
                    updateLinePreview(e.lngLat.toArray(), false);
                    return;
                }
                if (isNearFirstVertex(e.point)) { finishLine(); return; }
                lineVertices.push(e.lngLat.toArray());
                updateLinePreview(e.lngLat.toArray(), false);
            });
            map.on('mouseup', function(e) {
                if (!drawActive || !boundaryReady || !drawing) { return; }
                if (drawStyle === 'edit') {
                    drawing = false;
                    editingVertexIndex = -1;
                    map.getCanvas().style.cursor = 'crosshair';
                    var ring = boundaryData && boundaryData.coordinates ? boundaryData.coordinates[0] : null;
                    if (ring && ring.length >= 3) {
                        var unclosed = ring.slice(0, ring.length - 1);
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.boundaryDrawn) {
                            window.webkit.messageHandlers.boundaryDrawn.postMessage(unclosed);
                        }
                    }
                    return;
                }
                drawing = false;
                var ring = drawPoints;
                drawPoints = [];
                map.getSource('boundary-preview').setData(emptyFC);
                if (ring.length >= 3) {
                    setBoundary(ring);
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.boundaryDrawn) {
                        window.webkit.messageHandlers.boundaryDrawn.postMessage(ring);
                    }
                }
            });

            function restoreFilters() {
                Object.keys(originalFilters).forEach(function(id) {
                    map.setFilter(id, originalFilters[id]);
                });
            }

            function applyDate(dateStr) {
                restoreFilters();
                if (dateStr && typeof map.filterByDate === 'function') {
                    map.filterByDate(dateStr);
                }
            }

            function setDate(dateStr) { currentDate = dateStr; applyDate(dateStr); }

            function applyLanguage() {
                var lang = \(jsString(language));
                var style = map.getStyle();
                if (!style || !style.layers) { return; }
                style.layers.forEach(function(layer) {
                    var tf = layer.layout && layer.layout['text-field'];
                    if (!tf) { return; }
                    var s;
                    try { s = JSON.stringify(tf); } catch (e) { return; }
                    if (s.indexOf('"name"') === -1) { return; }
                    map.setLayoutProperty(layer.id, 'text-field',
                        ['coalesce', ['get', 'name_' + lang], ['get', 'name']]);
                });
            }

            function applyLabelSize() {
                var z = map.getZoom();
                var scale = Math.max(0.8, Math.min(1.8, 1 + 0.08 * (z - 5)));
                var size = Math.round(labelBaseSize * scale * 10) / 10;
                document.documentElement.style.setProperty('--place-label-size', size + 'px');
            }

            function applyBasemapCities() {
                var style = map.getStyle();
                if (!style || !style.layers) { return; }
                var vis = HIDE_BASEMAP_CITIES ? 'none' : 'visible';
                style.layers.forEach(function(layer) {
                    if (layer.id && layer.id.indexOf('city_') === 0 && map.getLayer(layer.id)) {
                        map.setLayoutProperty(layer.id, 'visibility', vis);
                    }
                });
            }
            function setHideBasemapCities(v) {
                HIDE_BASEMAP_CITIES = !!v;
                applyBasemapCities();
            }

            function snapshotAndApply() {
                originalFilters = {};
                var style = map.getStyle();
                if (style && style.layers) {
                    style.layers.forEach(function(layer) {
                        if ('source-layer' in layer) { originalFilters[layer.id] = map.getFilter(layer.id); }
                    });
                }
                applyLanguage();
                applyDate(currentDate);
                applyLabelSize();
                applyLabelReveal();
                applyBasemapCities();
            }
            map.on('styledata', snapshotAndApply);
            map.on('zoom', applyLabelSize);
            map.on('zoom', applyLabelReveal);

            var ready = false;
            var pendingFocus = null;
            var pendingPreview = null;
            function doFocus(lon, lat, zoom) {
                map.flyTo({ center: [lon, lat], zoom: zoom, duration: 600 });
            }
            function focus(lon, lat, zoom) {
                if (!ready) { pendingFocus = [lon, lat, zoom]; return; }
                doFocus(lon, lat, zoom);
            }
            function focusDefault() {
                doFocus(HOME_CENTER[0], HOME_CENTER[1], HOME_ZOOM);
            }
            function onLoad() {
                ready = true;
                setupBoundary();
                setCapital(INITIAL_INDEX, '\(initialColor)');
                applyLabelSize();
                if (pendingBoundary !== null) {
                    var pb = pendingBoundary;
                    var anim = pendingBoundaryAnimate;
                    pendingBoundary = null;
                    pendingBoundaryAnimate = false;
                    if (anim) { animateBoundaryTo(pb, 650); } else { setBoundaryStr(pb); }
                }
                if (pendingFocus) { doFocus(pendingFocus[0], pendingFocus[1], pendingFocus[2]); pendingFocus = null; }
                else if (INITIAL_INDEX === -1) { focusDefault(); }
                if (pendingPreview) { setPreviewBoundaryStr(pendingPreview[0], pendingPreview[1]); pendingPreview = null; }
            }
            if (map.loaded()) { onLoad(); } else { map.on('load', onLoad); }
        </script>
        </body>
        </html>
        """
    }
}


