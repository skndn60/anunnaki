import SwiftUI
import SwiftData
import MapKit
import WebKit

/// One mappable place rendered on the dynasty map (color as hex for JS).
struct DynastyMapPlace {
    let name: String
    let latitude: Double
    let longitude: Double
    let colorHex: String
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

/// MapKit style for the modern map version.
enum ModernMapStyle: String, CaseIterable, Identifiable {
    case standard, hybrid
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .standard: "Standard"
        case .hybrid: "Hybrid"
        }
    }
}

struct SumerianDynastyMapView: View {
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var places: [Place]
    @Query private var figures: [Figure]

    /// Runtime toggle: historical (OpenHistoricalMap) vs modern (MapKit .standard).
    @AppStorage("dynastyMapUseHistorical") private var useHistoricalMap = true
    /// Standard startup zoom for each map version (see App Settings).
    @AppStorage("dynastyMapModernStartupZoom") private var modernStartupZoom = 6.0
    @AppStorage("dynastyMapHistoricalStartupZoom") private var historicalStartupZoom = 5.0
    /// Per-version presentation settings (see App Settings).
    @AppStorage("dynastyMapModernStyle") private var modernMapStyleRaw = ModernMapStyle.standard.rawValue
    @AppStorage("dynastyMapModernMuted") private var modernMapMuted = false
    @AppStorage("dynastyMapHistoricalTheme") private var historicalThemeRaw = HistoricalMapTheme.historical.rawValue
    @AppStorage("dynastyMapHistoricalLanguage") private var historicalLanguageRaw = HistoricalMapLanguage.english.rawValue
    @AppStorage("dynastyMapLabelSize") private var labelSizeRaw = MapLabelSize.medium.rawValue
    @AppStorage("dynastyMapDateFilter") private var dateFilterEnabled = false

    private var modernMapStyle: MapStyle {
        if modernMapStyleRaw == ModernMapStyle.hybrid.rawValue {
            return .hybrid(pointsOfInterest: .excludingAll, showsTraffic: false)
        }
        if modernMapMuted {
            return .standard(emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false)
        }
        return .standard(pointsOfInterest: .excludingAll, showsTraffic: false)
    }

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

