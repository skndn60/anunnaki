import SwiftUI
import SwiftData
import WebKit

struct EventTrailMapView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Event.name)]) private var events: [Event]

    @State private var trailEvents: [TrailEvent] = []
    @State private var loaded = false
    @State private var yearRange = 1...1

    @State private var playhead = Int.max
    @State private var isPlaying = false
    @State private var eraFilter: String?
    @State private var selectedID: PersistentIdentifier?
    @State private var focusRequest: TrailMapFocus?

    private static let palette: [Color] = [
        .red, .green, .blue, .orange, .purple, .teal,
        .pink, .indigo, .yellow, .brown, .mint, .cyan
    ]

    private var erasByCount: [String] {
        var counts: [String: Int] = [:]
        for e in trailEvents { counts[e.era, default: 0] += 1 }
        return counts.keys.sorted { (counts[$0] ?? 0, $0) > (counts[$1] ?? 0, $1) }
    }

    private func eraColor(_ era: String) -> Color {
        let idx = erasByCount.firstIndex(of: era) ?? 0
        return Self.palette[idx % Self.palette.count]
    }

    private func eraColorHex(_ era: String) -> String {
        colorHex(from: eraColor(era))
    }

    private var eventRows: [EventRow] {
        trailEvents.sorted { ($0.year, $0.name) < ($1.year, $1.name) }
            .map { EventRow(id: $0.id, name: $0.name, year: $0.year, era: $0.era, color: eraColor($0.era)) }
    }

    private var rowIndexByID: [PersistentIdentifier: Int] {
        Dictionary(uniqueKeysWithValues: eventRows.enumerated().map { ($0.element.id, $0.offset) })
    }

    private var visibleEvents: [TrailEvent] {
        let revealed = trailEvents.filter { $0.year <= playhead }
        guard let eraFilter else { return revealed }
        return revealed.filter { $0.era == eraFilter }
    }

    private var sceneJSON: String {
        buildSceneJSON() ?? "{\"dots\":{\"type\":\"FeatureCollection\",\"features\":[]},\"trails\":{\"type\":\"FeatureCollection\",\"features\":[]}}"
    }

    private func buildSceneJSON() -> String? {
        let indexes = rowIndexByID
        let seen = NSMutableOrderedSet()

        var dotFeatures: [[String: Any]] = []
        var trailFeatures: [[String: Any]] = []

        for event in visibleEvents.sorted(by: { ($0.year, $0.name) < ($1.year, $1.name) }) {
            guard let index = indexes[event.id] else { continue }
            for stop in event.stops {
                if seen.contains(stop.key) { continue }
                seen.add(stop.key)
                dotFeatures.append([
                    "type": "Feature",
                    "properties": ["idx": index, "color": eraColorHex(event.era)],
                    "geometry": ["type": "Point", "coordinates": [stop.lon, stop.lat]]
                ])
            }
        }

        let grouped = Dictionary(grouping: visibleEvents, by: \.era)
        for era in erasByCount {
            guard let group = grouped[era] else { continue }
            let events = group.sorted { ($0.year, $0.name) < ($1.year, $1.name) }
            var coords: [[Double]] = []
            var lastKey: String?
            for ev in events {
                for stop in ev.stops {
                    if stop.key == lastKey { continue }
                    lastKey = stop.key
                    coords.append([stop.lon, stop.lat])
                }
            }
            guard coords.count >= 2 else { continue }
            trailFeatures.append([
                "type": "Feature",
                "properties": ["color": eraColorHex(era)],
                "geometry": ["type": "LineString", "coordinates": coords]
            ])
        }

        let root: [String: Any] = [
            "dots": ["type": "FeatureCollection", "features": dotFeatures],
            "trails": ["type": "FeatureCollection", "features": trailFeatures]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .fragmentsAllowed]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            HStack(spacing: 0) {
                Group {
                    if loaded {
                        EventTrailOHMMapView(
                            sceneJSON: sceneJSON,
                            focusRequest: focusRequest,
                            onSelect: handleMapSelect
                        )
                    } else {
                        ProgressView("Arranging events…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                Divider()
                eventList
                    .frame(width: 320)
            }
        }
        .task {
            rebuild()
        }
        .onChange(of: events.map(\.persistentModelID)) {
            rebuild()
        }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            let tick = max(5, Int((Double(yearRange.upperBound - yearRange.lowerBound)) / 240))
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
                let next = min(playhead + tick, yearRange.upperBound)
                playhead = next
                if next >= yearRange.upperBound {
                    isPlaying = false
                    return
                }
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Event Trail Map", systemImage: "route")
                    .font(.headline)
                Spacer()
                Text(yearLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Slider(value: playheadBinding,
                       in: Double(yearRange.lowerBound)...Double(yearRange.upperBound))
                    .frame(width: 220)
                playButton
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    eraChip("All", era: nil, count: trailEvents.count)
                    ForEach(erasByCount, id: \.self) { era in
                        eraChip(era, era: era, count: trailEvents.filter { $0.era == era }.count)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
    }

    private func eraChip(_ label: String, era: String?, count: Int) -> some View {
        let active = eraFilter == era
        return Button {
            eraFilter = (active ? nil : era)
        } label: {
            HStack(spacing: 5) {
                if let era {
                    Circle()
                        .fill(eraColor(era))
                        .frame(width: 8, height: 8)
                }
                Text("\(label) (\(count))")
                    .font(.caption)
                    .foregroundStyle(active ? Color.white : .primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                active ? AnyShapeStyle(eraColor(era ?? "") == eraColor("") ? .blue : eraColor(era ?? "")) : AnyShapeStyle(.quaternary.opacity(0.5)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private var playButton: some View {
        Button {
            if isPlaying {
                isPlaying = false
            } else {
                if playhead >= yearRange.upperBound {
                    playhead = yearRange.lowerBound
                }
                isPlaying = true
            }
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var playheadBinding: Binding<Double> {
        Binding(
            get: { Double(clampToRange(playhead)) },
            set: {
                playhead = Int($0.rounded())
                isPlaying = false
            }
        )
    }

    private func clampToRange(_ value: Int) -> Int {
        min(yearRange.upperBound, max(yearRange.lowerBound, value))
    }

    private var yearLabel: String {
        let y = clampToRange(playhead)
        return "c. \(abs(y)) \(y < 0 ? "BCE" : "CE")"
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(eventRows) { row in
                    Button {
                        select(row)
                    } label: {
                        HStack(spacing: 8) {
                            Text(yearString(row.year))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 78, alignment: .trailing)
                            Text(row.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 4)
                            Circle()
                                .fill(row.color)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            row.id == selectedID ? Color.accentColor.opacity(0.18) : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.4)
                }
            }
            .padding(.top, 4)
        }
        .overlay {
            if eventRows.isEmpty {
                Text(loaded ? "No dated events with mapped places." : "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    private struct EventRow: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let year: Int
        let era: String
        let color: Color
    }

    private func yearString(_ year: Int) -> String {
        let suffix = year < 0 ? " BCE" : " CE"
        return "\(abs(year))\(suffix)"
    }

    private func select(_ row: EventRow) {
        selectedID = row.id
        playhead = row.year
        isPlaying = false
        focusOnEvent(row.id)
    }

    private func handleMapSelect(_ index: Int) {
        guard eventRows.indices.contains(index) else { return }
        select(eventRows[index])
    }

    private func focusOnEvent(_ id: PersistentIdentifier) {
        guard let stop = trailEvents.first(where: { $0.id == id })?.stops.first else { return }
        let seq = (focusRequest?.seq ?? 0) + 1
        focusRequest = TrailMapFocus(lon: stop.lon, lat: stop.lat, zoom: 8.5, seq: seq)
    }

    private func rebuild() {
        var list: [TrailEvent] = []
        for event in events {
            var stops: [TrailStop] = []
            for association in event.placeAssociations {
                guard let place = association.place,
                      let lat = place.latitude,
                      let lon = place.longitude else { continue }
                stops.append(TrailStop(name: place.name, lat: lat, lon: lon))
            }
            guard !stops.isEmpty,
                  let year = event.date.startYear ?? event.date.endYear else { continue }
            list.append(TrailEvent(
                id: event.persistentModelID,
                name: event.name,
                year: year,
                era: event.era.isEmpty ? "Unassigned" : event.era,
                stops: stops
            ))
        }
        trailEvents = list
        loaded = true
        if let min = list.map(\.year).min(), let max = list.map(\.year).max() {
            yearRange = min...max
            if playhead >= Int.max / 2 { playhead = max }
            playhead = clampToRange(playhead)
        } else {
            yearRange = 1...1
            playhead = 1
        }
    }

    private func colorHex(from color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "#999999" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private struct TrailStop {
        let name: String
        let lat: Double
        let lon: Double

        var key: String {
            String(format: "%.3f,%.3f", lat, lon)
        }
    }

    private struct TrailEvent: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let year: Int
        let era: String
        let stops: [TrailStop]
    }
}

private struct TrailMapFocus: Equatable {
    let lon: Double
    let lat: Double
    let zoom: Double
    let seq: Int
}

// MARK: - Historical (OpenHistoricalMap via MapLibre) renderer

private struct EventTrailOHMMapView: NSViewRepresentable {
    let sceneJSON: String
    let focusRequest: TrailMapFocus?
    let onSelect: (Int) -> Void

    private static let homeCenter = (44.9, 33.3)
    private static let homeZoom = 4.8

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var lastSceneJSON: String = ""
        var lastFocusSeq: Int = -1
        var onSelect: ((Int) -> Void)?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "eventClicked",
                  let index = (message.body as? NSNumber)?.intValue,
                  let handler = onSelect else { return }
            handler(index)
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "eventClicked")
        configuration.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.lastSceneJSON = sceneJSON
        context.coordinator.onSelect = onSelect
        if let html = Self.html(sceneJSON: sceneJSON) {
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.openhistoricalmap.org"))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSelect = onSelect
        if sceneJSON != context.coordinator.lastSceneJSON {
            context.coordinator.lastSceneJSON = sceneJSON
            webView.evaluateJavaScript("setScene(\(sceneJSON));", completionHandler: nil)
        }
        if let request = focusRequest, request.seq != context.coordinator.lastFocusSeq {
            context.coordinator.lastFocusSeq = request.seq
            webView.evaluateJavaScript("focus(\(request.lon), \(request.lat), \(request.zoom));", completionHandler: nil)
        }
    }

    private static func html(sceneJSON: String) -> String? {
        let template = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script src="https://cdn.jsdelivr.net/npm/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/maplibre-gl@4.7.1/dist/maplibre-gl.css">
        <style>
            html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; }
        </style>
        </head>
        <body>
        <div id="map"></div>
        <script>
            var HOME_CENTER = [\(Self.homeCenter.0), \(Self.homeCenter.1)];
            var HOME_ZOOM = \(Self.homeZoom);
            var map = new maplibregl.Map({
                container: 'map',
                style: 'https://www.openhistoricalmap.org/map-styles/main/main.json',
                center: HOME_CENTER,
                zoom: HOME_ZOOM,
                attributionControl: false
            });
            map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right');

            var emptyFC = { type: 'FeatureCollection', features: [] };
            var ready = false;
            var pendingScene = null;
            var pendingFocus = null;
            var scene = __SCENE__;

            function applyScene() {
                var data = pendingScene || scene || emptyFC;
                map.getSource('eventDots').setData(data.dots || emptyFC);
                map.getSource('trailLines').setData(data.trails || emptyFC);
            }
            function setScene(json) { pendingScene = json; if (ready) { applyScene(); } }
            function doFocus(lon, lat, zoom) { map.flyTo({ center: [lon, lat], zoom: zoom, duration: 600 }); }
            function focus(lon, lat, zoom) { if (!ready) { pendingFocus = [lon, lat, zoom]; return; } doFocus(lon, lat, zoom); }
            function setupLayers() {
                if (ready) { return; }
                map.addSource('eventDots', { type: 'geojson', data: emptyFC });
                map.addSource('trailLines', { type: 'geojson', data: emptyFC });
                map.addLayer({
                    id: 'trail-lines',
                    type: 'line',
                    source: 'trailLines',
                    layout: { 'line-cap': 'round', 'line-join': 'round' },
                    paint: {
                        'line-color': ['coalesce', ['get', 'color'], '#888888'],
                        'line-width': 2.5,
                        'line-opacity': 0.85
                    }
                });
                map.addLayer({
                    id: 'event-dots',
                    type: 'circle',
                    source: 'eventDots',
                    paint: {
                        'circle-radius': 5,
                        'circle-color': ['coalesce', ['get', 'color'], '#888888'],
                        'circle-stroke-color': 'rgba(255,255,255,0.95)',
                        'circle-stroke-width': 1.2,
                        'circle-opacity': 0.9
                    }
                });
                map.on('click', 'event-dots', function(e) {
                    if (e.features && e.features[0] && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.eventClicked) {
                        window.webkit.messageHandlers.eventClicked.postMessage(e.features[0].properties.idx);
                    }
                });
                map.on('mouseenter', 'event-dots', function() { map.getCanvas().style.cursor = 'pointer'; });
                map.on('mouseleave', 'event-dots', function() { map.getCanvas().style.cursor = ''; });
                ready = true;
                applyScene();
            }
            function onLoad() {
                setupLayers();
                if (pendingFocus) { doFocus(pendingFocus[0], pendingFocus[1], pendingFocus[2]); pendingFocus = null; }
            }
            if (map.loaded()) { onLoad(); } else { map.on('load', onLoad); }
        </script>
        </body>
        </html>
        """
        return template.replacingOccurrences(of: "__SCENE__", with: sceneJSON)
    }
}
