import XCTest
import SwiftData
@testable import MeCore

@MainActor
final class MeCoreTests: XCTestCase {
    private func makeContainer() -> ModelContainer {
        let schema = Schema([
            Figure.self, FigureType.self, Relationship.self, Era.self,
            Place.self, PlaceType.self, Event.self, EventType.self,
            Source.self, Citation.self, AlternateName.self, Attachment.self,
            FigureImage.self, FigurePlaceAssociation.self, PlacePlaceAssociation.self,
            EventEventAssociation.self, EventPlaceAssociation.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create test container: \(error)")
        }
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
        XCTAssertEqual(figureTypes.count, 4)
        XCTAssertEqual(figureTypes.map(\.name), ["Deity", "Human", "Primordial", "Semi-Divine"])
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

        XCTAssertEqual(figureTypes, 4)
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

        let relationship = Relationship(fromFigure: anu, toFigure: enlil, relationshipType: .father)
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

        context.insert(Relationship(fromFigure: anu, toFigure: enlil, relationshipType: .father))
        context.insert(Relationship(fromFigure: antu, toFigure: enlil, relationshipType: .mother))
        try? context.save()

        let dossier = context.buildFigureDossier(enlil)
        XCTAssertEqual(dossier.parents.map(\.name).sorted(), ["Antu", "Anu"])
        XCTAssertEqual(dossier.children.map(\.name), [])
        XCTAssertEqual(dossier.figure.name, "Enlil")
    }
}
