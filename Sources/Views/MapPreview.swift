import SwiftUI
import WebKit

// MARK: - Reusable button that opens a map sheet

struct MapPreviewButton: View {
    let place: Place

    @State private var showMap = false

    var body: some View {
        Button("OpenHistoricalMap") {
            showMap = true
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .sheet(isPresented: $showMap) {
            MapPreviewSheet(place: place)
        }
    }
}

// MARK: - Sheet with WebView

struct MapPreviewSheet: View {
    let place: Place

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MapWebView(url: mapURL)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Open in Browser") {
                            NSWorkspace.shared.open(mapURL)
                        }
                    }
                }
        }
        .frame(width: 800, height: 600)
    }

    private var mapURL: URL {
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
