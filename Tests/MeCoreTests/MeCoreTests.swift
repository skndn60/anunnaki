import XCTest
import SwiftData
@testable import MeCore

@MainActor
final class MeCoreTests: XCTestCase {
    private func makeContainer() -> ModelContainer {
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
            FigureGroup.self, FigureGroupAssociation.self
        ])
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

    func testRegnalKeyOrdersEventsByDate() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Events", entityType: .event)
        context.insert(group)
        // sortValue: negative = earlier (BCE).
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

    func testFromTextGenderDeityDetected() {
        let male = FromTextParser.parse("Marduk is a god of Babylon, the son of Enki")
        XCTAssertEqual(male.gender, .male)
        XCTAssertEqual(male.figureKind, .deity)

        let female = FromTextParser.parse("Sarpanit is a goddess, the consort of Marduk")
        XCTAssertEqual(female.gender, .female)
        XCTAssertEqual(female.figureKind, .deity)
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
}
