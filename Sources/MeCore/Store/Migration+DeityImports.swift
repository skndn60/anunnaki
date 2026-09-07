import Foundation
import SwiftData

extension Migration {
    /// Import deities from deities_import.json that don't already exist in the database.
    package static func ensureDeitiesImportExist(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { DuplicateMerger.normalizationKey($0.name) } ?? [])
        let targetNames: Set<String> = [
            "Ishkur", "Uraš", "Zababa", "Ninazu", "Ningishzida",
            "Gugalanna", "Birtu", "Kulla", "Mushdamma", "Hendursaga",
            "Isimud", "Papsukkal", "Lugal-Marada", "Numushda", "Shara",
            "Pabilsag", "Lulal", "Enkimdu", "Ninshubur",
        ]
        let targetNamesLower = Set(targetNames.map { DuplicateMerger.normalizationKey($0) })
        guard targetNamesLower.intersection(existingNames).count != targetNamesLower.count else { return }

        let url: URL? = {
            if let u = Bundle.module.url(forResource: "deities_import", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "deities_import", withExtension: "json")
        }()
        guard let u = url,
              let data = try? Data(contentsOf: u),
               let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            return
        }

        let rootExistingNames = Set(root.figures.map { DuplicateMerger.normalizationKey($0.name) })
        guard rootExistingNames.isSubset(of: targetNamesLower) else {
            return
        }

        let toImport = root.figures.filter { !existingNames.contains(DuplicateMerger.normalizationKey($0.name)) }
        guard !toImport.isEmpty else { return }

        let importedIds = Set(toImport.map(\.id))
        var filteredRoot = root
        filteredRoot.figures = toImport
        filteredRoot.alternateNames = root.alternateNames.filter { importedIds.contains($0.figureId ?? "") }
        filteredRoot.figurePlaceAssociations = root.figurePlaceAssociations?.filter { importedIds.contains($0.figureId) }

        SeedData.importFrom(root: filteredRoot, context: context)
    }

    /// Import deities from missing_deities_import.json.
    /// Uses figureName (not figureId) for alternate names — resolves at import time.
    /// Each imported figure gets a sticky note "FROM 26-08-2026 IMPORT".
    /// Additive + idempotent.
    package static func ensureMissingDeitiesImportExist(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { DuplicateMerger.normalizationKey($0.name) } ?? [])

        let url: URL? = {
            if let u = Bundle.module.url(forResource: "missing_deities_import", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "missing_deities_import", withExtension: "json")
        }()
        guard let url,
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            return
        }

        let toImport = root.figures.filter { !existingNames.contains(DuplicateMerger.normalizationKey($0.name)) }
        guard !toImport.isEmpty else { return }

        // Import figures via SeedData.importFrom (filters alt names by figureId)
        let importedIds = Set(toImport.map(\.id))
        var filteredRoot = root
        filteredRoot.figures = toImport
        filteredRoot.alternateNames = root.alternateNames.filter { importedIds.contains($0.figureId ?? "") }
        SeedData.importFrom(root: filteredRoot, context: context)

        // Add sticky notes to all newly imported figures
        let stickyPrefix = "FROM 26-08-2026 IMPORT"
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let importedNames = Set(toImport.map { DuplicateMerger.normalizationKey($0.name) })
        for figure in allFigures where importedNames.contains(DuplicateMerger.normalizationKey(figure.name)) {
            let alreadyHas = figure.stickies.contains { $0.text.hasPrefix(stickyPrefix) }
            guard !alreadyHas else { continue }
            context.insert(StickyNote(text: stickyPrefix, figure: figure))
        }
        try? context.save()
    }

    /// Import the broad attested Mesopotamian pantheon from
    /// mesopotamian_deities_import.json (129 gods across Sumerian,
    /// Akkadian, Hurrian, Elamite and Kassite traditions). Additive +
    /// idempotent: only names absent from the store are inserted.
    package static func ensureMesopotamianDeitiesImportExist(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { DuplicateMerger.normalizationKey($0.name) } ?? [])

        let url: URL? = {
            if let u = Bundle.module.url(forResource: "mesopotamian_deities_import", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "mesopotamian_deities_import", withExtension: "json")
        }()
        guard let url,
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            return
        }

        let toImport = root.figures.filter { !existingNames.contains(DuplicateMerger.normalizationKey($0.name)) }
        guard !toImport.isEmpty else { return }

        var filteredRoot = root
        filteredRoot.figures = toImport
        SeedData.importFrom(root: filteredRoot, context: context)
        try? context.save()
    }

    /// Import curated alternate names (bynames, cross-language equivalents,
    /// epithets, syncretisms and hypostases) from alt_names_import.json.
    /// Keyed by exact figure name; additive + idempotent per (figure, name, tradition).
    package static func ensureAlternateNamesImportExist(context: ModelContext) {
        struct AltRow: Decodable {
            let name: String
            let tradition: String
            let nameType: String
            let note: String
        }
        struct AltNameEntry: Decodable {
            let figure: String
            let alternates: [AltRow]
        }

        let url: URL? = {
            if let u = Bundle.module.url(forResource: "alt_names_import", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "alt_names_import", withExtension: "json")
        }()
        guard let url,
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([AltNameEntry].self, from: data) else {
            return
        }

        let figuresByName = Dictionary(uniqueKeysWithValues:
            ((try? context.fetch(FetchDescriptor<Figure>())) ?? []).map { ($0.name, $0) })
        let existing = Set(((try? context.fetch(FetchDescriptor<AlternateName>())) ?? []).compactMap { alt -> String? in
            guard let fig = alt.figure else { return nil }
            return "\(fig.name.lowercased())|\(alt.name.lowercased())|\(alt.tradition.rawValue.lowercased())"
        })

        var added = 0
        for entry in entries {
            guard let figure = figuresByName[entry.figure] else { continue }
            for row in entry.alternates {
                let key = "\(figure.name.lowercased())|\(row.name.lowercased())|\(row.tradition.lowercased())"
                guard !existing.contains(key),
                      let tradition = AlternateName.Tradition(rawValue: row.tradition),
                      let nameType = AlternateName.NameType(rawValue: row.nameType) else { continue }
                context.insert(AlternateName(figure: figure, name: row.name, tradition: tradition, nameType: nameType, note: row.note))
                added += 1
            }
        }
        guard added > 0 else { return }
        try? context.save()
    }

    /// Removes the legacy orphaned alternate-name pair created before the
    /// Kittum/Niĝgina mapping was expressed as a linked AlternateName. These two
    /// rows have neither a figure nor a place link and trip the orphaned-alternate-
    /// name integrity check. Targeted by (name, unlinked) so no other rows are touched.
    package static func removeOrphanedKittumNigginaAltNames(context: ModelContext) {
        let names = ["Niĝgina", "Kittum"].map { $0.lowercased() }
        let orphans = ((try? context.fetch(FetchDescriptor<AlternateName>())) ?? [])
            .filter { $0.figure == nil && $0.place == nil && names.contains($0.name.lowercased()) }
        guard !orphans.isEmpty else { return }
        for orphan in orphans { context.delete(orphan) }
        try? context.save()
    }

}
