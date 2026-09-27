import Foundation
import SwiftData

extension Migration {
    /// Descriptor for one Amorite ruler of Babylon's first dynasty, with the
    /// Middle Chronology regnal span used for the figure's kingship columns.
    package struct FirstBabylonianRuler {
        package let name: String
        package let startYear: Int
        package let endYear: Int
        package let note: String
    }

    /// Canonical sequence of the eleven rulers attested by the Babylonian King
    /// List A (column 1). Spans follow the Middle Chronology and are
    /// approximate; the list itself gives succession, not absolute dates.
    package static let firstBabylonianRulers: [FirstBabylonianRuler] = [
        .init(name: "Sumu-abum", startYear: -1894, endYear: -1881, note: "Founder of the dynasty; first Amorite king of Babylon."),
        .init(name: "Sumu-la-El", startYear: -1880, endYear: -1845, note: "Second king of the dynasty."),
        .init(name: "Sabium", startYear: -1844, endYear: -1831, note: "Third king of the dynasty."),
        .init(name: "Apil-Sin", startYear: -1830, endYear: -1813, note: "Fourth king of the dynasty."),
        .init(name: "Sin-Muballit", startYear: -1812, endYear: -1793, note: "Fifth king of the dynasty; father of Hammurabi."),
        .init(name: "Hammurabi", startYear: -1792, endYear: -1750, note: "Sixth king of the dynasty; promulgator of the Code of Hammurabi."),
        .init(name: "Samsu-iluna", startYear: -1749, endYear: -1712, note: "Son and successor of Hammurabi."),
        .init(name: "Abi-Eshuh", startYear: -1711, endYear: -1684, note: "Eighth king of the dynasty."),
        .init(name: "Ammi-ditana", startYear: -1683, endYear: -1647, note: "Ninth king of the dynasty."),
        .init(name: "Ammisaduqa", startYear: -1646, endYear: -1626, note: "Tenth king of the dynasty; his reign is the subject of a famous omen text."),
        .init(name: "Samsu-ditana", startYear: -1625, endYear: -1595, note: "Eleventh and last king; Babylon was sacked by the Hittite king Mursili I in his reign."),
    ]

    package static let firstBabylonianEraName = "First Dynasty of Babylon"

    /// Creates the First Dynasty of Babylon as first-class data: a dynasty
    /// `Era` in the post-SKL ruling lane, the eleven BKL rulers as figures
    /// linked to that era, the father-to-son succession attested by the king
    /// list, and citations to the king list and a modern chronology.
    ///
    /// Additive + idempotent. Existing figures are matched on normalized name
    /// (so user spellings win) and only blank fields are filled; a ruler the
    /// user has filed under some other era keeps that era. Missing rulers,
    /// relationships, sources and citations are created, nothing is deleted.
    /// `ensureDynastyGroups` picks the new era up on the next pass and builds
    /// the mixed figure/event subgroup page.
    package static func ensureFirstBabylonianDynasty(context: ModelContext) {
        let eraName = firstBabylonianEraName
        let eraKey = NameDuplicateCheck.normalizedKey(eraName)
        let supersedingEraKey = NameDuplicateCheck.normalizedKey("Old Babylonian Period")
        let manager = RelationshipManager(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraDescription = "Amorite dynasty of Babylon, the first dynasty of the Old Babylonian period. Listed in the Babylonian King List with eleven kings, from Sumu-abum to Samsu-ditana; it ended when the Hittite king Mursili I sacked Babylon in c. 1595 BCE."
        let era: Era
        if let existing = eras.first(where: { NameDuplicateCheck.normalizedKey($0.name) == eraKey }) {
            era = existing
            if existing.eraDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                existing.eraDescription = eraDescription
            }
            if existing.startDate.startYear == nil {
                existing.startDate = MythologicalDate(startYear: -1894, endYear: -1595, era: eraName, isApproximate: true)
            }
            if existing.endDate.endYear == nil {
                existing.endDate = MythologicalDate(year: -1595, era: eraName, isApproximate: true)
            }
        } else {
            let created = Era(
                name: eraName,
                orderIndex: 31,
                eraDescription: eraDescription,
                startDate: MythologicalDate(startYear: -1894, endYear: -1595, era: eraName, isApproximate: true),
                endDate: MythologicalDate(year: -1595, era: eraName, isApproximate: true)
            )
            context.insert(created)
            era = created
        }

        let humanPredicate = #Predicate<FigureType> { $0.name == "Human" }
        let humanType = (try? context.fetch(FetchDescriptor<FigureType>(predicate: humanPredicate)))?.first

        let existingFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var figureByKey: [String: Figure] = [:]
        for figure in existingFigures {
            let key = NameDuplicateCheck.normalizedKey(figure.name)
            if figureByKey[key] == nil { figureByKey[key] = figure }
        }

        let kingListSource = firstBabylonianKingListSource(context: context)
        let chronologySource = firstBabylonianChronologySource(context: context)

        var roster: [Figure] = []
        roster.reserveCapacity(firstBabylonianRulers.count)

        for (index, seed) in firstBabylonianRulers.enumerated() {
            let key = NameDuplicateCheck.normalizedKey(seed.name)
            let figure: Figure
            if let match = figureByKey[key] {
                figure = match
            } else {
                let created = Figure(
                    name: seed.name,
                    figureType: humanType,
                    gender: .male,
                    birthDate: MythologicalDate(startYear: seed.startYear, endYear: seed.endYear, era: eraName, isApproximate: true),
                    deathDate: MythologicalDate(year: seed.endYear, era: eraName, isApproximate: true),
                    source: kingListSource.name,
                    orderIndex: index
                )
                context.insert(created)
                figureByKey[key] = created
                figure = created
            }

            if figure.title.trimmingCharacters(in: .whitespaces).isEmpty {
                figure.title = "King of Babylon"
            }
            if figure.domain.trimmingCharacters(in: .whitespaces).isEmpty {
                figure.domain = "Babylonia"
            }
            if figure.figureDescription.trimmingCharacters(in: .whitespaces).isEmpty {
                figure.figureDescription = "Ruler of Babylon in the First Dynasty of Babylon, listed in the Babylonian King List. \(seed.note) Regnal span c. \(abs(seed.startYear))–\(abs(seed.endYear)) BCE (Middle Chronology)."
            }
            if figure.source.trimmingCharacters(in: .whitespaces).isEmpty {
                figure.source = kingListSource.name
            }
            if figure.orderIndex == 0 { figure.orderIndex = index }
            if figure.reignStartYear == nil || figure.reignEndYear == nil {
                figure.updateKingship(
                    reignStartYear: figure.reignStartYear ?? seed.startYear,
                    reignEndYear: figure.reignEndYear ?? seed.endYear,
                    reignYears: figure.reignYears
                )
            }

            // Adopt the dynasty era unless the figure is already filed under
            // another era the user chose; the birth/death era strings are the
            // source of truth `ensureFigureEraLinks` reconciles from, so they
            // move together with the relationship.
            let birthEraKey = NameDuplicateCheck.normalizedKey(figure.birthDate.era)
            let currentEraKey = NameDuplicateCheck.normalizedKey(figure.era?.name ?? "")
            let sourceOfTruthKey = birthEraKey.isEmpty ? currentEraKey : birthEraKey
            if sourceOfTruthKey.isEmpty || sourceOfTruthKey == supersedingEraKey || sourceOfTruthKey == eraKey {
                figure.era = era
                if birthEraKey.isEmpty || birthEraKey == supersedingEraKey {
                    figure.birthDate.era = eraName
                }
                let deathEraKey = NameDuplicateCheck.normalizedKey(figure.deathDate.era)
                if deathEraKey.isEmpty || deathEraKey == supersedingEraKey {
                    figure.deathDate.era = eraName
                }
            }

            manager.addCitation(
                to: kingListSource,
                location: "Dynasty I, column 1",
                note: seed.note,
                entityType: .figure,
                linkedEntityName: figure.name
            )
            manager.addCitation(
                to: chronologySource,
                location: "Babylon: First Dynasty (Middle Chronology)",
                note: "Regnal span c. \(abs(seed.startYear))–\(abs(seed.endYear)) BCE; absolute dates are conventional, not given by the king list.",
                entityType: .figure,
                linkedEntityName: figure.name
            )

            roster.append(figure)
        }

        manager.addCitation(
            to: kingListSource,
            location: "Dynasty I",
            note: "Eleven kings of Babylon, from Sumu-abum to Samsu-ditana, listed in column 1.",
            entityType: .era,
            linkedEntityName: eraName
        )

        if let fatherType = babylonianFatherType(context: context, manager: manager) {
            for (father, son) in zip(roster, roster.dropFirst()) {
                manager.addRelationship(
                    from: father,
                    to: son,
                    relationshipType: fatherType,
                    source: kingListSource.name,
                    sourceRef: kingListSource,
                    isPreferred: true
                )
            }
        }

        Commit.save(context, "ensureFirstBabylonianDynasty")
    }

