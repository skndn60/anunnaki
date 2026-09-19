import SwiftUI
import SwiftData
import WebKit

// MARK: - Value snapshot (no @Model faulting in render paths)

private struct AtlasLayer {
    let key: String
    let label: String
    let icon: String
    let colorHex: String
    let isWater: Bool
    let pinCount: Int
    let minorCount: Int
    let boundaryCount: Int
    let features: [String: Any]
}

private struct AtlasDynasty {
    let name: String
    let colorHex: String
    let geometry: [String: Any]
}

private struct MesopotamiaSnapshot {
    var layers: [AtlasLayer] = []
    var dynasties: [AtlasDynasty] = []
}

// MARK: - Mesopotamia Map

struct MesopotamiaMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \PlaceType.name) private var placeTypes: [PlaceType]
    @Query(sort: \Place.name) private var places: [Place]
    @Query(sort: \Era.orderIndex) private var eras: [Era]

    @AppStorage("mesopotamiaMapHiddenLayersV2") private var hiddenLayersRaw = ""
    @AppStorage("mapLabelRevealZoom") private var labelMinZoom = 8
    @AppStorage("mapHideBasemapCities") private var hideBasemapCities = true

    @State private var snapshot = MesopotamiaSnapshot()
    @State private var coordinator = MesopotamiaMapCoordinator()
    @State private var zoomController = MapZoomController()

    private let dynastyColorHex = "#8E7CC3"

    private let dynastyPalette: [String] = [
        "#D96A3B", "#3378B8", "#CC9926", "#99408C", "#3FA666",
        "#B34C4C", "#6659BF", "#BF8C59", "#4D9999", "#CC731A",
        "#6FA833", "#8C5A2B", "#5B5B8C", "#C9508A",
    ]

    var body: some View {
        HSplitView {
            layerSidebar
                .frame(minWidth: 240, idealWidth: 260, maxWidth: 340)
            mapCanvas
                .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Mesopotamia Map")
        .task { rebuildSnapshot() }
        .onChange(of: placeTypes.map(\.persistentModelID)) { _, _ in rebuildSnapshot() }
        .onChange(of: places.map(\.persistentModelID)) { _, _ in rebuildSnapshot() }
        .onChange(of: eras.map(\.persistentModelID)) { _, _ in rebuildSnapshot() }
    }

    // MARK: - Sidebar

    private var layerSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerToolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(snapshot.layers, id: \.key) { layer in
                        layerRow(layer)
                    }
                    dynastyRow
                    basemapCitiesRow
                }
                .padding(.vertical, 6)
            }
        }
        .background(.bar)
    }

    private var headerToolbar: some View {
        HStack(spacing: 10) {
            Text("More landmarks appear as you zoom in")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                zoomController.fitView()
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Fit map to all places and territories")
        }
    }

    private func layerRow(_ layer: AtlasLayer) -> some View {
        let isVisible = !hiddenKeys.contains(layer.key)
        return HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: layer.colorHex))
                .frame(width: 12, height: 12)
            Image(systemName: layer.icon)
                .font(.caption)
                .foregroundStyle(Color(hex: layer.colorHex))
                .frame(width: 14)
            Text(layer.label)
                .font(.body)
            if layer.isWater {
                Image(systemName: "water.waves")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(pinSummary(layer))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Toggle("", isOn: Binding(
                get: { isVisible },
                set: { setHidden(!$0, for: layer.key) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var dynastyRow: some View {
        let visible = !hiddenKeys.contains("dyn")
        return HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: dynastyColorHex))
                .frame(width: 12, height: 12)
            Image(systemName: "crown.fill")
                .font(.caption)
                .foregroundStyle(Color(hex: dynastyColorHex))
                .frame(width: 14)
            Text("Dynasties")
                .font(.body)
            Spacer(minLength: 4)
            Text("\(snapshot.dynasties.count) territories")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Toggle("", isOn: Binding(
                get: { visible },
                set: { setHidden(!$0, for: "dyn") }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var basemapCitiesRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.2")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text("Base map cities")
                .font(.body)
            Spacer(minLength: 4)
            Toggle("", isOn: $hideBasemapCities)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .help("Hide city labels drawn by the base map")
    }

    private func pinSummary(_ layer: AtlasLayer) -> String {
        if layer.minorCount == 0 { return "\(layer.pinCount) pl" }
        return "\(layer.pinCount)+\(layer.minorCount) pl"
    }

    // MARK: - Map canvas

    private var mapCanvas: some View {
        ZStack(alignment: .bottomLeading) {
            MesopotamiaMapWebView(snapshot: snapshot, state: stateJSON, coordinator: coordinator, zoomController: zoomController, onPlaceSelected: openPlace)
            legendPanel
                .padding(10)
        }
    }

    private var legendPanel: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Visible")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            ForEach(visibleLayerEntries, id: \.label) { entry in
                HStack(spacing: 6) {
                    Circle().fill(entry.color).frame(width: 9, height: 9)
                    Text(entry.label).font(.caption)
                }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.quaternary, lineWidth: 1))
    }

    private var visibleLayerEntries: [(color: Color, label: String)] {
        var entries = snapshot.layers.compactMap { layer -> (color: Color, label: String)? in
            guard !hiddenKeys.contains(layer.key) else { return nil }
            return (Color(hex: layer.colorHex), layer.label)
        }
        if !hiddenKeys.contains("dyn") && !snapshot.dynasties.isEmpty {
            entries.append((Color(hex: dynastyColorHex), "Dynasties"))
        }
        return entries
    }

    // MARK: - Snapshot + state

    private var hiddenKeys: Set<String> {
        if hiddenLayersRaw.isEmpty {
            return defaultHidden
        }
        return Set(hiddenLayersRaw.split(separator: ",").map(String.init))
    }

    private var defaultHidden: Set<String> {
        Set(snapshot.layers.compactMap { layer in
            (layer.isWater || layer.label == "City") ? nil : layer.key
        }).union(["dyn"])
    }

    private var stateJSON: String {
        let obj: [String: Any] = ["hidden": Array(hiddenKeys), "labelZoom": labelMinZoom, "hideCityLabels": hideBasemapCities]
        return (try? JSONSerialization.data(withJSONObject: obj)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    private func setHidden(_ hidden: Bool, for key: String) {
        var set = hiddenKeys
        if hidden { set.insert(key) } else { set.remove(key) }
        hiddenLayersRaw = set.sorted().joined(separator: ",")
    }

    private func rebuildSnapshot() {
        var typeLayers: [AtlasLayer] = []
        let types = placeTypes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        var usedKeys: Set<String> = []
        for type in types {
            let typePlaces = places.filter { $0.placeType?.persistentModelID == type.persistentModelID }
            let baseKey = sanitizedKey(type.name)
            var key = baseKey
            var suffix = 2
            while usedKeys.contains(key) {
                key = "\(baseKey)-\(suffix)"
                suffix += 1
            }
            usedKeys.insert(key)

            let majorPins: [Place] = typePlaces.filter { ($0.isMajor ?? false) && $0.latitude != nil }
            let minorPins: [Place] = typePlaces.filter { !($0.isMajor ?? false) && $0.latitude != nil }
            let boundaries: [Place] = typePlaces.filter { $0.boundaryGeoJSON?.polygonGeometry() != nil }

            var features: [[String: Any]] = []
            var boundaryIndex = 0
            for place in majorPins {
                features.append(pointFeature(name: place.name, kind: "pin", lon: place.longitude!, lat: place.latitude!, zoomLevel: place.mapZoomLevel))
            }
            for place in minorPins {
                features.append(pointFeature(name: place.name, kind: "pin-minor", lon: place.longitude!, lat: place.latitude!, zoomLevel: place.mapZoomLevel))
            }
            for place in boundaries {
                if let geometry = place.boundaryGeoJSON?.polygonGeometry() {
                    features.append(boundaryFeature(id: boundaryIndex, name: place.name, geometry: geometry))
                    boundaryIndex += 1
                }
            }
            let collection: [String: Any] = ["type": "FeatureCollection", "features": features]

            typeLayers.append(AtlasLayer(
                key: key,
                label: type.name,
                icon: type.icon,
                colorHex: "#\(type.colorHex)",
                isWater: type.isWater ?? false,
                pinCount: majorPins.count,
                minorCount: minorPins.count,
                boundaryCount: boundaries.count,
                features: collection
            ))
        }

        var dynasties: [AtlasDynasty] = []
        let drawnEras = eras.filter { $0.boundaryGeoJSON?.polygonGeometry() != nil }
        for (index, era) in drawnEras.enumerated() {
            if let geometry = era.boundaryGeoJSON?.polygonGeometry() {
                dynasties.append(AtlasDynasty(
                    name: era.name,
                    colorHex: dynastyPalette[index % dynastyPalette.count],
                    geometry: geometry
                ))
            }
        }

        snapshot = MesopotamiaSnapshot(layers: typeLayers, dynasties: dynasties)
    }

    private func openPlace(named name: String) {
        guard let place = places.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else { return }
        openWindow(id: "place-quickview", value: place.persistentModelID)
    }

    private func sanitizedKey(_ name: String) -> String {
        let filtered = String(name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }).lowercased()
        return filtered.isEmpty ? "type" : filtered
    }
}

// MARK: - Feature builders

private func pointFeature(name: String, kind: String, lon: Double, lat: Double, zoomLevel: Int) -> [String: Any] {
    [
        "type": "Feature",
        "properties": ["name": name, "kind": kind, "zoomLevel": zoomLevel],
        "geometry": ["type": "Point", "coordinates": [lon, lat]],
    ]
}

private func boundaryFeature(id: Int, name: String, geometry: [String: Any]) -> [String: Any] {
    [
        "type": "Feature",
        "id": id,
        "properties": ["name": name, "kind": "boundary"],
        "geometry": geometry,
    ]
}

// MARK: - WKWebView wrapper

private struct MesopotamiaMapWebView: NSViewRepresentable {
    let snapshot: MesopotamiaSnapshot
    let state: String
    let coordinator: MesopotamiaMapCoordinator
    let zoomController: MapZoomController
    let onPlaceSelected: ((String) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.configuration.userContentController.add(coordinator, name: "atlas")
        webView.configuration.userContentController.add(coordinator, name: "placeClicked")
        zoomController.webView = webView
        coordinator.zoomController = zoomController
        coordinator.onPlaceSelected = onPlaceSelected
        if let json = MesopotamiaMapHTMLBuilder.atlasJSON(snapshot),
           let html = MesopotamiaMapHTMLBuilder.html(fromJSON: json) {
            coordinator.lastKey = json
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.openhistoricalmap.org"))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        coordinator.onPlaceSelected = onPlaceSelected
        if let json = MesopotamiaMapHTMLBuilder.atlasJSON(snapshot), json != coordinator.lastKey {
            coordinator.lastKey = json
            if let html = MesopotamiaMapHTMLBuilder.html(fromJSON: json) {
                webView.loadHTMLString(html, baseURL: URL(string: "https://www.openhistoricalmap.org"))
            }
        }
        coordinator.state = state
        if coordinator.isReady {
            webView.evaluateJavaScript("setLayerState(\(state));", completionHandler: nil)
        }
    }
}

// MARK: - Coordinator

private final class MesopotamiaMapCoordinator: NSObject, WKScriptMessageHandler {
    var lastKey: String?
    var isReady = false
    var state = "{}"
    var zoomController: MapZoomController?
    var onPlaceSelected: ((String) -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "atlas":
            guard let body = message.body as? String else { return }
            if body == "ready" {
                isReady = true
                if let webView = zoomController?.webView {
                    webView.evaluateJavaScript("setLayerState(\(state));", completionHandler: nil)
                }
            }
        case "placeClicked":
            if let name = message.body as? String { onPlaceSelected?(name) }
        default:
            break
        }
    }
}

// MARK: - HTML builder

private enum MesopotamiaMapHTMLBuilder {

    static func atlasJSON(_ snapshot: MesopotamiaSnapshot) -> String? {
        let atlas: [String: Any] = [
            "layers": snapshot.layers.map { layer -> [String: Any] in
                [
                    "key": layer.key,
                    "colorHex": layer.colorHex,
                    "isWater": layer.isWater,
                    "features": layer.features,
                ]
            },
            "dynasties": snapshot.dynasties.map { dynasty -> [String: Any] in
                [
                    "name": dynasty.name,
                    "colorHex": dynasty.colorHex,
                    "geometry": dynasty.geometry,
                ]
            },
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: atlas, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    static func html(fromJSON json: String) -> String? {
        guard let quoted = jsString(json) else { return nil }
        return mapTemplate.replacingOccurrences(of: "__ATLAS__", with: quoted)
    }

    private static let mapTemplate = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script src="https://cdn.jsdelivr.net/npm/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/maplibre-gl@4.7.1/dist/maplibre-gl.css">
    <style>
        html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; }
        .atlas-marker { cursor: pointer; display: flex; align-items: center; gap: 3px; }
        .atlas-dot { width: 12px; height: 12px; border-radius: 50%; border: 1.5px solid rgba(255,255,255,0.95); box-shadow: 0 1px 2px rgba(0,0,0,0.4); }
        .atlas-dot-minor { width: 9px; height: 9px; opacity: 0.75; }
        .atlas-label { font: 600 12px -apple-system, 'Helvetica Neue', sans-serif; color: #111; text-shadow: 0 0 2px #fff, 0 0 2px #fff, 0 0 3px #fff; white-space: nowrap; pointer-events: none; }
        .atlas-label-minor { font-weight: 500; font-size: 10.5px; color: #333; }
        .atlas-popup { font: 12px -apple-system, 'Helvetica Neue', sans-serif; font-weight: 600; }
    </style>
    </head>
    <body>
    <div id="map"></div>
    <script>
        var ATLAS = JSON.parse(__ATLAS__);

        var map = new maplibregl.Map({
            container: 'map',
            style: 'https://www.openhistoricalmap.org/map-styles/main/main.json',
            center: [45.0, 33.5],
            zoom: 5,
            attributionControl: false
        });
        map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right');

        var ready = false;
        var markers = [];
        var pointItems = [];
        var popup = new maplibregl.Popup({ closeButton: true, offset: 16 });
        var layerDefaults = {};
        var boundaryFillLayerIds = [];

        function escapeHtml(s) {
            return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
        }

        function makeMarker(lngLat, color, name, minor, isPlace) {
            var el = document.createElement('div');
            el.className = 'atlas-marker';
            var dot = document.createElement('span');
            dot.className = minor ? 'atlas-dot atlas-dot-minor' : 'atlas-dot';
            dot.style.background = color;
            var label = document.createElement('span');
            label.className = minor ? 'atlas-label atlas-label-minor' : 'atlas-label';
            label.textContent = name;
            el.appendChild(dot);
            el.appendChild(label);
            el.addEventListener('click', function() {
                if (isPlace && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.placeClicked) {
                    window.webkit.messageHandlers.placeClicked.postMessage(name);
                } else {
                    popup.setLngLat(lngLat).setHTML('<div class="atlas-popup">' + escapeHtml(name) + '</div>').addTo(map);
                }
            });
            return { el: el, label: label };
        }

        function polygonCenterRing(ring) {
            var cx = 0, cy = 0;
            for (var i = 0; i < ring.length; i++) { cx += ring[i][0]; cy += ring[i][1]; }
            return [cx / ring.length, cy / ring.length];
        }

        function setupLayers() {
            (ATLAS.layers || []).forEach(function(L) {
                var sourceId = 's-' + L.key;
                if (!map.getSource(sourceId)) {
                    map.addSource(sourceId, { type: 'geojson', data: L.features });
                    map.addLayer({ id: 'l-' + L.key + '-fill', type: 'fill', source: sourceId,
                        filter: ['==', ['get', 'kind'], 'boundary'],
                        paint: { 'fill-color': L.colorHex, 'fill-opacity': L.isWater ? 0.32 : 0.16 } });
                    map.addLayer({ id: 'l-' + L.key + '-line', type: 'line', source: sourceId,
                        filter: ['==', ['get', 'kind'], 'boundary'],
                        layout: { 'line-cap': 'round', 'line-join': 'round' },
                        paint: { 'line-color': L.colorHex, 'line-width': 2.5, 'line-opacity': 0.9 } });
                    layerDefaults['l-' + L.key + '-fill'] = { fill: L.isWater ? 0.32 : 0.16, hoverFill: L.isWater ? 0.46 : 0.30, line: 2.5, hoverLine: 4.6, lineOp: 0.9 };
                    map.on('click', 'l-' + L.key + '-fill', function(e) { showBoundaryPopup(e); });
                    boundaryFillLayerIds.push('l-' + L.key + '-fill');
                }
                (L.features.features || []).forEach(function(f) {
                    if (!f.geometry || f.geometry.type !== 'Point') { return; }
                    var minor = f.properties.kind === 'pin-minor';
                    var level = f.properties.zoomLevel || 0;
                    pointItems.push({
                        lat: f.geometry.coordinates[1],
                        lon: f.geometry.coordinates[0],
                        color: L.colorHex,
                        name: f.properties.name || '',
                        minor: minor,
                        level: level,
                        group: L.key
                    });
                });
            });

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

            var spreadCoords = spreadOverlapping(pointItems);

            pointItems.forEach(function(p, i) {
                var coord = spreadCoords[i];
                var mk = makeMarker([coord.lon, coord.lat], p.color, p.name, p.minor, true);
                new maplibregl.Marker({ element: mk.el, anchor: 'left' })
                    .setLngLat([coord.lon, coord.lat]).addTo(map);
                markers.push({ el: mk.el, label: mk.label, group: p.group, minor: p.minor, level: p.level });
            });

            var dyns = ATLAS.dynasties || [];
            if (dyns.length) {
                var dynFeatures = dyns.map(function(d, i) {
                    return { type: 'Feature', id: i, properties: { name: d.name, color: d.colorHex }, geometry: d.geometry };
                });
                map.addSource('s-dyn', { type: 'geojson', data: { type: 'FeatureCollection', features: dynFeatures } });
                map.addLayer({ id: 'l-dyn-fill', type: 'fill', source: 's-dyn',
                    paint: { 'fill-color': ['get', 'color'], 'fill-opacity': 0.14 } });
                map.addLayer({ id: 'l-dyn-line', type: 'line', source: 's-dyn',
                    layout: { 'line-cap': 'round', 'line-join': 'round' },
                    paint: { 'line-color': ['get', 'color'], 'line-width': 2.2, 'line-opacity': 0.85 } });
                layerDefaults['l-dyn-fill'] = { fill: 0.14, hoverFill: 0.28, line: 2.2, hoverLine: 4.2, lineOp: 0.85 };
                map.on('click', 'l-dyn-fill', function(e) { showBoundaryPopup(e); });
                boundaryFillLayerIds.push('l-dyn-fill');
                dyns.forEach(function(d) {
                    if (!d.geometry || !d.geometry.coordinates || !d.geometry.coordinates[0]) { return; }
                    var center = polygonCenterRing(d.geometry.coordinates[0]);
                    var mk = makeMarker(center, d.colorHex, d.name || '', false, false);
                    new maplibregl.Marker({ element: mk.el, anchor: 'left' }).setLngLat(center).addTo(map);
                    markers.push({ el: mk.el, label: mk.label, group: 'dyn', minor: true, level: 0 });
                });
            }

            ready = true;
            fitView();
            applyZoomReveal();
        }

        function showBoundaryPopup(e) {
            if (!e.features || !e.features[0]) { return; }
            var n = e.features[0].properties.name || '';
            popup.setLngLat(e.lngLat).setHTML('<div class="atlas-popup">' + escapeHtml(n) + '</div>').addTo(map);
        }

        var activeFillLayer = null;
        var activeName = '';
        var hoverPopup = new maplibregl.Popup({ closeButton: false, offset: 14 });
        var popupName = '';
        var hoverRaf = false;
        var hoverLngLat = null;

        function paintBoundary(fillLayer, name) {
            var lineId = fillLayer.replace('-fill', '-line');
            var d = layerDefaults[fillLayer];
            if (!d || !map.getLayer(fillLayer) || !map.getLayer(lineId)) { return; }
            if (name) {
                map.setPaintProperty(fillLayer, 'fill-opacity', ['case', ['==', ['get', 'name'], name], d.hoverFill, d.fill]);
                map.setPaintProperty(lineId, 'line-width', ['case', ['==', ['get', 'name'], name], d.hoverLine, d.line]);
                map.setPaintProperty(lineId, 'line-opacity', ['case', ['==', ['get', 'name'], name], 1, d.lineOp]);
            } else {
                map.setPaintProperty(fillLayer, 'fill-opacity', d.fill);
                map.setPaintProperty(lineId, 'line-width', d.line);
                map.setPaintProperty(lineId, 'line-opacity', d.lineOp);
            }
        }

        function setHighlight(fillLayer, name) {
            if (activeFillLayer === fillLayer && activeName === name) { return; }
            if (activeFillLayer) { paintBoundary(activeFillLayer, ''); }
            activeFillLayer = fillLayer;
            activeName = name;
            if (fillLayer && name) { paintBoundary(fillLayer, name); }
        }

        function moveHoverPopup(lngLat) {
            hoverLngLat = lngLat;
            if (hoverRaf) { return; }
            hoverRaf = true;
            requestAnimationFrame(function() {
                hoverRaf = false;
                if (hoverLngLat) { hoverPopup.setLngLat(hoverLngLat); }
            });
        }

        function showHover(feature, fillLayer, lngLat) {
            if (!feature || !feature.properties) { return; }
            cancelPendingClear();
            var name = feature.properties.name || '';
            setHighlight(fillLayer, name);
            if (name !== popupName) {
                popupName = name;
                hoverPopup.setHTML('<div class="atlas-popup">' + escapeHtml(name) + '</div>');
            }
            if (!hoverPopup.isOpen()) { hoverPopup.addTo(map); }
            moveHoverPopup(lngLat);
        }

        var pendingClearTimer = null;

        function clearHover() {
            cancelPendingClear();
            if (!activeFillLayer && !hoverPopup.isOpen()) { return; }
            setHighlight(null, '');
            popupName = '';
            hoverPopup.remove();
        }

        function cancelPendingClear() {
            if (pendingClearTimer) { clearTimeout(pendingClearTimer); pendingClearTimer = null; }
        }

        function scheduleClear() {
            cancelPendingClear();
            pendingClearTimer = setTimeout(function() {
                pendingClearTimer = null;
                clearHover();
            }, 50);
        }

        function onMapMouseMove(e) {
            var fts = map.queryRenderedFeatures(e.point, { layers: boundaryFillLayerIds });
            if (fts && fts.length && fts[0].layer && fts[0].layer.id) {
                map.getCanvas().style.cursor = 'pointer';
                showHover(fts[0], fts[0].layer.id, e.lngLat);
            } else {
                map.getCanvas().style.cursor = '';
                scheduleClear();
            }
        }

        function onMapMouseLeave() {
            map.getCanvas().style.cursor = '';
            clearHover();
        }

        function fitView() {
            var bounds = new maplibregl.LngLatBounds();
            (ATLAS.layers || []).forEach(function(L) {
                (L.features.features || []).forEach(function(f) {
                    if (!f.geometry) { return; }
                    if (f.geometry.type === 'Point') { bounds.extend(f.geometry.coordinates); }
                    else if (f.geometry.type === 'Polygon' && f.geometry.coordinates && f.geometry.coordinates[0]) {
                        f.geometry.coordinates[0].forEach(function(c) { bounds.extend(c); });
                    }
                });
            });
            (ATLAS.dynasties || []).forEach(function(d) {
                if (d.geometry && d.geometry.coordinates && d.geometry.coordinates[0]) {
                    d.geometry.coordinates[0].forEach(function(c) { bounds.extend(c); });
                }
            });
            if (!bounds.isEmpty()) {
                map.fitBounds(bounds, { padding: 44, maxZoom: 7.5 });
            }
        }

        var state = { hidden: [], labelZoom: 8, hideCityLabels: true };
        function applyZoomReveal() {
            if (!ready) { return; }
            var z = map.getZoom();
            var labelMin = (typeof state.labelZoom === 'number') ? state.labelZoom : 8;
            markers.forEach(function(m) {
                if (state.hidden.indexOf(m.group) !== -1) { m.el.style.display = 'none'; return; }
                var visible = z >= m.level;
                m.el.style.display = visible ? '' : 'none';
                if (m.label) { m.label.style.display = (visible && z >= labelMin) ? '' : 'none'; }
            });
        }

        function applyBasemapCityLabels() {
            var style = map.getStyle();
            if (!style || !style.layers) { return; }
            var vis = state.hideCityLabels ? 'none' : 'visible';
            style.layers.forEach(function(layer) {
                if (layer.id && layer.id.indexOf('city_') === 0 && map.getLayer(layer.id)) {
                    map.setLayoutProperty(layer.id, 'visibility', vis);
                }
            });
        }

        function setLayerState(json) {
            state = json || state;
            if (typeof state.labelZoom !== 'number') { state.labelZoom = 8; }
            if (typeof state.hideCityLabels !== 'boolean') { state.hideCityLabels = true; }
            if (!ready) { return; }
            (ATLAS.layers || []).forEach(function(L) {
                var on = state.hidden.indexOf(L.key) === -1;
                ['l-' + L.key + '-fill', 'l-' + L.key + '-line'].forEach(function(id) {
                    if (map.getLayer(id)) {
                        map.setLayoutProperty(id, 'visibility', on ? 'visible' : 'none');
                    }
                });
            });
            var dynOn = state.hidden.indexOf('dyn') === -1;
            ['l-dyn-fill', 'l-dyn-line'].forEach(function(id) {
                if (map.getLayer(id)) {
                    map.setLayoutProperty(id, 'visibility', dynOn ? 'visible' : 'none');
                }
            });
            applyBasemapCityLabels();
            applyZoomReveal();
        }

        map.on('zoom', applyZoomReveal);
        map.on('styledata', applyBasemapCityLabels);
        map.on('mousemove', onMapMouseMove);
        map.on('mouseleave', onMapMouseLeave);

        function onLoad() {
            setupLayers();
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.atlas) {
                window.webkit.messageHandlers.atlas.postMessage('ready');
            }
        }
        if (map.loaded()) { onLoad(); } else { map.on('load', onLoad); }
    </script>
    </body>
    </html>
    """

    private static func jsString(_ value: String) -> String? {
        (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }
}

// MARK: - GeoJSON helpers

private extension String {
    func polygonGeometry() -> [String: Any]? {
        guard let data = self.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["type"] as? String == "Polygon" else { return nil }
        return obj
    }
}