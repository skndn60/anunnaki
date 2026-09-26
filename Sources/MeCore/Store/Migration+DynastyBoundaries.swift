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

    /// Author-era territory polygons (lon, lat), keyed by normalized era name.
    /// Covers the SKL dynasty eras plus the later historical eras (Old Assyrian,
    /// Neo-Assyrian, Achaemenid, Roman Mesopotamia…) that were imported with the
    /// wider era set. Open rings; closed at serialization. Drawn once when
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
        "first dynasty of babylon": [[44.05, 33.45], [44.95, 33.55], [45.80, 33.35], [46.35, 32.85], [46.55, 32.10], [46.45, 31.25], [46.15, 30.55], [45.35, 30.30], [44.55, 30.45], [43.95, 30.95], [43.65, 31.70], [43.70, 32.60]],
        "gutian rule": [[44.60, 34.20], [45.40, 34.40], [46.40, 34.90], [47.20, 35.10], [47.80, 34.40], [47.30, 33.50], [46.40, 33.30], [45.60, 33.40], [44.90, 33.80]],
        "old assyrian period": [[41.50, 34.80], [42.50, 34.90], [43.50, 35.10], [44.30, 35.30], [44.90, 35.50], [45.20, 35.90], [45.00, 36.40], [44.40, 36.70], [43.60, 36.80], [42.70, 36.60], [42.00, 36.30], [41.50, 35.90], [41.40, 35.30]],
        "old babylonian period": [[40.40, 34.60], [42.00, 34.90], [43.50, 34.90], [45.00, 34.70], [46.50, 34.30], [47.50, 33.60], [48.00, 32.60], [48.10, 31.60], [47.70, 30.70], [47.00, 29.90], [46.10, 29.60], [45.20, 29.60], [44.30, 29.80], [43.40, 30.20], [42.50, 30.80], [41.70, 31.50], [41.00, 32.30], [40.40, 33.20], [40.10, 34.00]],
        "neo-assyrian period": [[34.80, 36.80], [36.00, 37.20], [37.50, 37.50], [39.00, 37.70], [40.50, 37.70], [42.00, 37.60], [43.50, 37.50], [45.00, 37.30], [46.50, 36.90], [47.80, 36.30], [48.80, 35.60], [49.40, 34.80], [49.70, 33.90], [49.70, 33.00], [49.40, 32.10], [48.80, 31.30], [48.00, 30.80], [47.00, 30.30], [46.00, 30.00], [45.00, 29.90], [44.00, 30.10], [43.00, 30.50], [42.10, 31.10], [41.20, 31.80], [40.30, 32.50], [39.40, 33.20], [38.40, 33.80], [37.40, 34.20], [36.40, 34.60], [35.50, 35.20], [34.80, 35.90]],
        "uruk period": [[44.80, 32.30], [45.60, 32.50], [46.50, 32.50], [47.20, 32.20], [47.70, 31.70], [47.90, 31.10], [47.80, 30.50], [47.30, 30.00], [46.60, 29.80], [45.90, 29.80], [45.20, 30.00], [44.80, 30.40], [44.60, 31.00], [44.60, 31.60], [44.70, 32.00]],
        "jemdet nasr period": [[43.90, 32.80], [44.60, 32.90], [45.30, 32.80], [45.90, 32.50], [46.20, 32.00], [46.20, 31.50], [45.90, 31.10], [45.30, 31.00], [44.60, 31.10], [44.10, 31.50], [43.80, 32.10]],
        "mitanni": [[37.20, 36.50], [38.30, 36.70], [39.40, 36.90], [40.40, 37.00], [41.50, 36.90], [42.50, 36.80], [43.50, 36.70], [44.20, 36.30], [44.40, 35.70], [44.00, 35.10], [43.10, 34.70], [42.00, 34.50], [41.00, 34.50], [40.00, 34.70], [39.10, 35.00], [38.20, 35.50], [37.60, 36.00]],
        "karduniaš (kassite babylonia)": [[42.50, 34.20], [43.60, 34.40], [44.80, 34.40], [45.80, 34.10], [46.60, 33.60], [47.20, 33.00], [47.50, 32.20], [47.60, 31.30], [47.20, 30.60], [46.50, 30.00], [45.60, 29.70], [44.70, 29.70], [43.80, 30.00], [43.00, 30.50], [42.30, 31.20], [41.90, 32.00], [41.90, 32.80], [42.10, 33.50]],
        "middle assyrian period": [[40.30, 35.30], [41.60, 35.20], [42.60, 35.25], [43.40, 35.15], [44.30, 35.30], [45.00, 35.60], [45.40, 36.10], [45.50, 36.70], [45.20, 37.30], [44.60, 37.70], [43.90, 37.90], [43.00, 37.80], [42.10, 37.60], [41.30, 37.20], [40.70, 36.70], [40.30, 36.00]],
        "late bronze age collapse": [[31.50, 36.50], [33.00, 37.20], [35.00, 37.80], [37.50, 38.20], [40.00, 38.40], [42.50, 38.30], [45.00, 37.90], [47.00, 37.20], [48.50, 36.30], [49.20, 35.30], [49.30, 34.30], [49.00, 33.30], [48.30, 32.50], [47.40, 31.90], [46.50, 31.60], [45.50, 31.50], [44.60, 31.60], [43.80, 32.00], [42.90, 32.50], [41.90, 33.00], [40.90, 33.40], [39.60, 33.60], [38.50, 33.70], [37.50, 33.70], [36.40, 33.60], [35.30, 33.40], [34.40, 33.20], [33.50, 33.10], [32.70, 33.30], [32.10, 33.80], [31.70, 34.50], [31.40, 35.40]],
        "neo-babylonian empire": [[35.00, 33.60], [36.20, 34.00], [37.50, 34.30], [38.50, 34.50], [39.50, 34.60], [40.60, 34.70], [41.70, 34.70], [42.80, 34.60], [43.90, 34.40], [45.00, 34.10], [46.00, 33.60], [46.80, 33.00], [47.30, 32.20], [47.60, 31.30], [47.50, 30.40], [47.00, 29.80], [46.10, 29.50], [45.20, 29.50], [44.30, 29.80], [43.40, 30.20], [42.50, 30.80], [41.60, 31.50], [40.80, 32.30], [39.90, 33.00], [38.90, 33.40], [37.90, 33.60], [36.90, 33.70]],
        "achaemenid empire": [[34.00, 37.30], [36.00, 38.00], [38.00, 38.60], [40.00, 39.00], [42.00, 39.20], [44.00, 39.10], [46.00, 38.80], [48.00, 38.30], [50.00, 37.70], [52.00, 37.00], [53.50, 36.20], [55.00, 35.30], [56.00, 34.30], [56.50, 33.20], [56.40, 32.10], [55.80, 31.00], [55.00, 30.20], [54.00, 29.60], [52.90, 29.20], [51.80, 28.80], [50.70, 28.60], [49.60, 28.50], [48.50, 28.60], [47.40, 28.90], [46.30, 29.20], [45.20, 29.60], [44.20, 30.00], [43.20, 30.50], [42.20, 31.10], [41.20, 31.80], [40.20, 32.50], [39.20, 33.20], [38.10, 33.80], [37.00, 34.20], [35.90, 34.70], [34.80, 35.40], [34.10, 36.20]],
        "macedonian empire": [[35.00, 37.60], [37.00, 38.30], [39.00, 38.80], [41.00, 39.10], [43.00, 39.20], [45.00, 39.00], [47.00, 38.60], [49.00, 38.10], [51.00, 37.40], [52.80, 36.60], [54.30, 35.80], [55.50, 34.90], [56.20, 33.90], [56.40, 32.80], [56.00, 31.70], [55.20, 30.80], [54.10, 30.10], [53.00, 29.60], [51.90, 29.20], [50.80, 29.00], [49.70, 28.90], [48.60, 29.00], [47.50, 29.30], [46.40, 29.70], [45.30, 30.10], [44.30, 30.60], [43.40, 31.20], [42.40, 31.90], [41.50, 32.60], [40.60, 33.30], [39.60, 34.00], [38.60, 34.60], [37.50, 35.00], [36.40, 35.40], [35.50, 35.90], [34.90, 36.60], [34.80, 37.20]],
        "seleucid empire": [[35.50, 37.00], [37.00, 37.50], [39.00, 37.90], [41.00, 38.00], [43.00, 37.90], [45.00, 37.60], [47.00, 37.10], [49.00, 36.40], [50.80, 35.60], [52.20, 34.80], [53.30, 33.90], [53.90, 32.90], [53.90, 31.90], [53.30, 30.90], [52.30, 30.20], [51.20, 29.70], [50.10, 29.40], [49.00, 29.30], [47.90, 29.30], [46.80, 29.50], [45.70, 29.90], [44.60, 30.40], [43.60, 30.90], [42.60, 31.50], [41.60, 32.10], [40.60, 32.80], [39.60, 33.40], [38.60, 34.00], [37.60, 34.50], [36.60, 34.90], [36.60, 36.00]],
        "parthian empire": [[40.20, 35.20], [41.60, 35.70], [43.20, 36.00], [44.80, 36.10], [46.40, 36.00], [48.00, 35.70], [49.60, 35.30], [51.00, 34.80], [52.30, 34.20], [53.50, 33.50], [54.40, 32.60], [54.90, 31.70], [54.90, 30.70], [54.30, 29.80], [53.30, 29.10], [52.10, 28.60], [50.90, 28.30], [49.70, 28.30], [48.50, 28.50], [47.40, 28.90], [46.30, 29.40], [45.20, 30.00], [44.20, 30.60], [43.20, 31.30], [42.30, 32.10], [41.60, 33.00], [41.10, 34.00], [40.60, 34.60]],
        "roman and byzantine mesopotamia": [[38.30, 36.30], [39.30, 36.70], [40.30, 37.05], [41.30, 37.25], [42.30, 37.20], [43.20, 37.10], [43.90, 36.60], [44.10, 35.60], [43.90, 35.00], [43.10, 34.60], [42.10, 34.40], [41.10, 34.50], [40.10, 34.70], [39.40, 35.10], [38.80, 35.70]],
        "sassanid empire": [[39.50, 35.30], [41.00, 35.80], [42.60, 36.10], [44.30, 36.20], [46.00, 36.00], [47.60, 35.60], [49.20, 35.10], [50.60, 34.50], [51.90, 33.90], [53.10, 33.20], [54.10, 32.30], [54.70, 31.30], [54.80, 30.30], [54.30, 29.40], [53.30, 28.70], [52.00, 28.20], [50.70, 28.00], [49.40, 28.00], [48.20, 28.30], [47.00, 28.70], [45.90, 29.20], [44.80, 29.70], [43.80, 30.30], [42.90, 31.00], [42.10, 31.80], [41.40, 32.70], [40.80, 33.60], [40.30, 34.50]],
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

    /// The canonical list of auto-generated territory `Place` records retired by
    /// `removeEraTerritoryPlaces`: display name and era anchor for each non-SKL
    /// historical era, keyed by the same normalized era name as
    /// `dynastyBoundaryRings`. These era-shadows were created by the retired
    /// `ensureEraTerritoryPlaces` migration and simply double-drew a ring that the
    /// era itself already carries on `Era.boundaryGeoJSON`.
    package static let eraTerritoryPlaces: [String: (name: String, placeType: String, latitude: Double, longitude: Double, modernLocation: String)] = [
        "old assyrian period": ("Old Assyrian Kingdom", "Kingdom", 35.4566, 43.2607, "Assur on the upper Tigris, north-central Iraq"),
        "old babylonian period": ("Old Babylonian Kingdom", "Kingdom", 32.536, 44.421, "Central Mesopotamia around Babylon, Iraq"),
        "neo-assyrian period": ("Neo-Assyrian Empire", "Kingdom", 36.359, 43.153, "Northern Mesopotamia around Nineveh, northern Iraq"),
        "uruk period": ("Uruk Period", "Region", 31.322, 45.637, "Southern Mesopotamia around Uruk, Iraq"),
        "jemdet nasr period": ("Jemdet Nasr Period", "Region", 32.55, 44.639, "Central Mesopotamia around Kish, Iraq"),
        "mitanni": ("Mitanni", "Kingdom", 36.83, 40.04, "Northern Mesopotamia on the Khabur, northern Syria"),
        "karduniaš (kassite babylonia)": ("Karduniaš", "Kingdom", 32.536, 44.421, "Central Mesopotamia, Babylon-centered Kassite Babylonia, Iraq"),
        "middle assyrian period": ("Middle Assyrian Kingdom", "Kingdom", 35.4566, 43.2607, "Upper Tigris around Assur, northern Iraq"),
        "late bronze age collapse": ("Late Bronze Age Collapse", "Region", 36.5, 36.0, "Eastern Mediterranean littoral and the Near East collapse zone"),
        "neo-babylonian empire": ("Neo-Babylonian Empire", "Kingdom", 32.536, 44.421, "Central Mesopotamia around Babylon, Iraq"),
        "achaemenid empire": ("Achaemenid Empire", "Kingdom", 32.19, 48.24, "Iranian plateau and Mesopotamia, Iran–Iraq"),
        "macedonian empire": ("Macedonian Empire", "Kingdom", 32.536, 44.421, "From the Aegean across Mesopotamia to the Iranian plateau"),
        "seleucid empire": ("Seleucid Empire", "Kingdom", 33.09, 44.58, "Seleucia-on-the-Tigris region, Syria and Mesopotamia"),
        "parthian empire": ("Parthian Empire", "Kingdom", 33.09, 44.58, "Ctesiphon on the Tigris, Iran and Mesopotamia"),
        "roman and byzantine mesopotamia": ("Roman Mesopotamia", "Region", 37.91, 40.24, "Northern Mesopotamia between the Euphrates and Tigris, south-eastern Turkey"),
        "sassanid empire": ("Sassanid Empire", "Kingdom", 33.09, 44.58, "Ctesiphon on the Tigris, Mesopotamia and the Iranian plateau"),
    ]

    /// Removes the auto-generated territory `Place` records created by the retired
    /// `ensureEraTerritoryPlaces` migration ("Old Assyrian Kingdom", "Mitanni",
    /// "Karduniaš", "Late Bronze Age Collapse", …). The eras keep their authored
    /// rings on `Era.boundaryGeoJSON` — that is what the dynasty maps and the
    /// atlas's Dynasties layer draw — so the mirrored Place records only doubled
    /// the same polygons and polluted the Places list with era-shadows.
    /// Additive + idempotent by signature: only records whose name matches a
    /// retired artifact AND whose description has the migration's exact
    /// "<era name> territory" shape are deleted, so a user-authored place that
    /// happens to share a name is never touched.
    package static func removeEraTerritoryPlaces(context: ModelContext) {
        guard !Self.eraTerritoryPlaces.isEmpty else { return }
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByNormalized: [String: Era] = Dictionary(
            eras.map { (Self.normalizedGroupName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        var changed = false
        for (eraKey, seed) in Self.eraTerritoryPlaces {
            guard let era = eraByNormalized[eraKey] else { continue }
            let signature = "\(era.name) territory"
            for place in places
            where place.name == seed.name && place.placeDescription == signature {
                context.delete(place)
                changed = true
            }
        }
        if changed { try? context.save() }
    }

}

extension Migration {
}