    @State private var selectedDynastyIndex: Int = 0
    @State private var detailFigure: Figure?
    @State private var detailPlace: Place?
    @State private var zoomController = MapZoomController()
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.3, longitude: 44.4),
        span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
    ))

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

    /// Converts the app's abstract zoom level to a MapKit latitude/longitude span.
    /// Convention: zoom 5 -> span 6, zoom 6 -> span 3 (the previous hardcoded values).
    private func span(for zoom: Double) -> Double {
        6 * pow(2, 5 - zoom)
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
                Picker("Map style", selection: $useHistoricalMap) {
                    Text("Modern").tag(false)
                    Text("Historical").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Switch between the modern map and OpenHistoricalMap")
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

    @ViewBuilder
    private var mapPanel: some View {
        if useHistoricalMap {
            historicalMapPanel
        } else {
            legacyMapPanel
        }
    }

    private var historicalMapPanel: some View {
        ZStack(alignment: .topTrailing) {
            DynastyHistoricalMapView(
                places: mapPlaces,
                capitalIndex: capitalPlaceIndex,
                focusToken: selectedDynastyIndex,
                dynastyColorHex: dynastyColorHex(for: selectedDynastyIndex),
                startupZoom: historicalStartupZoom,
                theme: HistoricalMapTheme(rawValue: historicalThemeRaw) ?? .historical,
                language: historicalLanguageRaw,
                labelSize: (MapLabelSize(rawValue: labelSizeRaw) ?? .medium).basePx,
                dateString: dynastyDateString,
                defaultCenter: nil,
                onPlaceSelected: { index in openPlace(at: index) },
                zoomController: zoomController
            )
            MapZoomButtons(controller: zoomController)
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private var legacyMapPanel: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            ForEach(allPlaces, id: \.persistentModelID) { place in
                let coord = CLLocationCoordinate2D(
                    latitude: place.latitude!,
                    longitude: place.longitude!
                )
                let isCapital = place.name == capital
                Annotation(coordinate: coord) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isCapital ? dynastyColor(for: selectedDynastyIndex) : (place.placeType?.color ?? Color(white: 0.6)))
                            .frame(width: 13, height: 13)
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                        Text(place.name)
                            .font(.system(size: 11, weight: isCapital ? .semibold : .regular))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { openPlace(place) }
                } label: {
                    EmptyView()
                }
            }
        }
        .mapStyle(modernMapStyle)
        .mapControlVisibility(.hidden)
        .onChange(of: selectedDynastyIndex) { _, _ in
            focusModernMap()
        }
        .onAppear {
            focusModernMap()
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

    private func openPlace(at index: Int) {
        guard allPlaces.indices.contains(index) else { return }
        openPlace(allPlaces[index])
    }

    private func openPlace(_ place: Place) {
        detailPlace = place
    }

    private func focusModernMap() {
        let span = MKCoordinateSpan(latitudeDelta: span(for: modernStartupZoom), longitudeDelta: span(for: modernStartupZoom))
        if let cap = capital, let place = allPlaces.first(where: { $0.name == cap }) {
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: place.latitude!, longitude: place.longitude!),
                span: span
            ))
        } else {
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 33.3, longitude: 44.4),
                span: span
            ))
        }
    }

    private func dynastyColorHex(for index: Int) -> String {
        colorHex(from: dynastyColor(for: index))
    }

    private func colorHex(from color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "#999999" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
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

// MARK: - Historical dynasty map (OpenHistoricalMap via MapLibre)

struct DynastyHistoricalMapView: NSViewRepresentable {
    let places: [DynastyMapPlace]
    let capitalIndex: Int?
    let focusToken: Int
    let dynastyColorHex: String
    let startupZoom: Double
    let theme: HistoricalMapTheme
    let language: String
    let labelSize: Double
    let dateString: String?
    /// Fallback map center (lon, lat) used when `places` is empty, so a bare
    /// historical basemap can still be shown for a time period. Pass `nil` when
    /// `places` is always non-empty.
    let defaultCenter: (Double, Double)?
    let onPlaceSelected: (Int) -> Void
    let zoomController: MapZoomController

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var lastSignature: String = ""
        var lastFocusToken: Int = -1
        var onPlaceSelected: ((Int) -> Void)?
        var lastDefaultCenter: (Double, Double)?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "placeClicked":
                guard let index = (message.body as? NSNumber)?.intValue,
                      let handler = onPlaceSelected else { return }
                handler(index)
            default:
                break
            }
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "placeClicked")
        configuration.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.onPlaceSelected = onPlaceSelected
        zoomController.webView = webView
        context.coordinator.lastSignature = Self.signature(for: places)
        context.coordinator.lastFocusToken = focusToken
        context.coordinator.lastDefaultCenter = defaultCenter
        if let html = Self.mapHTML(for: places, capitalIndex: capitalIndex, capitalColorHex: dynastyColorHex, startupZoom: startupZoom, theme: theme, language: language, labelSize: labelSize, dateString: dateString, defaultCenter: defaultCenter) {
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.openhistoricalmap.org"))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onPlaceSelected = onPlaceSelected
        let sig = Self.signature(for: places)
        let centerChanged = defaultCenter?.0 != context.coordinator.lastDefaultCenter?.0
            || defaultCenter?.1 != context.coordinator.lastDefaultCenter?.1
        if sig != context.coordinator.lastSignature || centerChanged {
            context.coordinator.lastSignature = sig
            context.coordinator.lastFocusToken = focusToken
            context.coordinator.lastDefaultCenter = defaultCenter
            if let html = Self.mapHTML(for: places, capitalIndex: capitalIndex, capitalColorHex: dynastyColorHex, startupZoom: startupZoom, theme: theme, language: language, labelSize: labelSize, dateString: dateString, defaultCenter: defaultCenter) {
                webView.loadHTMLString(html, baseURL: URL(string: "https://www.openhistoricalmap.org"))
            }
            return
        }
        guard focusToken != context.coordinator.lastFocusToken else { return }
        context.coordinator.lastFocusToken = focusToken
        guard let index = capitalIndex, places.indices.contains(index) else { return }
        let place = places[index]
        webView.evaluateJavaScript(
            "setCapital(\(index), '\(dynastyColorHex)'); focus(\(place.longitude), \(place.latitude), \(startupZoom)); setDate(\(Self.jsString(dateString ?? "")));",
            completionHandler: nil
        )
    }

    private static func signature(for places: [DynastyMapPlace]) -> String {
        places.map { "\($0.name)|\($0.latitude)|\($0.longitude)|\($0.colorHex)" }.joined(separator: ";")
    }

    private static func jsString(_ value: String) -> String {
        let data = (try? JSONEncoder().encode(value)) ?? Data("\"\"".utf8)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    private static func mapHTML(for places: [DynastyMapPlace], capitalIndex: Int?, capitalColorHex: String, startupZoom: Double, theme: HistoricalMapTheme, language: String, labelSize: Double, dateString: String?, defaultCenter: (Double, Double)? = nil, boundaryGeoJSON: String? = nil) -> String? {
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
            var map = new maplibregl.Map({
                container: 'map',
                style: '\(theme.styleURL)',
                center: [\(centerLon), \(centerLat)],
                zoom: \(startupZoom),
                attributionControl: false
            });
            map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right');

            var places = [\(rows)];

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
                var marker = new maplibregl.Marker({ element: el, anchor: 'left' })
                    .setLngLat([p.lon, p.lat])
                    .addTo(map);
                marker.getElement().addEventListener('click', function() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.placeClicked) {
                        window.webkit.messageHandlers.placeClicked.postMessage(i);
                    }
                });
            });

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
            function setupBoundary() {
                if (boundaryReady || !map.isStyleLoaded()) { return; }
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
                    paint: { 'line-color': '#E0432F', 'line-width': 3, 'line-dasharray': [2, 1.5] }
                });
                boundaryReady = true;
            }

            function setBoundary(ring) {
                if (!boundaryReady) { return; }
                var geo = (ring && ring.length >= 3) ? { type: 'Polygon', coordinates: [ring] } : emptyFC;
                map.getSource('boundary').setData(geo);
            }

            var drawActive = false;
            var drawPoints = [];
            var drawing = false;
            function setDrawMode(on) {
                drawActive = !!on;
                if (drawActive) {
                    map.dragPan.disable();
                    map.doubleClickZoom.disable();
                    map.touchZoomRotate.disable();
                    map.getCanvas().style.cursor = 'crosshair';
                } else {
                    map.dragPan.enable();
                    map.doubleClickZoom.enable();
                    map.touchZoomRotate.enable();
                    map.getCanvas().style.cursor = '';
                    drawing = false;
                    drawPoints = [];
                    if (boundaryReady) { map.getSource('boundary-preview').setData(emptyFC); }
                }
            }
            map.on('mousedown', function(e) {
                if (!drawActive || !boundaryReady) { return; }
                e.preventDefault();
                drawing = true;
                drawPoints = [e.lngLat.toArray()];
            });
            map.on('mousemove', function(e) {
                if (!drawActive || !drawing || !boundaryReady) { return; }
                drawPoints.push(e.lngLat.toArray());
                map.getSource('boundary-preview').setData({ type: 'LineString', coordinates: drawPoints });
            });
            map.on('mouseup', function(e) {
                if (!drawActive || !drawing || !boundaryReady) { return; }
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
            }
            map.on('styledata', snapshotAndApply);
            map.on('zoom', applyLabelSize);

            var ready = false;
            var pendingFocus = null;
            function doFocus(lon, lat, zoom) {
                map.flyTo({ center: [lon, lat], zoom: zoom, duration: 600 });
            }
            function focus(lon, lat, zoom) {
                if (!ready) { pendingFocus = [lon, lat, zoom]; return; }
                doFocus(lon, lat, zoom);
            }
            function onLoad() {
                ready = true;
                setupBoundary();
                setCapital(\(initialIndex), '\(initialColor)');
                applyLabelSize();
                if (pendingFocus) { doFocus(pendingFocus[0], pendingFocus[1], pendingFocus[2]); pendingFocus = null; }
            }
            if (map.loaded()) { onLoad(); } else { map.on('load', onLoad); }
        </script>
        </body>
        </html>
        """
    }
}


