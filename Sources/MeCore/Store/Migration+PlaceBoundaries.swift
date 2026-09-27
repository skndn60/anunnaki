import Foundation
import SwiftData

extension Migration {
    /// Coarse hand-authored territory profiles for region-type places that have no
    /// dynasty era to inherit from (Mesopotamia, Cedar Forest, Dilmun, Lebanon,
    /// Upper Mesopotamia, the southern marshes, Gutium, Magan, Meluhha…).
    /// Keyed by normalized place name → `[[Double]]` ring (`[lon, lat]`).
    /// Georeferenced to known landmarks; intentionally fuzzy where ancient borders
    /// are poorly known. Entries for not-yet-created places (Elam, Subartu, Amurru)
    /// are forward-compatible — they backfill whenever such a place exists at launch.
    /// The first coarse seeding profile for the southern marshes (superseded by the
    /// Hawizeh/Hammar-aware ring in `placeBoundaryRings`). Kept only so the targeted
    /// `upgradeSeededMarshesBoundary` can recognize — and replace — exactly the value
    /// this app seeded, leaving any boundary the user has since drawn or edited untouched.
    package static let legacySeededMarshesRing: [[Double]] = [
        [46.3, 30.3], [47.2, 30.2], [48.1, 30.6], [48.4, 31.3], [47.8, 31.7],
        [47.2, 31.9], [46.6, 31.7], [46.1, 31.2], [46.1, 30.8], [46.3, 30.3],
    ]

    /// The original cedar-forest profile: a ~370 km Levantine corridor covering
    /// both the Lebanon and Amanus ranges. Superseded by the Mount-Lebanon-focused
    /// ring in `placeBoundaryRings`. Kept only so the targeted
    /// `upgradeSeededCedarForestBoundary` can recognize — and replace — exactly this
    /// seeded value, leaving any boundary the user has since drawn or edited untouched.
    package static let legacySeededCedarForestRing: [[Double]] = [
        [36.2, 37.2], [36.4, 36.7], [36.4, 36.2], [36.7, 35.9], [36.8, 35.2],
        [36.5, 34.8], [36.4, 34.4], [36.2, 34.1], [35.6, 33.9], [35.4, 34.4],
        [35.7, 35.2], [35.9, 35.9], [36.0, 36.5], [36.2, 37.2],
    ]

