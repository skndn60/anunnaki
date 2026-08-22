import XCTest
import SwiftData
@testable import MeCore

@MainActor
final class MeCoreTests: XCTestCase {
    private func makeContainer() -> ModelContainer {
        _makeContainer(isDisk: false)
    }

    private func makeDiskContainer() -> ModelContainer {
        _makeContainer(isDisk: true)
    }

    private func _makeContainer(isDisk: Bool) -> ModelContainer {
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
            PopupTable.self, PopupTableAttribute.self, PopupTableCell.self, PopupTableColumn.self
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

    private func relType(_ name: String, _ context: ModelContext) -> RelationshipType? {
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

    func testQueryEngineEventDateRangeYes() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let flood = Event(name: "The Great Flood", date: MythologicalDate(startYear: -30000, endYear: -24000))
        context.insert(flood)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("Was the Great Flood between 30000 and 24000 BCE?")
        guard case .answer(let text) = result else {
            XCTFail("Expected answer string, got \(result)")
            return
        }
        XCTAssertTrue(text.hasPrefix("Yes"))
    }

    func testQueryEngineEventDateRangeNo() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let flood = Event(name: "The Great Flood", date: MythologicalDate(startYear: -30000, endYear: -24000))
        context.insert(flood)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("Was the Great Flood between 1000 and 500 BCE?")
        guard case .answer(let text) = result else {
            XCTFail("expected answer string, got \(result)")
            return
        }
        XCTAssertTrue(text.hasPrefix("No"))
    }

    func testQueryEngineFigureDateRangeFrom() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let figure = Figure(name: "Gilgamesh", gender: .male, birthDate: MythologicalDate(startYear: -2900, endYear: -2700))
        context.insert(figure)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("Was Gilgamesh alive from 2500 to 2100 BCE?")
        guard case .answer(let text) = result else {
            XCTFail("expected answer string, got \(result)")
            return
        }
        XCTAssertTrue(text.hasPrefix("No"))
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

    private struct TestFixture {
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

    private func makeFixture() -> TestFixture {
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
            PopupTable.self, PopupTableAttribute.self, PopupTableCell.self, PopupTableColumn.self
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
            PopupTable.self, PopupTableAttribute.self, PopupTableCell.self
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
            PopupTable.self, PopupTableAttribute.self, PopupTableCell.self, PopupTableColumn.self
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

    // MARK: - Group ordering (sortMode / orderIndex)

    func testGroupSortModeDefaultsToAlphabetical() {
        let group = FigureGroup(name: "Council")
        XCTAssertEqual(group.sortMode, .alphabetical)
    }

    func testGroupSortModeBackwardsCompatibleNil() {
        let group = FigureGroup(name: "Council", sortMode: .ordered)
        group.sortModeRawValue = nil
        XCTAssertEqual(group.sortMode, .alphabetical)
    }

    func testGroupSortModeRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings", sortMode: .ordered)
        context.insert(group)
        try? context.save()
        XCTAssertEqual(group.sortMode, .ordered)
        XCTAssertEqual(group.sortModeRawValue, "ordered")
    }

    private func makeFigureGroupWithMembers(context: ModelContext, names: [String]) -> FigureGroup {
        let group = FigureGroup(name: "Test")
        context.insert(group)
        for name in names {
            let f = Figure(name: name)
            context.insert(f)
            let assoc = FigureGroupAssociation(figure: f)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        return group
    }

    private func addSubgroup(_ sub: FigureGroup, to group: FigureGroup) {
        if group.subgroups == nil { group.subgroups = [] }
        group.subgroups?.append(sub)
    }

    func testSortedAssociationsAlphabeticalByDefault() {
        let container = makeContainer()
        let context = container.mainContext
        let group = makeFigureGroupWithMembers(context: context, names: ["Ziusudra", "Enki", "Abzu"])
        try? context.save()

        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["Abzu", "Enki", "Ziusudra"])
    }

    func testSortedAssociationsOrderedByOrderIndex() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings", sortMode: .ordered)
        context.insert(group)
        let alulu = Figure(name: "Alulim")
        let alalgar = Figure(name: "Alalgar")
        let ziusudra = Figure(name: "Ziusudra")
        for f in [alulu, alalgar, ziusudra] { context.insert(f) }
        for (i, f) in [alalgar, ziusudra, alulu].enumerated() {
            let assoc = FigureGroupAssociation(figure: f, orderIndex: i)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["Alalgar", "Ziusudra", "Alulim"])
    }

    func testSortedAssociationsOrderIndexDefersToNameWhenNil() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings", sortMode: .ordered)
        context.insert(group)
        // C has an explicit high orderIndex; A and B are nil (tie-break by name).
        let a = Figure(name: "A")
        let b = Figure(name: "B")
        let c = Figure(name: "C")
        for f in [a, b, c] { context.insert(f) }
        for assoc in [
            FigureGroupAssociation(figure: a),
            FigureGroupAssociation(figure: b),
            FigureGroupAssociation(figure: c, orderIndex: 99)
        ] {
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["C", "A", "B"])
    }

    func testSetSortModeOrderedSeedsSequentialIndexes() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings")
        context.insert(group)
        let a = Figure(name: "Ziu")
        let b = Figure(name: "Anu")
        for f in [a, b] { context.insert(f) }
        for assoc in [FigureGroupAssociation(figure: a), FigureGroupAssociation(figure: b)] {
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        group.setSortMode(.ordered)
        let indexes = group.figureAssociations.compactMap(\.orderIndex).sorted()
        XCTAssertEqual(indexes, [0, 1])
        XCTAssertEqual(group.sortMode, .ordered)
    }

    func testMoveAssociationSwapsOrder() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "A")
        let b = Figure(name: "B")
        let c = Figure(name: "C")
        for f in [a, b, c] { context.insert(f) }
        let assocs = [FigureGroupAssociation(figure: a, orderIndex: 0),
                      FigureGroupAssociation(figure: b, orderIndex: 1),
                      FigureGroupAssociation(figure: c, orderIndex: 2)]
        for assoc in assocs { context.insert(assoc); group.figureAssociations.append(assoc) }
        try? context.save()

        // Move C (at index 2) up by one -> [A, C, B]
        group.moveAssociation(assocs[2], direction: -1)
        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["A", "C", "B"])

        // Moving top member up is a no-op.
        group.moveAssociation(assocs[0], direction: -1)
        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["A", "C", "B"])
    }

    func testSortedSubgroupsOrderedByOrderIndex() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page", sortMode: .ordered)
        context.insert(group)
        let one = FigureGroup(name: "One", orderIndex: 1)
        let zero = FigureGroup(name: "Zero", orderIndex: 0)
        let two = FigureGroup(name: "Two", orderIndex: 2)
        for sub in [two, zero, one] {
            context.insert(sub)
            addSubgroup(sub, to: group)
        }
        try? context.save()

        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["Zero", "One", "Two"])
    }

    func testSortedSubgroupsNameTieBreakWhenNil() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page", sortMode: .ordered)
        context.insert(group)
        // No explicit orderIndex: tie-break by name.
        let b = FigureGroup(name: "Beta")
        let a = FigureGroup(name: "Alpha")
        for sub in [b, a] {
            context.insert(sub)
            addSubgroup(sub, to: group)
        }
        try? context.save()

        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["Alpha", "Beta"])
    }

    func testSetSortModeOrderedSeedsSubgroupIndexes() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page")
        context.insert(group)
        let zeta = FigureGroup(name: "Zeta")
        let alpha = FigureGroup(name: "Alpha")
        for sub in [zeta, alpha] {
            context.insert(sub)
            addSubgroup(sub, to: group)
        }
        try? context.save()

        group.setSortMode(.ordered)
        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["Alpha", "Zeta"])
        XCTAssertEqual(alpha.orderIndex, 0)
        XCTAssertEqual(zeta.orderIndex, 1)
    }

    func testMoveSubgroupSwapsOrder() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page", sortMode: .ordered)
        context.insert(group)
        let a = FigureGroup(name: "A", orderIndex: 0)
        let b = FigureGroup(name: "B", orderIndex: 1)
        let c = FigureGroup(name: "C", orderIndex: 2)
        for sub in [a, b, c] {
            context.insert(sub)
            addSubgroup(sub, to: group)
        }
        try? context.save()

        // Move C (at index 2) up by one -> [A, C, B]
        group.moveSubgroup(c, direction: -1)
        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["A", "C", "B"])

        // Moving top subgroup up is a no-op.
        group.moveSubgroup(a, direction: -1)
        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["A", "C", "B"])

        // Renumbering is contiguous after the swap.
        XCTAssertEqual(group.sortedSubgroups.map(\.orderIndex), [0, 1, 2])
    }

    func testApplyRegnalOrderAcrossEras() {
        let container = makeContainer()
        let context = container.mainContext
        let dynastyA = Era(name: "First dynasty of Kish", orderIndex: 1)
        let dynastyB = Era(name: "First dynasty of Uruk", orderIndex: 2)
        context.insert(dynastyA)
        context.insert(dynastyB)

        let group = FigureGroup(name: "SKL", kind: .skl)
        context.insert(group)
        // Grouped by era; within each era the in-era sequence is figure.orderIndex.
        let rulers: [(String, Int, Era)] = [
            ("Etana", 3, dynastyA),
            ("Balih", 1, dynastyA),
            ("Meskiag", 0, dynastyB),
            ("Enmerkar", 1, dynastyB),
        ]
        var assocs: [FigureGroupAssociation] = []
        for (name, seq, era) in rulers {
            let f = Figure(name: name, orderIndex: seq)
            f.era = era
            context.insert(f)
            let assoc = FigureGroupAssociation(figure: f)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
            assocs.append(assoc)
        }
        try? context.save()

        group.applyRegnalOrder()
        group.sortMode = .ordered
        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name },
                       ["Balih", "Etana", "Meskiag", "Enmerkar"])
    }

    func testGroupTextBlockSpineInterleavesMembersAndText() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "Alpha")
        let b = Figure(name: "Beta")
        context.insert(a); context.insert(b)
        let ass1 = FigureGroupAssociation(figure: a, orderIndex: 0)
        let ass2 = FigureGroupAssociation(figure: b, orderIndex: 2)
        context.insert(ass1); context.insert(ass2)
        group.figureAssociations.append(ass1); group.figureAssociations.append(ass2)
        // A prose block sits between member 0 and member 2.
        let block = GroupTextBlock(title: "Aside", text: "Prose", orderIndex: 1)
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        let spine = group.memberTextSpine
        XCTAssertEqual(spine.count, 3)
        switch spine[0] { case .member(let m): XCTAssertEqual(m.figure?.name, "Alpha"); case .text: XCTFail("expected member") }
        switch spine[1] { case .text(let t): XCTAssertEqual(t.title, "Aside"); case .member: XCTFail("expected text") }
        switch spine[2] { case .member(let m): XCTAssertEqual(m.figure?.name, "Beta"); case .text: XCTFail("expected member") }
    }

    func testGroupTextBlockSummaryRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter")
        context.insert(group)
        let block = GroupTextBlock(
            title: "Atrahasis Tablet I",
            text: "Long full prose body.",
            summary: "The Anunnaki assign the Igigi their digging work.",
            summaryRichText: nil
        )
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        let fetched = try? context.fetch(FetchDescriptor<GroupTextBlock>()).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.summary, "The Anunnaki assign the Igigi their digging work.")
        XCTAssertNil(fetched?.summaryRichText)
        // Defaults for blocks without a summary: nil, and init default is nil.
        let plain = GroupTextBlock(title: "Plain", text: "No summary")
        XCTAssertNil(plain.summary)
        XCTAssertNil(plain.summaryRichText)
    }

    func testGroupMemberTextSpineMoveRenumbers() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "Alpha")
        let b = Figure(name: "Beta")
        context.insert(a); context.insert(b)
        let ass1 = FigureGroupAssociation(figure: a, orderIndex: 0)
        let ass2 = FigureGroupAssociation(figure: b, orderIndex: 2)
        context.insert(ass1); context.insert(ass2)
        group.figureAssociations.append(ass1); group.figureAssociations.append(ass2)
        let block = GroupTextBlock(title: "Aside", text: "Prose", orderIndex: 1)
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        // Move the text block up so it precedes Alpha entirely.
        let item = group.memberTextSpine[1] // text
        group.moveMemberTextItem(item, direction: -1)
        XCTAssertEqual(block.orderIndex, 0)
        XCTAssertEqual(ass1.orderIndex, 1)
        XCTAssertEqual(ass2.orderIndex, 2)
        XCTAssertEqual(group.memberTextSpine.compactMap { $0.name },
                       ["Aside", "Alpha", "Beta"])
    }

    func testGroupMemberTextSpineMoveToIndex() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "Alpha")
        let b = Figure(name: "Beta")
        let c = Figure(name: "Gamma")
        context.insert(a); context.insert(b); context.insert(c)
        let ass1 = FigureGroupAssociation(figure: a, orderIndex: 0)
        let ass2 = FigureGroupAssociation(figure: b, orderIndex: 1)
        let ass3 = FigureGroupAssociation(figure: c, orderIndex: 2)
        context.insert(ass1); context.insert(ass2); context.insert(ass3)
        group.figureAssociations.append(ass1); group.figureAssociations.append(ass2); group.figureAssociations.append(ass3)
        try? context.save()

        // Move Alpha (index 0) to the end (index 2).
        group.moveMemberTextItem(.member(ass1), toIndex: 2)
        XCTAssertEqual(group.memberTextSpine.compactMap { $0.name }, ["Beta", "Gamma", "Alpha"])
        XCTAssertEqual([ass2.orderIndex, ass3.orderIndex, ass1.orderIndex], [0, 1, 2])

        // Move Gamma (now index 1) to the front (index 0).
        group.moveMemberTextItem(.member(ass3), toIndex: 0)
        XCTAssertEqual(group.memberTextSpine.compactMap { $0.name }, ["Gamma", "Beta", "Alpha"])
        XCTAssertEqual([ass3.orderIndex, ass2.orderIndex, ass1.orderIndex], [0, 1, 2])
    }

    func testGroupMemberTextSpineCanMoveUsesSpinePosition() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "Alpha")
        let b = Figure(name: "Beta")
        context.insert(a); context.insert(b)
        let ass1 = FigureGroupAssociation(figure: a, orderIndex: 0)
        let ass2 = FigureGroupAssociation(figure: b, orderIndex: 2)
        context.insert(ass1); context.insert(ass2)
        group.figureAssociations.append(ass1); group.figureAssociations.append(ass2)
        let block = GroupTextBlock(title: "Aside", text: "Prose", orderIndex: 1)
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        // The text block has spine index 1 (between Alpha and Beta). Even though it's the
        // ONLY text block (text-only arrows would be disabled), it can move up and down
        // within the unified spine.
        XCTAssertEqual(group.memberTextSpine.map { $0.name }, ["Alpha", "Aside", "Beta"])
        XCTAssertTrue(group.canMoveMemberTextItem(.text(block), direction: -1))
        XCTAssertTrue(group.canMoveMemberTextItem(.text(block), direction: 1))
        // First member can't move up (anyshift), last member can't move down.
        XCTAssertFalse(group.canMoveMemberTextItem(.member(ass1), direction: -1))
        XCTAssertTrue(group.canMoveMemberTextItem(.member(ass1), direction: 1))
        XCTAssertFalse(group.canMoveMemberTextItem(.member(ass2), direction: 1))
        // Out-of-spine items report false.
        let other = GroupTextBlock(title: "Elsewhere", text: "")
        context.insert(other)
        XCTAssertFalse(group.canMoveMemberTextItem(.text(other), direction: -1))
    }

    func testGroupMemberTextSpineNilOrderDefersByName() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page", sortMode: .ordered)
        context.insert(group)
        let z = Figure(name: "Zed")
        context.insert(z)
        let ass = FigureGroupAssociation(figure: z, orderIndex: nil)
        context.insert(ass)
        group.figureAssociations.append(ass)
        let block = GroupTextBlock(title: "Alpha", text: "P", orderIndex: nil)
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        // Nil orderIndex ties break by name ("Alpha" < "Zed").
        XCTAssertEqual(group.memberTextSpine.map { $0.name }, ["Alpha", "Zed"])
    }

