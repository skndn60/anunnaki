import Foundation
import SwiftData

extension Migration {
    /// Reign-length variants documented in the seed prose that the single-valued
    /// reign columns cannot express. Each entry keys on the canonical figure's
    /// (normalized) name; a variant row is only created if the figure has no
    /// existing row with the same years + tradition. Purely additive and
    /// idempotent — safe to run on every launch.
    package static func ensureReignVersionBackfill(context: ModelContext) {
        let configs: [(figureName: String, years: Int, tradition: String, note: String)] = [
            ("Kullassina-bel", 900, "Some copies of the Sumerian King List",
             "The SKL's own listed figure is 960 years."),
            ("Etana", 635, "Some copies of the Sumerian King List",
             "The SKL's own listed figure is 1,500 years."),
            ("Bur-Suen", 22, "Ur-Isin king list",
             "The Sumerian King List gives 21 years."),
            ("Iter-pisha", 3, "Ur-Isin king list",
             "The Sumerian King List gives 4 years."),
            ("Ur-du-kuga", 3, "Ur-Isin kinglist",
             "The Sumerian King List gives 4 years."),
        ]
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var createdAny = false
        for config in configs {
            guard let figure = figures.first(where: { DuplicateMerger.normalizationKey($0.name) == DuplicateMerger.normalizationKey(config.figureName) }) else { continue }
            let alreadyBackfilled = figure.reignVersions.contains {
                $0.years == config.years && $0.tradition == config.tradition
            }
            guard !alreadyBackfilled else { continue }
            let version = ReignVersion(years: config.years, tradition: config.tradition, note: config.note)
            figure.reignVersions.append(version)
            context.insert(version)
            createdAny = true
        }
        if createdAny { try? context.save() }
    }
}