    package static let placeBoundaryRings: [String: [[Double]]] = [
        "lebanon": [
            [35.9, 34.65], [36.3, 34.6], [36.4, 34.3], [36.3, 33.9], [36.0, 33.5],
            [35.7, 33.2], [35.2, 33.2], [35.1, 33.9], [35.3, 34.4], [35.9, 34.65],
        ],
        "cedar forest": [
            [36.30, 34.62], [36.18, 34.40], [36.12, 34.16], [35.92, 33.88],
            [35.80, 33.55], [35.60, 33.62], [35.55, 33.92], [35.72, 34.10],
            [35.92, 34.32], [36.00, 34.52], [36.30, 34.62],
        ],
        "dilmun": [
            [49.1, 27.7], [49.9, 26.9], [50.4, 26.5], [50.7, 26.0], [50.6, 25.5],
            [50.0, 25.2], [49.4, 25.8], [48.9, 27.0], [49.1, 27.7],
        ],
        "dudael": [
            [35.2, 32.3], [36.0, 32.4], [36.7, 32.0], [36.9, 31.4], [36.8, 30.9],
            [36.3, 30.6], [35.5, 30.7], [35.0, 31.0], [34.8, 31.6], [34.9, 32.1],
            [35.2, 32.3],
        ],
        "mesopotamia": [
            [40.6, 37.5], [42.9, 38.0], [44.9, 37.7], [46.3, 36.5], [46.9, 34.5],
            [47.7, 32.4], [48.1, 30.8], [47.4, 29.9], [46.3, 30.1], [45.3, 30.7],
            [43.6, 31.6], [41.8, 32.7], [40.4, 33.9], [40.6, 37.5],
        ],
        "upper mesopotamia": [
            [38.6, 36.9], [40.9, 37.9], [43.3, 37.7], [44.7, 37.3], [45.2, 36.4],
            [45.1, 35.3], [44.0, 34.7], [42.4, 35.1], [40.7, 35.0], [38.9, 35.4],
            [38.2, 36.1], [38.6, 36.9],
        ],
        "southern mesopotamian marshes (hawizeh / hammar system)": [
            [46.35, 31.20], [46.55, 31.55], [46.90, 31.78], [47.35, 31.78],
            [47.75, 31.72], [48.10, 31.82], [47.95, 31.62], [48.50, 31.28],
            [48.45, 30.90], [48.05, 30.72], [47.60, 30.45], [47.10, 30.48],
            [46.60, 30.55], [46.20, 30.62], [45.95, 30.80], [46.05, 31.05],
        ],
        "gutium": [
            [45.2, 36.2], [46.9, 36.4], [48.3, 35.7], [48.9, 34.6], [48.9, 33.7],
            [48.3, 33.0], [47.3, 32.8], [46.4, 33.2], [45.7, 33.6], [45.0, 34.6],
            [44.9, 35.5], [45.2, 36.2],
        ],
        "kassite homeland": [
            [46.0, 36.0], [48.2, 35.9], [49.3, 35.3], [49.2, 33.9], [48.3, 33.0],
            [46.2, 33.2], [45.4, 34.0], [46.0, 35.3], [46.0, 36.0],
        ],
        "magan": [
            [52.3, 26.5], [55.0, 26.6], [56.3, 26.2], [59.6, 24.7], [59.7, 23.2],
            [58.7, 21.9], [56.3, 21.8], [54.8, 22.4], [53.2, 23.3], [52.2, 24.7],
            [52.2, 25.7], [52.3, 26.5],
        ],
        "meluhha": [
            [66.3, 30.4], [69.0, 30.7], [72.5, 30.6], [75.6, 29.9], [76.8, 28.6],
            [76.9, 26.5], [76.2, 24.9], [73.5, 23.5], [70.9, 23.2], [68.0, 23.7],
            [66.2, 24.9], [65.9, 27.2], [66.3, 30.4],
        ],
        "elam": [
            [47.95, 32.75], [49.3, 32.95], [50.8, 32.75], [52.4, 31.9], [54.0, 30.8],
            [54.5, 29.2], [53.0, 28.7], [51.0, 28.5], [49.2, 28.9], [48.6, 30.0],
            [47.95, 31.4], [47.95, 32.75],
        ],
        "subartu": [
            [38.6, 38.2], [41.5, 39.0], [44.0, 38.8], [45.3, 38.0], [45.2, 37.0],
            [44.4, 36.4], [42.5, 36.3], [41.0, 36.4], [39.3, 36.7], [38.2, 37.3],
            [38.4, 37.9], [38.6, 38.2],
        ],
        "hurri": [
            [37.4, 35.7], [38.6, 36.7], [38.3, 37.4], [38.9, 38.0], [40.2, 38.3],
            [42.9, 38.0], [43.2, 37.0], [42.6, 35.6], [41.5, 34.9], [39.5, 35.1],
            [37.4, 35.7],
        ],
        "amurru": [
            [36.4, 34.2], [35.95, 34.62], [35.92, 34.85], [35.92, 35.6],
            [37.4, 36.0], [39.2, 35.9], [40.6, 36.1], [41.6, 35.4],
            [40.8, 33.9], [38.6, 33.7], [37.0, 33.8], [36.4, 34.2],
        ],
        "assyria": [
            [40.7, 37.4], [43.2, 37.4], [44.6, 36.7], [45.2, 36.0], [44.9, 35.1],
            [43.6, 34.6], [41.8, 34.4], [40.3, 34.8], [39.9, 35.9], [40.7, 37.4],
        ],
        "persian gulf (the lower sea)": [
            [49.30, 30.45], [50.40, 29.85], [51.50, 27.95], [53.80, 26.75],
            [55.20, 26.85], [56.45, 26.55], [56.70, 26.00], [55.80, 25.80],
            [54.80, 25.10], [54.30, 24.40], [52.60, 24.10], [51.30, 24.35],
            [51.55, 25.00], [51.75, 25.70], [51.45, 26.20], [51.10, 26.30],
            [50.75, 24.80], [50.60, 25.40], [50.75, 26.15], [50.50, 26.80],
            [49.50, 27.90], [48.65, 29.25], [48.30, 29.75], [48.85, 29.95],
            [48.65, 30.30], [49.30, 30.45],
        ],
        "mediterranean sea (the upper sea)": [
            [30.50, 36.90], [32.50, 36.80], [34.50, 36.40], [35.90, 36.60],
            [36.40, 36.00], [35.80, 35.20], [35.30, 34.40], [35.00, 33.60],
            [34.50, 32.50], [33.80, 31.90], [32.80, 31.30], [31.50, 31.50],
            [30.00, 32.00], [29.20, 33.00], [29.50, 34.50], [30.20, 35.60],
            [30.50, 36.90],
        ],
    ]