func testRegnalKeyOrdersEventsByDate() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Events", entityType: .event)
        context.insert(group)
        let later = Event(name: "Treaty", date: MythologicalDate(year: -1200))
        let earlier = Event(name: "Foundation", date: MythologicalDate(year: -1500))
        context.insert(later)
        context.insert(earlier)
        for assoc in [FigureGroupAssociation(event: later), FigureGroupAssociation(event: earlier)] {
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        XCTAssertLessThan(FigureGroup.regnalKey(FigureGroupAssociation(event: earlier)),
                          FigureGroup.regnalKey(FigureGroupAssociation(event: later)))
    }

    func testGroupAssociationOrderIndexRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Enki")
        context.insert(figure)
        let assoc = FigureGroupAssociation(figure: figure, orderIndex: 3)
        context.insert(assoc)
        try? context.save()
        XCTAssertEqual(assoc.orderIndex, 3)
    }

    // MARK: - Group aggregation

    func testGroupAggregationCodableRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "First Dynasty of Ur")
        context.insert(group)
        group.decodedAggregation = GroupAggregation(
            operation: .sum,
            target: .reignYears,
            label: "Total listed reign"
        )
        try? context.save()

        XCTAssertEqual(group.decodedAggregation?.operation, .sum)
        XCTAssertEqual(group.decodedAggregation?.target, .reignYears)
        XCTAssertEqual(group.decodedAggregation?.label, "Total listed reign")
        XCTAssertNotNil(group.aggregationRawValue)
    }

    func testGroupAggregationBackwardsCompatibleNil() {
        let group = FigureGroup(name: "Council")
        XCTAssertNil(group.decodedAggregation)
        group.decodedAggregation = nil
        XCTAssertNil(group.aggregationRawValue)
    }

    func testGroupAggregationSumReignYears() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "First Dynasty of Ur")
        context.insert(group)
        let kings = [
            Figure(name: "Mesannepada", figureDescription: "Reigned 80 years. (Listed reign: 80 years.)"),
            Figure(name: "Meshkiang-nanna", figureDescription: "Reigned 36 years."),
            Figure(name: "Elulu", figureDescription: "Reigned 25 years."),
        ]
        for king in kings {
            context.insert(king)
            let assoc = FigureGroupAssociation(figure: king)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        let agg = GroupAggregation(operation: .sum, target: .reignYears)
        let result = agg.compute(in: group)
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?.sum, 141)
        XCTAssertNil(result?.average)
        XCTAssertEqual(agg.title, "Total listed reign")
        XCTAssertEqual(agg.formattedValue(for: result!), "141 years")
    }

    func testGroupAggregationAverageLifespan() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Long-lived Rulers")
        context.insert(group)
        let a = Figure(name: "A", birthDate: MythologicalDate(year: -2400), deathDate: MythologicalDate(year: -2300))
        let b = Figure(name: "B", birthDate: MythologicalDate(year: -2000), deathDate: MythologicalDate(year: -1960))
        context.insert(a)
        context.insert(b)
        for figure in [a, b] {
            let assoc = FigureGroupAssociation(figure: figure)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        let agg = GroupAggregation(operation: .average, target: .lifespan)
        let result = agg.compute(in: group)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?.average ?? 0, 70, accuracy: 0.001)
        XCTAssertEqual(agg.title, "Average lifespan")
        XCTAssertEqual(agg.formattedValue(for: result!), "70 years")
    }

    func testGroupAggregationEventYearSum() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Akkad Battles", entityType: .event)
        context.insert(group)
        let events = [
            Event(name: "Fall of Kish", date: MythologicalDate(year: -2300)),
            Event(name: "Fall of Uruk", date: MythologicalDate(year: -2100)),
        ]
        for event in events {
            context.insert(event)
            let assoc = FigureGroupAssociation(event: event)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        let agg = GroupAggregation(operation: .sum, target: .eventYear)
        let result = agg.compute(in: group)
        XCTAssertEqual(result?.sum, -4400)
        XCTAssertEqual(agg.formattedValue(for: result!), "4,400 BCE")
        XCTAssertEqual(agg.title, "Total event date")
    }

    func testGroupAggregationIgnoresMissingData() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings")
        context.insert(group)
        let withReign = Figure(name: "Meskiag", figureDescription: "Reigned 900 years.")
        let withoutReign = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.")
        context.insert(withReign)
        context.insert(withoutReign)
        for figure in [withReign, withoutReign] {
            let assoc = FigureGroupAssociation(figure: figure)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        let agg = GroupAggregation(operation: .sum, target: .reignYears)
        let result = agg.compute(in: group)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.sum, 900)
        XCTAssertNil(GroupAggregation(operation: .sum, target: .reignSpan).compute(in: group))
    }

    func testGroupAggregationNoDataReturnsNil() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Empty")
        context.insert(group)
        let figure = Figure(name: "Nobody", figureDescription: "No reign recorded.")
        context.insert(figure)
        let assoc = FigureGroupAssociation(figure: figure)
        context.insert(assoc)
        group.figureAssociations.append(assoc)
        try? context.save()

        XCTAssertNil(GroupAggregation(operation: .sum, target: .reignYears).compute(in: group))
    }

    func testGroupAggregationCustomLabelWins() {
        let agg = GroupAggregation(operation: .sum, target: .reignYears, label: "Dynasty total")
        XCTAssertEqual(agg.title, "Dynasty total")
    }

    // MARK: - Figure reign duration (reignYears)

    func testReignLengthParsesListedReignSuffix() {
        XCTAssertEqual(ReignLength.parse(from: "…place him in Eridu and assign a reign to him lasting tens of thousands of years. (Listed reign: 28,800 years.)")?.years, 28800)
        XCTAssertEqual(ReignLength.parse(from: "…(Listed reign: 1,200 years.)")?.years, 1200)
    }

    func testReignLengthParsesLowercaseAndAroundVariants() {
        XCTAssertEqual(ReignLength.parse(from: "he reigned for around 670 years according to some versions")?.years, 670)
        XCTAssertEqual(ReignLength.parse(from: "he reigned for 25 years.")?.years, 25)
        XCTAssertEqual(ReignLength.parse(from: "He was said to have reigned for 18,600 years (5 sars and 1 ner).")?.years, 18600)
        XCTAssertEqual(ReignLength.parse(from: "Ruler from the First dynasty of Kish. Reigned 840 years (mythological length).")?.years, 840)
        XCTAssertEqual(ReignLength.parse(from: "possibly reigning for 6 years")?.years, 6)
        XCTAssertEqual(ReignLength.parse(from: "reigning for 7 years")?.years, 7)
    }

    func testReignLengthParsesNone() {
        XCTAssertNil(ReignLength.parse(from: "No reign recorded."))
        XCTAssertNil(ReignLength.parse(from: "Ruled c. 2255–2218 BC."))
    }

    func testEnsureReignYearsBackfillsFromDescription() {
        let container = makeContainer()
        let context = container.mainContext
        let a = Figure(name: "Kullassina-bel", figureDescription: "…(Listed reign: 960 years.)")
        let b = Figure(name: "En-men-gal-ana", figureDescription: "…ruled for 28,800 years…")
        let c = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.")
        context.insert(a)
        context.insert(b)
        context.insert(c)
        try? context.save()

        Migration.ensureReignYears(context: context)
        XCTAssertEqual(a.reignYears, 960)
        XCTAssertEqual(b.reignYears, 28800)
        XCTAssertNil(c.reignYears)
    }

    func testEnsureReignYearsDoesNotOverwrite() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Mesannepada", figureDescription: "Reigned 80 years. (Listed reign: 80 years.)")
        figure.reignYears = 9999  // user-entered value
        context.insert(figure)
        try? context.save()

        Migration.ensureReignYears(context: context)
        XCTAssertEqual(figure.reignYears, 9999)
    }

    func testGroupAggregationPrefersReignYearsField() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Dynasty")
        context.insert(group)
        let figure = Figure(name: "Mesannepada", figureDescription: "Reigned 80 years.")
        figure.reignYears = 120  // field wins over the parseable description
        context.insert(figure)
        let assoc = FigureGroupAssociation(figure: figure)
        context.insert(assoc)
        group.figureAssociations.append(assoc)
        try? context.save()

        let result = GroupAggregation(operation: .sum, target: .reignYears).compute(in: group)
        XCTAssertEqual(result?.sum, 120)
    }

    // MARK: - Figure epithet

    func testEnsureEpithetsBackfillsFromDoubleQuotedProse() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Etana", figureDescription: "Etana was the thirteenth king of Kish. Epithet: ''\"the shepherd who ascended to heaven\"''.")
        context.insert(figure)
        try? context.save()

        Migration.ensureEpithets(context: context)
        XCTAssertEqual(figure.epithet, "the shepherd who ascended to heaven")
    }

    func testEnsureEpithetsBackfillsFromSingleQuotedProse() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Nergal", figureDescription: "Patron of Kutha. Epithet: 'the one who comes forth from Meslam'.")
        context.insert(figure)
        try? context.save()

        Migration.ensureEpithets(context: context)
        XCTAssertEqual(figure.epithet, "the one who comes forth from Meslam")
    }

    func testEnsureEpithetsDoesNotOverwrite() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Etana", figureDescription: "Epithet: ''\"the boatman\"''.")
        figure.epithet = "user entered epithet"
        context.insert(figure)
        try? context.save()

        Migration.ensureEpithets(context: context)
        XCTAssertEqual(figure.epithet, "user entered epithet")
    }

    func testEnsureEpithetsIgnoresFiguresWithoutEpithetProse() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Marduk", figureDescription: "No epithet mentioned here.")
        context.insert(figure)
        try? context.save()

        Migration.ensureEpithets(context: context)
        XCTAssertNil(figure.epithet)
    }

    // MARK: - Computed SKL dates

    func testDateSourceDefaultsToNil() {
        let figure = Figure(name: "Test")
        XCTAssertNil(figure.dateSource)
        XCTAssertEqual(figure.decodedDateSource, .historical)
    }

    func testEnsureComputedSKLDatesWritesDatesAndSetsSource() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 390, startDate: MythologicalDate(startYear: -2334, endYear: -2334, era: "Dynasty of Akkad"), endDate: MythologicalDate(startYear: -2154, endYear: -2154, era: "Dynasty of Akkad"))
        context.insert(era)
        let anchor = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.\n(Listed reign: 37 years.)")
        anchor.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Dynasty of Akkad")
        anchor.era = era
        context.insert(anchor)
        let successor = Figure(name: "Sharkalisharri")
        successor.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Dynasty of Akkad")
        successor.era = era
        successor.figureDescription = "(Listed reign: 25 years.)"
        context.insert(successor)
        try? context.save()

        Migration.ensureComputedSKLDates(context: context)
        XCTAssertNotNil(anchor.birthDate.startYear)
        XCTAssertNotNil(successor.birthDate.startYear)
        XCTAssertEqual(anchor.decodedDateSource, .computed)
        XCTAssertEqual(successor.decodedDateSource, .computed)
    }

    func testEnsureComputedSKLDatesDoesNotOverwriteExistingDates() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 390, startDate: MythologicalDate(startYear: -2334, endYear: -2334, era: "Dynasty of Akkad"), endDate: MythologicalDate(startYear: -2154, endYear: -2154, era: "Dynasty of Akkad"))
        context.insert(era)
        let figure = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.\n(Listed reign: 37 years.)")
        figure.birthDate = MythologicalDate(startYear: -2200, endYear: -2160, era: "Dynasty of Akkad")
        figure.era = era
        figure.dateSource = Figure.DateSource.historical.rawValue
        context.insert(figure)
        try? context.save()

        Migration.ensureComputedSKLDates(context: context)
        XCTAssertEqual(figure.birthDate.startYear, -2200)
        XCTAssertEqual(figure.decodedDateSource, .historical)
    }

    func testEnsureComputedSKLDatesIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 390, startDate: MythologicalDate(startYear: -2334, endYear: -2334, era: "Dynasty of Akkad"), endDate: MythologicalDate(startYear: -2154, endYear: -2154, era: "Dynasty of Akkad"))
        context.insert(era)
        let figure = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.\n(Listed reign: 37 years.)")
        figure.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Dynasty of Akkad")
        figure.era = era
        context.insert(figure)
        try? context.save()

        Migration.ensureComputedSKLDates(context: context)
        let firstStartYear = figure.birthDate.startYear
        XCTAssertNotNil(firstStartYear)

        Migration.ensureComputedSKLDates(context: context)
        XCTAssertEqual(figure.birthDate.startYear, firstStartYear)
    }

    func testFixSKLFigureOrderFixesHyphenatedName() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Apil-kin")
        figure.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Gutian rule")
        figure.orderIndex = 0
        context.insert(figure)
        try? context.save()

        Migration.fixSKLFigureOrder(context: context)

        XCTAssertEqual(figure.orderIndex, 10, "seed 'Apilkin' (index 10) must match hyphenated DB 'Apil-kin'")
    }

    func testEnsureSKLGutianReignLengthsFixesHyphenatedName() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Apil-kin")
        figure.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Gutian rule")
        figure.figureDescription = "Ruler from the Gutian rule. Reigned 3 years."
        context.insert(figure)
        try? context.save()

        Migration.ensureSKLGutianReignLengths(context: context)

        XCTAssertTrue(
            figure.figureDescription.contains("(Listed reign: 3 years.)"),
            "seed 'Apilkin' (Listed reign: 3 years.) must match hyphenated DB 'Apil-kin'"
        )
    }

    func testEnsureComputedSKLDatesPropagatesFullGutianDynastyFromAnchor() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Gutian rule", orderIndex: 700, startDate: MythologicalDate(startYear: -2200, endYear: -2200, era: "Gutian rule"), endDate: MythologicalDate(startYear: -2072, endYear: -2072, era: "Gutian rule"))
        context.insert(era)

        let namesAndReigns: [(String, Int)] = [
            ("Inkishush", 6), ("Sarlagab", 6), ("Shulme", 6), ("Elulmesh", 6),
            ("Inimabakesh", 5), ("Igeshaush", 6), ("Yarlagab", 15), ("Ibate", 3),
            ("Yarla", 3), ("Kurum", 1), ("Apilkin", 3), ("La-erabum", 2),
            ("Irarum", 2), ("Ibranum", 1), ("Hablum", 2), ("Puzur-Suen", 7),
            ("Yarlaganda", 7), ("Unknown", 7), ("Tirigan", 40),
        ]
        var figures: [Figure] = []
        for (i, (name, reign)) in namesAndReigns.enumerated() {
            let figure = Figure(name: name)
            figure.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Gutian rule")
            figure.orderIndex = i
            figure.era = era
            if name == "Inkishush" {
                figure.figureDescription = "Ruler from the Gutian rule. Reigned \(reign) years. (Listed reign: \(reign) years.) c. 2200–2194 BC"
            } else {
                figure.figureDescription = "Ruler from the Gutian rule. Reigned \(reign) years. (Listed reign: \(reign) years.)"
            }
            context.insert(figure)
            figures.append(figure)
        }
        try? context.save()

        Migration.ensureComputedSKLDates(context: context)

        XCTAssertEqual(figures[0].birthDate.startYear, -2200)
        XCTAssertEqual(figures[0].birthDate.endYear, -2194)
        for figure in figures {
            XCTAssertNotNil(figure.birthDate.startYear, "\(figure.name) should have a computed start year")
            XCTAssertNotNil(figure.birthDate.endYear, "\(figure.name) should have a computed end year")
            XCTAssertEqual(figure.decodedDateSource, .computed, "\(figure.name) dates must be flagged computed")
        }
        for i in 1..<figures.count {
            XCTAssertEqual(figures[i].birthDate.startYear, figures[i - 1].birthDate.endYear, "contiguous reign chain breaks at \(figures[i].name)")
        }
        XCTAssertEqual(figures.last?.birthDate.endYear, -2072, "2200 minus 128 total Gutian reign-years")
    }

    // MARK: - Era date backfill from seed

    func testEnsureEraDatesFromSeedBackfillsSecondDynastyOfKish() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Second dynasty of Kish", orderIndex: 15, startDate: .unknown, endDate: .unknown))
        try? context.save()

        Migration.ensureEraDatesFromSeed(context: context)

        let era = (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == "Second dynasty of Kish" })))?.first
        XCTAssertEqual(era?.startDate.startYear, -2500, "seed anchors Second dynasty of Kish at its conventional slot after Awan")
        XCTAssertEqual(era?.startDate.endYear, -2500)
        XCTAssertEqual(era?.endDate.startYear, -2400)
        XCTAssertEqual(era?.endDate.endYear, -2400)
        XCTAssertTrue(era?.startDate.isApproximate == true)
    }

    func testEnsureEraDatesFromSeedBackfillsAllDatedDynastyEras() {
        let container = makeContainer()
        let context = container.mainContext
        let names = ["First dynasty of Kish", "Second dynasty of Kish", "Dynasty of Akkad", "Gutian rule", "Dynasty of Isin"]
        for (i, name) in names.enumerated() {
            context.insert(Era(name: name, orderIndex: 500 + i, startDate: .unknown, endDate: .unknown))
        }
        try? context.save()

        Migration.ensureEraDatesFromSeed(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        for era in eras {
            XCTAssertNotNil(era.startDate.startYear, "\(era.name) should be backfilled from seed")
            XCTAssertNotNil(era.endDate.startYear, "\(era.name) should be backfilled from seed")
        }
    }

    func testEnsureEraDatesFromSeedIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Second dynasty of Kish", orderIndex: 15, startDate: .unknown, endDate: .unknown))
        try? context.save()

        Migration.ensureEraDatesFromSeed(context: context)
        let first = (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == "Second dynasty of Kish" })))?.first
        let firstStart = first?.startDate.startYear

        Migration.ensureEraDatesFromSeed(context: context)
        let second = (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == "Second dynasty of Kish" })))?.first
        XCTAssertEqual(second?.startDate.startYear, firstStart)
    }

    func testEnsureEraDatesFromSeedNeverOverwritesExistingDates() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(
            name: "Second dynasty of Kish",
            orderIndex: 15,
            startDate: MythologicalDate(startYear: -2600, endYear: -2600, era: "Second dynasty of Kish"),
            endDate: MythologicalDate(startYear: -2550, endYear: -2550, era: "Second dynasty of Kish")
        ))
        try? context.save()

        Migration.ensureEraDatesFromSeed(context: context)

        let era = (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == "Second dynasty of Kish" })))?.first
        XCTAssertEqual(era?.startDate.startYear, -2600, "user-entered era dates must never be overwritten")
        XCTAssertEqual(era?.endDate.startYear, -2550)
    }

    // MARK: - Relationship sources

    func testEnsureRelationshipSourcesResolvesExistingSourceCaseInsensitively() {
        let container = makeContainer()
        let context = container.mainContext
        let source = Source(name: "Adapa Myth")
        context.insert(source)
        let rel = Relationship(source: "Adapa myth")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.name, "Adapa Myth")
        XCTAssertTrue(source.relationships.contains(where: { $0.persistentModelID == rel.persistentModelID }))
        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(allSources.count, 1)
    }

    func testEnsureRelationshipSourcesCreatesCoarseSourceForUnknownName() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Sumerian hymns")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.name, "Sumerian hymns")
        XCTAssertEqual(rel.sourceRef?.sourceType, .ancientText)
        XCTAssertEqual(rel.sourceRef?.relationships.count, 1)
    }

    func testEnsureRelationshipSourcesUsesFirstCommaSegment() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Enuma Elish, Babylonian texts")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.name, "Enuma Elish")
    }

    func testEnsureRelationshipSourcesKingListDetection() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Sumerian King List")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.sourceType, .kingList)
    }

    func testEnsureRelationshipSourcesIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Enuma Elish")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        Migration.ensureRelationshipSources(context: context)
        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(allSources.count, 1)
        XCTAssertNotNil(rel.sourceRef)
    }

    func testEnsureRelationshipSourcesNeverRepointsExistingSourceRef() {
        let container = makeContainer()
        let context = container.mainContext
        let sumerianTexts = Source(name: "Sumerian texts")
        let enumaElish = Source(name: "Enuma Elish")
        context.insert(sumerianTexts)
        context.insert(enumaElish)
        let rel = Relationship(source: "Enuma Elish")
        context.insert(rel)
        sumerianTexts.relationships.append(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.name, "Sumerian texts")
        XCTAssertFalse(enumaElish.relationships.contains(where: { $0.persistentModelID == rel.persistentModelID }))
    }

    func testRelationshipSourceDisplayNameFallsBackToString() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Enuma Elish")
        context.insert(rel)
        try? context.save()

        XCTAssertEqual(rel.sourceDisplayName, "Enuma Elish")
        XCTAssertNil(rel.sourceURL)

        let source = Source(name: "Enuma Elish", url: "https://example.com/enuma")
        context.insert(source)
        source.relationships.append(rel)
        try? context.save()

        XCTAssertEqual(rel.sourceDisplayName, "Enuma Elish")
        XCTAssertEqual(rel.sourceURL, "https://example.com/enuma")
    }

    // MARK: - Figure era links

    func testEnsureFigureEraLinksLinksByBirthEraString() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 390)
        context.insert(era)
        let figure = Figure(name: "Sargon", birthDate: MythologicalDate(year: -2334, era: "Dynasty of Akkad"))
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
    }

    func testEnsureFigureEraLinksAliasMapsBeforeTheFlood() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Age of the Watchers", orderIndex: 1)
        context.insert(era)
        let figure = Figure(name: "Shamhazai", birthDate: MythologicalDate(year: nil, era: "Before the Flood"))
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
    }

    func testEnsureFigureEraLinksFallsBackToDescriptionPrefix() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Antediluvian Period", orderIndex: 5)
        context.insert(era)
        let figure = Figure(name: "Ubara-Tutu", figureDescription: "Ruler from the Antediluvian Period. Father of Ziusudra.")
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
    }

    func testEnsureFigureEraLinksBackfillsBirthEraStringFromDescriptionPrefix() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Antediluvian Period", orderIndex: 5)
        context.insert(era)
        let figure = Figure(name: "Alalngar", figureDescription: "Ruler from the Antediluvian Period.")
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
        XCTAssertEqual(figure.birthDate.era, "Antediluvian Period")
    }

    func testEnsureFigureEraLinksDoesNotOverwriteExistingBirthEraString() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Antediluvian", orderIndex: 6)
        context.insert(era)
        let figure = Figure(name: "Alalngar", figureDescription: "Ruler from the Antediluvian Period.", birthDate: MythologicalDate(year: nil, era: "Antediluvian"))
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.birthDate.era, "Antediluvian")
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
    }

    func testEnsureFigureEraLinksResyncsStaleLink() {
        let container = makeContainer()
        let context = container.mainContext
        let oldEra = Era(name: "Gutian rule", orderIndex: 392)
        let newEra = Era(name: "Dynasty of Isin", orderIndex: 395)
        context.insert(oldEra)
        context.insert(newEra)
        let figure = Figure(name: "Ishbi-Erra", birthDate: MythologicalDate(year: -2017, era: "Dynasty of Isin"))
        figure.era = oldEra
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, newEra.persistentModelID)
    }

    func testEnsureFigureEraLinksClearsLinkWhenStringEmptyAndNoPrefix() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Creation", orderIndex: 0)
        context.insert(era)
        let figure = Figure(name: "Tiamat", figureDescription: "Primordial goddess of the salt sea.")
        figure.era = era
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertNil(figure.era)
    }

    func testEraNamedHelper() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Age of the Watchers", orderIndex: 1)
        context.insert(era)
        try? context.save()

        XCTAssertEqual(Migration.era(named: "Before the Flood", context: context)?.persistentModelID, era.persistentModelID)
        XCTAssertEqual(Migration.era(named: "Age of the Watchers", context: context)?.persistentModelID, era.persistentModelID)
        XCTAssertNil(Migration.era(named: "", context: context))
        XCTAssertNil(Migration.era(named: "  ", context: context))
        XCTAssertNil(Migration.era(named: "Nonexistent", context: context))
    }

    func testEraBoundaryGeoJSONRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[44.4,33.3],[45.0,33.5],[44.8,32.9],[44.4,33.3]]]}"
        context.insert(era)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<Era>()))?.first
        XCTAssertEqual(fetched?.name, "Dynasty of Akkad")
        XCTAssertEqual(fetched?.boundaryGeoJSON, era.boundaryGeoJSON, "boundary persisted on the era")
    }

    func testPolygonGeoJSONClosesRing() {
        let json = Migration.polygonGeoJSON(ring: [[44.0, 33.0], [45.0, 33.0], [45.0, 34.0]])
        XCTAssertNotNil(json)
        guard let data = json?.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let coordinates = object["coordinates"] as? [[[Double]]],
              let ring = coordinates.first else {
            XCTFail("expected a serialized Polygon")
            return
        }
        XCTAssertEqual(object["type"] as? String, "Polygon")
        XCTAssertEqual(ring.first!, ring.last!, "ring must be closed")
        XCTAssertEqual(ring.count, 4)
        XCTAssertNil(Migration.polygonGeoJSON(ring: [[44.0, 33.0], [45.0, 33.0]]))
    }

    func testEnsureDynastyBoundariesBackfillsEras() {
        let container = makeContainer()
        let context = container.mainContext
        for name in ["Dynasty of Akkad", "Dynasty of Isin", "Dynasty of Mari", "Dynasty of Awan", "Gutian rule"] {
            context.insert(Era(name: name, orderIndex: 1))
        }
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        for era in eras {
            XCTAssertNotNil(era.boundaryGeoJSON, "\(era.name) got a boundary")
            guard let data = era.boundaryGeoJSON?.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let coordinates = object["coordinates"] as? [[[Double]]],
                  let ring = coordinates.first else {
                XCTFail("\(era.name) boundary not a Polygon")
                continue
            }
            XCTAssertEqual(ring.first!, ring.last!, "\(era.name) ring closed")
        }
    }

    func testEnsureDynastyBoundariesContainsCapitals() {
        let container = makeContainer()
        let context = container.mainContext
        for name in ["Dynasty of Akkad", "Dynasty of Isin", "Dynasty of Mari", "First dynasty of Ur", "Dynasty of Awan"] {
            context.insert(Era(name: name, orderIndex: 1))
        }
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let points: [String: (Double, Double)] = [
            "Dynasty of Akkad": (44.42, 33.33),
            "Dynasty of Isin": (45.29, 31.92),
            "Dynasty of Mari": (40.89, 34.55),
            "First dynasty of Ur": (46.103, 30.963),
            "Dynasty of Awan": (46.0, 33.0),
        ]
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        for era in eras {
            guard let data = era.boundaryGeoJSON?.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let coordinates = object["coordinates"] as? [[[Double]]],
                  let ring = coordinates.first,
                  let capital = points[era.name] else { continue }
            XCTAssertTrue(pointInRing(capital, ring), "\(era.name) contains its capital")
        }
    }

    func testEnsureDynastyBoundariesNeverOverwrites() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[1.0,1.0],[2.0,1.0],[2.0,2.0],[1.0,1.0]]]}"
        context.insert(era)
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<Era>()))?.first
        XCTAssertEqual(fetched?.boundaryGeoJSON, era.boundaryGeoJSON, "existing boundary untouched")
    }

    func testEnsureDynastyBoundariesRepairsDegenerateTestDraw() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[42.6,32.67],[42.7,32.68],[42.8,32.68],[42.9,32.68],[43.0,32.68],[43.1,32.68],[43.2,32.68],[43.3,32.68],[43.4,32.68]]]}"
        context.insert(era)
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<Era>()))?.first
        guard let data = fetched?.boundaryGeoJSON?.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let coordinates = object["coordinates"] as? [[[Double]]],
              let ring = coordinates.first else {
            XCTFail("expected a repaired Polygon")
            return
        }
        XCTAssertEqual(ring.first!, ring.last!, "repaired ring must be closed")
        XCTAssertEqual(ring.count, 15, "authored Akkad ring is 14 vertices + closing point")
        let lats = ring.map { $0[1] }
        XCTAssertGreaterThan(lats.max()! - lats.min()!, 4.0, "degenerate sliver replaced with a real territory")
    }

    func testEnsureDynastyBoundariesRepairsClosedSliver() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        var ring: [[Double]] = []
        for lon in stride(from: 42.0, through: 44.5, by: 0.08) {
            ring.append([lon, 32.94])
            ring.append([lon + 0.04, 32.95])
        }
        ring.append(ring[0])
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[\(ring.map { "[\($0[0]),\($0[1])]" }.joined(separator: ","))]}"
        context.insert(era)
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<Era>()))?.first
        guard let data = fetched?.boundaryGeoJSON?.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let coordinates = object["coordinates"] as? [[[Double]]],
              let repaired = coordinates.first else {
            XCTFail("expected a repaired Polygon")
            return
        }
        XCTAssertEqual(repaired.first!, repaired.last!, "repaired ring must be closed")
        XCTAssertEqual(repaired.count, 15, "authored Akkad ring is 14 vertices + closing point")
        let lats = repaired.map { $0[1] }
        XCTAssertGreaterThan(lats.max()! - lats.min()!, 4.0, "closed horizontal sliver replaced with a real territory")
    }

    private func pointInRing(_ point: (Double, Double), _ ring: [[Double]]) -> Bool {
        var inside = false
        let n = ring.count
        for i in 0..<n {
            let p1 = ring[i]
            let p2 = ring[(i + 1) % n]
            if (p1[1] > point.1) != (p2[1] > point.1)
                && point.0 < (p2[0] - p1[0]) * (point.1 - p1[1]) / (p2[1] - p1[1]) + p1[0] {
                inside.toggle()
            }
        }
        return inside
    }

    func testFromTextSubjectOnly() {
        let result = FromTextParser.parse("Marduk")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertTrue(result.otherRelationships.isEmpty)
        XCTAssertTrue(result.placeLinks.isEmpty)
    }

    func testFromTextSubjectCouldNotResolve() {
        let result = FromTextParser.parse("is a deity")
        XCTAssertEqual(result.subject, "deity")
        XCTAssertTrue(result.otherRelationships.isEmpty)
        XCTAssertTrue(result.placeLinks.isEmpty)
    }

    func testFromTextSonOfCreatesParent() {
        let result = FromTextParser.parse("Marduk the son of Enki and Damkina")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.parents.count, 2)
        XCTAssertTrue(result.parents.contains { $0.fromFigure == "Enki" && $0.toFigure == "Marduk" && $0.relationshipType == "Father" })
        XCTAssertTrue(result.parents.contains { $0.fromFigure == "Damkina" && $0.toFigure == "Marduk" && $0.relationshipType == "Mother" })
        XCTAssertEqual(result.newFigures.sorted(), ["Damkina", "Enki"])
    }

    func testFromTextDaughterOfCreatesMotherRelation() {
        let result = FromTextParser.parse("Inanna the daughter of Nanna")
        XCTAssertEqual(result.parents.count, 1)
        XCTAssertEqual(result.parents.first?.fromFigure, "Nanna")
        XCTAssertEqual(result.parents.first?.toFigure, "Inanna")
        XCTAssertEqual(result.parents.first?.relationshipType, "Mother")
    }

    func testFromTextFatherOfCreatesFatherRelation() {
        let result = FromTextParser.parse("Enki the father of Marduk")
        XCTAssertEqual(result.parents.count, 1)
        XCTAssertEqual(result.parents.first?.fromFigure, "Enki")
        XCTAssertEqual(result.parents.first?.toFigure, "Marduk")
        XCTAssertEqual(result.parents.first?.relationshipType, "Father")
    }

    func testFromTextConsortOfCreatesPreferredSpouse() {
        let result = FromTextParser.parse("Marduk the consort of Sarpanit")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.otherRelationships.count, 1)
        XCTAssertEqual(result.otherRelationships.first?.toFigure, "Sarpanit")
        XCTAssertEqual(result.otherRelationships.first?.relationshipType, "Spouse")
        XCTAssertTrue(result.otherRelationships.first?.isPreferred == true)
    }

    func testFromTextCreatorOf() {
        let result = FromTextParser.parse("Marduk the creator of humans")
        XCTAssertEqual(result.otherRelationships.count, 1)
        XCTAssertEqual(result.otherRelationships.first?.relationshipType, "Creator")
        XCTAssertEqual(result.otherRelationships.first?.fromFigure, "humans")
        XCTAssertEqual(result.otherRelationships.first?.toFigure, "Marduk")
    }

    func testFromTextPatronPlaceLink() {
        let result = FromTextParser.parse("Marduk patron of Babylon")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.placeLinks.count, 1)
        XCTAssertEqual(result.placeLinks.first?.place, "Babylon")
        XCTAssertEqual(result.placeLinks.first?.roleName, "Patron Deity")
        XCTAssertEqual(result.newPlaces, ["Babylon"])
    }

    func testFromTextRulerPlaceLink() {
        let result = FromTextParser.parse("Marduk ruler of Babylon")
        XCTAssertEqual(result.placeLinks.first?.roleName, "Ruler")
        XCTAssertEqual(result.newPlaces, ["Babylon"])
    }

    func testFromTextMultipleRelationshipsWithAnd() {
        let result = FromTextParser.parse("Marduk brother of Ishtar and Ereshkigal")
        XCTAssertEqual(result.otherRelationships.count, 2)
        XCTAssertEqual(result.newFigures, ["Ereshkigal", "Ishtar"])
        XCTAssertTrue(result.otherRelationships.contains { $0.toFigure == "Ishtar" && $0.relationshipType == "Sibling" })
    }

    func testFromTextPartnerSiblingRelationDirection() {
        let partnerResult = FromTextParser.parse("Marduk consort of Sarpanit")
        XCTAssertEqual(partnerResult.otherRelationships.first?.fromFigure, "Marduk")
        XCTAssertEqual(partnerResult.otherRelationships.first?.toFigure, "Sarpanit")

        let parentResult = FromTextParser.parse("Enki father of Marduk")
        XCTAssertEqual(parentResult.parents.first?.fromFigure, "Enki")
        XCTAssertEqual(parentResult.parents.first?.toFigure, "Marduk")
    }

    func testFromTextEmptyYieldsNothing() {
        let result = FromTextParser.parse("")
        XCTAssertEqual(result.subject, "")
        XCTAssertTrue(result.otherRelationships.isEmpty)
        XCTAssertTrue(result.placeLinks.isEmpty)
    }

    func testFromTextSiblingRelationAppearsInNewFigures() {
        let result = FromTextParser.parse("Ishtar sister of Ereshkigal")
        XCTAssertEqual(result.otherRelationships.first?.relationshipType, "Sibling")
        XCTAssertEqual(result.newFigures, ["Ereshkigal"])
    }

    func testFromTextMultipleClausesWithoutSemicolons() {
        let result = FromTextParser.parse("Marduk the son of Enki, consort of Sarpanit, patron of Babylon")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.parents.count, 1)
        XCTAssertEqual(result.parents.first?.fromFigure, "Enki")
        XCTAssertEqual(result.parents.first?.relationshipType, "Father")
        XCTAssertEqual(result.otherRelationships.count, 1)
        XCTAssertEqual(result.otherRelationships.first?.toFigure, "Sarpanit")
        XCTAssertEqual(result.otherRelationships.first?.relationshipType, "Spouse")
        XCTAssertEqual(result.placeLinks.count, 1)
        XCTAssertEqual(result.placeLinks.first?.place, "Babylon")
        XCTAssertEqual(result.placeLinks.first?.roleName, "Patron Deity")
        XCTAssertEqual(result.newFigures.sorted(), ["Enki", "Sarpanit"])
        XCTAssertEqual(result.newPlaces, ["Babylon"])
    }

    func testFromTextNewlineDelimitedClauses() {
        let result = FromTextParser.parse("Sarpanit\nsister of Ishtar\nconsort of Marduk")
        XCTAssertEqual(result.subject, "Sarpanit")
        XCTAssertEqual(result.otherRelationships.count, 2)
        XCTAssertEqual(result.newFigures.sorted(), ["Ishtar", "Marduk"])
    }

    func testFromTextAlternateNames() {
        let result = FromTextParser.parse("Marduk, also known as Bel and Merodach, the patron of Babylon")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.alternateNames, ["Bel", "Merodach"])
    }

    func testFromTextHammurabiWikipediaBio() {
        let clip = "Hammurabi (also spelled Hammurapi) was the sixth Amorite king of Babylon, reigning from c. 1792 BC to c. 1750 BC. He was a son of Sin-Muballit."
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.subject, "Hammurabi")
        XCTAssertEqual(result.gender, .male)
        XCTAssertEqual(result.figureKind, .human)
        XCTAssertEqual(result.title, "King")
        XCTAssertEqual(result.alternateNames, ["Hammurapi"])
        XCTAssertEqual(result.parents.count, 1)
        XCTAssertEqual(result.parents.first?.fromFigure, "Sin-Muballit")
        XCTAssertEqual(result.parents.first?.relationshipType, "Father")
        XCTAssertTrue(result.placeLinks.contains { $0.place == "Babylon" && $0.roleName == "Ruler" })
        XCTAssertEqual(result.reignStart, -1792)
        XCTAssertEqual(result.reignEnd, -1750)
        XCTAssertFalse(result.newFigures.contains("became"))
        XCTAssertEqual(result.newFigures, ["Sin-Muballit"])
    }

    func testFromTextQueenGenderInferred() {
        let result = FromTextParser.parse("Kubaba was queen of Kish, the wife of Puzur-Suen")
        XCTAssertEqual(result.gender, .female)
        XCTAssertEqual(result.figureKind, .human)
        XCTAssertEqual(result.title, "Queen")
    }

    func testFromTextAlsoSpelledAlternate() {
        let result = FromTextParser.parse("Hammurabi, also spelled Hammurapi, king of Babylon")
        XCTAssertEqual(result.subject, "Hammurabi")
        XCTAssertEqual(result.alternateNames, ["Hammurapi"])
    }

    func testFromTextPtahWikipediaLead() {
        // Verbatim Wikipedia lead with Greek/Coptic/Phoenician scripts and a
        // descriptive word before a father's name ("father of the sage Imhotep").
        let clip = "Ptah (/tɑː/ TAH;[2] Ancient Egyptian: ptḥ, reconstructed [piˈtaħ]; Ancient Greek: Φθά, romanized: Phthá; Coptic: ⲡⲧⲁϩ, romanized: Ptah; Phoenician: 𐤐𐤕𐤇, romanized: ptḥ)[3][4][note 1] is an ancient Egyptian deity, a creator god,[5] and a patron deity of craftsmen and architects. In the triad of Memphis, he is the husband of Sekhmet and the father of Nefertem. He was also regarded as the father of the sage Imhotep."
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.subject, "Ptah")
        XCTAssertEqual(result.figureKind, .deity)
        XCTAssertEqual(result.gender, .male)
        XCTAssertEqual(result.parents.count, 2)
        XCTAssertEqual(result.parents.map { $0.toFigure }, ["Nefertem", "Imhotep"])
        XCTAssertEqual(result.parents.map { $0.relationshipType }, ["Father", "Father"])
        XCTAssertEqual(result.otherRelationships.map { "\($0.relationshipType):\($0.toFigure)" }, ["Spouse:Sekhmet"])
        XCTAssertEqual(result.newFigures.sorted(), ["Imhotep", "Nefertem", "Sekhmet"])
        XCTAssertTrue(result.placeLinks.isEmpty)
    }

    func testFromTextAkaMarkerWordBoundary() {
        // "aka " must not match inside "Shabaka" — otherwise "Stone" and
        // "Twenty-Fifth Dynasty" leak in as alternate names. Verify on the
        // full Origin-and-symbolism paragraph plus the epithet list.
        let clip = "Ptah is an Egyptian creator god who conceived the world and brought it into being through the creative power of speech. A hymn to Ptah dating to the Twenty-second Dynasty of Egypt says Ptah \"crafted the world in the design of his heart,\" and the Shabaka Stone, from the Twenty-Fifth Dynasty, says Ptah \"gave life to all the gods and their kas as well, through this heart and this tongue.\"[6] Ptah creating the world through heart and tongue, has been subject to comparative interest, in particular with the Jewish conceptions of divine word as a creative process.[7]\n\nHe bears many epithets that describe his role in ancient Egyptian religion and its importance in society at the time:\n\nPtah the begetter of the first beginning\nPtah lord of truth\nPtah lord of eternity\nPtah who listens to prayers\nPtah master of ceremonies\nPtah master of justice\nPtah the God who made himself to be God\nPtah the double being\nPtah the beautiful face"
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.alternateNames, [])
        XCTAssertEqual(result.subject, "Ptah")
    }

    func testFromTextWikipediaLeadWithCuneiform() {
        // Verbatim Wikipedia lead containing supplementary-plane cuneiform
        // (surrogate pairs) — must not corrupt UTF-16/grapheme index mapping.
        let clip = "Hammurabi (/ˌhæmʊˈrɑːbi/; Old Babylonian Akkadian: 𒄩𒄠𒈬𒊏𒁉, romanized: Ḫammu-rāpi;[2][a] Akkadian: [xammuˈraːpʰi]; c. 1810 BC – c. 1750 BC), also spelled Hammurapi,[4][5] was the sixth Amorite king of Babylon, reigning from c. 1792 BC to c. 1750 BC. He was preceded by his father, Sin-Muballit, who abdicated due to failing health. During his reign, he conquered the city-states of Larsa, Eshnunna, and Mari. He ousted Ishme-Dagan I, ruler of the Kingdom of Upper Mesopotamia, bringing almost all of Mesopotamia under Babylonian rule."
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.subject, "Hammurabi")
        XCTAssertEqual(result.alternateNames, ["Hammurapi"], "cuneiform must not corrupt the alternate-name value")
        XCTAssertTrue(result.placeLinks.contains { $0.place == "Babylon" && $0.roleName == "Ruler" })
        XCTAssertTrue(result.placeLinks.contains { $0.place == "Upper Mesopotamia" && $0.roleName == "Ruler" })
        XCTAssertFalse(result.placeLinks.contains { $0.place == "on" }, "no bogus 'on' place from UTF-16 corruption")
        XCTAssertEqual(result.reignStart, -1792)
        XCTAssertEqual(result.reignEnd, -1750)
        XCTAssertEqual(result.birthYear, -1810)
        XCTAssertEqual(result.deathYear, -1750)
        XCTAssertEqual(result.gender, .male)
        XCTAssertEqual(result.figureKind, .human)
        XCTAssertEqual(result.title, "King")
    }

    func testFromTextSubjectSkipsPrepositionalOpeners() {
        // Blurbs that open with a prepositional phrase or epithet, not the name.
        XCTAssertEqual(FromTextParser.parse("In Mesopotamian mythology, Ereshkigal was the queen of the underworld, also known as Allatu.").subject, "Ereshkigal")
        XCTAssertEqual(FromTextParser.parse("In Sumerian religion, Enki was the god of wisdom, fresh water and magic.").subject, "Enki")
        XCTAssertEqual(FromTextParser.parse("In the ancient city of Ur, Nanna was the moon god, patron of the city.").subject, "Nanna")
        XCTAssertEqual(FromTextParser.parse("According to the Sumerian King List, Etana ruled Kish.").subject, "Etana")
        XCTAssertEqual(FromTextParser.parse("God of the sun and justice, Shamash was worshipped in Sippar and Larsa.").subject, "Shamash")
        XCTAssertEqual(FromTextParser.parse("Lady of the great temple at Uruk, Inanna was the goddess of love and war.").subject, "Inanna")
        XCTAssertEqual(FromTextParser.parse("The ruler of the underworld, Nergal was a fearsome deity.").subject, "Nergal")
        XCTAssertEqual(FromTextParser.parse("A powerful storm god, Ishkur was venerated in Karkar.").subject, "Ishkur")
    }

    func testFromTextSubjectHandlesPossessiveAndPassive() {
        // Possessive subject: "Nergal's consort was Ereshkigal" — the figure is
        // the complement after the copula, not "Nergal".
        XCTAssertEqual(FromTextParser.parse("Nergal's consort was Ereshkigal, queen of the underworld.").subject, "Ereshkigal")
        // Pronoun stand-in resolved through the subordinate clause.
        XCTAssertEqual(FromTextParser.parse("It is said that Ptah created the world").subject, "Ptah")
        // Passive construction: the figure is the object of "by".
        XCTAssertEqual(FromTextParser.parse("The Akkadian Empire was founded by Sargon the Great.").subject, "Sargon")
        XCTAssertEqual(FromTextParser.parse("The city of Uruk was ruled by Gilgamesh.").subject, "Gilgamesh")
        XCTAssertEqual(FromTextParser.parse("The temple of Eanna was built by Naram-Sin.").subject, "Naram-Sin")
        XCTAssertEqual(FromTextParser.parse("The state of Lagash was conquered by Eannatum.").subject, "Eannatum")
        // A person as grammatical subject is preserved (not overridden by "by").
        XCTAssertEqual(FromTextParser.parse("Hammurabi was preceded by his father, Sin-Muballit.").subject, "Hammurabi")
        XCTAssertEqual(FromTextParser.parse("Sargon was born in Azupiranu on the banks of the Euphrates.").subject, "Sargon")
    }

    func testFromTextSubjectTitleCaseHeadingNotWholeSentence() {
        // Title-cased headings used to swallow the whole first sentence as the name.
        XCTAssertEqual(FromTextParser.parse("Ptah Lord Of Truth Lord Of Eternity Who Listens To Prayers").subject, "Ptah")
        XCTAssertEqual(FromTextParser.parse("Inanna Queen Of Heaven And Earth Goddess Of Love And War").subject, "Inanna")
        XCTAssertEqual(FromTextParser.parse("Ptah Creator God Of Memphis And Patron Of Craftsmen").subject, "Ptah")
        XCTAssertEqual(FromTextParser.parse("Ereshkigal Queen Of The Underworld Also Known As Allatu").subject, "Ereshkigal")
        XCTAssertEqual(FromTextParser.parse("Ptah Who Listens to Prayers").subject, "Ptah")
        XCTAssertEqual(FromTextParser.parse("The Sumerian goddess Inanna was known as Ishtar to the Akkadians.").subject, "Inanna")
    }

    func testFromTextGenderDeityDetected() {
        let male = FromTextParser.parse("Marduk is a god of Babylon, the son of Enki")
        XCTAssertEqual(male.gender, .male)
        XCTAssertEqual(male.figureKind, .deity)

        let female = FromTextParser.parse("Sarpanit is a goddess, the consort of Marduk")
        XCTAssertEqual(female.gender, .female)
        XCTAssertEqual(female.figureKind, .deity)
    }

    func testFromTextKingWithDeityMentionIsHuman() {
        // A historical king's biography mentions gods (of predecessors, temples)
        // but must classify as human, not deity.
        let result = FromTextParser.parse("Hammurabi king of Babylon, reigned 1792 BC, son of Sin-Muballit")
        XCTAssertEqual(result.figureKind, .human)
    }

    func testFromTextRulerMentionOfGodIsHuman() {
        // "successor of the god X" in a reign line must not flip a king to deity.
        let result = FromTextParser.parse("Ur-Nammu ruler of Ur, the successor of the god Enlil, reigned 2112 BC")
        XCTAssertEqual(result.figureKind, .human)
    }

    func testFromTextDeityPredicationStillDetected() {
        // Subject predicated as a god keeps deity classification.
        let result = FromTextParser.parse("Marduk is a god of Babylon, the son of Enki")
        XCTAssertEqual(result.figureKind, .deity)
    }

    func testFromTextDomainAndTitle() {
        let result = FromTextParser.parse("Marduk, the god of creation and wisdom, lord of Babylon")
        XCTAssertEqual(result.domain?.lowercased().contains("creation"), true)
    }

    func testFromTextReturnsClipAsDescription() {
        let clip = "Marduk is the patron deity of Babylon and the son of Enki and Damkina."
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.description, clip)
    }

    // MARK: - Apply + revert

    func testFromTextApplyCreatesFiguresPlacesAndLinks() {
        let container = makeContainer()
        let context = container.mainContext
        let result = FromTextParser.parse("Marduk the son of Enki and Damkina, patron of Babylon, also known as Bel")
        let record = FromTextRecognizer.apply(result, in: context)
        try? context.save()
        XCTAssertNotNil(record)
        let names = ((try? context.fetch(FetchDescriptor<Figure>())) ?? []).map(\.name)
        XCTAssertEqual(names.sorted(), ["Damkina", "Enki", "Marduk"])
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<Place>())) ?? []).map(\.name), ["Babylon"])
        XCTAssertEqual(record?.createdFigureNames.sorted(), ["Damkina", "Enki", "Marduk"])
        XCTAssertEqual(record?.createdPlaceNames, ["Babylon"])
        XCTAssertEqual(record?.alternateNames, ["Bel"])
        XCTAssertEqual(record?.relationships.count, 2)
        XCTAssertEqual(record?.placeLinks.count, 1)
    }

    func testFromTextRevertRemovesCreatedData() {
        let container = makeContainer()
        let context = container.mainContext
        let result = FromTextParser.parse("Marduk the son of Enki and Damkina, patron of Babylon, also known as Bel")
        let record = FromTextRecognizer.apply(result, in: context)!
        try? context.save()

        let report = FromTextRecognizer.revert(record, in: context)
        try? context.save()

        XCTAssertEqual(report.deletedFigures.sorted(), ["Damkina", "Enki", "Marduk"])
        XCTAssertEqual(report.deletedPlaces, ["Babylon"])
        XCTAssertEqual(report.deletedRelationships, 2)
        XCTAssertEqual(report.deletedPlaceLinks, 1)
        XCTAssertEqual(report.deletedAlternateNames, 1)
        XCTAssertTrue(report.keptFigures.isEmpty)
        XCTAssertTrue(report.keptPlaces.isEmpty)
        XCTAssertTrue(((try? context.fetch(FetchDescriptor<Figure>())) ?? []).isEmpty)
        XCTAssertTrue(((try? context.fetch(FetchDescriptor<Place>())) ?? []).isEmpty)
        XCTAssertTrue(((try? context.fetch(FetchDescriptor<Relationship>())) ?? []).isEmpty)
        XCTAssertTrue(((try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []).isEmpty)
    }

    func testFromTextApplyReusesExistingFigureAndRevertRestoresIt() {
        let container = makeContainer()
        let context = container.mainContext
        let existing = Figure(name: "Marduk", gender: .unknown)
        context.insert(existing)
        try? context.save()

        var result = FromTextResult(subject: "Marduk")
        result.gender = .male
        result.title = "King"
        result.figureKind = .deity
        let record = FromTextRecognizer.apply(result, in: context)!
        try? context.save()

        XCTAssertEqual(record.createdFigureNames, [])
        XCTAssertEqual(record.figureMutations.count, 1)
        XCTAssertEqual(existing.gender, .male)
        XCTAssertEqual(existing.title, "King")
        XCTAssertEqual(existing.figureType?.name, "Deity")

        let report = FromTextRecognizer.revert(record, in: context)
        try? context.save()

        XCTAssertEqual(existing.gender, .unknown)
        XCTAssertEqual(existing.title, "")
        XCTAssertNil(existing.figureType)
        XCTAssertEqual(report.restoredMutations, ["Marduk"])
        XCTAssertTrue(report.skippedMutations.isEmpty)
        XCTAssertTrue(((try? context.fetch(FetchDescriptor<Figure>())) ?? []).count == 1, "reused figure must survive revert")
    }

    func testFromTextRevertKeepsFigureWithLaterData() {
        let container = makeContainer()
        let context = container.mainContext
        var result = FromTextResult(subject: "Marduk")
        result.parents = [FromTextRelationship(fromFigure: "Enki", toFigure: "Marduk", relationshipType: "Father")]
        let record = FromTextRecognizer.apply(result, in: context)!
        try? context.save()

        // The user later links Enki to another relationship, so Enki has data beyond the add.
        let enki = ((try? context.fetch(FetchDescriptor<Figure>())) ?? []).first { $0.name == "Enki" }!
        let marduk = ((try? context.fetch(FetchDescriptor<Figure>())) ?? []).first { $0.name == "Marduk" }!
        let siblingType = RelationshipType(name: "Sibling", icon: "link", colorHex: "007AFF", category: "family")
        context.insert(siblingType)
        let later = Relationship(fromFigure: enki, toFigure: marduk, relationshipType: siblingType, source: "manual")
        context.insert(later)
        enki.outgoingRelationships.append(later)
        try? context.save()

        let report = FromTextRecognizer.revert(record, in: context)
        try? context.save()

        XCTAssertEqual(report.deletedRelationships, 1, "the add's Father relationship is removed")
        XCTAssertEqual(report.keptFigures.sorted(), ["Enki", "Marduk"], "figures with later data are kept")
        XCTAssertTrue(report.deletedFigures.isEmpty)
        XCTAssertTrue(((try? context.fetch(FetchDescriptor<Figure>())) ?? []).count == 2)
        let remainingRels = ((try? context.fetch(FetchDescriptor<Relationship>())) ?? []).map(\.source)
        XCTAssertEqual(remainingRels, ["manual"], "only the add's relationship is removed")
    }

    func testFromTextApplyRecordCodableRoundTrip() {
        var record = FromTextApplyRecord(subject: "Marduk")
        record.createdFigureNames = ["Enki", "Damkina"]
        record.createdPlaceNames = ["Babylon"]
        record.alternateNames = ["Bel"]
        record.relationships = [FromTextRecordedRelationship(fromFigure: "Enki", toFigure: "Marduk", relationshipType: "Father", source: "From text")]
        record.placeLinks = [FromTextRecordedPlaceLink(figure: "Marduk", place: "Babylon", roleName: "Patron Deity", source: "From text")]

        let data = try! JSONEncoder().encode(record)
        let decoded = try! JSONDecoder().decode(FromTextApplyRecord.self, from: data)
        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.subject, "Marduk")
        XCTAssertEqual(decoded.createdFigureNames, record.createdFigureNames)
        XCTAssertEqual(decoded.relationships, record.relationships)
        XCTAssertEqual(decoded.placeLinks, record.placeLinks)
    }

    // MARK: - Pantheon

    func testPantheonDefaults() {
        let pantheon = Pantheon(name: "Mesopotamian")
        XCTAssertEqual(pantheon.icon, "building.columns.circle.fill")
        XCTAssertEqual(pantheon.colorHex, "8E8E93")
        XCTAssertEqual(pantheon.figures.count, 0)
    }

    func testPantheonFigureManyToMany() {
        let container = makeContainer()
        let context = container.mainContext
        let meso = Pantheon(name: "Mesopotamian")
        let greek = Pantheon(name: "Greek")
        context.insert(meso)
        context.insert(greek)
        let enki = Figure(name: "Enki")
        let marduk = Figure(name: "Marduk")
        context.insert(enki)
        context.insert(marduk)
        try? context.save()

        enki.pantheons.append(meso)
        enki.pantheons.append(greek)
        marduk.pantheons.append(meso)
        try? context.save()

        XCTAssertEqual(meso.figures.count, 2)
        XCTAssertEqual(greek.figures.count, 1)
        XCTAssertTrue((enki.pantheons.contains { $0.name == "Mesopotamian" }))
        XCTAssertTrue((enki.pantheons.contains { $0.name == "Greek" }))
        XCTAssertTrue((marduk.pantheons.contains { $0.name == "Mesopotamian" }))
    }

    func testGroupMemberFilterMatchesPantheon() {
        let container = makeContainer()
        let context = container.mainContext
        let meso = Pantheon(name: "Mesopotamian")
        let greek = Pantheon(name: "Greek")
        context.insert(meso)
        context.insert(greek)
        let enki = Figure(name: "Enki")
        let marduk = Figure(name: "Marduk")
        context.insert(enki)
        context.insert(marduk)
        try? context.save()
        enki.pantheons.append(meso)
        marduk.pantheons.append(greek)
        try? context.save()

        let filter = GroupMemberFilter(pantheonNames: ["Mesopotamian"])
        XCTAssertTrue(filter.matches(enki))
        XCTAssertFalse(filter.matches(marduk))
    }

    func testGroupMemberFilterPantheonSummary() {
        let filter = GroupMemberFilter(pantheonNames: ["Mesopotamian", "Greek"])
        XCTAssertTrue(filter.summary.contains("Pantheon: Mesopotamian, Greek"))
    }

    func testEnsureMesopotamianPantheonsMigration() {
        let container = makeContainer()
        let context = container.mainContext
        let enki = Figure(name: "Enki")
        let marduk = Figure(name: "Marduk")
        context.insert(enki)
        context.insert(marduk)
        try? context.save()

        Migration.ensureMesopotamianPantheons(context: context)

        let pantheons = (try? context.fetch(FetchDescriptor<Pantheon>())) ?? []
        XCTAssertEqual(pantheons.count, 1)
        XCTAssertEqual(pantheons.first?.name, "Mesopotamian")
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in figures {
            XCTAssertEqual(figure.pantheons.count, 1)
            XCTAssertEqual(figure.pantheons.first?.name, "Mesopotamian")
        }
    }

    func testEnsureMesopotamianPantheonsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let enki = Figure(name: "Enki")
        context.insert(enki)
        try? context.save()

        Migration.ensureMesopotamianPantheons(context: context)
        Migration.ensureMesopotamianPantheons(context: context)

        let pantheons = (try? context.fetch(FetchDescriptor<Pantheon>())) ?? []
        XCTAssertEqual(pantheons.count, 1)
        XCTAssertEqual(enki.pantheons.count, 1)
    }

    func testEnsureMesopotamianPantheonsKeepsExistingMembership() {
        let container = makeContainer()
        let context = container.mainContext
        let meso = Pantheon(name: "Mesopotamian")
        let greek = Pantheon(name: "Greek")
        context.insert(meso)
        context.insert(greek)
        let enki = Figure(name: "Enki")
        context.insert(enki)
        try? context.save()
        enki.pantheons.append(greek)
        try? context.save()

        Migration.ensureMesopotamianPantheons(context: context)

        XCTAssertEqual(enki.pantheons.count, 1)
        XCTAssertEqual(enki.pantheons.first?.name, "Greek", "figures with existing membership are not reassigned")
    }

    // MARK: - Divine collectives (Anunnaki / Igigi)

    func testEnsureDivineCollectivesCreatesTypeAndFigures() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        Migration.ensureDivineCollectives(context: context)

        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        XCTAssertEqual(types.count, 1)
        XCTAssertEqual(types.first?.name, "Divine Collective")

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.count, 2)
        XCTAssertEqual(Set(figures.map(\.name)), Set(["Anunnaki", "Igigi"]))
        for figure in figures {
            XCTAssertEqual(figure.figureType?.name, "Divine Collective")
            XCTAssertEqual(figure.gender, .unknown)
        }
    }

    func testEnsureDivineCollectivesIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        Migration.ensureDivineCollectives(context: context)
        Migration.ensureDivineCollectives(context: context)

        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        XCTAssertEqual(types.count, 1)
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.count, 2)
    }

    func testEnsureDivineCollectivesReusesExistingTypeAndKeepsUserData() {
        let container = makeContainer()
        let context = container.mainContext
        let existingType = FigureType(name: "Divine Collective", icon: "person.3.fill", colorHex: "111111")
        context.insert(existingType)
        let anunnaki = Figure(name: "Anunnaki", gender: .female, figureDescription: "User's own description")
        context.insert(anunnaki)
        try? context.save()

        Migration.ensureDivineCollectives(context: context)

        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        XCTAssertEqual(types.count, 1, "no duplicate type")

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.count, 2)
        let updatedAnunnaki = figures.first { $0.name == "Anunnaki" }
        XCTAssertEqual(updatedAnunnaki?.figureDescription, "User's own description", "existing figure untouched")
        XCTAssertEqual(updatedAnunnaki?.gender, .female, "existing figure untouched")

        let igigi = figures.first { $0.name == "Igigi" }
        XCTAssertEqual(igigi?.figureType?.persistentModelID, existingType.persistentModelID, "Igigi joins the reused type")
    }

    // MARK: - ORACC deity import

    func testEnsureOraccDeityImportsCreatesAllSevenWithStickies() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        Migration.ensureOraccDeityImports(context: context)

        let expected: Set<String> = ["Gula", "Dagan", "Damu", "Girra", "Ninsi'anna", "Tašmetu", "Lugalirra"]
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(Set(figures.map(\.name)), expected)

        for figure in figures {
            XCTAssertEqual(figure.figureType?.name, "Deity")
            XCTAssertEqual(figure.source.contains("ORACC"), true)
            XCTAssertEqual(figure.stickies.count, 1)
            XCTAssertEqual(figure.stickies.first?.text, "IMPORTED FROM ORACC")
            XCTAssertEqual(figure.stickies.first?.isResolved, false)
        }

        let gula = figures.first { $0.name == "Gula" }
        XCTAssertEqual(gula?.gender, .female)

        let altNames = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertEqual(altNames.count, 6)
        XCTAssertEqual(
            Set(altNames.map(\.name)),
            Set(["Ninkarrak", "Dagon", "Bilgi", "Ninsianna", "Tashmetu", "Lugal-irra"])
        )
    }

    func testEnsureOraccDeityImportsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        Migration.ensureOraccDeityImports(context: context)
        Migration.ensureOraccDeityImports(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.count, 7)
        let stickies = figures.flatMap(\.stickies)
        XCTAssertEqual(stickies.count, 7)
    }

    func testEnsureOraccDeityImportsSkipsExistingNamesAndAliases() {
        let container = makeContainer()
        let context = container.mainContext
        let existing = Figure(name: "Dagan", figureDescription: "User's own Dagan")
        context.insert(existing)
        try? context.save()

        Migration.ensureOraccDeityImports(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.count, 7, "6 imports + the user's own Dagan")
        XCTAssertEqual(figures.first { $0.name == "Dagan" }?.figureDescription, "User's own Dagan", "existing figure untouched")
        XCTAssertNil(figures.first { $0.name == "Dagan" }?.stickies.first, "no sticky on pre-existing figure")

        let dagan = figures.first { $0.name == "Dagan" }
        let dagonAlt = (try? context.fetch(FetchDescriptor<AlternateName>()))?
            .first { $0.name == "Dagon" }
        XCTAssertNil(dagonAlt, "Dagan was skipped entirely — no alias may attach to a skipped name either")
        _ = dagan
    }

    // MARK: - Everyday-life episodes import

    private func seedEverydayLifeTypeTables(context: ModelContext) {
        Migration.ensureRelationTypesExist(context: context)
        Migration.ensureEventPlaceRoleTypesExist(context: context)
        Migration.ensureFigurePlaceRoleTypesExist(context: context)
        SeedData.ensureTypesExist(context: context)
    }

    func testEverydayLifeEpisodesCreateFiguresEventsPlacesAndRelationships() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)

        Migration.ensureEverydayLifeEpisodes(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.count, 12)
        XCTAssertEqual(figures.first { $0.name == "Taram-Kubi" }?.gender, .female)

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertEqual(events.count, 10)
        XCTAssertEqual(Set(events.map(\.eventType?.name)), Set(["Daily Life"]))
        let banquet = events.first { $0.name == "Ashurnasirpal II's Banquet at Kalhu" }
        XCTAssertEqual(banquet?.date.startYear, -879)
        XCTAssertEqual(banquet?.date.isApproximate, false)
        XCTAssertTrue(banquet?.involvedFigures.contains { $0.name == "Ashurnasirpal II" } ?? false)

        let letters = events.first { $0.name == "Taram-Kubi's Letters Home" }
        let roleByPlace = Dictionary((letters?.placeAssociations ?? []).map {
            ($0.place?.name ?? "", $0.roleType?.name ?? "")
        }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(roleByPlace["Assur"], "Started At")
        XCTAssertEqual(roleByPlace["Kanesh"], "Ended At")

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.count, 6)
        XCTAssertEqual(places.first { $0.name == "Kanesh" }?.latitude ?? 0, 38.8522, accuracy: 0.0001)

        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(relationships.count, 4, "two spouses plus Zizizi's father and mother")

        let assocs = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []
        XCTAssertEqual(assocs.count, 12)
        XCTAssertTrue(assocs.contains {
            $0.figure?.name == "Ashurnasirpal II" && $0.place?.name == "Kalhu" && $0.roleType?.name == "Ruler"
        })

        let stickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        XCTAssertEqual(stickies.count, 28, "one sticky on each created figure, place, and event")
        XCTAssertEqual(Set(stickies.map(\.text)), Set(["Import daily life events"]))
        XCTAssertEqual(stickies.filter { $0.figure != nil }.count, 12)
        XCTAssertEqual(stickies.filter { $0.place != nil }.count, 6)
        XCTAssertEqual(stickies.filter { $0.event != nil }.count, 10)
    }

    func testEverydayLifeEpisodesAreIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)

        Migration.ensureEverydayLifeEpisodes(context: context)
        Migration.ensureEverydayLifeEpisodes(context: context)

        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Figure>())) ?? -1, 12)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Event>())) ?? -1, 10)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Place>())) ?? -1, 6)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, 4)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<FigurePlaceAssociation>())) ?? -1, 12)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<StickyNote>())) ?? -1, 28)
    }

    func testEverydayLifeEpisodesSkipExistingUserData() {
        let container = makeContainer()
        let context = container.mainContext
        let usersEa = Figure(name: "Ea Nasir", figureDescription: "User's own Ea-nasir entry")
        let usersEvent = Event(name: "Poor Man of Nippur", eventDescription: "User's own write-up")
        let usersPlace = Place(name: "Ur", modernLocation: "")
        context.insert(usersEa)
        context.insert(usersEvent)
        context.insert(usersPlace)
        try? context.save()
        seedEverydayLifeTypeTables(context: context)

        Migration.ensureEverydayLifeEpisodes(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.count, 12, "the user's differently-spaced 'Ea Nasir' must suppress the import")
        XCTAssertEqual(
            figures.filter { NameDuplicateCheck.normalizedKey($0.name) == "eanasir" }.count,
            1,
            "no duplicate under any spelling"
        )
        XCTAssertEqual(
            figures.first { NameDuplicateCheck.normalizedKey($0.name) == "eanasir" }?.figureDescription,
            "User's own Ea-nasir entry",
            "existing figure untouched"
        )

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertEqual(events.count, 10, "nine imports plus the user's own Poor Man of Nippur")
        XCTAssertEqual(events.first { $0.name == "Poor Man of Nippur" }?.eventDescription, "User's own write-up")

        let complaint = events.first { $0.name == "The Complaint Tablet to Ea-nasir" }
        XCTAssertTrue(
            complaint?.involvedFigures.contains { $0 === usersEa } ?? false,
            "the episode must link to the user's existing figure rather than creating another"
        )

        let urPlaces = ((try? context.fetch(FetchDescriptor<Place>())) ?? []).filter { $0.name == "Ur" }
        XCTAssertEqual(urPlaces.count, 1)
        XCTAssertEqual(urPlaces.first?.modernLocation, "", "the user's bare Ur stays bare")

        let placeAssocCount = (try? context.fetchCount(FetchDescriptor<EventPlaceAssociation>())) ?? -1
        XCTAssertEqual(placeAssocCount, 10,
                       "all imported episode places except those of the user's own Poor Man of Nippur")

        let stickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        XCTAssertFalse(stickies.contains { $0.figure === usersEa }, "no import sticky on the user's own figure")
        XCTAssertFalse(stickies.contains { $0.event === usersEvent }, "no import sticky on the user's own event")
        XCTAssertFalse(stickies.contains { $0.place === usersPlace }, "no import sticky on the user's own place")
    }

    // MARK: - FigurePlaceAssociation confidence qualifier

    func testFigurePlaceAssociationConfidenceRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let gula = Figure(name: "Gula", figureDescription: "Healing goddess")
        let nippur = Place(name: "Nippur", placeDescription: "City of Enlil")
        context.insert(gula)
        context.insert(nippur)
        let assoc = FigurePlaceAssociation(
            figure: gula,
            place: nippur,
            roleType: nil,
            source: "AMGG, s.v. Gula",
            confidence: .possible
        )
        context.insert(assoc)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.confidence, .possible)
        XCTAssertEqual(fetched.first?.confidence?.label, "possible")
    }

    func testFigurePlaceAssociationConfidenceDefaultsToNilAndSupportsDisputed() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigurePlaceAssociation(source: "plain claim"))
        context.insert(FigurePlaceAssociation(source: "conflicting traditions", confidence: .disputed))
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched.first { $0.source == "plain claim" }?.confidence, nil)
        XCTAssertEqual(fetched.first { $0.source == "conflicting traditions" }?.confidence, .disputed)
        XCTAssertEqual(fetched.first { $0.source == "conflicting traditions" }?.confidence?.label, "disputed")

        XCTAssertEqual(Set(FigurePlaceAssociation.Confidence.allCases), [.possible, .disputed])
    }

    // MARK: - NameDuplicateCheck

    func testNameDuplicateCheckNormalizationCollidesSpellingVariants() {
        XCTAssertEqual(NameDuplicateCheck.normalizedKey("Ea-nasir"), "eanasir")
        XCTAssertEqual(NameDuplicateCheck.normalizedKey("Ea Nasir"), "eanasir")
        XCTAssertEqual(NameDuplicateCheck.normalizedKey("  UR-AS  "), "uras")
    }

    func testNameDuplicateCheckWarningFindsAndFormatsMatches() {
        let existing = ["Uras", "Ur-as", "Enlil", "Dagan"]
        XCTAssertEqual(NameDuplicateCheck.warning(candidate: "URAS!", existingNames: existing), "Ur-as, Uras")
        XCTAssertNil(NameDuplicateCheck.warning(candidate: "Nanna", existingNames: existing))
        XCTAssertNil(NameDuplicateCheck.warning(candidate: "", existingNames: existing))
        XCTAssertNil(NameDuplicateCheck.warning(candidate: "   ", existingNames: existing))
        XCTAssertNil(NameDuplicateCheck.warning(candidate: "Uras", existingNames: []))
    }

    // MARK: - Propagator: ignore non-reign prose dates

    func testPropagatorIgnoresMidTextTabletDate() {
        let container = makeContainer()
        let context = container.mainContext
        let alulim = Figure(
            name: "Alulim",
            figureDescription: "Alulim was a mythological ruler. The tablet of Old Babylonian period (c. 1900–1600 BC) from Ur describing the divine appointment of Alulim. (Listed reign: 28,800 years.)",
            birthDate: MythologicalDate(year: nil, era: "", isApproximate: true),
            deathDate: MythologicalDate(year: nil, era: "", isApproximate: true),
            orderIndex: 1
        )
        context.insert(alulim)
        try? context.save()

        Migration.enrichSKLData(context: context)

        XCTAssertNil(alulim.reignStartYear, "a mid-text tablet-date must not seed a reign start")
        XCTAssertNil(alulim.reignEndYear, "a mid-text tablet-date must not seed a reign end")
    }

    func testPropagatorIgnoresProseDateWithoutReignIntent() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(
            name: "Ili-Ishar",
            figureDescription: "Iii-Ishar was a ruler of the city of Mari after the fall of Akkad c. 2085-2072 BCE.",
            birthDate: MythologicalDate(year: nil, era: "", isApproximate: true),
            deathDate: MythologicalDate(year: nil, era: "", isApproximate: true)
        )
        context.insert(figure)
        try? context.save()

        Migration.enrichSKLData(context: context)

        XCTAssertNil(figure.reignStartYear, "'BCE' prose about an event must not seed a reign")
        XCTAssertNil(figure.reignEndYear)
    }

    func testPropagatorKeepsReignIntentDate() {
        let container = makeContainer()
        let context = container.mainContext
        let entemena = Figure(
            name: "Entemena",
            figureDescription: "Entemena, son of Eannatum, was a Sumerian king of Lagash who reigned c. 2440–2425 BC.",
            birthDate: MythologicalDate(year: nil, era: "Early Dynastic Period", isApproximate: true),
            deathDate: MythologicalDate(year: nil, era: "Early Dynastic Period", isApproximate: true)
        )
        context.insert(entemena)
        try? context.save()

        Migration.enrichSKLData(context: context)

        XCTAssertEqual(entemena.reignStartYear, -2440)
        XCTAssertEqual(entemena.reignEndYear, -2425)
    }

    func testPropagatorKeepsTailAnchoredAnchorDate() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(
            name: "Ur-Namma",
            figureDescription: "Ruler from the Third dynasty of Ur. Reigned 18 years. c. 2047–2030 BC (short)",
            birthDate: MythologicalDate(year: nil, era: "Third dynasty of Ur", isApproximate: true),
            deathDate: MythologicalDate(year: nil, era: "Third dynasty of Ur", isApproximate: true)
        )
        context.insert(figure)
        try? context.save()

        Migration.enrichSKLData(context: context)

        XCTAssertEqual(figure.reignStartYear, -2047)
        XCTAssertEqual(figure.reignEndYear, -2030)
    }

    // MARK: - Mugshots

    func testImageCropRectFullDefault() {
        XCTAssertEqual(ImageCropRect.full.cgRect, CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertNil(ImageCropRect(encoded: nil))
        XCTAssertNil(ImageCropRect(encoded: ""))
        XCTAssertNil(ImageCropRect(encoded: "0.1,0.2"))
        XCTAssertNil(ImageCropRect(encoded: "a,b,c,d"))
    }

    func testImageCropRectEncodeDecodeRoundTrip() {
        let crop = ImageCropRect(x: 0.25, y: 0.1, width: 0.4, height: 0.5)
        let decoded = ImageCropRect(encoded: crop.encoded())
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded, crop)
    }

    func testImageCropRectClampsOutOfBounds() {
        let crop = ImageCropRect(x: -0.2, y: 1.5, width: 3, height: -1)
        XCTAssertGreaterThanOrEqual(crop.x, 0)
        XCTAssertLessThanOrEqual(crop.x + crop.width, 1)
        XCTAssertLessThanOrEqual(crop.y + crop.height, 1)
        XCTAssertGreaterThanOrEqual(crop.height, 0)
    }

    func testMugshotFieldsRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let gudea = Figure(name: "Gudea", gender: .male)
        context.insert(gudea)
        let statue = ImageAsset(filename: "gudea_statue.jpg", caption: "Gudea statue from Girsu", source: "Louvre")
        context.insert(statue)
        gudea.mugshotImage = statue
        gudea.mugshotCropRect = ImageCropRect(x: 0.2, y: 0.1, width: 0.4, height: 0.5).encoded()
        gudea.mugshotIdentification = "inscribed"
        try? context.save()

        let fetched = try? context.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.name == "Gudea" })).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.mugshotImage?.filename, "gudea_statue.jpg")
        XCTAssertEqual(fetched?.mugshotIdentification, "inscribed")
        XCTAssertEqual(ImageCropRect(encoded: fetched?.mugshotCropRect), ImageCropRect(x: 0.2, y: 0.1, width: 0.4, height: 0.5))
        XCTAssertEqual(statue.mugshots.count, 1)
        XCTAssertEqual(statue.mugshots.first?.name, "Gudea")
    }

    func testMugshotRemovedWhenImageDeleted() {
        let container = makeContainer()
        let context = container.mainContext
        let gudea = Figure(name: "Gudea", gender: .male)
        context.insert(gudea)
        let statue = ImageAsset(filename: "statue.jpg")
        context.insert(statue)
        gudea.mugshotImage = statue
        try? context.save()

        context.delete(statue)
        try? context.save()

        XCTAssertNil(gudea.mugshotImage, "Deleting the mugshot image must nullify the figure's mugshot (delete rule .nullify)")
    }

    // MARK: - Duplicate Merger

    func testDuplicateMergerFindGroupsFiguresCaseInsensitive() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Ea"))
        context.insert(Figure(name: "ea"))
        context.insert(Figure(name: "EA"))
        context.insert(Figure(name: "Enki"))
        try? context.save()

        let groups = try! DuplicateMerger.findGroups(in: context)
        let figureGroups = groups.filter { $0.kind == .figure }
        XCTAssertEqual(figureGroups.count, 1)
        XCTAssertEqual(figureGroups.first?.name.lowercased(), "ea", "Group name keeps the first-seen spelling (fetch order not guaranteed)")
        XCTAssertEqual(figureGroups.first?.ids.count, 3)
    }

    func testDuplicateMergerFindGroupsDoesNotMixKinds() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Babylon"))
        context.insert(Place(name: "Babylon"))
        context.insert(Event(name: "Babylon"))
        try? context.save()

        let groups = try! DuplicateMerger.findGroups(in: context)
        XCTAssertTrue(groups.isEmpty, "A figure, place, and event sharing a name are distinct entities — never a merge group")
    }

    func testDuplicateMergerFindGroupsSkippedWhenSingle() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Enki"))
        context.insert(Place(name: "Nippur"))
        try? context.save()

        let groups = try! DuplicateMerger.findGroups(in: context)
        XCTAssertTrue(groups.isEmpty)
    }

    func testDuplicateMergerMergeFiguresRePointsRelationships() {
        let container = makeContainer()
        let context = container.mainContext
        let fatherType = RelationshipType(name: "Father", icon: "link", colorHex: "007AFF", category: "family")
        context.insert(fatherType)
        let keeper = Figure(name: "Enki")
        let duplicate = Figure(name: "enki")
        let child = Figure(name: "Marduk")
        let parent = Figure(name: "Anu")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(child)
        context.insert(parent)
        context.insert(Relationship(fromFigure: duplicate, toFigure: child, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: parent, toFigure: duplicate, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: duplicate, toFigure: duplicate, relationshipType: fatherType))
        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(rels.count, 2, "the duplicate→duplicate self-relationship is deleted")
        XCTAssertTrue(rels.contains { $0.fromFigure === keeper && $0.toFigure === child }, "outgoing re-pointed to keeper")
        XCTAssertTrue(rels.contains { $0.fromFigure === parent && $0.toFigure === keeper }, "incoming re-pointed to keeper")
        XCTAssertFalse(rels.contains { $0.fromFigure === duplicate || $0.toFigure === duplicate })
    }

    func testDuplicateMergerMergeFiguresFoldsOwnedContent() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Figure(name: "Ninhursag")
        let duplicate = Figure(name: "nin-hursag")
        context.insert(keeper)
        context.insert(duplicate)

        let alt = AlternateName(figure: duplicate, name: "Mami", tradition: .akkadian, nameType: .syncretism)
        context.insert(alt)
        duplicate.alternateNames.append(alt)

        let place = Place(name: "Nippur")
        context.insert(place)
        let role = FigurePlaceRoleType(name: "Patron", icon: "star", colorHex: "FF0000")
        context.insert(role)
        let pa = FigurePlaceAssociation(figure: duplicate, place: place, roleType: role)
        context.insert(pa)
        duplicate.placeAssociations.append(pa)
        place.figureAssociations.append(pa)

        let tag = Tag(name: "goddess")
        context.insert(tag)
        duplicate.tags.append(tag)

        let sticky = StickyNote(text: "check cult", figure: duplicate)
        context.insert(sticky)
        duplicate.stickies.append(sticky)

        let group = FigureGroup(name: "Pantheon")
        context.insert(group)
        let ga = FigureGroupAssociation(figure: duplicate, group: group)
        context.insert(ga)
        duplicate.groupAssociations.append(ga)

        let pantheon = Pantheon(name: "Mesopotamian")
        context.insert(pantheon)
        duplicate.pantheons.append(pantheon)

        let image = ImageAsset(filename: "ninhursag.jpg")
        context.insert(image)
        duplicate.images.append(image)

        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        XCTAssertEqual(keeper.alternateNames.map(\.name), ["Mami"])
        XCTAssertEqual(keeper.placeAssociations.count, 1)
        XCTAssertEqual(keeper.placeAssociations.first?.place, place)
        XCTAssertEqual(keeper.tags.count, 1)
        XCTAssertEqual(keeper.stickies.count, 1)
        XCTAssertEqual(keeper.groupAssociations.count, 1)
        XCTAssertEqual(keeper.pantheons.count, 1)
        XCTAssertEqual(keeper.images.count, 1)
        XCTAssertTrue(place.figureAssociations.contains { $0.figure === keeper })
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<Figure>())) ?? []).count, 1, "duplicate is deleted")
    }

    func testDuplicateMergerMergeFiguresAdoptsEmptyFields() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Figure(name: "Enki")
        let duplicate = Figure(name: "enki", gender: .male)
        duplicate.title = "Lord of the Abzu"
        duplicate.domain = "Water, Wisdom"
        duplicate.figureDescription = "God of fresh water"
        duplicate.epithet = "Nudimmud"
        context.insert(keeper)
        context.insert(duplicate)
        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        XCTAssertEqual(keeper.title, "Lord of the Abzu")
        XCTAssertEqual(keeper.domain, "Water, Wisdom")
        XCTAssertEqual(keeper.figureDescription, "God of fresh water")
        XCTAssertEqual(keeper.epithet, "Nudimmud")
        XCTAssertEqual(keeper.gender, .male)
    }

    func testDuplicateMergerMergeFiguresKeepsKeeperFields() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Figure(name: "Enki", gender: .male)
        keeper.title = "Keeper Title"
        keeper.domain = "Keeper Domain"
        let duplicate = Figure(name: "enki")
        duplicate.title = "Duplicate Title"
        duplicate.domain = "Duplicate Domain"
        context.insert(keeper)
        context.insert(duplicate)
        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        XCTAssertEqual(keeper.title, "Keeper Title", "keeper values always win")
        XCTAssertEqual(keeper.domain, "Keeper Domain")
    }

    func testDuplicateMergerMergePlacesRePointsAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Place(name: "Nippur")
        let duplicate = Place(name: "nippur")
        let figure = Figure(name: "Enlil")
        let other = Place(name: "Ekur")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(figure)
        context.insert(other)
        let role = FigurePlaceRoleType(name: "Worshipped", icon: "star", colorHex: "00FF00")
        context.insert(role)
        let fa = FigurePlaceAssociation(figure: figure, place: duplicate, roleType: role)
        context.insert(fa)
        figure.placeAssociations.append(fa)
        duplicate.figureAssociations.append(fa)
        let ppr = PlacePlaceRoleType(name: "Located Within", icon: "link", colorHex: "0000FF")
        context.insert(ppr)
        context.insert(PlacePlaceAssociation(fromPlace: duplicate, toPlace: other, roleType: ppr))
        try? context.save()

        try! DuplicateMerger.mergePlaces(keeper, duplicate, in: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.count, 2, "duplicate deleted, keeper + other remain")
        XCTAssertTrue(figure.placeAssociations.contains { $0.place === keeper })
        let ppas = (try? context.fetch(FetchDescriptor<PlacePlaceAssociation>())) ?? []
        XCTAssertEqual(ppas.count, 1)
        XCTAssertTrue(ppas.contains { $0.fromPlace === keeper && $0.toPlace === other })
    }

    func testDuplicateMergerMergeEventsRePointsAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Event(name: "The Flood")
        let duplicate = Event(name: "the flood")
        let figure = Figure(name: "Utnapishtim")
        let other = Event(name: "Ark Lands")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(figure)
        context.insert(other)
        let role = EventFigureRoleType(name: "Protagonist", icon: "person", colorHex: "FF00FF")
        context.insert(role)
        let efa = EventFigureAssociation(event: duplicate, figure: figure, roleType: role)
        context.insert(efa)
        duplicate.figureAssociations = [efa]
        let er = EventEventRoleType(name: "Precedes", icon: "arrow.right", colorHex: "00FFFF")
        context.insert(er)
        context.insert(EventEventAssociation(fromEvent: duplicate, toEvent: other, roleType: er))
        try? context.save()

        try! DuplicateMerger.mergeEvents(keeper, duplicate, in: context)

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertEqual(events.count, 2, "duplicate deleted, keeper + other remain")
        XCTAssertTrue((keeper.figureAssociations ?? []).contains { $0.figure === figure })
        let eeas = (try? context.fetch(FetchDescriptor<EventEventAssociation>())) ?? []
        XCTAssertEqual(eeas.count, 1)
        XCTAssertTrue(eeas.contains { $0.fromEvent === keeper && $0.toEvent === other })
    }

    func testDuplicateMergerMergeThingsFoldsAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Thing(name: "Tablet of Destinies")
        let duplicate = Thing(name: "tablet of destinies")
        let figure = Figure(name: "Marduk")
        let place = Place(name: "Esagila")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(figure)
        context.insert(place)
        let role = ThingFigureRoleType(name: "Holder", icon: "hand.raised", colorHex: "888888")
        context.insert(role)
        let tfa = ThingFigureAssociation(thing: duplicate, figure: figure, roleType: role)
        context.insert(tfa)
        duplicate.figureAssociations.append(tfa)
        figure.thingAssociations.append(tfa)
        let tpr = ThingPlaceRoleType(name: "Kept At", icon: "building.columns", colorHex: "999999")
        context.insert(tpr)
        let tpa = ThingPlaceAssociation(thing: duplicate, place: place, roleType: tpr)
        context.insert(tpa)
        duplicate.placeAssociations.append(tpa)
        place.thingAssociations.append(tpa)
        try? context.save()

        try! DuplicateMerger.mergeThings(keeper, duplicate, in: context)

        let things = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        XCTAssertEqual(things.count, 1)
        XCTAssertEqual(keeper.figureAssociations.count, 1)
        XCTAssertEqual(keeper.figureAssociations.first?.figure, figure)
        XCTAssertEqual(keeper.placeAssociations.count, 1)
        XCTAssertEqual(keeper.placeAssociations.first?.place, place)
    }

    func testDuplicateMergerMergeFiguresMovesEventFigureAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Figure(name: "Enkidu")
        let duplicate = Figure(name: "enkidu")
        let event = Event(name: "Hunting the Bull of Heaven")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(event)
        let role = EventFigureRoleType(name: "Participant", icon: "person", colorHex: "ABCDEF")
        context.insert(role)
        let efa = EventFigureAssociation(event: event, figure: duplicate, roleType: role)
        context.insert(efa)
        event.figureAssociations = [efa]
        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        XCTAssertEqual(event.figureAssociations?.first?.figure?.persistentModelID, keeper.persistentModelID)
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<Figure>())) ?? []).count, 1)
    }

    // MARK: - Seed reconciliation guards (case-insensitive)

    func testEnsureMissingCitiesAndAssociationsSkipsCaseVariantPlace() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "Bad-Tibira", placeType: nil, modernLocation: "Tell al-Madineh", placeDescription: "", source: "Sumerian King List", latitude: 31.382778, longitude: 46.004444))
        try? context.save()

        Migration.ensureMissingCitiesAndAssociations(context: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.count, 46, "all other seed places still created; the case-variant must not be re-seeded")
        let badTibiras = places.filter { $0.name.lowercased() == "bad-tibira" }
        XCTAssertEqual(badTibiras.count, 1, "a case-variant existing place must not be re-seeded")
        XCTAssertEqual(badTibiras.first?.name, "Bad-Tibira")
    }

    func testEnsureMissingCitiesAndAssociationsCreatesMissingPlace() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        Migration.ensureMissingCitiesAndAssociations(context: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.count, 46, "seed has 46 places")
        XCTAssertTrue(places.contains { $0.name == "Bad-tibira" })
    }

    func testEnsureSKLEventsAndFiguresSkipsCaseVariantFigureAndPlace() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Eannatum"))
        context.insert(Place(name: "Girsu", placeType: nil, modernLocation: "", placeDescription: "", source: "", latitude: 0, longitude: 0))
        try? context.save()

        Migration.ensureSKLEventsAndFigures(context: context)

        let eannatums = (try? context.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.name == "Eannatum" }))) ?? []
        XCTAssertEqual(eannatums.count, 1, "existing exact-name figure must not be duplicated")

        let girsu = (try? context.fetch(FetchDescriptor<Place>(predicate: #Predicate { $0.name == "Girsu" }))) ?? []
        XCTAssertEqual(girsu.count, 1, "existing exact-name place must not be duplicated")
    }

    // MARK: - Tag engine (rule-based auto-tags)

    func testTagEngineDeityTags() {
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        let figure = Figure(
            name: "Enki",
            figureType: deityType,
            gender: .male,
            domain: "Water, Wisdom, Magic, Crafts",
            figureDescription: "",
            birthDate: MythologicalDate(year: nil, era: "Age of the First Gods", isApproximate: true),
            deathDate: .unknown,
            source: "Atra-Hasis, Enki and Ninhursag"
        )
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("deity"))
        XCTAssertTrue(tags.contains("god"))
        XCTAssertFalse(tags.contains("goddess"))
        XCTAssertTrue(tags.contains("water"))
        XCTAssertTrue(tags.contains("wisdom"))
        XCTAssertTrue(tags.contains("magic"))
        XCTAssertTrue(tags.contains("crafts"))
        XCTAssertTrue(tags.contains("atrahasis"))
        XCTAssertTrue(tags.contains("age of the first gods"))
    }

    func testTagEngineGoddessTag() {
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        let figure = Figure(name: "Inanna", figureType: deityType, gender: .female, domain: "Love, War, Fertility, Venus", figureDescription: "", source: "Inanna's Descent")
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("goddess"))
        XCTAssertFalse(tags.contains("god"))
        XCTAssertTrue(tags.contains("inanna's descent"))
        XCTAssertTrue(tags.contains("love"))
        XCTAssertTrue(tags.contains("venus"))
    }

    func testTagEngineKingTags() {
        let humanType = FigureType(name: "Human", icon: "person", colorHex: "007AFF")
        let figure = Figure(name: "Aga of Kish", figureType: humanType, gender: .male, domain: "Kingship of Kish", figureDescription: "", source: "Sumerian King List")
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("human"))
        XCTAssertTrue(tags.contains("king"))
        XCTAssertTrue(tags.contains("kingship"))
        XCTAssertTrue(tags.contains("kish"))
        XCTAssertTrue(tags.contains("sumerian king list"))
    }

    func testTagEngineNonRulingHumanIsNotKing() {
        let humanType = FigureType(name: "Human", icon: "person", colorHex: "007AFF")
        let figure = Figure(name: "Hammurabi", figureType: humanType, gender: .male, domain: "", figureDescription: "", source: "")
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("human"))
        XCTAssertFalse(tags.contains("king"))
    }

    func testTagEngineWatcherTagForCommander() {
        let commanderType = FigureType(name: "Commander", icon: "shield", colorHex: "EF4444")
        let figure = Figure(name: "Samyaza", figureType: commanderType, gender: .male, domain: "Divine Council", figureDescription: "", source: "Book of Enoch (1 Enoch)")
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("watcher"))
        XCTAssertTrue(tags.contains("book of enoch"))
        XCTAssertTrue(tags.contains("divine"))
        XCTAssertTrue(tags.contains("council"))
    }

    func testTagEnginePlaceTags() {
        let cityType = PlaceType(name: "City", icon: "building", colorHex: "007AFF")
        let place = Place(name: "Eridu", placeType: cityType, modernLocation: "Abu Shahrain, Southern Iraq", placeDescription: "", source: "Sumerian King List", latitude: 30.816, longitude: 45.996)
        let tags = TagEngine.tags(for: place)
        XCTAssertTrue(tags.contains("city"))
        XCTAssertTrue(tags.contains("iraq"))
        XCTAssertTrue(tags.contains("sumerian king list"))
        XCTAssertEqual(TagEngine.historicalRegionTag("Upper Mesopotamia"), "mesopotamia")
        XCTAssertNil(TagEngine.historicalRegionTag("Eridu"))
    }

    func testTagEngineEventTags() {
        let battleType = EventType(name: "Battle", icon: "flame", colorHex: "FF3B30")
        let event = Event(name: "Sargon Conquers Sumer", eventType: battleType, eventDescription: "", date: .unknown, era: "Dynasty of Akkad", source: "Sumerian King List")
        let tags = TagEngine.tags(for: event)
        XCTAssertTrue(tags.contains("battle"))
        XCTAssertTrue(tags.contains("dynasty of akkad"))
        XCTAssertTrue(tags.contains("sumerian king list"))
    }

    func testTagEngineThingCategories() {
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "The Gold Dagger of Ur", description: "").contains("artifact"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Kingship", description: "").contains("office"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Truth", description: "").contains("concept"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Atra-Hasis", description: "").contains("literary work"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Craft of the smith", description: "").contains("craft"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Me", description: "").contains("divine powers"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "The flood", description: "").contains("flood"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Holy purification", description: "").contains("concept"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Kurgarra (cultic entertainer)", description: "").contains("office"))
    }

    func testTagEngineDomainSplitsPhrases() {
        XCTAssertEqual(TagEngine.domainTags("Sky, Kingship, Authority"), ["sky", "kingship", "authority"])
        XCTAssertEqual(TagEngine.domainTags("Kingship of Kish"), ["kingship", "kish"])
        XCTAssertEqual(TagEngine.domainTags("Salt Water, Chaos"), ["salt", "water", "chaos"])
        XCTAssertEqual(TagEngine.domainTags(""), [])
    }

    func testTagEngineDomainStripsConnectorsAndFragments() {
        XCTAssertEqual(TagEngine.domainTags("and the underworld"), ["underworld"])
        XCTAssertEqual(TagEngine.domainTags("associated with farming and fertility"), ["farming", "fertility"])
        XCTAssertEqual(TagEngine.domainTags("steward and scribe"), ["steward", "scribe"])
        XCTAssertEqual(TagEngine.domainTags("and boundary stones"), ["boundary", "stones"])
        XCTAssertEqual(TagEngine.domainTags("localized military defense"), ["localized", "military", "defense"])
        XCTAssertEqual(TagEngine.domainTags("and"), [])
        XCTAssertEqual(TagEngine.domainTags("Sky, Sky"), ["sky"])
    }

    func testTagEngineColorHexDeterministic() {
        XCTAssertEqual(TagEngine.colorHex(for: "wisdom"), TagEngine.colorHex(for: "wisdom"))
        XCTAssertNotEqual(TagEngine.colorHex(for: "wisdom"), TagEngine.colorHex(for: "battle"))
        XCTAssertEqual(TagEngine.colorHex(for: "water").count, 6)
    }

    func testEnsureAutoTagsTagsAllKinds() {
        let container = makeContainer()
        let context = container.mainContext
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        let figure = Figure(name: "Enki", figureType: deityType, gender: .male, domain: "Water, Wisdom", figureDescription: "", source: "Enuma Elish")
        context.insert(figure)
        let cityType = PlaceType(name: "City", icon: "building", colorHex: "007AFF")
        context.insert(Place(name: "Uruk", placeType: cityType, modernLocation: "Iraq", placeDescription: "", source: "", latitude: 31.322, longitude: 45.639))
        let battleType = EventType(name: "Battle", icon: "flame", colorHex: "FF3B30")
        context.insert(Event(name: "Slaying of Tiamat", eventType: battleType, eventDescription: "", date: .unknown, era: "Creation", source: "Enuma Elish"))
        context.insert(Thing(name: "The Gold Dagger of Ur", thingDescription: "", source: ""))
        try? context.save()

        Migration.ensureAutoTags(context: context)

        XCTAssertFalse(figure.tags.isEmpty)
        XCTAssertTrue(figure.tags.contains { $0.name == "deity" })
        XCTAssertTrue(figure.tags.contains { $0.name == "water" })
        let allPlaces: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(allPlaces.first?.tags.map(\.name).sorted(), ["city", "iraq"])
        let allEvents: [Event] = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertTrue(allEvents.first?.tags.contains { $0.name == "battle" } ?? false)
        XCTAssertTrue(allEvents.first?.tags.contains { $0.name == "creation" } ?? false)
        let allThings: [Thing] = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        XCTAssertTrue(allThings.first?.tags.contains { $0.name == "artifact" } ?? false)
    }

    func testEnsureAutoTagsSkipsEntitiesWithExistingTags() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Marduk", figureType: FigureType(name: "Deity", icon: "star", colorHex: "FF9500"), gender: .male, domain: "Storm, Creation, Kingship", figureDescription: "", source: "Enuma Elish")
        context.insert(figure)
        let userTag = Tag(name: "user-curated", colorHex: "FF9500")
        context.insert(userTag)
        figure.tags.append(userTag)
        try? context.save()

        Migration.ensureAutoTags(context: context)

        XCTAssertEqual(figure.tags.map(\.name), ["user-curated"], "an entity with any tag must be left untouched")
    }

    func testEnsureAutoTagsIsIdempotentAndReusesTags() {
        let container = makeContainer()
        let context = container.mainContext
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        context.insert(Figure(name: "Enki", figureType: deityType, gender: .male, domain: "Water", figureDescription: "", source: "Enuma Elish"))
        context.insert(Figure(name: "Ea", figureType: deityType, gender: .male, domain: "Water", figureDescription: "", source: "Enuma Elish"))
        try? context.save()

        Migration.ensureAutoTags(context: context)
        Migration.ensureAutoTags(context: context)

        let allTags: [Tag] = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        XCTAssertEqual(allTags.filter { $0.name == "water" }.count, 1, "the same tag name must resolve to one Tag row")
        XCTAssertEqual(allTags.filter { $0.name == "deity" }.count, 1)
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in figures {
            XCTAssertEqual(figure.tags.count, Set(figure.tags.map(\.name)).count, "no duplicate tag rows per figure")
        }
    }

    func testEnsureAutoTagsLeavesUntaggableEntitiesUntagged() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Thing(name: "Unremarkable", thingDescription: "", source: ""))
        try? context.save()

        Migration.ensureAutoTags(context: context)

        let allTags: [Tag] = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        XCTAssertTrue(allTags.isEmpty, "a thing that matches no category must not force a tag")
        let allThings: [Thing] = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        XCTAssertTrue(allThings.first?.tags.isEmpty ?? true)
    }

    func testEnsureRefinedDomainTagsSplitsLegacyFragments() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Ninurta", figureType: FigureType(name: "Deity", icon: "star", colorHex: "FF9500"), gender: .male, domain: "steward and scribe; associated with farming and fertility; and the underworld", figureDescription: "", source: "Sumerian King List")
        context.insert(figure)
        let legacyNames = ["steward and scribe", "associated with farming and fertility", "and the underworld", "sumerian king list"]
        for name in legacyNames {
            let tag = Tag(name: name, colorHex: "FF9500")
            context.insert(tag)
            figure.tags.append(tag)
        }
        try? context.save()

        Migration.ensureRefinedDomainTags(context: context)

        let names = Set(figure.tags.map(\.name))
        for obsolete in ["steward and scribe", "associated with farming and fertility", "and the underworld"] {
            XCTAssertFalse(names.contains(obsolete), "legacy fragment \(obsolete) must be removed")
        }
        for refined in ["steward", "scribe", "farming", "fertility", "underworld"] {
            XCTAssertTrue(names.contains(refined), "refined single-word tag \(refined) missing")
        }
        XCTAssertTrue(names.contains("sumerian king list"), "tradition tag must survive the pass")
    }

    func testEnsureRefinedDomainTagsIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Ninurta", figureType: FigureType(name: "Deity", icon: "star", colorHex: "FF9500"), gender: .male, domain: "steward and scribe", figureDescription: "", source: "")
        context.insert(figure)
        let legacy = Tag(name: "steward and scribe", colorHex: "FF9500")
        context.insert(legacy)
        figure.tags.append(legacy)
        try? context.save()

        Migration.ensureRefinedDomainTags(context: context)
        Migration.ensureRefinedDomainTags(context: context)

        XCTAssertEqual(Set(figure.tags.map(\.name)), ["steward", "scribe"])
        let allTags: [Tag] = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        XCTAssertEqual(allTags.filter { $0.name == "steward" }.count, 1, "one Tag row per refined name")
        XCTAssertEqual(allTags.filter { $0.name == "scribe" }.count, 1)
    }

    func testEnsureDynastyGroupsCreatesSubgroupsWithFiguresAndEvents() {
        let container = makeContainer()
        let context = container.mainContext
        let kishEra = Era(name: "First dynasty of Kish", orderIndex: 0)
        let akkadEra = Era(name: "Dynasty of Akkad", orderIndex: 1)
        context.insert(kishEra)
        context.insert(akkadEra)

        func king(_ name: String, era: Era, order: Int) -> Figure {
            let figure = Figure(name: name, domain: "Kingship", figureDescription: "", orderIndex: order)
            figure.era = era
            context.insert(figure)
            return figure
        }
        king("En-me-barage-si", era: kishEra, order: 0)
        king("Agga", era: kishEra, order: 1)
        king("Sargon", era: akkadEra, order: 0)
        king("Naram-Sin", era: akkadEra, order: 1)
        context.insert(Figure(name: "Enki", domain: "Wisdom", figureDescription: "", orderIndex: 0))

        let kishEvent = Event(name: "Siege of Uruk", date: .unknown, era: "First dynasty of Kish", source: "")
        let akkadEvent = Event(name: "Fall of Akkad", date: .unknown, era: "Dynasty of Akkad", source: "")
        let floodEvent = Event(name: "The Great Flood", date: .unknown, era: "The Great Flood", source: "")
        context.insert(kishEvent)
        context.insert(akkadEvent)
        context.insert(floodEvent)
        try? context.save()

        Migration.ensureDynastyGroups(context: context)
        Migration.ensureDynastyGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let top = groups.first(where: { $0.name == "Dynasties" }) else {
            return XCTFail("Dynasties top group missing")
        }
        XCTAssertEqual(top.kind, .skl)
        let subs = top.sortedSubgroups
        XCTAssertEqual(subs.map(\.name), ["First dynasty of Kish", "Dynasty of Akkad"])

        guard let kish = subs.first(where: { $0.name == "First dynasty of Kish" }),
              let akkad = subs.first(where: { $0.name == "Dynasty of Akkad" }) else {
            return XCTFail("dynasty subgroups missing")
        }

        XCTAssertEqual(kish.sortedAssociations.compactMap { $0.figure?.name }, ["En-me-barage-si", "Agga"], "kings in reign order")
        XCTAssertEqual(akkad.sortedAssociations.compactMap { $0.figure?.name }, ["Sargon", "Naram-Sin"])
        XCTAssertFalse(kish.sortedAssociations.contains { $0.figure?.name == "Enki" }, "non-dynastic figure excluded")

        XCTAssertEqual(kish.era?.persistentModelID, kishEra.persistentModelID, "subgroup linked to its era")
        XCTAssertEqual(akkad.era?.persistentModelID, akkadEra.persistentModelID, "subgroup linked to its era")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Era>())) ?? 0, 2)
        XCTAssertEqual(kishEra.groups?.map(\.name), ["First dynasty of Kish"], "inverse era.groups populated")

        XCTAssertEqual(kish.sortedAssociations.compactMap { $0.event?.name }, ["Siege of Uruk"], "era-matched event attached")
        XCTAssertEqual(akkad.sortedAssociations.compactMap { $0.event?.name }, ["Fall of Akkad"])
        XCTAssertFalse(akkad.sortedAssociations.contains { $0.event?.name == "The Great Flood" }, "non-dynastic event excluded")
        XCTAssertEqual(kish.sortMode, .ordered)

        let totalAssocs = (try? context.fetchCount(FetchDescriptor<FigureGroupAssociation>())) ?? 0
        XCTAssertEqual(totalAssocs, 6, "no duplicate members across two runs")
    }

    func testEnsureDynastyGroupsPreservesManualSubgroup() {
        let container = makeContainer()
        let context = container.mainContext
        let akkadEra = Era(name: "Dynasty of Akkad", orderIndex: 1)
        context.insert(akkadEra)
        let sargon = Figure(name: "Sargon", domain: "Kingship", figureDescription: "", orderIndex: 0)
        sargon.era = akkadEra
        context.insert(sargon)

        let top = FigureGroup(name: "Dynasties", icon: "building.columns", colorHex: "007AFF", kind: .skl)
        context.insert(top)
        let manualSub = FigureGroup(name: "Dynasty of Akkad", icon: "crown", colorHex: "007AFF", orderIndex: 0, kind: .skl, sortMode: .ordered)
        context.insert(manualSub)
        top.subgroups = [manualSub]
        let manualAssoc = FigureGroupAssociation(figure: sargon)
        context.insert(manualAssoc)
        manualSub.figureAssociations = [manualAssoc]
        sargon.groupAssociations.append(manualAssoc)
        manualAssoc.orderIndex = 7
        try? context.save()

        Migration.ensureDynastyGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        let subs = groups.filter { $0.name == "Dynasty of Akkad" }
        XCTAssertEqual(subs.count, 1, "existing subgroup reused, not duplicated")
        XCTAssertEqual(subs.first?.figureAssociations.count, 1, "manual member kept, no duplicate")
        XCTAssertEqual(subs.first?.figureAssociations.first?.orderIndex, 7, "manual order index untouched")
        XCTAssertEqual(subs.first?.era?.persistentModelID, akkadEra.persistentModelID, "existing subgroup linked to its era")
    }

    func testEnsureDynastyGroupsLinksErasAcrossOtherTrees() {
        let container = makeContainer()
        let context = container.mainContext
        let kishEra = Era(name: "First dynasty of Kish", orderIndex: 0)
        let akkadEra = Era(name: "Dynasty of Akkad", orderIndex: 1)
        context.insert(kishEra)
        context.insert(akkadEra)

        let legacyTop = FigureGroup(name: "Sumerian King List", icon: "building.columns", colorHex: "8E8E93", kind: .skl)
        context.insert(legacyTop)
        let kishSub = FigureGroup(name: "First dynasty of Kish", icon: "crown", colorHex: "8E8E93", orderIndex: 0, kind: .skl)
        let akkadSub = FigureGroup(name: "The dynasty of Akkad", icon: "crown", colorHex: "8E8E93", orderIndex: 1, kind: .skl)
        let typoSub = FigureGroup(name: "Fouth dynasty of Uruk", icon: "crown", colorHex: "8E8E93", orderIndex: 2, kind: .skl)
        context.insert(kishSub)
        context.insert(akkadSub)
        context.insert(typoSub)
        legacyTop.subgroups = [kishSub, akkadSub, typoSub]
        try? context.save()

        Migration.ensureDynastyGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        let kish = groups.first { $0.name == "First dynasty of Kish" && $0.parentGroup === legacyTop }
        let akkad = groups.first { $0.name == "The dynasty of Akkad" }
        let typo = groups.first { $0.name == "Fouth dynasty of Uruk" }
        XCTAssertEqual(kish?.era?.persistentModelID, kishEra.persistentModelID, "legacy subgroup linked by exact normalized name")
        XCTAssertEqual(akkad?.era?.persistentModelID, akkadEra.persistentModelID, "leading 'the' stripped before matching")
        XCTAssertNil(typo?.era, "typo'd name left untouched")
        XCTAssertEqual(kishEra.groups?.contains { $0 === kish }, true, "inverse era.groups includes legacy subgroup")
        XCTAssertEqual(kish?.figureAssociations.isEmpty, true, "no members auto-added to legacy tree")
    }

    // MARK: - Event Propagation

    func testAddEventWithPropagationCreatesFiguresAndPlacesAndThings() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Atrahasis Group", entityType: .figure)
        context.insert(group)

        let enki = Figure(name: "Enki", figureDescription: "")
        let mami = Figure(name: "Mami", figureDescription: "")
        context.insert(enki); context.insert(mami)

        let eridu = Place(name: "Eridu", placeDescription: "")
        context.insert(eridu)

        let tablet = Thing(name: "Atra-Hasis Tablet", thingDescription: "")
        context.insert(tablet)

        let flood = Event(name: "The Flood", eventDescription: "")
        context.insert(flood)

        let efa1 = EventFigureAssociation(event: flood, figure: enki)
        let efa2 = EventFigureAssociation(event: flood, figure: mami)
        context.insert(efa1); context.insert(efa2)
        flood.figureAssociations = [efa1, efa2]
        flood.involvedFigures = []

        let epa = EventPlaceAssociation(event: flood, place: eridu)
        context.insert(epa)
        flood.placeAssociations = [epa]

        let tea = ThingEventAssociation(thing: tablet, event: flood)
        context.insert(tea)
        tablet.eventAssociations = [tea]

        try? context.save()

        let summary = group.addEventWithPropagation(event: flood, in: context)
        try? context.save()

        XCTAssertEqual(summary?.figureNames.sorted(), ["Enki", "Mami"])
        XCTAssertEqual(summary?.placeNames, ["Eridu"])
        XCTAssertEqual(summary?.thingNames, ["Atra-Hasis Tablet"])

        let figNames = group.figureAssociations.compactMap { $0.figure?.name }.sorted()
        XCTAssertEqual(figNames, ["Enki", "Mami"])
        XCTAssertTrue(
            group.figureAssociations.filter { $0.event == nil }
                .allSatisfy { $0.propagatedFromEventName == "The Flood" },
            "every propagated member carries the source event name (order-independent)" )

        let placeNames = group.figureAssociations.compactMap { $0.place?.name }
        XCTAssertEqual(placeNames, ["Eridu"])

        let thingNames = group.figureAssociations.compactMap { $0.thing?.name }
        XCTAssertEqual(thingNames, ["Atra-Hasis Tablet"])
    }

    func testAddEventWithPropagationSkipsExistingMembers() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Test", entityType: .figure)
        context.insert(group)

        let enki = Figure(name: "Enki", figureDescription: "")
        context.insert(enki)

        let existing = FigureGroupAssociation(figure: enki)
        context.insert(existing)
        group.figureAssociations.append(existing)

        let flood = Event(name: "The Flood", eventDescription: "")
        context.insert(flood)

        let efa = EventFigureAssociation(event: flood, figure: enki)
        context.insert(efa)
        flood.figureAssociations = [efa]
        flood.involvedFigures = []
        try? context.save()

        let summary = group.addEventWithPropagation(event: flood, in: context)

        XCTAssertNil(summary, "nil when nothing new propagated")
        XCTAssertEqual(group.figureAssociations.count, 2, "event + existing figure")
        XCTAssertTrue(group.figureAssociations.contains { $0.event === flood }, "event was added")
    }

    func testAddEventWithPropagationIncludesLegacyInvolvedFigures() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Test", entityType: .figure)
        context.insert(group)

        let enki = Figure(name: "Enki", figureDescription: "")
        context.insert(enki)

        let flood = Event(name: "The Flood", eventDescription: "")
        context.insert(flood)
        flood.involvedFigures = [enki]
        flood.figureAssociations = []
        try? context.save()

        let summary = group.addEventWithPropagation(event: flood, in: context)

        XCTAssertEqual(summary?.figureNames, ["Enki"])
    }

    func testRemoveEventWithDepropagationRemovesOnlyPropagated() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Test", entityType: .figure)
        context.insert(group)

        let enki = Figure(name: "Enki", figureDescription: "")
        let manual = Figure(name: "Manually Added", figureDescription: "")
        context.insert(enki); context.insert(manual)

        let propagAssoc = FigureGroupAssociation(figure: enki, propagatedFromEventName: "The Flood")
        let manualAssoc = FigureGroupAssociation(figure: manual)
        context.insert(propagAssoc); context.insert(manualAssoc)
        group.figureAssociations = [propagAssoc, manualAssoc]

        let flood = Event(name: "The Flood", eventDescription: "")
        context.insert(flood)

        let efa = EventFigureAssociation(event: flood, figure: enki)
        context.insert(efa)
        flood.figureAssociations = [efa]
        flood.involvedFigures = []
        try? context.save()

        let removed = group.removeEventWithDepropagation(event: flood, in: context)
        try? context.save()

        XCTAssertEqual(removed, ["Enki"])
        XCTAssertEqual(group.figureAssociations.count, 1, "manual association kept")
        XCTAssertEqual(group.figureAssociations.first?.figure?.name, "Manually Added")
    }

    func testRemoveEventWithDepropagationKeepsIfCoveredByOtherEvent() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Test", entityType: .figure)
        context.insert(group)

        let enki = Figure(name: "Enki", figureDescription: "")
        context.insert(enki)

        let eventA = Event(name: "Event A", eventDescription: "")
        let eventB = Event(name: "Event B", eventDescription: "")
        context.insert(eventA); context.insert(eventB)

        let propagAssoc = FigureGroupAssociation(figure: enki, propagatedFromEventName: "Event A")
        let eventBAssoc = FigureGroupAssociation(event: eventB)
        context.insert(propagAssoc); context.insert(eventBAssoc)
        group.figureAssociations = [propagAssoc, eventBAssoc]

        let efaA = EventFigureAssociation(event: eventA, figure: enki)
        let efaB = EventFigureAssociation(event: eventB, figure: enki)
        context.insert(efaA); context.insert(efaB)
        eventA.figureAssociations = [efaA]
        eventB.figureAssociations = [efaB]
        eventA.involvedFigures = []
        eventB.involvedFigures = []
        try? context.save()

        _ = group.removeEventWithDepropagation(event: eventA, in: context)
        try? context.save()

        XCTAssertEqual(group.figureAssociations.count, 2, "eventB group assoc + enki (depromoted, kept)")
        XCTAssertNil(group.figureAssociations.first { $0.figure === enki }?.propagatedFromEventName, "propagation cleared")
        XCTAssertEqual(group.figureAssociations.first { $0.figure === enki }?.figure?.name, "Enki")
    }

    func testPropagationPreviewShowsCorrectCounts() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Test", entityType: .figure)
        context.insert(group)

        let enki = Figure(name: "Enki", figureDescription: "")
        let mami = Figure(name: "Mami", figureDescription: "")
        context.insert(enki); context.insert(mami)

        let eridu = Place(name: "Eridu", placeDescription: "")
        context.insert(eridu)

        let tablet = Thing(name: "Tablet", thingDescription: "")
        context.insert(tablet)

        let flood = Event(name: "The Flood", eventDescription: "")
        context.insert(flood)

        let efa = EventFigureAssociation(event: flood, figure: enki)
        context.insert(efa)
        flood.figureAssociations = [efa]
        flood.involvedFigures = [mami]

        let epa = EventPlaceAssociation(event: flood, place: eridu)
        context.insert(epa)
        flood.placeAssociations = [epa]

        let tea = ThingEventAssociation(thing: tablet, event: flood)
        context.insert(tea)
        tablet.eventAssociations = [tea]
        try? context.save()

        let preview = group.propagationPreview(for: flood)

        XCTAssertEqual(preview?.figureNames.count, 2)
        XCTAssertEqual(preview?.placeNames.count, 1)
        XCTAssertEqual(preview?.thingNames.count, 1)
        XCTAssertTrue(preview?.description.contains("2 figures") == true)
        XCTAssertTrue(preview?.description.contains("1 place") == true)
        XCTAssertTrue(preview?.description.contains("1 thing") == true)
    }

    func testPropagationPreviewExcludesExistingMembers() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Test", entityType: .figure)
        context.insert(group)

        let enki = Figure(name: "Enki", figureDescription: "")
        let mami = Figure(name: "Mami", figureDescription: "")
        context.insert(enki); context.insert(mami)

        let existing = FigureGroupAssociation(figure: enki)
        context.insert(existing)
        group.figureAssociations.append(existing)

        let flood = Event(name: "The Flood", eventDescription: "")
        context.insert(flood)

        let efa = EventFigureAssociation(event: flood, figure: enki)
        context.insert(efa)
        flood.figureAssociations = [efa]
        flood.involvedFigures = [mami]
        try? context.save()

        let preview = group.propagationPreview(for: flood)

        XCTAssertEqual(preview?.figureNames, ["Mami"], "only non-existing figure counted")
    }

    func testEventsInvolvingEntityReturnsMatchingEvents() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Test", entityType: .figure)
        context.insert(group)

        let enki = Figure(name: "Enki", figureDescription: "")
        context.insert(enki)

        let eventA = Event(name: "Event A", eventDescription: "")
        let eventB = Event(name: "Event B", eventDescription: "")
        context.insert(eventA); context.insert(eventB)

        let efaA = EventFigureAssociation(event: eventA, figure: enki)
        let efaB = EventFigureAssociation(event: eventB, figure: enki)
        context.insert(efaA); context.insert(efaB)
        eventA.figureAssociations = [efaA]
        eventB.figureAssociations = [efaB]
        eventA.involvedFigures = []
        eventB.involvedFigures = []
        try? context.save()

        let assoc = FigureGroupAssociation(figure: enki)
        let eventAInGroup = FigureGroupAssociation(event: eventA)
        let eventBInGroup = FigureGroupAssociation(event: eventB)
        context.insert(assoc); context.insert(eventAInGroup); context.insert(eventBInGroup)
        group.figureAssociations = [assoc, eventAInGroup, eventBInGroup]

        let events = group.eventsInvolving(entityID: enki.persistentModelID, in: context)
        let names = events.map(\.name).sorted()
        XCTAssertEqual(names, ["Event A", "Event B"])
    }

    func testPropagatedFromEventNameIsNilByDefault() {
        let container = makeContainer()
        let context = container.mainContext
        let assoc = FigureGroupAssociation(figure: Figure(name: "X"))
        context.insert(assoc)

        XCTAssertNil(assoc.propagatedFromEventName)
    }

    func testPropagatedFromEventNameRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let assoc = FigureGroupAssociation(figure: Figure(name: "X"), propagatedFromEventName: "The Flood")
        context.insert(assoc)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>()))?.first
        XCTAssertEqual(fetched?.propagatedFromEventName, "The Flood")
    }

    // MARK: - PopupTable Tests

    func testPopupTableDefaultInit() {
        let table = PopupTable()
        XCTAssertEqual(table.name, "")
        XCTAssertEqual(table.tableDescription, "")
        XCTAssertTrue(table.attributes.isEmpty)
        XCTAssertTrue(table.cells.isEmpty)
    }

    func testPopupTableRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Water Deities", tableDescription: "Comparing canal deities")
        context.insert(table)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<PopupTable>()))?.first
        XCTAssertEqual(fetched?.name, "Water Deities")
        XCTAssertEqual(fetched?.tableDescription, "Comparing canal deities")
    }

    func testPopupTableAttributeRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "T1")
        context.insert(table)
        let attr = PopupTableAttribute(table: table, name: "Primary Domain", orderIndex: 0)
        context.insert(attr)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<PopupTableAttribute>()))?.first
        XCTAssertEqual(fetched?.name, "Primary Domain")
        XCTAssertEqual(fetched?.orderIndex, 0)
        XCTAssertEqual(fetched?.table?.name, "T1")
    }

    func testPopupTableCellRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "T1")
        let figure = Figure(name: "Enki")
        let attr = PopupTableAttribute(table: table, name: "Domain")
        context.insert(table); context.insert(figure); context.insert(attr)
        let cell = PopupTableCell(table: table, attribute: attr, figure: figure, value: "Water")
        context.insert(cell)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<PopupTableCell>()))?.first
        XCTAssertEqual(fetched?.value, "Water")
        XCTAssertEqual(fetched?.figure?.name, "Enki")
        XCTAssertEqual(fetched?.attribute?.name, "Domain")
        XCTAssertEqual(fetched?.table?.name, "T1")
    }

    func testPopupTableFiguresDerivedFromCells() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "T1")
        let enki = Figure(name: "Enki")
        let enlil = Figure(name: "Enlil")
        let attr = PopupTableAttribute(name: "Role")
        table.attributes.append(attr)
        table.figures.append(enki)
        table.figures.append(enlil)
        context.insert(table); context.insert(enki); context.insert(enlil); context.insert(attr)
        context.insert(PopupTableCell(attribute: attr, figure: enki, value: "God of water"))
        context.insert(PopupTableCell(attribute: attr, figure: enlil, value: "God of air"))
        try? context.save()

        let fetched = ((try? context.fetch(FetchDescriptor<PopupTable>())) ?? []).first
        let names = fetched?.figures.map { $0.name }.sorted()
        XCTAssertEqual(names, ["Enki", "Enlil"])
    }

    func testPopupTableAttributeOrdering() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "T1")
        context.insert(table)
        let a2 = PopupTableAttribute(name: "Role", orderIndex: 1)
        let a1 = PopupTableAttribute(name: "Domain", orderIndex: 0)
        table.attributes.append(a2)
        table.attributes.append(a1)
        context.insert(a2); context.insert(a1)
        try? context.save()

        let fetched = ((try? context.fetch(FetchDescriptor<PopupTable>())) ?? []).first
        let sorted = fetched?.attributes.sorted { ($0.orderIndex ?? Int.max) < ($1.orderIndex ?? Int.max) }
        XCTAssertEqual(sorted?.first?.name, "Domain")
        XCTAssertEqual(sorted?.last?.name, "Role")
    }

    func testPopupTableCascadeDelete() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "T1")
        let figure = Figure(name: "Enki")
        let attr = PopupTableAttribute(name: "Domain")
        table.attributes.append(attr)
        table.figures.append(figure)
        context.insert(table); context.insert(figure); context.insert(attr)
        let cell = PopupTableCell(attribute: attr, figure: figure, value: "Water")
        table.cells.append(cell)
        context.insert(cell)
        try? context.save()

        context.delete(table)
        try? context.save()

        let tables = (try? context.fetch(FetchDescriptor<PopupTable>())) ?? []
        let attrs = (try? context.fetch(FetchDescriptor<PopupTableAttribute>())) ?? []
        let cells = (try? context.fetch(FetchDescriptor<PopupTableCell>())) ?? []
        XCTAssertTrue(tables.isEmpty)
        XCTAssertTrue(attrs.isEmpty)
        XCTAssertTrue(cells.isEmpty)
    }

    func testPopupTableCellNilValueRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "T1")
        let figure = Figure(name: "Enki")
        let attr = PopupTableAttribute(name: "Domain")
        table.attributes.append(attr)
        table.figures.append(figure)
        context.insert(table); context.insert(figure); context.insert(attr)
        let cell = PopupTableCell(attribute: attr, figure: figure, value: nil)
        table.cells.append(cell)
        context.insert(cell)
        try? context.save()

        let fetched = ((try? context.fetch(FetchDescriptor<PopupTableCell>())) ?? []).first
        XCTAssertNil(fetched?.value)
    }

    func testPopupTableColumnModeDefaultsToFigures() {
        let table = PopupTable(name: "T1")
        XCTAssertEqual(table.columnMode, .figures)
        XCTAssertNil(table.columnModeRawValue)
    }

    func testPopupTableColumnModeRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Worship")
        table.columnMode = .strings
        context.insert(table)
        try? context.save()

        let fetched = ((try? context.fetch(FetchDescriptor<PopupTable>())) ?? []).first
        XCTAssertEqual(fetched?.columnMode, .strings)
        XCTAssertEqual(fetched?.columnModeRawValue, "strings")
    }

    func testPopupTableColumnRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Worship")
        context.insert(table)
        let col = PopupTableColumn(table: table, name: "Sacrifice", orderIndex: 0)
        context.insert(col)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<PopupTableColumn>()))?.first
        XCTAssertEqual(fetched?.name, "Sacrifice")
        XCTAssertEqual(fetched?.orderIndex, 0)
        XCTAssertEqual(fetched?.table?.name, "Worship")
        XCTAssertEqual(fetched?.table?.columns.count, 1)
    }

    func testPopupTableCellWithColumnRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Worship")
        let attr = PopupTableAttribute(table: table, name: "Occasion")
        let col = PopupTableColumn(table: table, name: "Sacrifice")
        context.insert(table); context.insert(attr); context.insert(col)
        let cell = PopupTableCell(table: table, attribute: attr, column: col, value: "New Moon")
        context.insert(cell)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<PopupTableCell>()))?.first
        XCTAssertEqual(fetched?.value, "New Moon")
        XCTAssertEqual(fetched?.column?.name, "Sacrifice")
        XCTAssertNil(fetched?.figure)
        XCTAssertEqual(fetched?.attribute?.name, "Occasion")
        XCTAssertEqual(col.cells.count, 1)
    }

    func testPopupTableColumnsCascadeDelete() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Worship")
        let col = PopupTableColumn(table: table, name: "Sacrifice")
        context.insert(table); context.insert(col)
        let cell = PopupTableCell(table: table, column: col, value: "New Moon")
        table.cells.append(cell)
        context.insert(cell)
        try? context.save()

        context.delete(table)
        try? context.save()

        let columns = (try? context.fetch(FetchDescriptor<PopupTableColumn>())) ?? []
        let cells = (try? context.fetch(FetchDescriptor<PopupTableCell>())) ?? []
        XCTAssertTrue(columns.isEmpty)
        XCTAssertTrue(cells.isEmpty)
    }

    // MARK: - SKLTimelineLayout

    func testIsDynastyEra() {
        let sklFigure = Figure(name: "Jushur", source: "Sumerian King List")
        let mythFigure = Figure(name: "Enki", source: "Sumerian mythology")
        XCTAssertTrue(SKLTimelineLayout.isDynastyEra([sklFigure]))
        XCTAssertTrue(SKLTimelineLayout.isDynastyEra([mythFigure, sklFigure]))
        XCTAssertFalse(SKLTimelineLayout.isDynastyEra([mythFigure]))
        XCTAssertFalse(SKLTimelineLayout.isDynastyEra([]))
    }

    func testIsDynastyEraMatchesCompoundSource() {
        // Kings whose source is a compound string (like Etana) still count.
        let figure = Figure(name: "Etana", source: "Sumerian King List; Sumerian mythology")
        XCTAssertTrue(SKLTimelineLayout.isDynastyEra([figure]))
    }

    func testDynastyOrderedFiguresSortsByReignSequence() {
        // Insertion order is scrambled (as in the live DB); orderIndex is the SKL sequence.
        let jushur = Figure(name: "Jushur", source: "Sumerian King List", orderIndex: 0)
        let kullassina = Figure(name: "Kullassina-bel", source: "Sumerian King List", orderIndex: 1)
        let etana = Figure(name: "Etana", source: "Sumerian King List; Sumerian mythology", orderIndex: 12)
        let aga = Figure(name: "Aga of Kish", source: "Sumerian King List", orderIndex: 22)

        let ordered = SKLTimelineLayout.dynastyOrderedFigures([aga, etana, kullassina, jushur])
        XCTAssertEqual(ordered.map(\.name), ["Jushur", "Kullassina-bel", "Etana", "Aga of Kish"])
    }

    func testDynastyOrderedFiguresTieBreaksByName() {
        let a = Figure(name: "B", source: "Sumerian King List", orderIndex: 0)
        let b = Figure(name: "A", source: "Sumerian King List", orderIndex: 0)
        let ordered = SKLTimelineLayout.dynastyOrderedFigures([a, b])
        XCTAssertEqual(ordered.map(\.name), ["A", "B"])
    }

    func testDynastySlotCentersEqualSpacing() {
        // 23 kings across a 400-year band: first ≈ start+8.7, middle = 200, last ≈ start+391.3.
        let slots = SKLTimelineLayout.dynastySlotCenters(count: 23, spanYears: 400)
        XCTAssertEqual(slots.count, 23)
        XCTAssertEqual(slots.first, 8)
        XCTAssertEqual(slots[11], 200)
        XCTAssertEqual(slots.last, 391)
        XCTAssertEqual(slots, slots.sorted(), "slots are monotonically increasing")
    }

    func testDynastySlotCentersSingleRulerAndSmallSpan() {
        XCTAssertEqual(SKLTimelineLayout.dynastySlotCenters(count: 1, spanYears: 400), [200])
        XCTAssertEqual(SKLTimelineLayout.dynastySlotCenters(count: 0, spanYears: 100), [50], "count clamps to 1")
        XCTAssertEqual(SKLTimelineLayout.dynastySlotCenters(count: 3, spanYears: 100), [16, 50, 83])
    }

    // MARK: - fixEraOrderIndices dynasty renumbering

    func testFixEraOrderIndicesRenumbersDynastyErasToSeedOrder() {
        let container = makeContainer()
        let context = container.mainContext
        let dynasties: [(String, Int)] = [
            ("First dynasty of Kish", 509),
            ("First rulers of Uruk", 510),
            ("First dynasty of Ur", 511),
            ("Dynasty of Awan", 512),
            ("Dynasty of Akkad", 523),
            ("Gutian rule", 525),
            ("Dynasty of Isin", 528),
        ]
        for (name, order) in dynasties {
            context.insert(Era(name: name, orderIndex: order))
        }
        try? context.save()

        Migration.fixEraOrderIndices(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let byName = Dictionary(uniqueKeysWithValues: eras.map { ($0.name, $0) })
        XCTAssertEqual(byName["First dynasty of Kish"]?.orderIndex, 11)
        XCTAssertEqual(byName["First rulers of Uruk"]?.orderIndex, 12)
        XCTAssertEqual(byName["First dynasty of Ur"]?.orderIndex, 13)
        XCTAssertEqual(byName["Dynasty of Awan"]?.orderIndex, 14)
        XCTAssertEqual(byName["Dynasty of Akkad"]?.orderIndex, 25)
        XCTAssertEqual(byName["Gutian rule"]?.orderIndex, 27)
        XCTAssertEqual(byName["Dynasty of Isin"]?.orderIndex, 30)
    }

    func testFixEraOrderIndicesKeepsPreFloodAndUnknownErasStable() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Creation", orderIndex: 0))
        context.insert(Era(name: "Age of the First Gods", orderIndex: 2))
        context.insert(Era(name: "Early Dynastic Period", orderIndex: 9))
        context.insert(Era(name: "My Custom Period", orderIndex: 40))
        try? context.save()

        Migration.fixEraOrderIndices(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let byName = Dictionary(uniqueKeysWithValues: eras.map { ($0.name, $0) })
        XCTAssertEqual(byName["Creation"]?.orderIndex, 1)
        XCTAssertEqual(byName["Age of the First Gods"]?.orderIndex, 0)
        XCTAssertEqual(byName["Early Dynastic Period"]?.orderIndex, 9)
        XCTAssertEqual(byName["My Custom Period"]?.orderIndex, 41, "unlisted era >= 9 keeps the +1 shift")
    }

    func testFixEraOrderIndicesIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Dynasty of Akkad", orderIndex: 523))
        try? context.save()

        Migration.fixEraOrderIndices(context: context)
        Migration.fixEraOrderIndices(context: context)

        let era = (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == "Dynasty of Akkad" })))?.first
        XCTAssertEqual(era?.orderIndex, 25)
    }

    // MARK: - ensureAntediluvianChronology

    private func eraBy(name: String, _ context: ModelContext) -> Era? {
        (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == name })))?.first
    }

    private func figureBy(name: String, _ context: ModelContext) -> Figure? {
        (try? context.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.name == name })))?.first
    }

    func testAntediluvianChronologySetsEraDateBands() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Creation", orderIndex: 0))
        context.insert(Era(name: "Creation of Mankind", orderIndex: 4,
                           startDate: MythologicalDate(startYear: -200000, endYear: -200000, era: "Creation of Mankind"),
                           endDate: MythologicalDate(startYear: -100000, endYear: -100000, era: "Creation of Mankind")))
        context.insert(Era(name: "Age of the Watchers", orderIndex: 1))
        context.insert(Era(name: "Antediluvian Period", orderIndex: 5,
                           startDate: MythologicalDate(startYear: -241200, endYear: -241200, era: "Antediluvian Period"),
                           endDate: MythologicalDate(startYear: -28000, endYear: -28000, era: "Antediluvian Period")))
        try? context.save()

        Migration.ensureAntediluvianChronology(context: context)

        XCTAssertEqual(eraBy(name: "Creation", context)?.startDate.startYear, -300000)
        XCTAssertEqual(eraBy(name: "Creation", context)?.endDate.endYear, -280000)
        XCTAssertEqual(eraBy(name: "Creation of Mankind", context)?.startDate.startYear, -280000)
        XCTAssertEqual(eraBy(name: "Creation of Mankind", context)?.endDate.endYear, -275000)
        XCTAssertEqual(eraBy(name: "Age of the Watchers", context)?.startDate.startYear, -275000)
        XCTAssertEqual(eraBy(name: "Age of the Watchers", context)?.endDate.endYear, -269200)
        XCTAssertEqual(eraBy(name: "Antediluvian Period", context)?.startDate.startYear, -269200)
        XCTAssertEqual(eraBy(name: "Antediluvian Period", context)?.endDate.endYear, -28000)
    }

    func testAntediluvianChronologyEraDatesIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Creation", orderIndex: 0))
        try? context.save()

        Migration.ensureAntediluvianChronology(context: context)
        let first = eraBy(name: "Creation", context)?.startDate.startYear

        Migration.ensureAntediluvianChronology(context: context)
        XCTAssertEqual(eraBy(name: "Creation", context)?.startDate.startYear, first)
    }

    func testAntediluvianChronologyDoesNotOverwriteUserEditedEraDates() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Creation", orderIndex: 0,
                           startDate: MythologicalDate(startYear: -100000, endYear: -100000, era: "Creation"),
                           endDate: MythologicalDate(startYear: -90000, endYear: -90000, era: "Creation")))
        try? context.save()

        Migration.ensureAntediluvianChronology(context: context)

        XCTAssertEqual(eraBy(name: "Creation", context)?.startDate.startYear, -100000, "user-entered dates are never clobbered")
    }

    func testAntediluvianChronologyToleratesDuplicateFigureNames() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Creation", orderIndex: 0))
        let era = Era(name: "Antediluvian Period", orderIndex: 4)
        context.insert(era)
        context.insert(Figure(name: "Uras", title: "patron god of Dilbat"))
        context.insert(Figure(name: "Ur-As", source: "user-added duplicate"))
        let alulim = Figure(name: "Alulim", source: "Sumerian King List")
        alulim.era = era
        context.insert(alulim)
        try? context.save()

        Migration.ensureAntediluvianChronology(context: context)

        XCTAssertEqual(figureBy(name: "Alulim", context)?.birthDate.startYear, -269200,
                       "migration keeps working on canonical names despite duplicate user data")
        XCTAssertEqual(eraBy(name: "Creation", context)?.startDate.startYear, -300000)
        let urasCount = ((try? context.fetch(FetchDescriptor<Figure>())) ?? [])
            .filter { ["Uras", "Ur-As"].contains($0.name) }.count
        XCTAssertEqual(urasCount, 2, "migration never deletes user data")
    }

    func testAntediluvianChronologyAssignsKingDates() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Antediluvian Period", orderIndex: 4)
        context.insert(era)
        for name in ["Alulim", "Alalngar", "En-men-lu-ana", "En-men-gal-ana", "Dumuzi the Shepherd", "En-sipad-zid-ana", "En-men-dur-ana", "Ubara-Tutu"] {
            let f = Figure(name: name, source: "Sumerian King List")
            f.era = era
            context.insert(f)
        }
        let ziusudra = Figure(name: "Ziusudra",
                              birthDate: MythologicalDate(year: -30000, era: "Antediluvian Period"),
                              source: "Sumerian King List")
        ziusudra.era = era
        context.insert(ziusudra)
        try? context.save()

        Migration.ensureAntediluvianChronology(context: context)

        XCTAssertEqual(figureBy(name: "Alulim", context)?.birthDate.startYear, -269200)
        XCTAssertEqual(figureBy(name: "Alulim", context)?.deathDate.endYear, -240400)
        XCTAssertEqual(figureBy(name: "Alulim", context)?.decodedDateSource, .computed)
        XCTAssertEqual(figureBy(name: "Dumuzi the Shepherd", context)?.birthDate.startYear, -132400)
        XCTAssertEqual(figureBy(name: "Dumuzi the Shepherd", context)?.deathDate.endYear, -96400)
        XCTAssertEqual(figureBy(name: "Ubara-Tutu", context)?.birthDate.startYear, -46600)
        XCTAssertEqual(figureBy(name: "Ubara-Tutu", context)?.deathDate.endYear, -28000)
        XCTAssertEqual(ziusudra.birthDate.startYear, -30000, "Ziusudra is the flood survivor, not one of the eight — untouched")
    }

    func testAntediluvianChronologyDoesNotOverwriteExistingKingDates() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Antediluvian Period", orderIndex: 4)
        context.insert(era)
        let alulim = Figure(name: "Alulim",
                            birthDate: MythologicalDate(year: -111111, era: "Antediluvian Period"),
                            source: "Sumerian King List")
        alulim.era = era
        context.insert(alulim)
        try? context.save()

        Migration.ensureAntediluvianChronology(context: context)

        XCTAssertEqual(alulim.birthDate.startYear, -111111, "a user-entered king date is never overwritten")
    }

    func testAntediluvianChronologyMovesFigures() {
        let container = makeContainer()
        let context = container.mainContext
        let firstGods = Era(name: "Age of the First Gods", orderIndex: 0)
        let creation = Era(name: "Creation", orderIndex: 1)
        let mankind = Era(name: "Creation of Mankind", orderIndex: 2)
        let watchers = Era(name: "Age of the Watchers", orderIndex: 3)
        let antediluvian = Era(name: "Antediluvian Period", orderIndex: 4)
        for e in [firstGods, creation, mankind, watchers, antediluvian] { context.insert(e) }

        func fig(_ name: String, _ era: Era?) -> Figure {
            let f = Figure(name: name)
            f.era = era
            f.birthDate = MythologicalDate(year: nil, era: era?.name ?? "")
            context.insert(f)
            return f
        }
        let tiamat = fig("Tiamat", creation)
        let an = fig("An", firstGods)
        let michael = fig("Michael", creation)
        let alulim = fig("Alulim", nil)
        let dumuzi = fig("Dumuzi the Shepherd", firstGods)
        let adapa = fig("Adapa", mankind)
        let mushdamma = fig("Mushdamma", creation)
        try? context.save()

        Migration.ensureAntediluvianChronology(context: context)

        XCTAssertEqual(tiamat.era?.name, "Age of the First Gods")
        XCTAssertEqual(tiamat.birthDate.era, "Age of the First Gods", "birth-era string updated so the launch link-resync keeps the move")
        XCTAssertEqual(an.era?.name, "Creation")
        XCTAssertEqual(an.birthDate.era, "Creation")
        XCTAssertEqual(michael.era?.name, "Age of the Watchers")
        XCTAssertEqual(alulim.era?.name, "Antediluvian Period")
        XCTAssertEqual(alulim.birthDate.era, "Antediluvian Period")
        XCTAssertEqual(dumuzi.era?.name, "Antediluvian Period")
        XCTAssertEqual(adapa.era?.name, "Creation of Mankind", "already correct — no move")
        XCTAssertEqual(mushdamma.era?.name, "Creation", "already in Creation — no move")
    }

    func testAntediluvianChronologyMoveIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let firstGods = Era(name: "Age of the First Gods", orderIndex: 0)
        let creation = Era(name: "Creation", orderIndex: 1)
        context.insert(firstGods); context.insert(creation)
        let tiamat = Figure(name: "Tiamat")
        tiamat.era = creation
        tiamat.birthDate = MythologicalDate(year: nil, era: "Creation")
        context.insert(tiamat)
        try? context.save()

        Migration.ensureAntediluvianChronology(context: context)
        Migration.ensureAntediluvianChronology(context: context)

        XCTAssertEqual(tiamat.era?.name, "Age of the First Gods")
    }

    func testAntediluvianChronologySetsSuccessionOrder() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Antediluvian Period", orderIndex: 4)
        context.insert(era)
        let names = ["Ziusudra", "Alalngar", "En-men-lu-ana", "En-men-gal-ana", "Dumuzi the Shepherd", "En-sipad-zid-ana", "En-men-dur-ana", "Ubara-Tutu", "Alulim"]
        for (i, name) in names.enumerated() {
            let f = Figure(name: name, orderIndex: i == 0 ? 0 : 9 - i)
            f.era = era
            context.insert(f)
        }
        try? context.save()

        Migration.ensureAntediluvianChronology(context: context)

        XCTAssertEqual(figureBy(name: "Alulim", context)?.orderIndex, 0)
        XCTAssertEqual(figureBy(name: "Alalngar", context)?.orderIndex, 1)
        XCTAssertEqual(figureBy(name: "Dumuzi the Shepherd", context)?.orderIndex, 4)
        XCTAssertEqual(figureBy(name: "Ubara-Tutu", context)?.orderIndex, 7)
        XCTAssertEqual(figureBy(name: "Ziusudra", context)?.orderIndex, 8)
    }

    func testFixEraOrderIndicesPreFloodSequence() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Creation", orderIndex: 0))
        context.insert(Era(name: "Age of the Watchers", orderIndex: 1))
        context.insert(Era(name: "Age of the First Gods", orderIndex: 2))
        context.insert(Era(name: "Creation of Mankind", orderIndex: 4))
        context.insert(Era(name: "Antediluvian Period", orderIndex: 5))
        context.insert(Era(name: "The Great Flood", orderIndex: 7))
        try? context.save()

        Migration.fixEraOrderIndices(context: context)

        let byName = Dictionary(uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Era>())) ?? []).map { ($0.name, $0) })
        XCTAssertEqual(byName["Age of the First Gods"]?.orderIndex, 0)
        XCTAssertEqual(byName["Creation"]?.orderIndex, 1)
        XCTAssertEqual(byName["Creation of Mankind"]?.orderIndex, 2)
        XCTAssertEqual(byName["Age of the Watchers"]?.orderIndex, 3)
        XCTAssertEqual(byName["Antediluvian Period"]?.orderIndex, 4)
        XCTAssertEqual(byName["The Great Flood"]?.orderIndex, 7, "flood stays at the post-flood boundary (orderIndex >= 7)")
    }

    // MARK: - Role Type Reverse Names Tests

    func testRoleTypeDisplayNameForwardAndReverse() {
        let role = PlacePlaceRoleType(name: "Located Within", icon: "arrow.down", colorHex: "34C759", reverseName: "Contains")
        XCTAssertEqual(role.displayName(isReverse: false), "Located Within")
        XCTAssertEqual(role.displayName(isReverse: true), "Contains")
    }

    func testRoleTypeDisplayNameFallsBackToNameWhenNoReverse() {
        let role = EventEventRoleType(name: "Parallels", icon: "equal", colorHex: "34C759")
        XCTAssertEqual(role.displayName(isReverse: false), "Parallels")
        XCTAssertEqual(role.displayName(isReverse: true), "Parallels", "no reverseName set → fall back to forward name")
    }

    func testEnsureRoleReverseNamesBackfillsAllKinds() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensurePlacePlaceRoleTypesExist(context: context)
        Migration.ensureEventEventRoleTypesExist(context: context)
        Migration.ensureEventPlaceRoleTypesExist(context: context)
        Migration.ensureFigurePlaceRoleTypesExist(context: context)
        Migration.ensureThingFigureRoleTypesExist(context: context)
        Migration.ensureThingPlaceRoleTypesExist(context: context)
        Migration.ensureThingEventRoleTypesExist(context: context)

        Migration.ensureRoleReverseNames(context: context)

        let ppa = (try? context.fetch(FetchDescriptor<PlacePlaceRoleType>())) ?? []
        XCTAssertEqual(ppa.first { $0.name == "Located Within" }?.reverseName, "Contains")
        let eee = (try? context.fetch(FetchDescriptor<EventEventRoleType>())) ?? []
        XCTAssertEqual(eee.first { $0.name == "Caused" }?.reverseName, "Caused By")
        XCTAssertEqual(eee.first { $0.name == "Precedes" }?.reverseName, "Follows")
        let epa = (try? context.fetch(FetchDescriptor<EventPlaceRoleType>())) ?? []
        XCTAssertEqual(epa.first { $0.name == "Occurred At" }?.reverseName, "Site Of")
        let fpa = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
        XCTAssertEqual(fpa.first { $0.name == "Patron Deity" }?.reverseName, "Patron Of")
        let tfa = (try? context.fetch(FetchDescriptor<ThingFigureRoleType>())) ?? []
        XCTAssertEqual(tfa.first { $0.name == "Owned By" }?.reverseName, "Owns")
        let tpa = (try? context.fetch(FetchDescriptor<ThingPlaceRoleType>())) ?? []
        XCTAssertEqual(tpa.first { $0.name == "Located At" }?.reverseName, "Houses")
        let tea = (try? context.fetch(FetchDescriptor<ThingEventRoleType>())) ?? []
        XCTAssertEqual(tea.first { $0.name == "Used In" }?.reverseName, "Used")
    }

    func testEnsureRoleReverseNamesIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensurePlacePlaceRoleTypesExist(context: context)
        Migration.ensureRoleReverseNames(context: context)
        Migration.ensureRoleReverseNames(context: context)
        let roles = (try? context.fetch(FetchDescriptor<PlacePlaceRoleType>())) ?? []
        XCTAssertEqual(roles.first { $0.name == "Located Within" }?.reverseName, "Contains")
    }

    func testEnsureRoleReverseNamesNeverOverwritesUserValue() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensurePlacePlaceRoleTypesExist(context: context)
        let roles = (try? context.fetch(FetchDescriptor<PlacePlaceRoleType>())) ?? []
        roles.first { $0.name == "Located Within" }?.reverseName = "Encloses"
        try? context.save()

        Migration.ensureRoleReverseNames(context: context)

        let after = (try? context.fetch(FetchDescriptor<PlacePlaceRoleType>())) ?? []
        XCTAssertEqual(after.first { $0.name == "Located Within" }?.reverseName, "Encloses", "user-set reverse name must win")
    }
}
