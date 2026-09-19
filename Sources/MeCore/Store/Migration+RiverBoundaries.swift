import Foundation
import SwiftData

extension Migration {
    /// Riverside corridor boundaries bundled as GeoJSON resources, keyed by
    /// normalized place name. Generated offline: the river's OSM relation
    /// centerline (endpoint-chained) buffered with `BoundaryGeometry.bufferPolyline`.
    /// OSM data is ODbL; attribution is kept in each file's `properties`.
    package static let riverBoundaryResources: [String: String] = [
        "tigris river": "tigris_boundary",
        "euphrates river": "euphrates_boundary",
        "balikh river": "balikh_boundary",
        "diyala river": "diyala_boundary",
        "irnina canal": "irnina_boundary",
        "karkheh river": "karkheh_boundary",
        "karun river": "karun_boundary",
        "khabur river": "khabur_boundary",
"greater zab river": "greater_zab_boundary",
        "lesser zab river": "lesser_zab_boundary",
        "shatt al-nil (ancient iturungal)": "shatt_al_nil_boundary",
    ]

    /// Creates river places that exist only as corridors, additively. The Greater
    /// and Lesser Zab are not in the user's curated data yet; check-by-name so this
    /// never duplicates or overwrites. All river-type places otherwise pre-exist.
    package static func ensureRiverPlaces(context: ModelContext) {
        let desired = [
            ("The Greater Zab River", "Greater Zab: Assyrian Zaba 'elīta, Tigris tributary"),
            ("The Lesser Zab River", "Lesser Zab: Assyrian Zaba šaplīta, Tigris tributary"),
        ]
        let existing = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let names = Set(existing.map { Self.normalizedGroupName($0.name) })
        let riverTypes = try? context.fetch(FetchDescriptor<PlaceType>())
        let riverType = riverTypes?.first { Self.normalizedGroupName($0.name) == "river canal" || $0.name == "River, canal" }
        guard let riverType else { return }
        var changed = false
        for (name, description) in desired where !names.contains(Self.normalizedGroupName(name)) {
            let place = Place(
                name: name,
                placeType: riverType,
                modernLocation: "Iraq",
                placeDescription: description
            )
            context.insert(place)
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Backfills `Place.storedBoundaryGeoJSON` for the river places in
    /// `riverBoundaryResources` from the bundled GeoJSON, once. Additive and
    /// idempotent: an existing shaped boundary (user-drawn or already seeded) is
    /// never overwritten, mirroring `ensurePlaceBoundaries`' check.
    package static func ensureRiverBoundaries(context: ModelContext) {
        guard !Self.riverBoundaryResources.isEmpty else { return }
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let placeByName: [String: Place] = Dictionary(
            places.map { (Self.normalizedGroupName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var changed = false
        for (normalizedName, resourceName) in Self.riverBoundaryResources {
            guard let place = placeByName[normalizedName],
                  let authored = Self.riverBoundaryJSON(resourceName: resourceName) else { continue }
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
        if changed { try? context.save() }
    }

    /// Loads a bundled river GeoJSON Polygon and re-serializes it through the same
    /// canonical writer as every other boundary (`polygonGeoJSON`), so the stored
    /// string matches the app's exact format.
    package static func riverBoundaryJSON(resourceName: String) -> String? {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "geojson")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "geojson"),
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let coordinates = json["coordinates"] as? [[[Double]]],
            var ring = coordinates.first,
            ring.count >= 3,
            ring.first == ring.last
        else { return nil }
        ring.removeLast()
        return Self.polygonGeoJSON(ring: ring)
    }
}