    /// Backfills `Place.storedBoundaryGeoJSON` for the region places in
    /// `placeBoundaryRings`, once. Additive + idempotent: a closed, non-degenerate
    /// existing stored boundary (user-drawn or edited) is never overwritten; the
    /// same sliver/repair rules as `ensureDynastyBoundaries` apply.
    package static func ensurePlaceBoundaries(context: ModelContext) {
        guard !Self.placeBoundaryRings.isEmpty else { return }
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let placeByName: [String: Place] = Dictionary(
            places.map { (Self.normalizedGroupName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var changed = false
        for (normalizedName, ring) in Self.placeBoundaryRings {
            guard let place = placeByName[normalizedName],
                  let authored = Self.polygonGeoJSON(ring: ring) else { continue }
            if let existing = place.storedBoundaryGeoJSON,
               let stored = Self.decodedRing(from: existing),
               stored.count >= 4,
               stored.first == stored.last,
               Self.ringAreaSq(stored) > 0.001,
               Self.ringMinAxisDegrees(stored) >= Self.sliverMinAxisDegrees {
                continue
            }
            place.storedBoundaryGeoJSON = authored
            changed = true
        }
        if changed { Commit.save(context, "ensurePlaceBoundaries") }
    }

    /// Replaces the *seeded* placeholder boundary for the southern Mesopotamian
    /// marshes with the refined Hawizeh/Hammar-system ring once. Additive and
    /// idempotent: fires only when the stored ring decodes to exactly the legacy
    /// seeded profile, so a user-drawn or further-edited boundary is never touched.
    package static func upgradeSeededMarshesBoundary(context: ModelContext) {
        let normalizedName = "southern mesopotamian marshes (hawizeh / hammar system)"
        guard let authoredRing = Self.placeBoundaryRings[normalizedName],
              let authored = Self.polygonGeoJSON(ring: authoredRing) else { return }
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        guard let place = places.first(where: { Self.normalizedGroupName($0.name) == normalizedName }),
              let existing = place.storedBoundaryGeoJSON,
              let stored = Self.decodedRing(from: existing),
              stored.first == stored.last,
              Array(stored.dropLast()).count == Self.legacySeededMarshesRing.count,
              zip(Array(stored.dropLast()), Self.legacySeededMarshesRing).allSatisfy({ lhs, rhs in
                  zip(lhs, rhs).allSatisfy { abs($0.0 - $0.1) < 1e-9 }
              }) else { return }
        place.storedBoundaryGeoJSON = authored
        Commit.save(context, "upgradeSeededMarshesBoundary")
    }

    /// Replaces the *seeded* Cedar Forest profile with the refined Mount-Lebanon
    /// ring once. Additive and idempotent: fires only when the stored ring decodes
    /// to exactly the legacy seeded corridor, so a user-drawn or further-edited
    /// boundary is never touched.
    package static func upgradeSeededCedarForestBoundary(context: ModelContext) {
        let normalizedName = "cedar forest"
        guard let authoredRing = Self.placeBoundaryRings[normalizedName],
              let authored = Self.polygonGeoJSON(ring: authoredRing) else { return }
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        guard let place = places.first(where: { Self.normalizedGroupName($0.name) == normalizedName }),
              let existing = place.storedBoundaryGeoJSON,
              let stored = Self.decodedRing(from: existing),
              stored.first == stored.last,
              Array(stored.dropLast()).count == Self.legacySeededCedarForestRing.count,
              zip(Array(stored.dropLast()), Self.legacySeededCedarForestRing).allSatisfy({ lhs, rhs in
                  zip(lhs, rhs).allSatisfy { abs($0.0 - $0.1) < 1e-9 }
              }) else { return }
        place.storedBoundaryGeoJSON = authored
        Commit.save(context, "upgradeSeededCedarForestBoundary")
    }
}