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

// MARK: - Window with WebView

struct MapPreviewWindow: View {
    let placeID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @State private var place: Place?

    var body: some View {
        Group {
            if let place {
                MapWebView(url: mapURL(for: place))
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

    private func mapURL(for place: Place) -> URL {
        if let lat = place.latitude, let lon = place.longitude {
            return URL(string: "https://www.openhistoricalmap.org/#map=11/\(lat)/\(lon)")!
        } else {
            let query = (place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.name)
            return URL(string: "https://www.openhistoricalmap.org/search?query=\(query)")!
        }
    }
}

// MARK: - WKWebView wrapper

struct MapWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
