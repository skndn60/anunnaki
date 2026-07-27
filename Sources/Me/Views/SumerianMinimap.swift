import SwiftUI
import SwiftData

struct SumerianMinimap: View {
    let places: [Place]
    let highlightedCity: String?

    init(places: [Place], highlightedCity: String? = nil) {
        self.places = places.filter { $0.latitude != nil && $0.longitude != nil }
        self.highlightedCity = highlightedCity
    }

    private var latMin: Double { (places.map(\.latitude!).min() ?? 30) - 0.3 }
    private var latMax: Double { (places.map(\.latitude!).max() ?? 33) + 0.3 }
    private var lngMin: Double { (places.map(\.longitude!).min() ?? 44) - 0.3 }
    private var lngMax: Double { (places.map(\.longitude!).max() ?? 47) + 0.3 }

    private func normalized(_ lat: Double, _ lng: Double) -> CGPoint {
        let lngSpan = max(lngMax - lngMin, 0.5)
        let latSpan = max(latMax - latMin, 0.5)
        let x = CGFloat((lng - lngMin) / lngSpan)
        let y = 1 - CGFloat((lat - latMin) / latSpan)
        return CGPoint(x: x, y: y)
    }

    private func cityColor(_ name: String) -> Color {
        let colors: [Color] = [.brown, .orange, .teal, .indigo, .cyan, .mint, .pink, .purple, .red, .yellow]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        if places.isEmpty {
            EmptyView()
        } else {
            Canvas { context, cgSize in
                let padding: CGFloat = 8
                let drawW = cgSize.width - padding * 2
                let drawH = cgSize.height - padding * 2
                let origin = CGPoint(x: padding, y: padding)

                for place in places {
                    let norm = normalized(place.latitude!, place.longitude!)
                    let px = origin.x + norm.x * drawW
                    let py = origin.y + norm.y * drawH
                    let isHighlighted = place.name == highlightedCity
                    let dotR: CGFloat = isHighlighted ? 5 : 2.5

                    context.fill(
                        Path(ellipseIn: CGRect(x: px - dotR, y: py - dotR, width: dotR * 2, height: dotR * 2)),
                        with: .color(isHighlighted ? .orange : cityColor(place.name).opacity(0.5))
                    )

                    if isHighlighted {
                        context.draw(
                            Text(place.name)
                                .font(.system(size: 6, design: .serif).bold())
                                .foregroundColor(.orange),
                            at: CGPoint(x: px + 9, y: py),
                            anchor: .leading
                        )
                    }
                }
            }
            .frame(width: 80, height: 65)
        }
    }
}
