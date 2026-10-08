import Foundation
import SwiftData

extension Migration {
    /// Update era orderIndex values to match current seed data ordering.
    /// Fixes the pre/post flood split that shifted when new eras were inserted.
    package static func fixEraOrderIndices(context: ModelContext) {
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let newOrder: [String: Int] = [
            "Age of the First Gods": 0,
            "Creation": 1,
            "Creation of Mankind": 2,
            "Age of the Watchers": 3,
            "Antediluvian Period": 4,
            "Anunnaki on Earth": 5,
            "Antediluvian": 6,
            "SKL Antediluvian": 6,
            "The Great Flood": 7,
            "Post-Flood Kingdoms": 8,
            "Early Dynastic Period": 9,
            "First dynasty of Kish": 11,
            "First rulers of Uruk": 12,
            "First dynasty of Ur": 13,
            "Dynasty of Awan": 14,
            "Second dynasty of Kish": 15,
            "Dynasty of Hamazi": 16,
            "Second dynasty of Uruk": 17,
            "Second dynasty of Ur": 18,
            "Dynasty of Adab": 19,
            "Dynasty of Mari": 20,
            "Third dynasty of Kish": 21,
            "Dynasty of Akshak": 22,
            "Fourth dynasty of Kish": 23,
            "Third dynasty of Uruk": 24,
            "Dynasty of Akkad": 25,
            "Fourth dynasty of Uruk": 26,
            "Gutian rule": 27,
            "Fifth dynasty of Uruk": 28,
            "Third dynasty of Ur": 29,
            "Dynasty of Isin": 30,
            "First Dynasty of Babylon": 31,
            "Old Assyrian Period": 32,
            "Old Babylonian Period": 33,
            "Neo-Assyrian Period": 34,
            "Uruk Period": 35,
            "Jemdet Nasr Period": 36,
            "Mitanni": 37,
            "Karduniaš (Kassite Babylonia)": 38,
            "Middle Assyrian Period": 39,
            "Late Bronze Age Collapse": 40,
            "Neo-Babylonian Empire": 41,
            "Achaemenid Empire": 42,
            "Macedonian Empire": 43,
            "Seleucid Empire": 44,
            "Parthian Empire": 45,
            "Roman and Byzantine Mesopotamia": 46,
            "Sassanid Empire": 47,
            // Dynasties II-X of the Babylonian king list. Dynasty I is the
            // "First Dynasty of Babylon" entry above, which
            // `ensureFirstBabylonianDynasty` owns. These sit after the existing
            // post-SKL lane rather than interleaved into it: the lane above is not
            // in chronological order (Jemdet Nasr follows Old Babylonian), so
            // picking ten slots between 32 and 47 would have meant renumbering
            // eras the user already has to accommodate a list that does not fit
            // that scheme.
            "First Dynasty of the Sealand": 48,
            "Kassite Dynasty of Babylon": 49,
            "Second Dynasty of Isin": 50,
            "Second Dynasty of the Sealand": 51,
            "Bazi Dynasty": 52,
            "Elamite Dynasty": 53,
            "Second Dynasty of Babylon": 54,
            "Assyrian Dynasty of Babylon": 55,
            "Chaldean Dynasty": 56,
        ]
        var changed = false
        for era in eras {
            if let newOI = newOrder[era.name] {
                if era.orderIndex != newOI {
                    era.orderIndex = newOI
                    changed = true
                }
            } else if era.orderIndex >= 9 {
                // Unlisted post-flood era — shift by +1 to account for the inserted eras
                era.orderIndex = era.orderIndex + 1
                changed = true
            }
        }
        if changed { Commit.save(context, "fixEraOrderIndices") }
    }

