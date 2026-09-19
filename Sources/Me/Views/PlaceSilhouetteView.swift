import SwiftUI

/// Plain SwiftUI silhouette of a place's inherited territory boundary (GeoJSON
/// Polygon exterior ring). Draws the ring filled + stroked in a given color so
/// it can be shown outside a map context (detail cards, list rows, etc.).
struct PlaceSilhouetteView: View {
    let boundaryGeoJSON: String?
    var color: Color = .teal
    var fillOpacity: Double = 0.18
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard let ring = decodeRing(from: boundaryGeoJSON),
                      let projection = project(ring, size: size) else { return }
                let points = ring.dropLast(ring.last == ring.first ? 1 : 0)
                guard points.count >= 3 else { return }
                var path = Path()
                path.move(to: projection(points.first!))
                for coord in points.dropFirst() {
                    path.addLine(to: projection(coord))
                }
                path.closeSubpath()
                context.fill(path, with: .color(color.opacity(fillOpacity)))
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
        }
    }

    private func decodeRing(from geoJSON: String?) -> [[Double]]? {
        guard let geoJSON, let data = geoJSON.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let coordinates = object["coordinates"] as? [[[Double]]],
              let ring = coordinates.first, ring.count >= 3 else { return nil }
        return ring
    }

    private func project(_ ring: [[Double]], size: CGSize) -> (([Double]) -> CGPoint)? {
        let points = ring.dropLast(ring.last == ring.first ? 1 : 0)
        guard points.count >= 3,
              let minLon = points.map({ $0[0] }).min(),
              let maxLon = points.map({ $0[0] }).max(),
              let minLat = points.map({ $0[1] }).min(),
              let maxLat = points.map({ $0[1] }).max() else { return nil }
        let spanLon = max(maxLon - minLon, 0.001)
        let spanLat = max(maxLat - minLat, 0.001)
        let padding: CGFloat = 8
        let scale = min((size.width - padding * 2) / spanLon, (size.height - padding * 2) / spanLat)
        let drawWidth = spanLon * scale
        let drawHeight = spanLat * scale
        let originX = (size.width - drawWidth) / 2
        let originY = (size.height - drawHeight) / 2
        return { coord in
            CGPoint(
                x: originX + CGFloat(coord[0] - minLon) * scale,
                y: originY + CGFloat(maxLat - coord[1]) * scale
            )
        }
    }
}