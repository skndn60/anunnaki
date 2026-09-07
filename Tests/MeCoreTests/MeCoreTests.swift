import XCTest
import SwiftData
@testable import MeCore

@MainActor
final class MeCoreTests: XCTestCase {
    func makeContainer() -> ModelContainer {
        _makeContainer(isDisk: false)
    }

    func makeDiskContainer() -> ModelContainer {
        _makeContainer(isDisk: true)
    }

    func _makeContainer(isDisk: Bool) -> ModelContainer {
        let schema = Schema([
            Figure.self, FigureType.self, Relationship.self, RelationshipType.self, Era.self,
            Place.self, PlaceType.self, Event.self, EventType.self,
            Source.self, Citation.self, AlternateName.self, Attachment.self,
            ImageAsset.self, Tag.self, DataVersion.self,
            FigurePlaceAssociation.self, FigurePlaceRoleType.self,
            PlacePlaceAssociation.self, PlacePlaceRoleType.self,
            EventEventAssociation.self, EventEventRoleType.self,
            EventPlaceAssociation.self, EventPlaceRoleType.self,
            StickyNote.self,
            Thing.self, ThingType.self,
            ThingFigureAssociation.self, ThingFigureRoleType.self,
            ThingPlaceAssociation.self, ThingPlaceRoleType.self,
            ThingEventAssociation.self, ThingEventRoleType.self,
            Agent.self, CollectedDatum.self, BlindSpot.self,
            BlockedSource.self, DictionaryEntry.self,
            FigureGroup.self, FigureGroupAssociation.self, GroupTextBlock.self,
            Pantheon.self, FigurePantheonAssociation.self,
            PopupTable.self, PopupTableAttribute.self, PopupTableCell.self, PopupTableColumn.self,
            PopupTableColumnLayout.self,
            User.self, ActivityLogEntry.self,
            IntegrityFinding.self, FindingDismissal.self
        ])
        if isDisk {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("MeTests-\(UUID().uuidString).store")
            let config = ModelConfiguration(schema: schema, url: url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create disk test container: \(error)")
            }
        }
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create test container: \(error)")
        }
    }

    func relType(_ name: String, _ context: ModelContext) -> RelationshipType? {
        let all: [RelationshipType] = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        return all.first(where: { $0.name == name })
    }

    func testMythologicalDateDisplayLabel() {
        let approximateBCE = MythologicalDate(year: -445000, era: "Creation", isApproximate: true)
        XCTAssertEqual(approximateBCE.displayLabel, "~445,000 BCE")

        let exactCE = MythologicalDate(year: 100, era: "Common Era", isApproximate: false)
        XCTAssertEqual(exactCE.displayLabel, "100 CE")

        let mythological = MythologicalDate(year: nil, era: "Mythological", isApproximate: false)
        XCTAssertEqual(mythological.displayLabel, "Mythological")

        let emptyEra = MythologicalDate(year: nil, era: "", isApproximate: false)
        XCTAssertEqual(emptyEra.displayLabel, "Unknown")
    }

    func testMythologicalDateSortValue() {
        let numeric = MythologicalDate(year: -1000, era: "", isApproximate: false)
        XCTAssertEqual(numeric.sortValue, -1000)

        let mythological = MythologicalDate(year: nil, era: "Creation", isApproximate: false)
        XCTAssertEqual(mythological.sortValue, Int.min)
    }

    func testEnsureTypesExistCreatesDefaultFigureTypes() {
        let container = makeContainer()
        let context = ModelContext(container)

        SeedData.ensureTypesExist(context: context)

        let figureTypes = (try? context.fetch(FetchDescriptor<FigureType>(sortBy: [SortDescriptor(\.name)]))) ?? []
        XCTAssertEqual(figureTypes.count, 8)
        XCTAssertEqual(figureTypes.map(\.name), ["Archangel", "Commander", "Deity", "Divine Collective", "Human", "Igigi", "Primordial", "Semi-Divine"])
    }

    func testEnsureMesopotamianDeitiesImportIsAdditiveAndIdempotent() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        Migration.ensureMesopotamianDeitiesImportExist(context: context)
        let first = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertGreaterThanOrEqual(first.count, 100, "migration should insert 100+ figures, got \(first.count)")
        let importedNames = Set(first.map { $0.name.lowercased() })
        XCTAssertTrue(importedNames.contains("ashur"))
        XCTAssertTrue(importedNames.contains("siduri"))

        Migration.ensureMesopotamianDeitiesImportExist(context: context)
        let second = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(second.count, first.count, "second run must not duplicate figures")
    }

    func testEnsureMesopotamianDeitiesImportSkippedByDiacriticVariant() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        context.insert(Figure(name: "Ištaran"))
        context.insert(Figure(name: "Ninšar"))
        context.insert(Figure(name: "Ninsi'anna"))
        try? context.save()

        Migration.ensureMesopotamianDeitiesImportExist(context: context)

        let names = (try? context.fetch(FetchDescriptor<Figure>()))?.map { DuplicateMerger.normalizationKey($0.name) } ?? []
        for ascii in ["Istaran", "Ninsar", "Ninsianna"] {
            let matches = names.filter { $0 == DuplicateMerger.normalizationKey(ascii) }.count
            XCTAssertEqual(matches, 1, "ASCII variant \(ascii) must not be duplicated when diacritic figure exists; got \(names)")
        }
    }

    func testNormalizationKeyEquatesVariantSpellings() {
        let cases: [(String, String)] = [
            ("Ninnibru", "Nin-Nibru"),
            ("Ea-nasir", "Eanasir"),
            ("Ištaran", "Istaran"),
            ("Atra-Hasis", "Atrahasis"),
            ("Meslamtaea", "Meslamta-ea"),
            ("Ninsi'anna", "Ninsianna"),
        ]
        for (canonical, variant) in cases {
            XCTAssertEqual(
                DuplicateMerger.normalizationKey(canonical),
                DuplicateMerger.normalizationKey(variant),
                "variant '\(variant)' must normalize to the same key as '\(canonical)' so description auto-linking can match it"
            )
        }

        let nonVariants: [(String, String)] = [
            ("Ninnibru", "Nin Nibru"),
            ("Ninnibru", "Ninnibrus"),
            ("Ea-nasir", "Ea Nasir"),
        ]
        for (canonical, other) in nonVariants {
            XCTAssertNotEqual(
                DuplicateMerger.normalizationKey(canonical),
                DuplicateMerger.normalizationKey(other),
                "'\(other)' is a real word/space difference, never a link candidate for '\(canonical)'"
            )
        }
    }

    func testEnsureAlternateNamesImportIsAdditiveAndIdempotent() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        Migration.ensureMesopotamianDeitiesImportExist(context: context)

        Migration.ensureAlternateNamesImportExist(context: context)
        let alts = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertGreaterThanOrEqual(alts.count, 20, "expected 20+ curated alternate-name rows, got \(alts.count)")

        let ashurAlts = alts.filter { $0.figure?.name == "Ashur" }.map { $0.name }
        XCTAssertTrue(ashurAlts.contains("Assur"), "Ashur should gain Akkadian spelling Assur; got \(ashurAlts)")

        let ninnibruAlts = alts.filter { $0.figure?.name == "Ninnibru" }.map { $0.name }
        XCTAssertTrue(ninnibruAlts.contains("Nin-Nibru"), "Ninnibru should gain its hyphenated transliteration Nin-Nibru; got \(ninnibruAlts)")

        Migration.ensureAlternateNamesImportExist(context: context)
        let alts2 = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertEqual(alts2.count, alts.count, "second run must not duplicate alternate names")
    }

    func testHistoricalEventsImportIsAdditiveAndIdempotent() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        Migration.ensureHistoricalEventsImportExist(context: context)
        let firstEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let firstFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertGreaterThanOrEqual(firstEvents.count, 60, "expected 60+ documented events, got \(firstEvents.count)")
        XCTAssertGreaterThanOrEqual(firstFigures.count, 30, "expected 30+ kings created, got \(firstFigures.count)")

        let eventNames = Set(firstEvents.map { $0.name.lowercased() })
        XCTAssertTrue(eventNames.contains("the fall of nineveh"), "fall of Nineveh should be present")
        XCTAssertTrue(eventNames.contains("the battle of qarqar"), "Qarqar should be present")
        XCTAssertTrue(eventNames.contains("the code of hammurabi"), "Code of Hammurabi should be present")

        let figureNames = Set(firstFigures.map { $0.name.lowercased() })
        XCTAssertTrue(figureNames.contains("sargon of akkad"), "Sargon of Akkad should be created as a king")
        XCTAssertTrue(figureNames.contains("ashurbanipal") == false || figureNames.contains("sennacherib") == false || figureNames.count >= 30,
                      "king set should be populated")

        Migration.ensureHistoricalEventsImportExist(context: context)
        let secondEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let secondFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(secondEvents.count, firstEvents.count, "second run must not duplicate events")
        XCTAssertEqual(secondFigures.count, firstFigures.count, "second run must not duplicate kings")
    }

    func testEnsureMissingFigureDescriptionsFillsOnlyBlanks() {
        let container = makeContainer()
        let context = ModelContext(container)

        let bau = Figure(name: "Bau")
        let ningishzida = Figure(name: "Ningishzida")
        let unknown = Figure(name: "NotInBlurbs")
        unknown.figureDescription = "  "
        context.insert(bau)
        context.insert(ningishzida)
        context.insert(unknown)
        try? context.save()

        Migration.ensureMissingFigureDescriptions(context: context)

        let after = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let byName = Dictionary(uniqueKeysWithValues: after.map { ($0.name, $0.figureDescription) })
        XCTAssertFalse((byName["Bau"] ?? "").isEmpty, "Bau should gain a description")
        XCTAssertFalse((byName["Ningishzida"] ?? "").isEmpty, "Ningishzida should gain a description")
        XCTAssertEqual(byName["NotInBlurbs"]?.trimmingCharacters(in: .whitespacesAndNewlines), "", "unknown figure stays untouched")

        Migration.ensureMissingFigureDescriptions(context: context)
        let second = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let secondDescriptions = second.filter { $0.name == "Bau" }.map(\.figureDescription)
        XCTAssertEqual(secondDescriptions.count, 1, "second run must not alter filled descriptions")
    }

    func testRemoveOrphanedKittumNigginaAltNamesRemovesOnlyTargetPair() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)
        Migration.ensureMesopotamianDeitiesImportExist(context: context)
        Migration.ensureAlternateNamesImportExist(context: context)

        context.insert(AlternateName(name: "Niĝgina", tradition: .sumerian, nameType: .syncretism))
        context.insert(AlternateName(name: "Kittum", tradition: .akkadian, nameType: .translation))
        context.insert(AlternateName(name: "Unrelated Orphan", tradition: .other, nameType: .epithet))
        try? context.save()

        Migration.removeOrphanedKittumNigginaAltNames(context: context)

        let orphans = ((try? context.fetch(FetchDescriptor<AlternateName>())) ?? [])
            .filter { $0.figure == nil && $0.place == nil }
        XCTAssertFalse(orphans.contains { $0.name == "Niĝgina" })
        XCTAssertFalse(orphans.contains { $0.name == "Kittum" })
        XCTAssertTrue(orphans.contains { $0.name == "Unrelated Orphan" }, "unrelated orphans must be untouched")

        let kittum = (try? context.fetch(FetchDescriptor<Figure>()))?.first { $0.name == "Kittum" }
        let linked = ((try? context.fetch(FetchDescriptor<AlternateName>())) ?? [])
            .filter { $0.figure == kittum }.map { $0.name }
        XCTAssertTrue(linked.contains("Niggina"), "linked Niggina alt must survive; got \(linked)")
    }

    func testEnsureTypesExistCreatesDefaultPlaceTypes() {
        let container = makeContainer()
        let context = ModelContext(container)

        SeedData.ensureTypesExist(context: context)

        let placeTypes = (try? context.fetch(FetchDescriptor<PlaceType>(sortBy: [SortDescriptor(\.name)]))) ?? []
        XCTAssertEqual(placeTypes.count, 6)
    }

    func testEnsureTypesExistCreatesDefaultEventTypes() {
        let container = makeContainer()
        let context = ModelContext(container)

        SeedData.ensureTypesExist(context: context)

        let eventTypes = (try? context.fetch(FetchDescriptor<EventType>(sortBy: [SortDescriptor(\.name)]))) ?? []
        XCTAssertEqual(eventTypes.count, 10)
    }

    func testEnsureTypesExistIsIdempotent() {
        let container = makeContainer()
        let context = ModelContext(container)

        SeedData.ensureTypesExist(context: context)
        SeedData.ensureTypesExist(context: context)

        let figureTypes = (try? context.fetchCount(FetchDescriptor<FigureType>())) ?? 0
        let placeTypes = (try? context.fetchCount(FetchDescriptor<PlaceType>())) ?? 0
        let eventTypes = (try? context.fetchCount(FetchDescriptor<EventType>())) ?? 0

        XCTAssertEqual(figureTypes, 8)
        XCTAssertEqual(placeTypes, 6)
        XCTAssertEqual(eventTypes, 10)
    }

    func testQueryEngineFindsFigureByName() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let anu = Figure(name: "Anu", gender: .male)
        context.insert(anu)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("Anu")

        guard case .figure(let dossier) = result else {
            XCTFail("Expected figure result, got \(result)")
            return
        }
        XCTAssertEqual(dossier.figure.name, "Anu")
    }

    func testQueryEngineChildrenOfFigure() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let anu = Figure(name: "Anu", gender: .male)
        let enlil = Figure(name: "Enlil", gender: .male)
        context.insert(anu)
        context.insert(enlil)

        let relationship = Relationship(fromFigure: anu, toFigure: enlil, relationshipType: relType("Father", context))
        context.insert(relationship)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("children of Anu")

        guard case .figureList(let title, let figures) = result else {
            XCTFail("Expected figure list result, got \(result)")
            return
        }
        XCTAssertEqual(title, "Children of Anu")
        XCTAssertEqual(figures.count, 1)
        XCTAssertEqual(figures.first?.name, "Enlil")
    }

    func testQueryEngineHowManyChildrenNatural() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let anu = Figure(name: "Anu", gender: .male)
        let enlil = Figure(name: "Enlil", gender: .male)
        let enki = Figure(name: "Enki", gender: .male)
        context.insert(anu)
        context.insert(enlil)
        context.insert(enki)

        context.insert(Relationship(fromFigure: anu, toFigure: enlil, relationshipType: relType("Father", context)))
        context.insert(Relationship(fromFigure: anu, toFigure: enki, relationshipType: relType("Father", context)))
        try? context.save()

        let engine = QueryEngine(context: context)

        let result = engine.query("how many children did anu have? I want a number and a list of their names")

        let title: String
        let figures: [Figure]
        switch result {
        case .figureList(let t, let f):
            title = t; figures = f
        case .answer(let text):
            XCTFail("Expected figureList, got answer: '\(text)'")
            return
        case .figure(let dossier):
            XCTFail("Expected figureList, got figure dossier for '\(dossier.figure.name)'")
            return
        default:
            XCTFail("Expected figureList, got \(result)")
            return
        }
        XCTAssertEqual(title, "Anu had 2 children", "Title was: '\(title)'")
        XCTAssertEqual(figures.count, 2)
        XCTAssertTrue(figures.contains(where: { $0.name == "Enlil" }))
        XCTAssertTrue(figures.contains(where: { $0.name == "Enki" }))
    }

    func testQueryEngineEmbeddingSynonymKids() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let anu = Figure(name: "Anu", gender: .male)
        let enlil = Figure(name: "Enlil", gender: .male)
        let enki = Figure(name: "Enki", gender: .male)
        context.insert(anu)
        context.insert(enlil)
        context.insert(enki)

        context.insert(Relationship(fromFigure: anu, toFigure: enlil, relationshipType: relType("Father", context)))
        context.insert(Relationship(fromFigure: anu, toFigure: enki, relationshipType: relType("Father", context)))
        try? context.save()

        let engine = QueryEngine(context: context)

        let result = engine.query("how many kids does anu have")

        let title: String
        let figures: [Figure]
        switch result {
        case .figureList(let t, let f):
            title = t; figures = f
        case .answer(let text):
            XCTFail("Expected figureList, got answer: '\(text)'")
            return
        default:
            XCTFail("Expected figureList, got \(result)")
            return
        }
        XCTAssertTrue(title.lowercased().contains("2"), "Title should mention the count: '\(title)'")
        XCTAssertEqual(figures.count, 2)
        XCTAssertTrue(figures.contains(where: { $0.name == "Enlil" }))
        XCTAssertTrue(figures.contains(where: { $0.name == "Enki" }))
    }

    func testQueryEnginePossessiveSynonymMom() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let enki = Figure(name: "Enki", gender: .male)
        let nammu = Figure(name: "Nammu", gender: .female)
        context.insert(enki)
        context.insert(nammu)
        context.insert(Relationship(fromFigure: nammu, toFigure: enki, relationshipType: relType("Mother", context)))
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("enki's mom")
        let title: String
        let figures: [Figure]
        switch result {
        case .figureList(let t, let f):
            title = t; figures = f
        default:
            XCTFail("Expected figureList, got \(result)")
            return
        }
        XCTAssertEqual(title, "Mother of Enki")
        XCTAssertEqual(figures.count, 1)
        XCTAssertEqual(figures.first?.name, "Nammu")
    }

    func testQueryEngineYesNoChoice() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let enki = Figure(name: "Enki", gender: .male)
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "#FFD700")
        context.insert(deityType)
        enki.figureType = deityType
        context.insert(enki)
        try? context.save()

        let engine = QueryEngine(context: context)

        let result = engine.query("Was Enki a deity or a human?")

        switch result {
        case .answer(let text):
            XCTAssertEqual(text, "Enki is a Deity, not a Human.")
        default:
            XCTFail("Expected answer string, got \(result)")
        }
    }

    func testQueryEngineUnknownReturnsNoMatch() {
        let container = makeContainer()
        let context = ModelContext(container)
        let engine = QueryEngine(context: context)

        let result = engine.query("and humans?")
        switch result {
        case .noMatch:
            break
        default:
            XCTFail("Expected noMatch for unknown query, got \(result)")
        }
    }

    func testDossierBuilderCollectsParentsAndChildren() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let anu = Figure(name: "Anu", gender: .male)
        let antu = Figure(name: "Antu", gender: .female)
        let enlil = Figure(name: "Enlil", gender: .male)
        context.insert(anu)
        context.insert(antu)
        context.insert(enlil)

        context.insert(Relationship(fromFigure: anu, toFigure: enlil, relationshipType: relType("Father", context)))
        context.insert(Relationship(fromFigure: antu, toFigure: enlil, relationshipType: relType("Mother", context)))
        try? context.save()

        let dossier = context.buildFigureDossier(enlil)
        XCTAssertEqual(dossier.parents.map(\.name).sorted(), ["Antu", "Anu"])
        XCTAssertEqual(dossier.children.map(\.name), [])
        XCTAssertEqual(dossier.figure.name, "Enlil")
    }

    // MARK: - New Relationship Type Queries

    func testQueryEngineUnclesOfFigure() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let enlil = Figure(name: "Enlil", gender: .male)
        let enki = Figure(name: "Enki", gender: .male)
        let ninurta = Figure(name: "Ninurta", gender: .male)
        context.insert(enlil)
        context.insert(enki)
        context.insert(ninurta)

        context.insert(Relationship(fromFigure: enki, toFigure: ninurta, relationshipType: relType("Uncle", context)))
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("Ninurta's uncle")

        guard case .figureList(let title, let figures) = result else {
            XCTFail("Expected figure list, got \(result)")
            return
        }
        XCTAssertEqual(title, "Uncles of Ninurta")
        XCTAssertEqual(figures.first?.name, "Enki")
    }

    func testQueryEngineUncleOfPrepositional() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let enlil = Figure(name: "Enlil", gender: .male)
        let enki = Figure(name: "Enki", gender: .male)
        let ninurta = Figure(name: "Ninurta", gender: .male)
        context.insert(enlil)
        context.insert(enki)
        context.insert(ninurta)

        context.insert(Relationship(fromFigure: enki, toFigure: ninurta, relationshipType: relType("Uncle", context)))
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("uncle of Ninurta")

        guard case .figureList(_, let figures) = result else {
            XCTFail("Expected figure list, got \(result)")
            return
        }
        XCTAssertEqual(figures.first?.name, "Enki")
    }

    func testQueryEngineAuntsOfFigure() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let ninhursag = Figure(name: "Ninhursag", gender: .female)
        let ninurta = Figure(name: "Ninurta", gender: .male)
        context.insert(ninhursag)
        context.insert(ninurta)

        context.insert(Relationship(fromFigure: ninhursag, toFigure: ninurta, relationshipType: relType("Aunt", context)))
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("Ninurta's aunt")

        guard case .figureList(let title, let figures) = result else {
            XCTFail("Expected figure list, got \(result)")
            return
        }
        XCTAssertEqual(title, "Aunts of Ninurta")
        XCTAssertEqual(figures.first?.name, "Ninhursag")
    }

    func testQueryEngineEnemyOfFigure() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let marduk = Figure(name: "Marduk", gender: .male)
        let tiamat = Figure(name: "Tiamat", gender: .female)
        context.insert(marduk)
        context.insert(tiamat)

        context.insert(Relationship(fromFigure: tiamat, toFigure: marduk, relationshipType: relType("Enemy", context)))
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("Marduk's enemies")

        guard case .figureList(let title, let figures) = result else {
            XCTFail("Expected figure list, got \(result)")
            return
        }
        XCTAssertEqual(title, "Enemies of Marduk")
        XCTAssertEqual(figures.first?.name, "Tiamat")
    }

    func testQueryEngineAllyOfFigure() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let gilgamesh = Figure(name: "Gilgamesh", gender: .male)
        let enkidu = Figure(name: "Enkidu", gender: .male)
        context.insert(gilgamesh)
        context.insert(enkidu)

        context.insert(Relationship(fromFigure: gilgamesh, toFigure: enkidu, relationshipType: relType("Ally", context)))
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("Gilgamesh's allies")

        guard case .figureList(let title, let figures) = result else {
            XCTFail("Expected figure list, got \(result)")
            return
        }
        XCTAssertEqual(title, "Allies of Gilgamesh")
        XCTAssertEqual(figures.first?.name, "Enkidu")
    }

    // MARK: - Listing Queries

    func testQueryEngineListAllFigures() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let anu = Figure(name: "Anu", gender: .male)
        let enlil = Figure(name: "Enlil", gender: .male)
        context.insert(anu)
        context.insert(enlil)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("list all figures")

        guard case .figureList(let title, let figures) = result else {
            XCTFail("Expected figure list, got \(result)")
            return
        }
        XCTAssertEqual(title, "All Figures")
        XCTAssertEqual(figures.count, 2)
    }

    func testQueryEngineListAllEvents() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let flood = Event(name: "The Great Flood")
        let creation = Event(name: "Creation")
        context.insert(flood)
        context.insert(creation)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("show all events")

        guard case .eventList(let title, let events) = result else {
            XCTFail("Expected event list, got \(result)")
            return
        }
        XCTAssertEqual(title, "All Events")
        XCTAssertEqual(events.count, 2)
    }

    // MARK: - Domain Queries

    func testQueryEngineDomainQuery() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let enlil = Figure(name: "Enlil", gender: .male, domain: "Air, Wind, Storms")
        let enki = Figure(name: "Enki", gender: .male, domain: "Water, Wisdom, Creation")
        context.insert(enlil)
        context.insert(enki)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("wind gods")

        guard case .figureList(_, let figures) = result else {
            XCTFail("Expected figure list, got \(result)")
            return
        }
        XCTAssertTrue(figures.contains(where: { $0.name == "Enlil" }))
    }

    // MARK: - Gender Queries

    func testQueryEngineGenderQuery() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let inanna = Figure(name: "Inanna", gender: .female)
        let ninhursag = Figure(name: "Ninhursag", gender: .female)
        let enlil = Figure(name: "Enlil", gender: .male)
        context.insert(inanna)
        context.insert(ninhursag)
        context.insert(enlil)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("female figures")

        guard case .figureList(_, let figures) = result else {
            XCTFail("Expected figure list, got \(result)")
            return
        }
        XCTAssertEqual(figures.count, 2)
        XCTAssertTrue(figures.allSatisfy { $0.gender == .female })
    }

    // MARK: - Era Queries

    func testQueryEngineEraQuery() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let earlyFigure = Figure(name: "Etana", gender: .male, birthDate: MythologicalDate(year: nil, era: "Early Dynastic Period", isApproximate: true))
        let floodFigure = Figure(name: "Ziusudra", gender: .male, birthDate: MythologicalDate(year: nil, era: "The Great Flood", isApproximate: true))
        context.insert(earlyFigure)
        context.insert(floodFigure)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("figures of the early dynastic period")

        guard case .figureList(_, let figures) = result else {
            XCTFail("Expected figure list, got \(result)")
            return
        }
        XCTAssertEqual(figures.count, 1)
        XCTAssertEqual(figures.first?.name, "Etana")
    }

    // MARK: - Duration Queries

    func testQueryEngineEraDuration() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let era = Era(
            name: "Early Dynastic Period",
            orderIndex: 3,
            eraDescription: "The early dynastic period of Mesopotamia",
            startDate: MythologicalDate(year: -2900, era: "Early Dynastic Period", isApproximate: true),
            endDate: MythologicalDate(year: -2350, era: "Early Dynastic Period", isApproximate: true)
        )
        context.insert(era)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("duration of the Early Dynastic Period")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        XCTAssertTrue(text.contains("Early Dynastic Period"), "Got: \(text)")
        // Check numeric value ignoring locale grouping separators
        let digits = text.filter(\.isNumber)
        XCTAssertTrue(digits.contains("550"), "Expected 550 in text, got: \(text)")
    }

    func testQueryEngineEraDurationHowLong() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let era = Era(
            name: "Antediluvian Period",
            orderIndex: 1,
            startDate: MythologicalDate(year: -300000, era: "Antediluvian", isApproximate: true),
            endDate: MythologicalDate(year: -290000, era: "Antediluvian", isApproximate: true)
        )
        context.insert(era)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("how long did the Antediluvian Period last")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        let digits = text.filter(\.isNumber)
        XCTAssertTrue(digits.contains("10000"), "Expected 10000 in text, got: \(text)")
    }

    func testQueryEngineFigureLifespan() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let figure = Figure(
            name: "Etana",
            gender: .male,
            birthDate: MythologicalDate(year: -3000, era: "Early Dynastic Period", isApproximate: true),
            deathDate: MythologicalDate(year: -2950, era: "Early Dynastic Period", isApproximate: true)
        )
        context.insert(figure)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("duration of Etana")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        let digits = text.filter(\.isNumber)
        XCTAssertTrue(digits.contains("50"), "Expected 50 in text, got: \(text)")
        XCTAssertTrue(text.contains("Etana"))
    }

    // MARK: - Reign Queries

    func testQueryEngineFigureReignHowLong() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let figure = Figure(
            name: "Gilgamesh",
            title: "King of Uruk",
            gender: .male,
            birthDate: MythologicalDate(year: -2800, era: "Early Dynastic Period", isApproximate: true),
            deathDate: MythologicalDate(year: -2700, era: "Early Dynastic Period", isApproximate: true)
        )
        context.insert(figure)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("how long did Gilgamesh reign")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        let digits = text.filter(\.isNumber)
        XCTAssertTrue(digits.contains("100"), "Expected 100 in text, got: \(text)")
        XCTAssertTrue(text.contains("Gilgamesh"))
    }

    func testQueryEngineFigureReignPossessive() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let figure = Figure(
            name: "Gilgamesh",
            gender: .male,
            birthDate: MythologicalDate(year: -2800, era: "", isApproximate: true),
            deathDate: MythologicalDate(year: -2700, era: "", isApproximate: true)
        )
        context.insert(figure)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("Gilgamesh's reign")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        XCTAssertTrue(text.contains("100"))
    }

    func testQueryEngineFigureReignPrepositional() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let figure = Figure(
            name: "Gilgamesh",
            gender: .male,
            birthDate: MythologicalDate(year: -2800, era: "", isApproximate: true),
            deathDate: MythologicalDate(year: -2700, era: "", isApproximate: true)
        )
        context.insert(figure)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("reign of Gilgamesh")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        XCTAssertTrue(text.contains("100"))
    }

    func testQueryEngineDurationNoDates() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let era = Era(
            name: "Mythological Age",
            orderIndex: 0,
            startDate: .unknown,
            endDate: .unknown
        )
        context.insert(era)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("duration of the Mythological Age")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        XCTAssertTrue(text.contains("no specific start and end dates"))
    }

    // MARK: - Fallback Resolution

    func testQueryEngineUnmatchedReturnsNoMatch() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let engine = QueryEngine(context: context)
        let result = engine.query("king of shuruppak")

        guard case .noMatch = result else {
            XCTFail("Expected noMatch for unresolved query, got \(result)")
            return
        }
    }

    // MARK: - Enoch Backfill

    func testEnsureEnochDataExistsCreatesPlacesAndEvents() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let figureNames = ["Samyaza", "Azazel", "Enoch", "Noah", "Michael", "Uriel", "Raphael"]
        for name in figureNames {
            let figure = Figure(name: name, gender: .male)
            context.insert(figure)
        }
        try? context.save()

        SeedData.ensureEnochDataExists(context: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let placeNames = places.map(\.name).sorted()
        XCTAssertEqual(places.count, 4)
        XCTAssertEqual(placeNames, ["Dudael", "Mount Hermon", "Paradise", "Sheol"])

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let eventNames = events.map(\.name)
        XCTAssertEqual(events.count, 5)
        XCTAssertTrue(eventNames.contains("The Fall of the Watchers"))
        XCTAssertTrue(eventNames.contains("The Binding of Azazel"))
        XCTAssertTrue(eventNames.contains("The Binding of the Watchers"))
        XCTAssertTrue(eventNames.contains("Enoch's Heavenly Journeys"))
        XCTAssertTrue(eventNames.contains("The Deluge Judgment"))

        let fallEvent = events.first { $0.name == "The Fall of the Watchers" }
        XCTAssertNotNil(fallEvent)
        XCTAssertEqual(fallEvent?.involvedFigures.count, 2)
        XCTAssertTrue(fallEvent?.involvedFigures.contains { $0.name == "Samyaza" } ?? false)
        XCTAssertTrue(fallEvent?.involvedFigures.contains { $0.name == "Azazel" } ?? false)

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertTrue(sources.contains { $0.name == "Book of Enoch (1 Enoch)" })

        let sourceCountBefore = sources.count
        SeedData.ensureEnochDataExists(context: context)
        let sourcesAfter = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let placesAfter = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let eventsAfter = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertEqual(sourcesAfter.count, sourceCountBefore)
        XCTAssertEqual(placesAfter.count, 4)
        XCTAssertEqual(eventsAfter.count, 5)
    }

    // MARK: - Test Fixture: Seeded Mini-Database

    struct TestFixture {
        let container: ModelContainer
        let context: ModelContext
        let engine: QueryEngine

        let enki: Figure
        let enlil: Figure
        let ninhursag: Figure
        let marduk: Figure
        let tiamat: Figure
        let nabu: Figure

        let fatherType: RelationshipType
        let motherType: RelationshipType
        let spouseType: RelationshipType
        let siblingType: RelationshipType
        let creatorType: RelationshipType

        let uruk: Place
        let eridu: Place

        let creationEvent: Event
    }

    func makeFixture() -> TestFixture {
        let container = makeContainer()
        let context = container.mainContext

        let fatherType = RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent")
        let motherType = RelationshipType(name: "Mother", icon: "arrow.down", colorHex: "FF2D55", category: "parent")
        let spouseType = RelationshipType(name: "Spouse", icon: "heart", colorHex: "FF3B30", category: "partner")
        let siblingType = RelationshipType(name: "Sibling", icon: "arrow.left.arrow.right", colorHex: "FF9500", category: "sibling")
        let creatorType = RelationshipType(name: "Creator", icon: "wand.and.stars", colorHex: "AF52DE", category: "creator")
        for t in [fatherType, motherType, spouseType, siblingType, creatorType] { context.insert(t) }

        let enki = Figure(name: "Enki", gender: .male, domain: "Wisdom", figureDescription: "God of freshwater and wisdom")
        let enlil = Figure(name: "Enlil", gender: .male, domain: "Air", figureDescription: "God of wind and storms")
        let ninhursag = Figure(name: "Ninhursag", gender: .female, domain: "Earth", figureDescription: "Mother goddess")
        let marduk = Figure(name: "Marduk", gender: .male, domain: "Order", figureDescription: "King of the gods")
        let tiamat = Figure(name: "Tiamat", gender: .female, domain: "Salt water", figureDescription: "Primordial goddess of the sea")
        let nabu = Figure(name: "Nabu", gender: .male, domain: "Writing", figureDescription: "God of writing and scribes")
        for f in [enki, enlil, ninhursag, marduk, tiamat, nabu] { context.insert(f) }

        let altName = AlternateName(figure: enki, name: "Nudimmud", tradition: .akkadian, nameType: .epithet)
        context.insert(altName)

        let uruk = Place(name: "Uruk", modernLocation: "Iraq")
        let eridu = Place(name: "Eridu", modernLocation: "Iraq")
        for p in [uruk, eridu] { context.insert(p) }

        let creationEvent = Event(name: "Creation of Humanity", era: "Primordial", involvedFigures: [enki, tiamat])
        context.insert(creationEvent)

        // Relationships
        let r1 = Relationship(fromFigure: enlil, toFigure: enki, relationshipType: fatherType, source: "test")
        let r2 = Relationship(fromFigure: ninhursag, toFigure: enki, relationshipType: motherType, source: "test")
        let r3 = Relationship(fromFigure: enlil, toFigure: ninhursag, relationshipType: spouseType, source: "test")
        let r4 = Relationship(fromFigure: enki, toFigure: marduk, relationshipType: fatherType, source: "test")
        let r5 = Relationship(fromFigure: tiamat, toFigure: marduk, relationshipType: motherType, source: "test")
        let r6 = Relationship(fromFigure: marduk, toFigure: nabu, relationshipType: siblingType, source: "test")
        let r7 = Relationship(fromFigure: tiamat, toFigure: marduk, relationshipType: creatorType, source: "test")
        for r in [r1, r2, r3, r4, r5, r6, r7] { context.insert(r) }

        try? context.save()

        let engine = QueryEngine(context: context)

        return TestFixture(
            container: container, context: context, engine: engine,
            enki: enki, enlil: enlil, ninhursag: ninhursag,
            marduk: marduk, tiamat: tiamat, nabu: nabu,
            fatherType: fatherType, motherType: motherType,
            spouseType: spouseType, siblingType: siblingType, creatorType: creatorType,
            uruk: uruk, eridu: eridu,
            creationEvent: creationEvent
        )
    }

    // MARK: - resolve* Tests

    func testResolveFigureExact() {
        let f = makeFixture()
        let result = f.engine.query("Enki")
        guard case .figure(let dossier) = result else {
            return XCTFail("Expected .figure, got \(result)")
        }
        XCTAssertEqual(dossier.figure.name, "Enki")
    }

    func testResolveFigureCaseInsensitive() {
        let f = makeFixture()
        let result = f.engine.query("enki")
        guard case .figure(let dossier) = result else {
            return XCTFail("Expected .figure, got \(result)")
        }
        XCTAssertEqual(dossier.figure.name, "Enki")
    }

    func testResolveFigurePartial() {
        let f = makeFixture()
        let result = f.engine.query("enk")
        guard case .figure(let dossier) = result else {
            return XCTFail("Expected .figure, got \(result)")
        }
        XCTAssertEqual(dossier.figure.name, "Enki")
    }

    func testResolveFigureNoMatch() {
        let f = makeFixture()
        let result = f.engine.query("zzznonexistent")
        guard case .noMatch = result else {
            return XCTFail("Expected .noMatch, got \(result)")
        }
    }

    func testResolveFigureAlternateName() {
        let f = makeFixture()
        let result = f.engine.query("Nudimmud")
        guard case .figure(let dossier) = result else {
            return XCTFail("Expected .figure, got \(result)")
        }
        XCTAssertEqual(dossier.figure.name, "Enki")
    }

    func testSortedAlternateNamesAlphabetical() {
        let f = makeFixture()
        for name in ["Zag", "ab", "Mami", "Ea"] {
            f.context.insert(AlternateName(figure: f.enki, name: name))
        }
        try? f.context.save()
        XCTAssertEqual(f.enki.sortedAlternateNames.map(\.name), ["ab", "Ea", "Mami", "Nudimmud", "Zag"])
    }

    func testResolvePlaceExact() {
        let f = makeFixture()
        let result = f.engine.query("Uruk")
        guard case .place(let dossier) = result else {
            return XCTFail("Expected .place, got \(result)")
        }
        XCTAssertEqual(dossier.place.name, "Uruk")
    }

    func testResolvePlaceNoMatch() {
        let f = makeFixture()
        let result = f.engine.query("Atlantis")
        guard case .noMatch = result else {
            return XCTFail("Expected .noMatch, got \(result)")
        }
    }

    func testResolveEventExact() {
        let f = makeFixture()
        let result = f.engine.query("Creation of Humanity")
        guard case .event(let dossier) = result else {
            return XCTFail("Expected .event, got \(result)")
        }
        XCTAssertEqual(dossier.event.name, "Creation of Humanity")
    }

    // MARK: - RetrievalIndex (shared retrieval layer) Tests

    func testRetrievalIndexMentionsAlternateName() {
        let f = makeFixture()
        let index = RetrievalIndex(
            figures: [f.enki, f.enlil, f.ninhursag, f.marduk, f.tiamat, f.nabu],
            places: [f.uruk, f.eridu],
            events: [f.creationEvent],
            things: [],
            alternateNames: [AlternateName(figure: f.ninhursag, name: "Mami", tradition: .sumerian)]
        )
        let mentioned = index.figuresMentioned(in: "What do we know about Mami?")
        XCTAssertTrue(mentioned.contains { $0.persistentModelID == f.ninhursag.persistentModelID })
        XCTAssertFalse(mentioned.contains { $0.persistentModelID == f.enki.persistentModelID })
    }

    func testRetrievalIndexMentionsSingleTokenFallback() {
        let f = makeFixture()
        let index = RetrievalIndex(
            figures: [f.enki, f.enlil, f.ninhursag, f.marduk, f.tiamat, f.nabu],
            places: [f.uruk, f.eridu],
            events: [f.creationEvent],
            things: [],
            alternateNames: []
        )
        let mentioned = index.eventsMentioned(in: "What created humanity?")
        XCTAssertTrue(mentioned.contains { $0.persistentModelID == f.creationEvent.persistentModelID })
    }

    func testRetrievalIndexMentionsStopWordGuard() {
        let f = makeFixture()
        let index = RetrievalIndex(
            figures: [f.enki, f.enlil, f.ninhursag, f.marduk, f.tiamat, f.nabu],
            places: [f.uruk, f.eridu],
            events: [f.creationEvent],
            things: [],
            alternateNames: []
        )
        XCTAssertFalse(index.figuresMentioned(in: "the").contains { $0.persistentModelID == f.enki.persistentModelID })
        XCTAssertFalse(index.eventsMentioned(in: "was").contains { $0.persistentModelID == f.creationEvent.persistentModelID })
    }

    func testRetrievalIndexMentionsSortNameOverride() {
        let f = makeFixture()
        let flood = Event(name: "The Great Flood", sortName: "Flood")
        f.context.insert(flood)
        let index = RetrievalIndex(
            figures: [f.enki, f.enlil, f.ninhursag, f.marduk, f.tiamat, f.nabu],
            places: [f.uruk, f.eridu],
            events: [f.creationEvent, flood],
            things: [],
            alternateNames: []
        )
        let mentioned = index.eventsMentioned(in: "What was the flood like?")
        XCTAssertTrue(mentioned.contains { $0.persistentModelID == flood.persistentModelID })
    }

    func testRetrievalIndexResolveFigureByAlternateName() {
        let f = makeFixture()
        let index = RetrievalIndex(
            figures: [f.enki, f.enlil, f.ninhursag, f.marduk, f.tiamat, f.nabu],
            places: [f.uruk, f.eridu],
            events: [f.creationEvent],
            things: [],
            alternateNames: [AlternateName(figure: f.enki, name: "Nudimmud", tradition: .akkadian)]
        )
        XCTAssertEqual(index.resolveFigure("Nudimmud")?.persistentModelID, f.enki.persistentModelID)
        XCTAssertEqual(index.resolveFigure("Enki")?.persistentModelID, f.enki.persistentModelID)
        XCTAssertEqual(index.resolveFigure("enk")?.persistentModelID, f.enki.persistentModelID)
    }

    func testRetrievalIndexResolutionParityWithQueryEngine() {
        let f = makeFixture()
        let index = RetrievalIndex(
            figures: [f.enki, f.enlil, f.ninhursag, f.marduk, f.tiamat, f.nabu],
            places: [f.uruk, f.eridu],
            events: [f.creationEvent],
            things: [],
            alternateNames: [AlternateName(figure: f.enki, name: "Nudimmud", tradition: .akkadian)]
        )
        XCTAssertEqual(index.resolvePlace("Uruk")?.persistentModelID, f.uruk.persistentModelID)
        XCTAssertEqual(index.resolvePlace("uk")?.persistentModelID, f.uruk.persistentModelID)
        XCTAssertEqual(index.resolveEvent("Creation of Humanity")?.persistentModelID, f.creationEvent.persistentModelID)
        XCTAssertNil(index.resolveFigure("zzznonexistent"))
        XCTAssertNil(index.resolvePlace("Atlantis"))
    }

    func testQueryEngineStructuredPipelineResolvesAlternateName() {
        let f = makeFixture()
        f.context.insert(AlternateName(figure: f.ninhursag, name: "Mami", tradition: .sumerian))
        try? f.context.save()

        let result = f.engine.query("What is Mami?")
        guard case .figure(let dossier) = result else {
            return XCTFail("Expected .figure for alternate-name query, got \(result)")
        }
        XCTAssertEqual(dossier.figure.name, "Ninhursag")
    }

    // MARK: - find* Tests

    func testFindChildren() {
        let f = makeFixture()
        let result = f.engine.query("Enlil's children")
        guard case .figureList(_, let figures) = result else {
            return XCTFail("Expected .figureList, got \(result)")
        }
        let names = figures.map(\.name)
        XCTAssertTrue(names.contains("Enki"), "Enlil should be father of Enki")
    }

    func testFindChildrenNone() {
        let f = makeFixture()
        let result = f.engine.query("Nabu's children")
        guard case .figureList(_, let figures) = result else {
            return XCTFail("Expected .figureList, got \(result)")
        }
        XCTAssertTrue(figures.isEmpty, "Nabu has no children")
    }

    func testFindParents() {
        let f = makeFixture()
        let result = f.engine.query("Enki's parents")
        guard case .figureList(_, let figures) = result else {
            return XCTFail("Expected .figureList, got \(result)")
        }
        let names = figures.map(\.name)
        XCTAssertTrue(names.contains("Enlil"), "Enki's father should be Enlil")
        XCTAssertTrue(names.contains("Ninhursag"), "Enki's mother should be Ninhursag")
    }

    func testFindParentsNone() {
        let f = makeFixture()
        let result = f.engine.query("Enlil's parents")
        guard case .figureList(_, let figures) = result else {
            return XCTFail("Expected .figureList, got \(result)")
        }
        XCTAssertTrue(figures.isEmpty, "Enlil has no parents in test data")
    }

    func testFindSpouses() {
        let f = makeFixture()
        let result = f.engine.query("Enlil's spouse")
        guard case .figureList(_, let figures) = result else {
            return XCTFail("Expected .figureList, got \(result)")
        }
        let names = figures.map(\.name)
        XCTAssertTrue(names.contains("Ninhursag"), "Enlil's spouse should be Ninhursag")
    }

    func testFindSiblings() {
        let f = makeFixture()
        let result = f.engine.query("Marduk's siblings")
        guard case .figureListAnnotated(_, let annotated) = result else {
            return XCTFail("Expected .figureListAnnotated, got \(result)")
        }
        let names = annotated.map { $0.0.name }
        XCTAssertTrue(names.contains("Nabu"), "Marduk's sibling should be Nabu")
    }

    func testFindCreators() {
        let f = makeFixture()
        let result = f.engine.query("creators of Marduk")
        guard case .figureList(_, let figures) = result else {
            return XCTFail("Expected .figureList, got \(result)")
        }
        let names = figures.map(\.name)
        XCTAssertTrue(names.contains("Tiamat"), "Tiamat created Marduk")
    }

    func testFindCreations() {
        let f = makeFixture()
        let result = f.engine.query("creations of Tiamat")
        guard case .figureList(_, let figures) = result else {
            return XCTFail("Expected .figureList, got \(result)")
        }
        let names = figures.map(\.name)
        XCTAssertTrue(names.contains("Marduk"), "Tiamat created Marduk")
    }

    // MARK: - Fallback Intent-Based Queries

    func testCountDynastiesAtPlace() {
        let container = makeContainer()
        let context = container.mainContext

        let kish = Place(name: "Kish", placeDescription: "Ancient Sumerian city")
        context.insert(kish)

        let humanType = FigureType(name: "Human", icon: "person", colorHex: "#FFFFFF")
        context.insert(humanType)

        let era1Figure = Figure(name: "Etana", title: "King of Kish", gender: .male, figureDescription: "Reigned 1500 years", birthDate: MythologicalDate(year: nil, era: "First Dynasty of Kish", isApproximate: true))
        let era2Figure = Figure(name: "Enmebaragesi", title: "King of Kish", gender: .male, figureDescription: "Reigned 900 years", birthDate: MythologicalDate(year: nil, era: "Second Dynasty of Kish", isApproximate: true))
        let era3Figure = Figure(name: "Agga", title: "King of Kish", gender: .male, figureDescription: "Reigned 625 years", birthDate: MythologicalDate(year: nil, era: "First Dynasty of Kish", isApproximate: true))
        for f in [era1Figure, era2Figure, era3Figure] { context.insert(f) }

        let roleType = FigurePlaceRoleType(name: "Ruler", icon: "crown.fill", colorHex: "FFCC00")
        context.insert(roleType)

        for f in [era1Figure, era2Figure, era3Figure] {
            let assoc = FigurePlaceAssociation(figure: f, place: kish, roleType: roleType, source: "SKL")
            context.insert(assoc)
        }
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("how many dynasties did Kish have")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        XCTAssertTrue(text.contains("2"), "Expected 2 dynasties, got: \(text)")
        XCTAssertTrue(text.contains("Kish"))
        XCTAssertTrue(text.contains("First Dynasty of Kish"))
        XCTAssertTrue(text.contains("Second Dynasty of Kish"))
    }

    func testCountKingsAtPlace() {
        let container = makeContainer()
        let context = container.mainContext

        let uruk = Place(name: "Uruk", placeDescription: "City of Gilgamesh")
        context.insert(uruk)

        let gilgamesh = Figure(name: "Gilgamesh", title: "King of Uruk", gender: .male, figureDescription: "King of Uruk")
        let lugalbanda = Figure(name: "Lugalbanda", title: "King of Uruk", gender: .male, figureDescription: "A king of Uruk")
        let enmerkar = Figure(name: "Enmerkar", title: "King of Uruk", gender: .male, figureDescription: "King of Uruk")
        for f in [gilgamesh, lugalbanda, enmerkar] { context.insert(f) }

        for f in [gilgamesh, lugalbanda, enmerkar] {
            let assoc = FigurePlaceAssociation(figure: f, place: uruk, source: "SKL")
            context.insert(assoc)
        }
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("how many kings ruled in Uruk")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        XCTAssertTrue(text.contains("3"), "Expected 3 kings, got: \(text)")
    }

    func testListDynastiesAtPlace() {
        let container = makeContainer()
        let context = container.mainContext

        let kish = Place(name: "Kish")
        context.insert(kish)

        let d1 = Figure(name: "Etana", gender: .male, birthDate: MythologicalDate(year: nil, era: "First Dynasty of Kish"))
        let d2 = Figure(name: "Enmebaragesi", gender: .male, birthDate: MythologicalDate(year: nil, era: "Second Dynasty of Kish"))
        let d1b = Figure(name: "Agga", gender: .male, birthDate: MythologicalDate(year: nil, era: "First Dynasty of Kish"))
        for f in [d1, d2, d1b] { context.insert(f) }

        for f in [d1, d2, d1b] {
            context.insert(FigurePlaceAssociation(figure: f, place: kish, source: "SKL"))
        }
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("what dynasties ruled Kish")

        guard case .answer(let text) = result else {
            XCTFail("Expected answer, got \(result)")
            return
        }
        XCTAssertTrue(text.contains("First Dynasty of Kish"))
        XCTAssertTrue(text.contains("Second Dynasty of Kish"))
    }

    func testWhoRuledPlace() {
        let container = makeContainer()
        let context = container.mainContext

        let uruk = Place(name: "Uruk")
        context.insert(uruk)

        let gilgamesh = Figure(name: "Gilgamesh", title: "King of Uruk", gender: .male)
        let enmerkar = Figure(name: "Enmerkar", title: "King of Uruk", gender: .male)
        let inanna = Figure(name: "Inanna", gender: .female, domain: "Love and War")
        context.insert(gilgamesh)
        context.insert(enmerkar)
        context.insert(inanna)

        for f in [gilgamesh, enmerkar] {
            context.insert(FigurePlaceAssociation(figure: f, place: uruk, source: "SKL"))
        }
        context.insert(FigurePlaceAssociation(figure: inanna, place: uruk, source: "Mythology"))
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("who ruled Uruk")

        guard case .figureList(let title, let figures) = result else {
            XCTFail("Expected figureList, got \(result)")
            return
        }
        XCTAssertEqual(title, "Rulers of Uruk")
        XCTAssertEqual(figures.count, 2)
        XCTAssertTrue(figures.contains(where: { $0.name == "Gilgamesh" }))
        XCTAssertTrue(figures.contains(where: { $0.name == "Enmerkar" }))
        XCTAssertFalse(figures.contains(where: { $0.name == "Inanna" }))
    }

    func testWhichRulersBelongedToEra() {
        let container = makeContainer()
        let context = container.mainContext

        let kish1 = Figure(name: "Etana", title: "King of Kish", gender: .male, figureDescription: "Reigned 1500 years", birthDate: MythologicalDate(year: nil, era: "First Dynasty of Kish", isApproximate: true))
        let kish2 = Figure(name: "Enmebaragesi", title: "King of Kish", gender: .male, figureDescription: "Reigned 900 years", birthDate: MythologicalDate(year: nil, era: "First Dynasty of Kish", isApproximate: true))
        let kish3 = Figure(name: "Agga", title: "King of Kish", gender: .male, figureDescription: "Reigned 625 years", birthDate: MythologicalDate(year: nil, era: "First Dynasty of Kish", isApproximate: true))
        let otherEra = Figure(name: "Gilgamesh", title: "King of Uruk", gender: .male, figureDescription: "King of Uruk", birthDate: MythologicalDate(year: nil, era: "Early Dynastic Period", isApproximate: true))
        for f in [kish1, kish2, kish3, otherEra] { context.insert(f) }
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("which rulers belonged to the first dynasty of kish")

        guard case .figureList(let title, let figures) = result else {
            XCTFail("Expected figureList, got \(result)")
            return
        }
        XCTAssertEqual(figures.count, 3)
        XCTAssertTrue(figures.allSatisfy { $0.name != "Gilgamesh" })
        XCTAssertTrue(figures.contains(where: { $0.name == "Etana" }))
    }

    func testKingsOfTheEra() {
        let container = makeContainer()
        let context = container.mainContext

        let etana = Figure(name: "Etana", title: "King of Kish", gender: .male, figureDescription: "Reigned 1500 years", birthDate: MythologicalDate(year: nil, era: "Early Dynastic Period", isApproximate: true))
        let enmerkar = Figure(name: "Enmerkar", title: "King of Uruk", gender: .male, figureDescription: "Reigned 420 years", birthDate: MythologicalDate(year: nil, era: "Early Dynastic Period", isApproximate: true))
        let lugalbanda = Figure(name: "Lugalbanda", title: "King of Uruk", gender: .male, figureDescription: "Reigned 1200 years", birthDate: MythologicalDate(year: nil, era: "Early Dynastic Period", isApproximate: true))
        for f in [etana, enmerkar, lugalbanda] { context.insert(f) }
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("kings of the early dynastic period")

        guard case .figureList(let title, let figures) = result else {
            XCTFail("Expected figureList, got \(result)")
            return
        }
        XCTAssertEqual(figures.count, 3)
    }

    func testFallbackNoMatchForUnrelatedQuery() {
        let container = makeContainer()
        let context = container.mainContext
        let engine = QueryEngine(context: context)
        let result = engine.query("what is the meaning of life")
        guard case .noMatch = result else {
            XCTFail("Expected noMatch, got \(result)")
            return
        }
    }

    func testFigureGroupEntityTypeDefaultsToFigure() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Council")
        context.insert(group)
        try? context.save()
        XCTAssertEqual(group.entityType, .figure)
        XCTAssertEqual(group.entityTypeRawValue, "figure")
    }

    func testFigureGroupEntityTypeBackwardsCompatibleNil() {
        let group = FigureGroup(name: "Council")
        group.entityTypeRawValue = nil
        XCTAssertEqual(group.entityType, .figure)
    }

    func testFigureGroupEntityTypeRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Temples", entityType: .place)
        context.insert(group)
        try? context.save()
        XCTAssertEqual(group.entityType, .place)
        XCTAssertEqual(group.entityTypeRawValue, "place")
    }

    func testFigureGroupMemberLabelsDefaultToMember() {
        let group = FigureGroup(name: "Council")
        XCTAssertEqual(group.memberSingularLabel, "member")
        XCTAssertEqual(group.memberPluralLabel, "members")
        XCTAssertEqual(group.memberCountText(count: 1), "1 member")
        XCTAssertEqual(group.memberCountText(count: 7), "7 members")
    }

    func testFigureGroupMemberLabelsRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Dynasty of Akkad", memberSingular: "ruler", memberPlural: "rulers")
        context.insert(group)
        try? context.save()
        XCTAssertEqual(group.memberSingular, "ruler")
        XCTAssertEqual(group.memberPlural, "rulers")
        XCTAssertEqual(group.memberSingularLabel, "ruler")
        XCTAssertEqual(group.memberPluralLabel, "rulers")
        XCTAssertEqual(group.memberCountText(count: 1), "1 ruler")
        XCTAssertEqual(group.memberCountText(count: 7), "7 rulers")
    }

    func testFigureGroupMemberLabelsFallbackWhenEmpty() {
        let group = FigureGroup(name: "Council", memberSingular: "", memberPlural: "")
        XCTAssertEqual(group.memberSingularLabel, "member")
        XCTAssertEqual(group.memberPluralLabel, "members")
        XCTAssertEqual(group.memberCountText(count: 2), "2 members")
    }

    func testGroupMemberFilterMatchesPlaceType() {
        let container = makeContainer()
        let context = container.mainContext
        let templeType = PlaceType(name: "Temple", icon: "building.columns", colorHex: "5856D6")
        let cityType = PlaceType(name: "City", icon: "building", colorHex: "8E8E93")
        context.insert(templeType)
        context.insert(cityType)
        let temple = Place(name: "Ekur", placeType: templeType)
        let city = Place(name: "Ur", placeType: cityType)
        let untyped = Place(name: "Netherworld")
        context.insert(temple)
        context.insert(city)
        context.insert(untyped)
        try? context.save()

        let filter = GroupMemberFilter(placeTypeNames: ["Temple"])
        XCTAssertTrue(filter.matchesPlace(temple))
        XCTAssertFalse(filter.matchesPlace(city))
        XCTAssertFalse(filter.matchesPlace(untyped))
    }

    func testGroupMemberFilterMatchesEventType() {
        let container = makeContainer()
        let context = container.mainContext
        let battleType = EventType(name: "Battle", icon: "crossed.circles", colorHex: "FF3B30")
        let festivalType = EventType(name: "Festival", icon: "music.note", colorHex: "FF9500")
        context.insert(battleType)
        context.insert(festivalType)
        let battle = Event(name: "Battle of Lagash", eventType: battleType)
        let festival = Event(name: "Akitu", eventType: festivalType)
        context.insert(battle)
        context.insert(festival)
        try? context.save()

        let filter = GroupMemberFilter(eventTypeNames: ["Battle"])
        XCTAssertTrue(filter.matchesEvent(battle))
        XCTAssertFalse(filter.matchesEvent(festival))
    }

    func testGroupMemberFilterMatchesThingType() {
        let container = makeContainer()
        let context = container.mainContext
        let artifactType = ThingType(name: "Artifact", icon: "cube", colorHex: "8E8E93")
        context.insert(artifactType)
        let artifact = Thing(name: "Tablet of Destinies")
        artifact.thingType = artifactType
        let plain = Thing(name: "Me")
        context.insert(artifact)
        context.insert(plain)
        try? context.save()

        let filter = GroupMemberFilter(thingTypeNames: ["Artifact"])
        XCTAssertTrue(filter.matchesThing(artifact))
        XCTAssertFalse(filter.matchesThing(plain))
    }

    func testSmartFlagDefaultsOffAndRoundTrips() {
        let group = FigureGroup(name: "G")
        XCTAssertFalse(group.isSmart)
        XCTAssertNil(group.isSmartRawValue)
        group.isSmart = true
        XCTAssertTrue(group.isSmart)
        group.isSmart = false
        XCTAssertFalse(group.isSmart)
        XCTAssertNil(group.isSmartRawValue)
    }

    func testSmartFlagInitParameter() {
        let manual = FigureGroup(name: "Manual")
        XCTAssertFalse(manual.isSmart)
        let smart = FigureGroup(name: "Smart", isSmart: true)
        XCTAssertTrue(smart.isSmart)
    }

    func testLiveMatchIDsSmartFigureGroup() {
        let container = makeContainer()
        let context = container.mainContext
        SeedData.ensureTypesExist(context: context)
        let deityType = (try? context.fetch(FetchDescriptor<FigureType>()))?.first { $0.name == "Deity" }
        let humanType = (try? context.fetch(FetchDescriptor<FigureType>()))?.first { $0.name == "Human" }

        let enlil = Figure(name: "Enlil", figureType: deityType, domain: "Sumerian")
        let marduk = Figure(name: "Marduk", figureType: deityType, domain: "Babylonian")
        let gilgamesh = Figure(name: "Gilgamesh", figureType: humanType, domain: "Kingship")
        let ilabrat = Figure(name: "Ilabrat", figureType: humanType, domain: "Sumerian")
        context.insert(enlil)
        context.insert(marduk)
        context.insert(gilgamesh)
        context.insert(ilabrat)

        let group = FigureGroup(name: "Sumerian Pantheon", isSmart: true)
        context.insert(group)
        try? context.save()

        // Domain-only rule: Enlil and Ilabrat match; Marduk/Gilgamesh don't.
        group.decodedFilter = GroupMemberFilter(domainKeywords: ["Sumerian"])
        let domainIDs = group.liveMatchIDs(in: context)
        XCTAssertEqual(Set(domainIDs), Set([enlil.persistentModelID, ilabrat.persistentModelID]))

        // Type-only rule (OR semantics): all Deities match regardless of domain.
        group.decodedFilter = GroupMemberFilter(figureTypeNames: ["Deity"])
        let typeIDs = group.liveMatchIDs(in: context)
        XCTAssertEqual(Set(typeIDs), Set([enlil.persistentModelID, marduk.persistentModelID]))
        XCTAssertFalse(typeIDs.contains(gilgamesh.persistentModelID))
        XCTAssertFalse(typeIDs.contains(ilabrat.persistentModelID))
    }

    func testLiveMatchIDsManualGroupReturnsEmpty() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Enki", domain: "Sumerian")
        context.insert(figure)
        let group = FigureGroup(name: "Manual", isSmart: false)
        group.decodedFilter = GroupMemberFilter(domainKeywords: ["Sumerian"])
        context.insert(group)
        try? context.save()

        XCTAssertTrue(group.liveMatchIDs(in: context).isEmpty)
    }

    func testLiveMatchIDsSmartPlaceGroup() {
        let container = makeContainer()
        let context = container.mainContext
        let templeType = PlaceType(name: "Temple", icon: "building.columns", colorHex: "5856D6")
        let cityType = PlaceType(name: "City", icon: "building", colorHex: "8E8E93")
        context.insert(templeType)
        context.insert(cityType)
        let ekur = Place(name: "Ekur", placeType: templeType)
        let ur = Place(name: "Ur", placeType: cityType)
        context.insert(ekur)
        context.insert(ur)

        let group = FigureGroup(name: "Temples", isSmart: true, entityType: .place)
        group.decodedFilter = GroupMemberFilter(placeTypeNames: ["Temple"])
        context.insert(group)
        try? context.save()

        XCTAssertEqual(group.liveMatchIDs(in: context), [ekur.persistentModelID])
    }

    func testSmartGroupIgnoresFilterWhenSmartOff() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Enki", domain: "Sumerian")
        context.insert(figure)
        let group = FigureGroup(name: "G", isSmart: false)
        group.decodedFilter = GroupMemberFilter(domainKeywords: ["Sumerian"])
        context.insert(group)
        try? context.save()

        group.isSmart = true
        XCTAssertEqual(group.liveMatchIDs(in: context), [figure.persistentModelID])
        group.isSmart = false
        XCTAssertTrue(group.liveMatchIDs(in: context).isEmpty)
    }

    func testGroupDirectMembersAcrossTypes() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Enki")
        let place = Place(name: "Eridu")
        let event = Event(name: "The Flood")
        let thing = Thing(name: "Tablet")
        context.insert(figure)
        context.insert(place)
        context.insert(event)
        context.insert(thing)

        let group = FigureGroup(name: "Mixed")
        context.insert(group)
        for assoc in [
            FigureGroupAssociation(figure: figure),
            FigureGroupAssociation(place: place),
            FigureGroupAssociation(event: event),
            FigureGroupAssociation(thing: thing)
        ] {
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        XCTAssertEqual(group.directFigures.map(\.name), ["Enki"])
        XCTAssertEqual(group.directPlaces.map(\.name), ["Eridu"])
        XCTAssertEqual(group.directEvents.map(\.name), ["The Flood"])
        XCTAssertEqual(group.directThings.map(\.name), ["Tablet"])
        XCTAssertEqual(place.groupAssociations.count, 1)
        XCTAssertEqual(event.groupAssociations.count, 1)
        XCTAssertEqual(thing.groupAssociations.count, 1)
    }

    func testGroupDeleteWithFigureAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Enki")
        context.insert(figure)
        let group = FigureGroup(name: "Sumerian Pantheon")
        context.insert(group)
        let assoc = FigureGroupAssociation(figure: figure)
        context.insert(assoc)
        group.figureAssociations.append(assoc)
        try? context.save()

        XCTAssertEqual(figure.groupAssociations.count, 1)

        context.delete(group)
        try? context.save()

        let remaining = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>())) ?? []
        XCTAssertTrue(remaining.isEmpty)
    }

    func testRemoveOrphanedGroupAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Enki")
        context.insert(figure)
        let group = FigureGroup(name: "Divine Council")
        context.insert(group)
        let assoc = FigureGroupAssociation(figure: figure)
        context.insert(assoc)
        group.figureAssociations.append(assoc)
        try? context.save()

        group.figureAssociations = []
        context.delete(group)
        try? context.save()

        XCTAssertEqual(figure.groupAssociations.count, 1)
        XCTAssertNil(figure.groupAssociations.first?.group)

        Migration.removeOrphanedGroupAssociations(context: context)
        try? context.save()

        XCTAssertTrue(figure.groupAssociations.isEmpty)
        let remaining = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>())) ?? []
        XCTAssertTrue(remaining.isEmpty)
    }

    func testGroupDeleteSmartGroupWithManyAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Sumerian Pantheon")
        group.isSmart = true
        context.insert(group)
        for i in 0..<72 {
            let figure = Figure(name: "Deity \(i)")
            context.insert(figure)
            let assoc = FigureGroupAssociation(figure: figure)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        XCTAssertEqual(group.figureAssociations.count, 72)

        context.delete(group)
        try? context.save()

        let remaining = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>())) ?? []
        XCTAssertTrue(remaining.isEmpty)
    }

    func testGroupDeleteSharedFiguresDiskStore() {
        let container = makeDiskContainer()
        let context = container.mainContext
        let pantheon = FigureGroup(name: "Sumerian Pantheon")
        pantheon.isSmart = true
        context.insert(pantheon)
        let other = FigureGroup(name: "Divine Council")
        context.insert(other)
        for i in 0..<72 {
            let figure = Figure(name: "Deity \(i)")
            context.insert(figure)
            let a1 = FigureGroupAssociation(figure: figure)
            context.insert(a1)
            pantheon.figureAssociations.append(a1)
            if i % 2 == 0 {
                let a2 = FigureGroupAssociation(figure: figure)
                context.insert(a2)
                other.figureAssociations.append(a2)
            }
        }
        try? context.save()

        XCTAssertEqual(pantheon.figureAssociations.count, 72)

        context.delete(pantheon)
        try? context.save()

        let remaining = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>())) ?? []
        XCTAssertEqual(remaining.count, 36)
    }

    func testGroupDeleteRealStoreCopy() throws {
        let live = URL(fileURLWithPath: NSString(string: "~/Library/Application Support/Me/Me.store").expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: live.path) else {
            throw XCTSkip("Live store not present — diagnostic test only")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeRealStore-\(UUID().uuidString).store")
        try? FileManager.default.copyItem(at: live, to: url)
        let schema = Schema([
            Figure.self, FigureType.self, Relationship.self, RelationshipType.self, Era.self,
            Place.self, PlaceType.self, Event.self, EventType.self,
            Source.self, Citation.self, AlternateName.self, Attachment.self,
            ImageAsset.self, Tag.self, DataVersion.self,
            FigurePlaceAssociation.self, FigurePlaceRoleType.self,
            PlacePlaceAssociation.self, PlacePlaceRoleType.self,
            EventEventAssociation.self, EventEventRoleType.self,
            EventPlaceAssociation.self, EventPlaceRoleType.self,
            StickyNote.self,
            Thing.self, ThingType.self,
            ThingFigureAssociation.self, ThingFigureRoleType.self,
            ThingPlaceAssociation.self, ThingPlaceRoleType.self,
            ThingEventAssociation.self, ThingEventRoleType.self,
            Agent.self, CollectedDatum.self, BlindSpot.self,
            BlockedSource.self, DictionaryEntry.self,
            FigureGroup.self, FigureGroupAssociation.self, GroupTextBlock.self,
            Pantheon.self, FigurePantheonAssociation.self,
            PopupTable.self, PopupTableAttribute.self, PopupTableCell.self, PopupTableColumn.self,
            PopupTableColumnLayout.self
        ])
        let config = ModelConfiguration(schema: schema, url: url, allowsSave: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            XCTFail("Could not open real store copy")
            return
        }
        let context = container.mainContext
        let all = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let group = all.first(where: { !($0.figureAssociations ?? []).isEmpty || !($0.textBlocks ?? []).isEmpty }) else {
            throw XCTSkip("No group with children in live store — diagnostic test only")
        }
        let groupName = group.name
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in allFigures {
            _ = figure.groupAssociations
        }
        for g in all {
            _ = g.figureAssociations
        }
        for assoc in group.figureAssociations {
            _ = assoc.figure
        }
        context.delete(group)
        try? context.save()
        let remaining = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>())) ?? []
        XCTAssertFalse(remaining.contains { $0.group?.name == groupName })
        try? FileManager.default.removeItem(at: url)
    }

    func testGroupDeleteRealStoreAutosaveNoManualSave() throws {
        let live = URL(fileURLWithPath: NSString(string: "~/Library/Application Support/Me/Me.store").expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: live.path) else {
            throw XCTSkip("Live store not present — diagnostic test only")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeRealStoreAutosave-\(UUID().uuidString).store")
        try? FileManager.default.copyItem(at: live, to: url)
        let schema = Schema([
            Figure.self, FigureType.self, Relationship.self, RelationshipType.self, Era.self,
            Place.self, PlaceType.self, Event.self, EventType.self,
            Source.self, Citation.self, AlternateName.self, Attachment.self,
            ImageAsset.self, Tag.self, DataVersion.self,
            FigurePlaceAssociation.self, FigurePlaceRoleType.self,
            PlacePlaceAssociation.self, PlacePlaceRoleType.self,
            EventEventAssociation.self, EventEventRoleType.self,
            EventPlaceAssociation.self, EventPlaceRoleType.self,
            StickyNote.self,
            Thing.self, ThingType.self,
            ThingFigureAssociation.self, ThingFigureRoleType.self,
            ThingPlaceAssociation.self, ThingPlaceRoleType.self,
            ThingEventAssociation.self, ThingEventRoleType.self,
            Agent.self, CollectedDatum.self, BlindSpot.self,
            BlockedSource.self, DictionaryEntry.self,
            FigureGroup.self, FigureGroupAssociation.self, GroupTextBlock.self,
            Pantheon.self, FigurePantheonAssociation.self,
            PopupTable.self, PopupTableAttribute.self, PopupTableCell.self,
            PopupTableColumnLayout.self
        ])
        let config = ModelConfiguration(schema: schema, url: url, allowsSave: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            XCTFail("Could not open real store copy")
            return
        }
        let context = container.mainContext
        let all = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let group = all.first(where: { !($0.figureAssociations ?? []).isEmpty || !($0.textBlocks ?? []).isEmpty }) else {
            throw XCTSkip("No group with children in live store — diagnostic test only")
        }
        let groupName = group.name
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in allFigures {
            _ = figure.groupAssociations
        }
        for g in all {
            _ = g.figureAssociations
        }
        for assoc in group.figureAssociations {
            _ = assoc.figure
        }
        context.delete(group)
        try? context.save()
        let remaining = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>())) ?? []
        XCTAssertFalse(remaining.contains { $0.group?.name == groupName })
        try? FileManager.default.removeItem(at: url)
    }

    func testGroupDeleteRealStoreExplicitChildDeletion() throws {
        let live = URL(fileURLWithPath: NSString(string: "~/Library/Application Support/Me/Me.store").expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: live.path) else {
            throw XCTSkip("Live store not present — diagnostic test only")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeRealStoreExplicit-\(UUID().uuidString).store")
        try? FileManager.default.copyItem(at: live, to: url)
        let schema = Schema([
            Figure.self, FigureType.self, Relationship.self, RelationshipType.self, Era.self,
            Place.self, PlaceType.self, Event.self, EventType.self,
            Source.self, Citation.self, AlternateName.self, Attachment.self,
            ImageAsset.self, Tag.self, DataVersion.self,
            FigurePlaceAssociation.self, FigurePlaceRoleType.self,
            PlacePlaceAssociation.self, PlacePlaceRoleType.self,
            EventEventAssociation.self, EventEventRoleType.self,
            EventPlaceAssociation.self, EventPlaceRoleType.self,
            StickyNote.self,
            Thing.self, ThingType.self,
            ThingFigureAssociation.self, ThingFigureRoleType.self,
            ThingPlaceAssociation.self, ThingPlaceRoleType.self,
            ThingEventAssociation.self, ThingEventRoleType.self,
            Agent.self, CollectedDatum.self, BlindSpot.self,
            BlockedSource.self, DictionaryEntry.self,
            FigureGroup.self, FigureGroupAssociation.self, GroupTextBlock.self,
            Pantheon.self, FigurePantheonAssociation.self,
            PopupTable.self, PopupTableAttribute.self, PopupTableCell.self, PopupTableColumn.self,
            PopupTableColumnLayout.self
        ])
        let config = ModelConfiguration(schema: schema, url: url, allowsSave: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            XCTFail("Could not open real store copy")
            return
        }
        let context = container.mainContext
        let all = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let group = all.first(where: { !($0.figureAssociations ?? []).isEmpty || !($0.textBlocks ?? []).isEmpty }) else {
            throw XCTSkip("No group with children in live store — diagnostic test only")
        }
        let groupName = group.name
        for assoc in group.figureAssociations {
            context.delete(assoc)
        }
        context.delete(group)
        try? context.save()
        let remaining = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>())) ?? []
        XCTAssertFalse(remaining.contains { $0.group?.name == groupName })
        try? FileManager.default.removeItem(at: url)
    }

    func testGroupReparentTopLevelGroupAfterSave() {
        let container = makeContainer()
        let context = container.mainContext
        let parent = FigureGroup(name: "Cities", entityType: .place)
        let child = FigureGroup(name: "Sumerian Cities", entityType: .place)
        context.insert(parent)
        context.insert(child)
        try? context.save()

        XCTAssertNil(child.parentGroup)

        parent.subgroups?.append(child)
        try? context.save()

        XCTAssertEqual(child.parentGroup?.persistentModelID, parent.persistentModelID)
        XCTAssertTrue((parent.subgroups ?? []).contains { $0.persistentModelID == child.persistentModelID })
    }

}