    /// Establish the canonical pre-flood chronology. The eight SKL antediluvian kings
    /// carry their (mythological but canonical) reign lengths, so we anchor the epoch
    /// at the flood (−28,000 BCE) and back-propagate each reign to give every king a
    /// concrete span: the eight reigns sum to 241,200 years, so the epoch runs
    /// −269,200 → −28,000 BCE. The older mythological eras are ordered around it
    /// (Age of the First Gods → Creation → Creation of Mankind → Age of the Watchers →
    /// Antediluvian Period) and given sequential placeholder spans so every band on the
    /// pre-flood timeline shows a date. User-approved figure moves place the primordial
    /// gods in Age of the First Gods, the great gods in Creation, the archangels in Age
    /// of the Watchers, and Alulim + Dumuzi the Shepherd into the Antediluvian Period.
    /// Additive + idempotent; see docs/PRE-FLOOD-TIMELINE.md for the full reasoning.
    package static func ensureAntediluvianChronology(context: ModelContext) {
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByName = Dictionary(eras.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName = Dictionary(allFigures.map { (Self.seedNameKey($0.name), $0) }, uniquingKeysWith: { first, _ in first })
        var changed = false

        // 1. Era date bands — only corrected while they still hold the legacy seed
        //    values (or are undated), so a user's later manual edit is never clobbered.
        func applyEraDates(_ name: String, targetStart: Int, targetEnd: Int, legacyStart: Int?, legacyEnd: Int?) -> Bool {
            guard let era = eraByName[name] else { return false }
            let curStart = era.startDate.startYear
            let curEnd = era.endDate.endYear
            let isLegacy = (curStart == nil && curEnd == nil)
                || (legacyStart != nil && curStart == legacyStart && curEnd == legacyEnd)
            guard isLegacy else { return false }
            let newStart = MythologicalDate(startYear: targetStart, endYear: targetStart, era: name)
            let newEnd = MythologicalDate(startYear: targetEnd, endYear: targetEnd, era: name)
            guard era.startDate != newStart || era.endDate != newEnd else { return false }
            era.startDate = newStart
            era.endDate = newEnd
            return true
        }
        changed = applyEraDates("Age of the First Gods", targetStart: -450000, targetEnd: -300000, legacyStart: -450000, legacyEnd: -300000) || changed
        changed = applyEraDates("Creation", targetStart: -300000, targetEnd: -280000, legacyStart: nil, legacyEnd: nil) || changed
        changed = applyEraDates("Creation of Mankind", targetStart: -280000, targetEnd: -275000, legacyStart: -200000, legacyEnd: -100000) || changed
        changed = applyEraDates("Age of the Watchers", targetStart: -275000, targetEnd: -269200, legacyStart: nil, legacyEnd: nil) || changed
        changed = applyEraDates("Antediluvian Period", targetStart: -269200, targetEnd: -28000, legacyStart: -241200, legacyEnd: -28000) || changed
        changed = applyEraDates("The Great Flood", targetStart: -28000, targetEnd: -27000, legacyStart: -28000, legacyEnd: -27000) || changed

        // 2. Antediluvian king dates — computed by back-propagating each SKL reign
        //    from the flood anchor. Only written where no date exists yet.
        let kingReigns: [(name: String, birth: Int, death: Int)] = [
            ("Alulim", -269200, -240400),
            ("Alalngar", -240400, -204400),
            ("En-men-lu-ana", -204400, -161200),
            ("En-men-gal-ana", -161200, -132400),
            ("Dumuzi the Shepherd", -132400, -96400),
            ("En-sipad-zid-ana", -96400, -67600),
            ("En-men-dur-ana", -67600, -46600),
            ("Ubara-Tutu", -46600, -28000),
        ]
        for reign in kingReigns {
            guard let figure = figureByName[Self.seedNameKey(reign.name)],
                  figure.birthDate.startYear == nil else { continue }
            figure.birthDate = MythologicalDate(startYear: reign.birth, endYear: reign.birth, era: "Antediluvian Period")
            figure.deathDate = MythologicalDate(startYear: reign.death, endYear: reign.death, era: "Antediluvian Period")
            figure.dateSource = Figure.DateSource.computed.rawValue
            changed = true
        }

        // 3. User-approved figure reassignments. Each move only fires while the figure
        //    sits in the legacy (wrong) era, so a later user move is never overridden.
        func moveToEra(_ name: String, _ targetEraName: String, from legacyEraName: String?) {
            guard let target = eraByName[targetEraName],
                  let figure = figureByName[Self.seedNameKey(name)],
                  (legacyEraName == nil ? figure.era == nil : figure.era?.name == legacyEraName),
                  figure.era?.persistentModelID != target.persistentModelID else { return }
            figure.era = target
            figure.birthDate.era = targetEraName
            figure.deathDate.era = targetEraName
            changed = true
        }
        let primordialGods = ["Kishar", "Tiamat", "Apsu", "Nammu", "Anshar", "Anunnaki", "Igigi"]
        for name in primordialGods { moveToEra(name, "Age of the First Gods", from: "Creation") }
        let greatGods = ["An", "Enlil", "Enki", "Ninhursag", "Nanna", "Utu", "Inanna", "Marduk", "Nabu", "Nergal", "Ereshkigal", "Ningal", "Sarpanit", "Sud", "Antu", "Haia", "Ningikuga", "Ninurta", "Ninsun"]
        for name in greatGods { moveToEra(name, "Creation", from: "Age of the First Gods") }
        let archangels = ["Michael", "Gabriel", "Uriel", "Raphael", "Raguel", "Saraqael", "Remiel"]
        for name in archangels { moveToEra(name, "Age of the Watchers", from: "Creation") }
        moveToEra("Alulim", "Antediluvian Period", from: nil)
        moveToEra("Dumuzi the Shepherd", "Antediluvian Period", from: "Age of the First Gods")

        // 4. Antediluvian succession order — the SKL sequence is the authority
        //    (Ziusudra, the flood survivor, comes last).
        let antediluvianOrder: [(name: String, index: Int)] = [
            ("Alulim", 0), ("Alalngar", 1), ("En-men-lu-ana", 2), ("En-men-gal-ana", 3),
            ("Dumuzi the Shepherd", 4), ("En-sipad-zid-ana", 5), ("En-men-dur-ana", 6),
            ("Ubara-Tutu", 7), ("Ziusudra", 8),
        ]
        for entry in antediluvianOrder {
            guard let figure = figureByName[Self.seedNameKey(entry.name)],
                  figure.era?.name == "Antediluvian Period",
                  figure.orderIndex != entry.index else { continue }
            figure.orderIndex = entry.index
            changed = true
        }

        if changed { Commit.save(context, "ensureAntediluvianChronology") }
    }

    /// Fit a list of reign-duration shares into an absolute BCE window, returning a
    /// contiguous (start, end) slot per share. Each share keeps its proportional
    /// fraction of the window — the SKL's mythological multi-millennium reigns are
    /// thereby compressed onto a conventional archaeological span. Pure and testable.
    package static func fitLegendaryWindow(shares: [Int], earliestBCE: Int, latestBCE: Int) -> [(start: Int, end: Int)] {
        guard !shares.isEmpty else { return [] }
        let span = max(0, latestBCE - earliestBCE)
        let normalized = shares.map { max(1, $0) }
        let total = normalized.reduce(0, +)
        var out: [(start: Int, end: Int)] = []
        out.reserveCapacity(normalized.count)
        var cumulative = 0
        for (index, share) in normalized.enumerated() {
            cumulative += share
            let startFrac = Double(cumulative - share) / Double(total)
            let endFrac = Double(cumulative) / Double(total)
            var start = earliestBCE + Int((Double(span) * startFrac).rounded())
            var end = earliestBCE + Int((Double(span) * endFrac).rounded())
            if index == 0 { start = earliestBCE }
            if index == normalized.count - 1 { end = latestBCE }
            if end < start { end = start }
            out.append((start, end))
        }
        for index in 1..<out.count where out[index].start < out[index - 1].end {
            out[index].start = out[index - 1].end
        }
        return out
    }

    /// Date the ten legendary SKL dynasties (Kish I, Uruk I, Ur I, Awan, Kish II,
    /// Hamazi, Uruk II, Ur II, Adab, Kish III) that have territory but no dated
    /// kings, so they participate in the Dynasty Evolution playback. Each dynasty is
    /// pinned to a conventional archaeological window (~2900–2400 BCE, SKL order);
    /// `fitLegendaryWindow` compresses each dynasty's listed mythological reigns onto
    /// that window and writes per-king `birthDate`/`deathDate` (marked `.computed`).
    /// Additive + idempotent: an era is only (re-)fitted while it is deemed derived
    /// data — either NO king carries a date yet (first fit), or every king's dates
    /// are `.computed` (safe to re-derive after a seed/order correction). Any
    /// hand-entered (`historical`) date blocks the fit forever, so a user's
    /// hand-entered dates are never clobbered. Reign columns ride along so the
    /// `reignOutsideLifespan` check never sees a reign span that disagrees with the
    /// fitted lifetime.
    package static func ensureLegendaryDynastyWindows(context: ModelContext) {
        let windows: [String: (earliest: Int, latest: Int)] = [
            "First dynasty of Kish": (-2900, -2550),
            "First rulers of Uruk": (-2700, -2550),
            "First dynasty of Ur": (-2560, -2430),
            "Dynasty of Awan": (-2550, -2470),
            "Second dynasty of Kish": (-2500, -2430),
            "Dynasty of Hamazi": (-2470, -2410),
            "Second dynasty of Uruk": (-2450, -2400),
            "Second dynasty of Ur": (-2430, -2395),
            "Dynasty of Adab": (-2410, -2394),
            "Third dynasty of Kish": (-2400, -2393),
        ]
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for (eraName, window) in windows {
            let kings = allFigures
                .filter { $0.source.contains("Sumerian King List") && $0.birthDate.era == eraName }
                .sorted { $0.orderIndex < $1.orderIndex }
            guard !kings.isEmpty else { continue }
            guard Self.legendaryEraReadyForFit(kings) else { continue }
            let shares = kings.map { $0.kingship?.effectiveReignYears ?? 1 }
            let fitted = fitLegendaryWindow(shares: shares, earliestBCE: window.earliest, latestBCE: window.latest)
            for (king, slot) in zip(kings, fitted) {
                king.birthDate = MythologicalDate(startYear: slot.start, era: eraName, isApproximate: true)
                king.deathDate = MythologicalDate(startYear: slot.end, era: eraName, isApproximate: true)
                king.dateSource = Figure.DateSource.computed.rawValue
                king.updateKingship(reignStartYear: slot.start, reignEndYear: slot.end, reignYears: king.reignYears)
            }
            changed = true
        }
        if changed { Commit.save(context, "ensureLegendaryDynastyWindows") }
    }

    /// True when a legendary dynasty is fit-eligible: undated (first fit) or fully
    /// `.computed` (re-fit after a seed/order correction). A single hand-entered date
    /// (`historical`/nil source) blocks the whole era.
    package static func legendaryEraReadyForFit(_ kings: [Figure]) -> Bool {
        guard !kings.isEmpty else { return false }
        let anyDated = kings.contains { $0.birthDate.startYear != nil }
        if !anyDated { return true }
        return kings.allSatisfy { $0.dateSource == Figure.DateSource.computed.rawValue }
    }

    /// Remove all auto-generated "Missing father/mother — look up on Wikipedia" stickies.
    package static func removeAutoGeneratedStickies(context: ModelContext) {
        let allStickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        let toDelete = allStickies.filter { $0.text.hasPrefix("Missing ") }
        guard !toDelete.isEmpty else { return }
        for sticky in toDelete {
            context.delete(sticky)
        }
        Commit.save(context, "removeAutoGeneratedStickies")
    }

    /// Backfill BCE anchor dates for SKL figures that lack them.
    /// Reads from seed_data.json and adds `c. XXXX–XXXX BC` date ranges to
    /// one strategic figure per dynasty. The SKLDatePropagator then fills in
    /// dates for all other figures in the same dynasty via reign-length propagation.
    package static func ensureSKLAnchorDates(context: ModelContext) {
        let url: URL? = {
            if let u = Bundle.module.url(forResource: "seed_data", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "seed_data", withExtension: "json")
        }()
        guard let u = url, let data = try? Data(contentsOf: u),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let bcRegex = try! NSRegularExpression(pattern: "c\\.\\s*\\d{3,4}[–-]\\d{3,4}\\s*BC")
        let centuryRegex = try! NSRegularExpression(pattern: "c\\.\\s*\\d{1,2}(st|nd|rd|th)\\s+century\\s+BC")

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []

        for seedFig in root.figures {
            guard seedFig.source.contains("Sumerian King List") else { continue }
            let seedDesc = seedFig.figureDescription
            guard bcRegex.firstMatch(in: seedDesc, range: NSRange(seedDesc.startIndex..., in: seedDesc)) != nil else { continue }

            guard let dbFig = allFigures.first(where: { Self.seedNameKey($0.name) == Self.seedNameKey(seedFig.name) }) else { continue }
            let dbDesc = dbFig.figureDescription
            guard bcRegex.firstMatch(in: dbDesc, range: NSRange(dbDesc.startIndex..., in: dbDesc)) == nil else { continue }

            var updated = dbDesc
            if let centuryMatch = centuryRegex.firstMatch(in: updated, range: NSRange(updated.startIndex..., in: updated)) {
                guard let r = Range(centuryMatch.range, in: updated) else { continue }
                updated.removeSubrange(r)
                updated = updated.trimmingCharacters(in: .whitespaces)
            }

            guard let bcMatch = bcRegex.firstMatch(in: seedDesc, range: NSRange(seedDesc.startIndex..., in: seedDesc)),
                  let r = Range(bcMatch.range, in: seedDesc) else { continue }
            let bcStr = String(seedDesc[r])
            if bcStr.isEmpty { continue }

            if !updated.isEmpty && !updated.hasSuffix(".") && !updated.hasSuffix(" ") { updated += " " }
            updated += bcStr
            if !updated.hasSuffix(".") { updated += "." }

            dbFig.figureDescription = updated
        }
        Commit.save(context, "ensureSKLAnchorDates")
    }

    /// Backfill `Era.startDate`/`endDate` from seed_data.json for eras whose
    /// dates are still unknown. The seed has carried per-dynasty date ranges
    /// since the live DB was first seeded, so older stores have NULL era dates
    /// — which left undated dynasties (e.g. Second dynasty of Kish) floating in
    /// the timeline's estimation window instead of their proper chronological
    /// slot. Additive and idempotent: only fills eras with no known start year,
    /// never overwrites user-entered dates.
    package static func ensureEraDatesFromSeed(context: ModelContext) {
        let url: URL? = {
            if let u = Bundle.module.url(forResource: "seed_data", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "seed_data", withExtension: "json")
        }()
        guard let u = url, let data = try? Data(contentsOf: u),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let allEras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        var changed = false
        for seedEra in root.eras {
            guard seedEra.startDate.startYear != nil else { continue }
            guard let era = allEras.first(where: { $0.name == seedEra.name }) else { continue }
            guard era.startDate.startYear == nil else { continue }
            era.startDate = seedEra.startDate.toMythologicalDate()
            era.endDate = seedEra.endDate.toMythologicalDate()
            changed = true
        }
        if changed { Commit.save(context, "ensureEraDatesFromSeed") }
    }

    package static let listedReignRegex = try! NSRegularExpression(pattern: "\\(Listed reign:\\s*[\\d,]+\\s+years\\.\\)")

    package static func ensureSKLGutianReignLengths(context: ModelContext) {
        let url: URL? = {
            if let u = Bundle.module.url(forResource: "seed_data", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "seed_data", withExtension: "json")
        }()
        guard let u = url, let data = try? Data(contentsOf: u),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for seedFig in root.figures {
            guard seedFig.source.contains("Sumerian King List"),
                  seedFig.birthDate.era == "Gutian rule" else { continue }
            let seedDesc = seedFig.figureDescription
            guard listedReignRegex.firstMatch(in: seedDesc, range: NSRange(seedDesc.startIndex..., in: seedDesc)) != nil else { continue }
            guard let dbFig = allFigures.first(where: { Self.seedNameKey($0.name) == Self.seedNameKey(seedFig.name) && $0.birthDate.era == seedFig.birthDate.era }) else { continue }
            guard listedReignRegex.firstMatch(in: dbFig.figureDescription, range: NSRange(dbFig.figureDescription.startIndex..., in: dbFig.figureDescription)) == nil else { continue }
            if let suffixRange = seedDesc.range(of: "(Listed reign:") {
                let suffix = String(seedDesc[suffixRange.lowerBound...]).trimmingCharacters(in: .whitespaces)
                var updated = dbFig.figureDescription
                if !updated.hasSuffix(".") { updated += "." }
                updated += " " + suffix
                dbFig.figureDescription = updated
                changed = true
            }
        }
        if changed { Commit.save(context, "ensureSKLGutianReignLengths") }
    }

    /// Backfill citations for events that lack them.
    /// Matches event.source free-text to known Source entities by substring.
    package static func ensureEventCitations(context: ModelContext) {
        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let sourceByKeyword: [(keyword: String, source: Source)] = allSources.compactMap { s in
            let keywords: [String] = [
                "Sumerian King List", "Epic of Gilgamesh", "Enuma Elish",
                "Atra-Hasis", "Inanna's Descent", "Etana Myth",
                "Book of Enoch (1 Enoch)", "Book of Jubilees"
            ]
            guard let match = keywords.first(where: { s.name.contains($0) }) else { return nil }
            return (keyword: match, source: s)
        }

        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let allCits = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        let hasCit: (Event) -> Bool = { event in
            allCits.contains(where: { $0.safeEntityName == event.name && $0.safeEntityType == .event })
        }

        for event in allEvents where !hasCit(event) {
            let src = sourceByKeyword.first(where: { event.source.contains($0.keyword) })?.source
            ?? allSources.first(where: { $0.name == "ETCSL (Electronic Text Corpus of Sumerian Literature)" })

            let cit = Citation(
                source: src,
                location: event.source,
                note: event.eventDescription,
                entityType: .event,
                linkedEntityName: event.name
            )
            context.insert(cit)
        }
        Commit.save(context, "ensureEventCitations")
    }

}