    private static func firstBabylonianKingListSource(context: ModelContext) -> Source {
        let name = "Babylonian King List A"
        if let existing = (try? context.fetch(FetchDescriptor<Source>()))?
            .first(where: { NameDuplicateCheck.normalizedKey($0.name) == NameDuplicateCheck.normalizedKey(name) }) {
            return existing
        }
        let created = Source(
            name: name,
            sourceType: .kingList,
            author: "Anonymous Babylonian scribes",
            language: "Akkadian",
            period: "Old Babylonian",
            sourceDescription: "Babylonian King List A, the oldest and most complete of the Babylonian king lists. Column 1 gives the succession of Babylon's first dynasty with eleven kings, from Sumu-abum to Samsu-ditana, followed by Kassite rulers. Surviving copies date to the early second millennium BCE.",
            publicationInfo: "Attested in Old Babylonian school tablets; published in transliteration and translation in standard editions of Mesopotamian historical texts.",
            url: "https://en.wikipedia.org/wiki/Babylonian_King_List"
        )
        context.insert(created)
        return created
    }

    private static func firstBabylonianChronologySource(context: ModelContext) -> Source {
        let name = "The Ancient Near East"
        if let existing = (try? context.fetch(FetchDescriptor<Source>()))?
            .first(where: { NameDuplicateCheck.normalizedKey($0.name) == NameDuplicateCheck.normalizedKey(name) }) {
            return existing
        }
        let created = Source(
            name: name,
            sourceType: .scholarlyWork,
            author: "Amélie Kuhrt",
            language: "English",
            period: "Modern",
            sourceDescription: "Standard scholarly survey of the ancient Near East. Absolute regnal dates for the Amorite kings of Babylon in this database follow the Middle Chronology, the conventional chronology used here for third- and second-millennium dates.",
            publicationInfo: "Routledge, 1995",
            url: "https://www.routledge.com/The-Ancient-Near-East-c-3000-330-BC/Kuhrt/p/book/9780415266377"
        )
        context.insert(created)
        return created
    }

    private static func babylonianFatherType(context: ModelContext, manager: RelationshipManager) -> RelationshipType? {
        if let existing = (try? context.fetch(FetchDescriptor<RelationshipType>()))?
            .first(where: { $0.name == "Father" }) {
            return existing
        }
        return manager.relationshipType(
            named: "Father",
            icon: "arrow.down",
            colorHex: "007AFF",
            category: "parent",
            reverseName: "Son of"
        )
    }
}
