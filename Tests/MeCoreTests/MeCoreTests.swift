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
             ImageAsset.self, FigurePlaceAssociation.self, FigurePlaceRoleType.self,
             PlacePlaceAssociation.self, PlacePlaceRoleType.self,
             EventEventAssociation.self, EventEventRoleType.self,
             EventPlaceAssociation.self, EventPlaceRoleType.self,
             DataVersion.self, Tag.self
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
        XCTAssertEqual(eventTypes.count, 8)
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
        XCTAssertEqual(eventTypes, 8)
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

    func testQueryEngineFallbackResolveByTitle() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)

        let figure = Figure(name: "Ziusudra", title: "King of Shuruppak", gender: .male)
        context.insert(figure)
        try? context.save()

        let engine = QueryEngine(context: context)
        let result = engine.query("king of shuruppak")

        guard case .figure(let dossier) = result else {
            XCTFail("Expected figure result, got \(result)")
            return
        }
        XCTAssertEqual(dossier.figure.name, "Ziusudra")
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
}
