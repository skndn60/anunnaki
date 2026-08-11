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
            Pantheon.self, FigurePantheonAssociation.self
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
        XCTAssertEqual(figureTypes.count, 7)
        XCTAssertEqual(figureTypes.map(\.name), ["Archangel", "Commander", "Deity", "Human", "Igigi", "Primordial", "Semi-Divine"])
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

        XCTAssertEqual(figureTypes, 7)
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
            Pantheon.self, FigurePantheonAssociation.self
        ])
        let config = ModelConfiguration(schema: schema, url: url)
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
            Pantheon.self, FigurePantheonAssociation.self
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
            Pantheon.self, FigurePantheonAssociation.self
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
}
