import SwiftUI
import SwiftData
import WebKit

// MARK: - Reusable button that opens a map window

struct MapPreviewButton: View {
    let place: Place
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("OpenHistoricalMap") {
            openWindow(id: "map-preview", value: place.persistentModelID)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// MARK: - Zoom control

@Observable
final class MapZoomController {
    weak var webView: WKWebView?

    func zoomIn() {
        evaluate("map.zoomIn()")
    }

    func zoomOut() {
        evaluate("map.zoomOut()")
    }

    private func evaluate(_ javaScript: String) {
        webView?.evaluateJavaScript(javaScript, completionHandler: nil)
    }
}

struct MapZoomButtons: View {
    let controller: MapZoomController

    var body: some View {
        VStack(spacing: 0) {
            zoomButton("plus", action: controller.zoomIn)
            Divider().frame(width: 26)
            zoomButton("minus", action: controller.zoomOut)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.quaternary, lineWidth: 1))
    }

    private func zoomButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable historical map view (works in any container)

struct HistoricalMapView: View {
    let place: Place
    @State private var zoomController = MapZoomController()

    var body: some View {
        Group {
            if place.latitude != nil, place.longitude != nil {
                ZStack(alignment: .topTrailing) {
                    MapWebView(place: place, controller: zoomController)
                        .id(place.persistentModelID)
                    MapZoomButtons(controller: zoomController)
                        .padding(8)
                }
            } else {
                NoCoordinatesView(place: place)
            }
        }
    }
}

// MARK: - Window with WebView

struct MapPreviewWindow: View {
    let placeID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @State private var place: Place?

    var body: some View {
        Group {
            if let place {
                HistoricalMapView(place: place)
            } else {
                Text("Place not found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let placeID else { return }
            let fetch = FetchDescriptor<Place>(predicate: #Predicate { $0.persistentModelID == placeID })
            place = try? modelContext.fetch(fetch).first
        }
    }
}

// MARK: - Popover variant

struct MapPreviewPopoverButton: View {
    let place: Place
    @State private var showMap = false

    var body: some View {
        Button {
            showMap.toggle()
        } label: {
            Label("Map", systemImage: "map")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .popover(isPresented: $showMap, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: place.placeType?.icon ?? "mappin")
                        .foregroundStyle(place.placeType?.color ?? .secondary)
                    Text(place.name).font(.headline)
                    Spacer()
                    MapPreviewButton(place: place)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                HistoricalMapView(place: place)
                    .frame(width: 480, height: 380)
            }
        }
    }
}

// MARK: - No-coordinates notice

struct NoCoordinatesView: View {
    let place: Place

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(place.name)
                .font(.headline)
            Text("No coordinates are stored for this place, so it can\u{2019}t be placed on the map.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Link(destination: Self.searchURL(for: place)) {
                Label("Open in OpenHistoricalMap", systemImage: "safari")
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static func searchURL(for place: Place) -> URL {
        let query = (place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.name)
        return URL(string: "https://www.openhistoricalmap.org/search?query=\(query)")!
    }
}

// MARK: - WKWebView wrapper

struct MapWebView: NSViewRepresentable {
    let place: Place
    let controller: MapZoomController

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        controller.webView = webView
        if let html = Self.mapHTML(for: place) {
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.openhistoricalmap.org"))
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    private static func mapHTML(for place: Place) -> String? {
        guard let lat = place.latitude, let lon = place.longitude else { return nil }
        let name = (try? JSONEncoder().encode(place.name)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return """
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
            var map = new maplibregl.Map({
                container: 'map',
                style: 'https://www.openhistoricalmap.org/map-styles/main/main.json',
                center: [\(lon), \(lat)],
                zoom: 5,
                attributionControl: false
            });
            map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right');
            new maplibregl.Marker()
                .setLngLat([\(lon), \(lat)])
                .setPopup(new maplibregl.Popup({ offset: 25 }).setText(\(name)))
                .addTo(map);
        </script>
        </body>
        </html>
        """
    }
}
