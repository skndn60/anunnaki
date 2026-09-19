import Foundation

/// Geometry helpers that turn simple parametric inputs into GeoJSON polygon
/// rings (`[[lon, lat], ...]`, unclosed) for place/era boundaries — used by the
/// water-body "blob" and river "buffer" authoring tools in the boundary editor.
package enum BoundaryGeometry {
    private static let kmPerLatDegree = 111.32

    /// Deterministic pseudo-random number in [0, 1) derived from a seed +
    /// salt, so identical parameters always reproduce the identical silhouette.
    private static func hash01(_ seed: Int, _ salt: Int) -> Double {
        var x = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15
        x &+= UInt64(bitPattern: Int64(truncatingIfNeeded: salt)) &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 30
        x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 27
        x = x &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Double(x % 10_000) / 10_000.0
    }

    /// A wavy, organic polygon ring shaped like a water body around a centroid.
    /// - Parameters:
    ///   - center: centroid (lon, lat) of the silhouette
    ///   - radiusKm: average radius of the blob in kilometres
    ///   - lonStretch: E–W elongation factor (>1 widens the blob east–west)
    ///   - vertices: number of contour points on the ring
    ///   - roughness: how wobbled the outline is (0 = perfect ellipse, 1 = very jagged)
    ///   - seed: changes the shape while keeping parameters identical
    package static func blobRing(
        center: (lon: Double, lat: Double),
        radiusKm: Double,
        lonStretch: Double = 1.0,
        vertices: Int = 24,
        roughness: Double = 0.35,
        seed: Int = 42
    ) -> [[Double]] {
        guard vertices >= 8, radiusKm > 0 else { return [] }
        let latDeg = center.lat * .pi / 180
        let rLat = radiusKm / kmPerLatDegree
        let rLon = (radiusKm * max(lonStretch, 0.01)) / (kmPerLatDegree * max(cos(latDeg), 0.2))

        let frequencies: [Double] = [3, 5, 8, 13]
        let amplitudes: [Double] = [0.55, 0.30, 0.11, 0.04]
        let phases = frequencies.enumerated().map { index, _ in
            hash01(seed, index) * 2.0 * .pi
        }

        return (0..<vertices).map { i in
            let angle = 2.0 * .pi * Double(i) / Double(vertices)
            var osc = 0.0
            for (fIndex, freq) in frequencies.enumerated() {
                osc += amplitudes[fIndex] * sin(freq * angle + phases[fIndex])
            }
            let factor = 1.0 + max(0.0, min(roughness, 1.0)) * osc
            let lon = center.lon + rLon * factor * sin(angle)
            let lat = center.lat + rLat * factor * cos(angle)
            return [lon, lat]
        }
    }

    /// A closed polygon ring approximating the corridor of a linear feature
    /// (river, canal) by offsetting every point of a hand-drawn centerline by
    /// half the requested width to each side.
    package static func bufferPolyline(_ points: [[Double]], widthKm: Double) -> [[Double]] {
        guard points.count >= 2, widthKm > 0 else { return [] }
        let halfLat = (widthKm / 2.0) / kmPerLatDegree
        let count = points.count

        func unitDirection(_ i: Int) -> (dx: Double, dy: Double) {
            var dx = 0.0
            var dy = 0.0
            if i == 0 {
                dx = points[1][0] - points[0][0]
                dy = points[1][1] - points[0][1]
            } else if i == count - 1 {
                dx = points[count - 1][0] - points[count - 2][0]
                dy = points[count - 1][1] - points[count - 2][1]
            } else {
                var v1x = points[i][0] - points[i - 1][0]
                var v1y = points[i][1] - points[i - 1][1]
                let l1 = max(hypot(v1x, v1y), 1e-9)
                v1x /= l1
                v1y /= l1
                var v2x = points[i + 1][0] - points[i][0]
                var v2y = points[i + 1][1] - points[i][1]
                let l2 = max(hypot(v2x, v2y), 1e-9)
                v2x /= l2
                v2y /= l2
                dx = v1x + v2x
                dy = v1y + v2y
            }
            let length = max(hypot(dx, dy), 1e-9)
            return (dx / length, dy / length)
        }

        var left: [[Double]] = []
        var right: [[Double]] = []
        for i in 0..<count {
            let direction = unitDirection(i)
            let halfLon = halfLat / max(cos(points[i][1] * .pi / 180), 0.2)
            let nx = -direction.dy
            let ny = direction.dx
            left.append([points[i][0] + nx * halfLon, points[i][1] + ny * halfLat])
            right.append([points[i][0] - nx * halfLon, points[i][1] - ny * halfLat])
        }

        var ring = left
        ring.append(contentsOf: right.reversed())
        return ring
    }
}