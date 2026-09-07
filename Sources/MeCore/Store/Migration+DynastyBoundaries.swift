import Foundation
import SwiftData

extension Migration {
    /// Creates a top-level "Dynasties" group (kind `.skl`) with one subgroup per SKL
    /// dynasty era from the `Era` table. Each subgroup auto-populates its kings (figures
    /// whose `era` points to that era) ordered by reign succession, plus any events whose
    /// era string matches the dynasty name — giving every dynasty a mixed-type page
    /// (figures + events, places added by hand) like the Enoch-style group pages.
    /// Additive + idempotent: only missing groups/members are created; existing groups and
    /// manual member additions are preserved. A subgroup's sidebar position is synced to its
    /// linked era's `orderIndex` so the "Dynasties" section follows the SKL ruling order.
    package static func ensureDynastyGroups(context: ModelContext) {
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        // The SKL post-flood ruling block spans "First dynasty of Kish" → "Dynasty of Isin".
        // Include the block's non-"dynasty" eras ("First rulers of Uruk", "Gutian rule") so the
        // "Dynasties" sidebar matches the post-flood timeline's ruling sequence.
        let sklBlockStart = eras.first { $0.name == "First dynasty of Kish" }?.orderIndex
        let sklBlockEnd = eras.first { $0.name == "Dynasty of Isin" }?.orderIndex
        let dynastyEras = eras
            .filter { era in
                if let sklBlockStart, let sklBlockEnd, era.orderIndex >= sklBlockStart, era.orderIndex <= sklBlockEnd {
                    return true
                }
                return era.name.localizedCaseInsensitiveContains("dynasty")
            }
            .sorted { $0.orderIndex < $1.orderIndex }
        guard !dynastyEras.isEmpty else { return }

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        var changed = false

        var top = allGroups.first { $0.name == "Dynasties" }
        if top == nil {
            let group = FigureGroup(
                name: "Dynasties",
                groupDescription: "Sumerian King List dynasties with their kings, events, and places",
                icon: "building.columns",
                colorHex: "007AFF",
                orderIndex: 100,
                kind: .skl,
                entityType: .figure
            )
            context.insert(group)
            top = group
            changed = true
        }
        guard let top else { return }
        // The "Dynasties" group page must list its dynasty subgroups in ruling order, not
        // alphabetically. `sortMode == .ordered` makes EntityGroupCollectionView sort by
        // orderIndex (chronological) instead of the default alphabetical-by-name mode.
        if top.sortMode != .ordered {
            top.sortMode = .ordered
            changed = true
        }

        for era in dynastyEras {
            var sub: FigureGroup?
            let isNew: Bool
            if let existing = (top.subgroups ?? []).first(where: { $0.name == era.name }) {
                sub = existing
                isNew = false
            } else {
                let newSub = FigureGroup(
                    name: era.name,
                    groupDescription: "Kings, events, and places of \(era.name)",
                    icon: "crown",
                    colorHex: "007AFF",
                    orderIndex: era.orderIndex,
                    kind: .skl,
                    entityType: .figure,
                    sortMode: .ordered
                )
                context.insert(newSub)
                if top.subgroups == nil { top.subgroups = [] }
                top.subgroups?.append(newSub)
                changed = true
                sub = newSub
                isNew = true
            }
            guard let sub else { continue }
            if sub.era?.persistentModelID != era.persistentModelID {
                sub.era = era
                changed = true
            }
            // Keep the subgroup's sidebar order in sync with the era's ruling order
            // so the "Dynasties" section lists dynasties chronologically, not alphabetically.
            if sub.orderIndex != era.orderIndex {
                sub.orderIndex = era.orderIndex
                changed = true
            }

            for figure in figures where figure.era?.persistentModelID == era.persistentModelID {
                guard !sub.figureAssociations.contains(where: { $0.figure?.persistentModelID == figure.persistentModelID }) else { continue }
                let assoc = FigureGroupAssociation(figure: figure)
                context.insert(assoc)
                sub.figureAssociations.append(assoc)
                figure.groupAssociations.append(assoc)
                changed = true
            }

            let eraName = era.name.trimmingCharacters(in: .whitespaces).lowercased()
            for event in events where event.era.trimmingCharacters(in: .whitespaces).lowercased() == eraName {
                guard !sub.figureAssociations.contains(where: { $0.event?.persistentModelID == event.persistentModelID }) else { continue }
                let assoc = FigureGroupAssociation(event: event)
                context.insert(assoc)
                sub.figureAssociations.append(assoc)
                event.groupAssociations.append(assoc)
                changed = true
            }

            if isNew && !sub.figureAssociations.isEmpty {
                sub.applyRegnalOrder()
            }
        }

        // Link eras to dynasty subgroups in any other tree (e.g. a legacy hand-built
        // "Sumerian King List" group) by normalized name. Additive + idempotent —
        // existing era links and user-created groups are untouched.
        let eraByNormalized: [String: Era] = Dictionary(
            dynastyEras.map { (Self.normalizedGroupName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for sub in allGroups where sub.parentGroup != nil && sub.era == nil {
            guard let era = eraByNormalized[Self.normalizedGroupName(sub.name)] else { continue }
            sub.era = era
            changed = true
        }

        // Reconcile legacy top-level dynasty trees (e.g. the pre-Groups-era hand-built
        // "Sumerian King List" group) with the SKL ruling block, so every dynasty list in
        // the sidebar follows the timeline's sequence. Additive + idempotent: missing
        // subgroups are created, typo'd subgroup names ("Fouth…", "rhird…") are aligned to
        // the canonical era name, and each subgroup's era link and sidebar order are synced.
        let canonicalByName: [String: Era] = Dictionary(
            dynastyEras.map { (Self.dynastyKey($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for legacyTop in allGroups where legacyTop.parentGroup == nil && legacyTop.name != "Dynasties" {
            let legacySubs = legacyTop.subgroups ?? []
            let isDynastyTree = legacyTop.kind == .skl
                || legacySubs.contains { canonicalByName[Self.dynastyKey($0.name)] != nil }
            guard isDynastyTree else { continue }
            for era in dynastyEras {
                let key = Self.dynastyKey(era.name)
                var sub: FigureGroup?
                let isNew: Bool
                if let existing = legacySubs.first(where: { Self.dynastyKey($0.name) == key }) {
                    sub = existing
                    isNew = false
                    if existing.name != era.name {
                        existing.name = era.name
                        changed = true
                    }
                } else {
                    let newSub = FigureGroup(
                        name: era.name,
                        groupDescription: "Kings, events, and places of \(era.name)",
                        icon: "crown",
                        colorHex: "007AFF",
                        orderIndex: era.orderIndex,
                        kind: .skl,
                        entityType: .figure,
                        sortMode: .ordered
                    )
                    context.insert(newSub)
                    if legacyTop.subgroups == nil { legacyTop.subgroups = [] }
                    legacyTop.subgroups?.append(newSub)
                    changed = true
                    sub = newSub
                    isNew = true
                }
                guard let sub else { continue }
                if sub.era?.persistentModelID != era.persistentModelID {
                    sub.era = era
                    changed = true
                }
                if sub.orderIndex != era.orderIndex {
                    sub.orderIndex = era.orderIndex
                    changed = true
                }
                if isNew {
                    for figure in figures where figure.era?.persistentModelID == era.persistentModelID {
                        guard !sub.figureAssociations.contains(where: { $0.figure?.persistentModelID == figure.persistentModelID }) else { continue }
                        let assoc = FigureGroupAssociation(figure: figure)
                        context.insert(assoc)
                        sub.figureAssociations.append(assoc)
                        figure.groupAssociations.append(assoc)
                        changed = true
                    }
                    let eraName = era.name.trimmingCharacters(in: .whitespaces).lowercased()
                    for event in events where event.era.trimmingCharacters(in: .whitespaces).lowercased() == eraName {
                        guard !sub.figureAssociations.contains(where: { $0.event?.persistentModelID == event.persistentModelID }) else { continue }
                        let assoc = FigureGroupAssociation(event: event)
                        context.insert(assoc)
                        sub.figureAssociations.append(assoc)
                        event.groupAssociations.append(assoc)
                        changed = true
                    }
                    if !sub.figureAssociations.isEmpty {
                        sub.applyRegnalOrder()
                    }
                }
            }
        }

        if changed { try? context.save() }
    }

    package static func normalizedGroupName(_ name: String) -> String {
        var s = name.trimmingCharacters(in: .whitespaces).lowercased()
        while s.hasPrefix("the ") { s = String(s.dropFirst(4)) }
        return s
    }

    /// Typo-tolerant normalized name for matching dynasty subgroups to canonical eras
    /// (e.g. legacy "Fouth dynasty of Uruk" / "The rhird dynasty of Uruk").
    package static func dynastyKey(_ name: String) -> String {
        var s = Self.normalizedGroupName(name)
        s = s.replacingOccurrences(of: "rhird", with: "third")
        s = s.replacingOccurrences(of: "fouth", with: "fourth")
        return s
    }

    /// Seed-to-DB name key tolerant of the spelling variants users accumulate
    /// (e.g. seed "Apilkin" vs DB "Apil-kin"): lowercased, hyphens stripped.
    package static func seedNameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "-", with: "")
    }

    /// Author-era territory polygons for the SKL dynasties (lon, lat), keyed by
    /// normalized era name. Open rings; closed at serialization. Drawn once when
    /// `era.boundaryGeoJSON` is empty so the user's own drawings always win.
    package static let dynastyBoundaryRings: [String: [[Double]]] = [
        "first dynasty of kish": [[44.05, 33.45], [44.75, 33.45], [45.05, 33.15], [45.15, 32.65], [45.35, 32.20], [45.20, 31.95], [44.95, 32.00], [44.55, 32.10], [44.30, 32.15], [44.10, 32.55], [44.00, 32.95]],
        "first rulers of uruk": [[45.35, 32.10], [45.75, 32.10], [46.15, 31.90], [46.30, 31.55], [46.15, 31.25], [45.80, 31.05], [45.45, 31.15], [45.30, 31.45], [45.25, 31.75]],
        "first dynasty of ur": [[45.55, 31.55], [46.00, 31.60], [46.35, 31.40], [46.40, 31.00], [46.20, 30.75], [45.90, 30.75], [45.70, 30.95], [45.45, 31.15]],
        "second dynasty of kish": [[44.10, 33.20], [44.70, 33.30], [45.00, 33.10], [45.10, 32.70], [45.00, 32.35], [44.70, 32.30], [44.35, 32.40], [44.15, 32.80]],
        "dynasty of hamazi": [[44.90, 33.60], [45.40, 33.70], [45.90, 34.00], [46.40, 34.10], [46.80, 33.90], [46.70, 33.40], [46.20, 33.20], [45.70, 33.30], [45.20, 33.40]],
        "second dynasty of uruk": [[45.40, 32.05], [45.80, 32.05], [46.10, 31.85], [46.25, 31.50], [46.10, 31.20], [45.75, 31.05], [45.45, 31.15], [45.30, 31.45], [45.40, 31.80]],
        "second dynasty of ur": [[45.60, 31.60], [46.05, 31.65], [46.40, 31.45], [46.50, 31.05], [46.25, 30.70], [45.95, 30.70], [45.65, 30.90], [45.45, 31.15]],
        "dynasty of adab": [[45.40, 32.30], [45.85, 32.30], [46.25, 32.10], [46.40, 31.80], [46.25, 31.50], [45.90, 31.50], [45.60, 31.70], [45.40, 32.00]],
        "dynasty of mari": [[40.30, 34.90], [40.90, 35.20], [41.60, 35.20], [42.20, 34.90], [42.30, 34.40], [41.70, 34.10], [41.00, 34.10], [40.40, 34.30], [40.10, 34.60]],
        "dynasty of awan": [[45.20, 33.60], [46.20, 33.80], [47.40, 33.60], [48.40, 33.20], [48.50, 32.20], [48.10, 31.70], [47.30, 31.90], [46.40, 32.10], [45.60, 32.40]],
        "third dynasty of kish": [[44.10, 33.25], [44.75, 33.30], [45.05, 33.05], [45.20, 32.60], [45.30, 32.15], [45.05, 31.95], [44.70, 32.10], [44.35, 32.20], [44.10, 32.60]],
        "dynasty of akshak": [[44.10, 33.45], [44.80, 33.50], [45.15, 33.30], [45.25, 32.90], [45.10, 32.50], [44.75, 32.35], [44.40, 32.45], [44.15, 32.85]],
        "fourth dynasty of kish": [[44.05, 33.40], [44.70, 33.45], [45.00, 33.15], [45.10, 32.65], [45.30, 32.20], [45.05, 32.00], [44.60, 32.10], [44.30, 32.20], [44.10, 32.60]],
        "third dynasty of uruk": [[45.25, 32.20], [45.65, 32.15], [46.05, 31.95], [46.20, 31.60], [46.05, 31.25], [45.70, 31.10], [45.40, 31.20], [45.25, 31.50]],
        "dynasty of akkad": [[40.60, 35.40], [42.30, 35.60], [45.30, 35.40], [46.60, 34.60], [47.20, 33.20], [46.60, 31.60], [46.00, 30.60], [45.30, 30.70], [44.70, 31.00], [43.90, 31.60], [43.20, 32.60], [42.60, 33.80], [41.60, 34.20], [40.60, 34.60]],
        "fourth dynasty of uruk": [[45.35, 32.00], [45.75, 32.00], [46.10, 31.80], [46.20, 31.45], [46.05, 31.20], [45.70, 31.05], [45.40, 31.15], [45.28, 31.45], [45.35, 31.80]],
        "fifth dynasty of uruk": [[45.40, 32.10], [45.85, 32.10], [46.15, 31.85], [46.25, 31.50], [46.10, 31.20], [45.75, 31.05], [45.42, 31.15], [45.30, 31.50], [45.40, 31.85]],
        "third dynasty of ur": [[43.60, 34.60], [45.20, 34.50], [46.80, 33.90], [48.40, 33.30], [48.60, 31.80], [47.80, 31.50], [46.60, 30.60], [45.60, 30.55], [44.80, 30.90], [43.90, 31.70], [43.20, 32.90], [43.20, 33.90]],
        "dynasty of isin": [[44.30, 32.80], [44.90, 32.80], [45.20, 32.60], [45.40, 32.20], [45.60, 31.90], [45.90, 31.70], [46.10, 31.40], [46.05, 31.10], [45.65, 30.95], [45.35, 31.10], [45.10, 31.45], [44.90, 31.85], [44.55, 32.10], [44.30, 32.50]],
        "gutian rule": [[44.60, 34.20], [45.40, 34.40], [46.40, 34.90], [47.20, 35.10], [47.80, 34.40], [47.30, 33.50], [46.40, 33.30], [45.60, 33.40], [44.90, 33.80]],
    ]

    /// Backfills `Era.boundaryGeoJSON` with the author-drawn territory polygon
    /// for every dynasty era, once. Additive + idempotent: closed, non-degenerate
    /// existing boundaries (user-drawn or edited) are never overwritten. Rings
    /// saved by the prototype draw tool were unclosed and could be degenerate
    /// (invisible slivers) — those are repaired back to the authored territory.
    /// The repair also covers *closed* slivers: a ring whose extent along either
    /// axis is below `sliverMinAxisDegrees` is a dot / thick line / test-draw,
    /// not a territory (the smallest authored ring spans 0.70 degrees), so it is
    /// restored to the authored polygon too.
    package static func ensureDynastyBoundaries(context: ModelContext) {
        guard !Self.dynastyBoundaryRings.isEmpty else { return }
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByNormalized: [String: Era] = Dictionary(
            eras.map { (Self.normalizedGroupName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var changed = false
        for (normalizedName, ring) in Self.dynastyBoundaryRings {
            guard let era = eraByNormalized[normalizedName],
                  let authored = Self.polygonGeoJSON(ring: ring) else { continue }
            if let existing = era.boundaryGeoJSON,
               let stored = Self.decodedRing(from: existing),
               stored.count >= 4,
               stored.first == stored.last,
               Self.ringAreaSq(stored) > 0.001,
               Self.ringMinAxisDegrees(stored) >= Self.sliverMinAxisDegrees {
                continue
            }
            era.boundaryGeoJSON = authored
            changed = true
        }
        if changed { try? context.save() }
    }

    package static let sliverMinAxisDegrees = 0.4

    /// The smallest bounding-box extent (degrees) across both axes. A closed
    /// ring whose min-axis is tiny is a degenerate dot/line, not a polygon.
    package static func ringMinAxisDegrees(_ ring: [[Double]]) -> Double {
        var minLon = Double.infinity, maxLon = -Double.infinity
        var minLat = Double.infinity, maxLat = -Double.infinity
        for point in ring {
            minLon = Swift.min(minLon, point[0])
            maxLon = Swift.max(maxLon, point[0])
            minLat = Swift.min(minLat, point[1])
            maxLat = Swift.max(maxLat, point[1])
        }
        return Swift.min(maxLon - minLon, maxLat - minLat)
    }

    package static func decodedRing(from json: String) -> [[Double]]? {
        guard let data = json.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["type"] as? String == "Polygon",
              let coordinates = object["coordinates"] as? [[[Double]]],
              let ring = coordinates.first else { return nil }
        return ring
    }

    package static func ringAreaSq(_ ring: [[Double]]) -> Double {
        guard ring.count >= 3 else { return 0 }
        var area = 0.0
        for i in 0..<ring.count {
            let p = ring[i]
            let q = ring[(i + 1) % ring.count]
            area += p[0] * q[1] - q[0] * p[1]
        }
        return abs(area) / 2
    }

    package static func polygonGeoJSON(ring: [[Double]]) -> String? {
        guard ring.count >= 3 else { return nil }
        let closed = ring + [ring[0]]
        let object: [String: Any] = ["type": "Polygon", "coordinates": [closed]]
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }

}

extension Migration {
}
