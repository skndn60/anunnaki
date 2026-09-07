import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
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

    // MARK: - PopupTable cell/table sources

    func testCellSourceLinksExistingSourceCaseInsensitivelyWithoutCreating() {
        let container = makeContainer()
        let context = container.mainContext
        let source = Source(name: "Enuma Elish")
        context.insert(source)
        let table = PopupTable(name: "T")
        context.insert(table)
        let cell = PopupTableCell(attribute: nil, figure: nil, value: "Sky father")
        table.cells.append(cell)
        context.insert(cell)
        try? context.save()

        cell.setSourceText("enuma elish", context: context)
        XCTAssertEqual(cell.source, "enuma elish")
        XCTAssertEqual(cell.sourceRef?.name, "Enuma Elish")
        XCTAssertTrue(source.popupTableCells.contains(where: { $0 == cell }))

        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(allSources.count, 1, "must never create a new Source row")

        cell.setSourceText("", context: context)
        XCTAssertNil(cell.source)
        XCTAssertNil(cell.sourceRef)
        XCTAssertTrue(source.popupTableCells.isEmpty)
    }

    func testCellSourceLenientMatchLinksVariantNameToSourceRow() {
        let container = makeContainer()
        let context = container.mainContext
        let an = Source(name: "Lexical God List An = Anum (Tablet IV)")
        context.insert(an)
        let table = PopupTable(name: "T")
        context.insert(table)
        let cell = PopupTableCell(attribute: nil, figure: nil, value: "An")
        table.cells.append(cell)
        context.insert(cell)
        try? context.save()

        cell.addCellSource(named: "An=Anum", location: "IV", context: context)

        let cellSource = cell.cellSources.first
        XCTAssertNotNil(cellSource)
        XCTAssertEqual(cellSource?.sourceRef?.name, "Lexical God List An = Anum (Tablet IV)")
        XCTAssertTrue(an.cellListSources.contains { $0 === cellSource })
        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(allSources.count, 1, "must never create a new Source row")
    }

    func testBestMatchPrefersExactThenShortestContaining() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Source(name: "Atra-Hasis"))
        context.insert(Source(name: "Enuma Elish"))
        context.insert(Source(name: "Lexical God List An = Anum (Tablet IV)"))
        let sources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []

        XCTAssertEqual(Source.bestMatch(forCandidate: "Atrahasis", among: sources)?.name, "Atra-Hasis")
        XCTAssertEqual(Source.bestMatch(forCandidate: "AN = ANUM", among: sources)?.name, "Lexical God List An = Anum (Tablet IV)")
        XCTAssertNil(Source.bestMatch(forCandidate: "No such source", among: sources))
        XCTAssertNil(Source.bestMatch(forCandidate: "x", among: sources), "too short → no spurious link")
    }

    func testEnsureCellSourceLinksMigrationBackLinksExistingFreeTextCells() {
        let container = makeContainer()
        let context = container.mainContext
        let an = Source(name: "Lexical God List An = Anum (Tablet IV)")
        context.insert(an)
        let table = PopupTable(name: "T")
        context.insert(table)
        let cell = PopupTableCell(attribute: nil, figure: nil, value: "An")
        table.cells.append(cell)
        context.insert(cell)
        let cellSource = CellSource(source: "An=Anum", location: nil)
        context.insert(cellSource)
        cell.cellSources.append(cellSource)
        try? context.save()
        XCTAssertNil(cellSource.sourceRef)

        Migration.ensureCellSourceLinksExist(context: context)

        XCTAssertEqual(cellSource.sourceRef?.name, "Lexical God List An = Anum (Tablet IV)")
        XCTAssertTrue(an.cellListSources.contains { $0 === cellSource })
    }

    func testTableSourceLinksAndDetachesIndependentlyOfCells() {
        let container = makeContainer()
        let context = container.mainContext
        let source = Source(name: "SKL")
        context.insert(source)
        let table = PopupTable(name: "Kings")
        context.insert(table)
        try? context.save()

        table.setSourceText("skl", context: context)
        XCTAssertEqual(table.sourceRef?.name, "SKL")
        XCTAssertTrue(source.popupTables.contains(where: { $0 == table }))
        XCTAssertNotEqual(table.sourceRef, source.popupTableCells.first?.sourceRef)

        table.setSourceText("Some other work", context: context)
        XCTAssertEqual(table.source, "Some other work")
        XCTAssertNil(table.sourceRef, "no matching Source row → text stays inert, link cleared")
        XCTAssertTrue(source.popupTables.isEmpty)

        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(allSources.count, 1)
    }

    func testRepointingSourceMovesLinkBetweenRows() {
        let container = makeContainer()
        let context = container.mainContext
        let a = Source(name: "Atra-Hasis")
        let b = Source(name: "Enuma Elish")
        context.insert(a)
        context.insert(b)
        let table = PopupTable(name: "T")
        context.insert(table)
        try? context.save()

        table.setSourceText("Atra-Hasis", context: context)
        XCTAssertTrue(a.popupTables.contains(where: { $0 == table }))

        table.setSourceText("enuma elish", context: context)
        XCTAssertTrue(b.popupTables.contains(where: { $0 == table }))
        XCTAssertTrue(a.popupTables.isEmpty)
    }

    // MARK: - AI-draft table findings

    func makeCell(_ context: ModelContext, table: PopupTable, value: String?, source: String?) -> PopupTableCell {
        let cell = PopupTableCell(value: value, source: source)
        cell.table = table
        table.cells.append(cell)
        context.insert(cell)
        return cell
    }

    func testAIDraftTableFindingReportsUnsourcedCells() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Water Deities")
        table.setSourceText("AI-generated (Gemini)", context: context)
        for _ in 0..<2 { makeCell(context, table: table, value: "x", source: nil) }
        makeCell(context, table: table, value: "y", source: "Enuma Elish")
        makeCell(context, table: table, value: "z", source: nil)
        try? context.save()

        let findings = ConsistencyEngine.checkAIDraftTables(tables: [table])
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.kind, .aiDraftTable)
        XCTAssertEqual(findings.first?.severity, .info)
        XCTAssertEqual(findings.first?.entityKind, "Comparison Table")
        XCTAssertTrue(findings.first?.message.contains("table-wide source is AI-generated") ?? false)
        XCTAssertTrue(findings.first?.message.contains("3 of 4 cells have no individual source") ?? false)
    }

    func testPlaceWithoutCoordinatesRespectsCoordinatesUnknownFlag() {
        let container = makeContainer()
        let context = container.mainContext
        let lost = Place(name: "Unfound Ancient City", placeType: nil, modernLocation: "Unknown", placeDescription: "", source: "")
        lost.coordinatesUnknown = true
        context.insert(lost)
        let plain = Place(name: "Missing But Known", placeType: nil, modernLocation: "Iraq", placeDescription: "", source: "")
        context.insert(plain)
        try? context.save()

        let findings = ConsistencyEngine.runAll(
            figures: [], relationships: [], alternateNames: [], events: [], eras: [],
            places: [lost, plain]
        )
        let coordFindings = findings.filter { $0.kind == .placeWithoutCoordinates }
        XCTAssertEqual(coordFindings.count, 1, "only the place not marked coordinatesUnknown should be flagged")
        XCTAssertEqual(coordFindings.first?.entityName, "Missing But Known")
    }

    func testPlaceWithoutCoordinatesStatsRespectsCoordinatesUnknownFlag() {
        let container = makeContainer()
        let context = container.mainContext
        let lost = Place(name: "Unfound Site", placeType: nil, modernLocation: "", placeDescription: "", source: "")
        lost.coordinatesUnknown = true
        context.insert(lost)
        try? context.save()

        let places: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let all = places.filter { $0.coverageExempt != true }
        var missing: [Place] = []
        for p in all {
            if p.latitude == nil || p.longitude == nil { if p.coordinatesUnknown != true { missing.append(p) } }
        }
        XCTAssertTrue(missing.isEmpty, "coordinatesUnknown places should not count as missing coordinates")
    }

    func testRealSourcedTableProducesNoAIDraftFinding() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Kings")
        table.setSourceText("Sumerian King List", context: context)
        makeCell(context, table: table, value: "a", source: nil)
        try? context.save()

        XCTAssertTrue(ConsistencyEngine.checkAIDraftTables(tables: [table]).isEmpty)

        var runAllFindings = ConsistencyEngine.runAll(
            figures: [], relationships: [], alternateNames: [], events: [], eras: [],
            popupTables: [table]
        )
        XCTAssertFalse(runAllFindings.contains { $0.kind == .aiDraftTable })
    }

    func testCellOnlyAIDraftCitationsFlagged() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Mixed Provenance")
        makeCell(context, table: table, value: "a", source: "Gemini draft")
        makeCell(context, table: table, value: "b", source: "Enuma Elish")
        try? context.save()

        let findings = ConsistencyEngine.checkAIDraftTables(tables: [table])
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings.first?.message.contains("1 cell cites AI-generated content") ?? false)
        XCTAssertTrue(findings.first?.message.contains("All 2 cells carry their own source.") ?? false)
    }

    func testRealTableWideSourceCoversUnsourcedCells() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Canal Deities")
        table.setSourceText("Sumerian Mythology", context: context)
        makeCell(context, table: table, value: "a", source: nil)
        makeCell(context, table: table, value: "b", source: nil)
        makeCell(context, table: table, value: "c", source: "Enuma Elish")
        try? context.save()

        let findings = ConsistencyEngine.checkAIDraftTables(tables: [table])
        XCTAssertEqual(findings.count, 0, "a real table-wide source should produce no AI-draft finding")
    }

    func testRealTableWideSourceStillFlagsAIDraftCellWithoutCountingCoveredCells() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Canal Deities")
        table.setSourceText("Sumerian Mythology", context: context)
        makeCell(context, table: table, value: "a", source: nil)
        makeCell(context, table: table, value: "b", source: "Gemini draft")
        try? context.save()

        let findings = ConsistencyEngine.checkAIDraftTables(tables: [table])
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings.first?.message.contains("1 cell cites AI-generated content") ?? false)
        XCTAssertTrue(findings.first?.message.contains("All cells are covered by the table-wide source.") ?? false)
        XCTAssertFalse(findings.first?.message.contains("have no individual source") ?? true)
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

    func testEnsureComparisonStateEmoji() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Mesopotamian City Matrix")
        context.insert(table)

        func add(_ value: String?) -> PopupTableCell {
            let cell = PopupTableCell(value: value)
            table.cells.append(cell)
            context.insert(cell)
            return cell
        }

        let friendly = add("Friendly")
        let neutral = add("neutral")
        let hostile = add("HOSTILE")
        let allied = add("Allied")
        let empty = add("")
        let nilCell = add(nil)

        let otherTable = PopupTable(name: "Water Deities")
        let untouched = PopupTableCell(value: "neutral")
        otherTable.cells.append(untouched)
        context.insert(otherTable); context.insert(untouched)
        try? context.save()

        Migration.ensureComparisonStateEmoji(context: context)
        try? context.save()

        XCTAssertEqual(friendly.value, "\u{1F91D}")
        XCTAssertEqual(neutral.value, "\u{1F610}")
        XCTAssertEqual(hostile.value, "\u{2694}\u{FE0F}")
        XCTAssertEqual(allied.value, "Allied")
        XCTAssertEqual(empty.value ?? "", "")
        XCTAssertNil(nilCell.value)
        XCTAssertEqual(untouched.value, "neutral")

        Migration.ensureComparisonStateEmoji(context: context)
        try? context.save()
        XCTAssertEqual(friendly.value, "\u{1F91D}")
        XCTAssertEqual(untouched.value, "neutral")
    }

    func testPopupTableCellCommentRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "T1")
        let figure = Figure(name: "Enki")
        let attr = PopupTableAttribute(name: "Status")
        table.attributes.append(attr)
        table.figures.append(figure)
        context.insert(table); context.insert(figure); context.insert(attr)
        let cell = PopupTableCell(attribute: attr, figure: figure, value: "Friendly", comment: "Considered blessed by Enki")
        table.cells.append(cell)
        context.insert(cell)
        try? context.save()

        let fetched = ((try? context.fetch(FetchDescriptor<PopupTableCell>())) ?? []).first
        XCTAssertEqual(fetched?.value, "Friendly")
        XCTAssertEqual(fetched?.comment, "Considered blessed by Enki")
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

    func testPopupTableColumnLayoutFigureWidthRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Water Deities")
        let figure = Figure(name: "Enki")
        context.insert(table); context.insert(figure)
        table.figures.append(figure)
        table.setColumnLayoutWidth(240, forFigure: figure, context: context)
        try? context.save()

        let fetched = ((try? context.fetch(FetchDescriptor<PopupTable>())) ?? []).first
        XCTAssertEqual(fetched?.columnLayoutWidth(forFigure: figure), 240)
        XCTAssertEqual(fetched?.columnLayouts.count, 1)
    }

    func testPopupTableColumnLayoutColumnWidthRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Worship")
        let col = PopupTableColumn(table: table, name: "Sacrifice")
        context.insert(table); context.insert(col)
        table.setColumnLayoutWidth(300, forColumn: col, context: context)
        try? context.save()

        let fetched = ((try? context.fetch(FetchDescriptor<PopupTable>())) ?? []).first
        XCTAssertEqual(fetched?.columnLayoutWidth(forColumn: col), 300)
        XCTAssertNil(fetched?.columnLayoutWidth(forFigure: Figure(name: "Enki")))
    }

    func testPopupTableColumnLayoutUnsetDefaultsNilAndOverwrites() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Water Deities")
        let figure = Figure(name: "Enki")
        context.insert(table); context.insert(figure)
        table.figures.append(figure)
        try? context.save()
        XCTAssertNil(table.columnLayoutWidth(forFigure: figure))

        table.setColumnLayoutWidth(200, forFigure: figure, context: context)
        table.setColumnLayoutWidth(320, forFigure: figure, context: context)
        try? context.save()
        XCTAssertEqual(table.columnLayoutWidth(forFigure: figure), 320)
        XCTAssertEqual(table.columnLayouts.count, 1)
    }

    func testPopupTableCascadeDeletesColumnLayouts() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Water Deities")
        let figure = Figure(name: "Enki")
        context.insert(table); context.insert(figure)
        table.figures.append(figure)
        table.setColumnLayoutWidth(240, forFigure: figure, context: context)
        let col = PopupTableColumn(table: table, name: "Sacrifice")
        context.insert(col)
        table.setColumnLayoutWidth(300, forColumn: col, context: context)
        try? context.save()

        context.delete(table)
        try? context.save()

        let layouts = (try? context.fetch(FetchDescriptor<PopupTableColumnLayout>())) ?? []
        XCTAssertTrue(layouts.isEmpty)
    }

    func testRemoveFigureColumnLayoutsExceptKeepsReferencedFigures() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Water Deities")
        let kept = Figure(name: "Enki")
        let dropped = Figure(name: "Enlil")
        context.insert(table); context.insert(kept); context.insert(dropped)
        table.figures = [kept, dropped]
        table.setColumnLayoutWidth(240, forFigure: kept, context: context)
        table.setColumnLayoutWidth(280, forFigure: dropped, context: context)
        let col = PopupTableColumn(table: table, name: "Sacrifice")
        context.insert(col)
        table.setColumnLayoutWidth(300, forColumn: col, context: context)
        try? context.save()

        table.removeFigureColumnLayouts(except: [kept.persistentModelID], context: context)
        try? context.save()

        XCTAssertEqual(table.columnLayoutWidth(forFigure: kept), 240)
        XCTAssertNil(table.columnLayoutWidth(forFigure: dropped))
        XCTAssertEqual(table.columnLayoutWidth(forColumn: col), 300)
        XCTAssertEqual((try? context.fetch(FetchDescriptor<PopupTableColumnLayout>()))?.count, 2)
    }

    func testRemoveAllColumnLayoutsRestoresDefaults() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Water Deities")
        let figure = Figure(name: "Enki")
        context.insert(table); context.insert(figure)
        table.figures = [figure]
        let col = PopupTableColumn(table: table, name: "Sacrifice")
        context.insert(col)
        table.setColumnLayoutWidth(240, forFigure: figure, context: context)
        table.setColumnLayoutWidth(300, forColumn: col, context: context)
        try? context.save()

        table.removeAllColumnLayouts(context: context)
        try? context.save()

        XCTAssertNil(table.columnLayoutWidth(forFigure: figure))
        XCTAssertNil(table.columnLayoutWidth(forColumn: col))
        XCTAssertEqual((try? context.fetch(FetchDescriptor<PopupTableColumnLayout>()))?.count, 0)
    }

    func testPopupTableGridScaleDefaultsToOne() {
        let table = PopupTable(name: "T1")
        XCTAssertEqual(table.columnScale, 1.0)
        XCTAssertEqual(table.rowScale, 1.0)
        XCTAssertNil(table.gridScaleRaw)
        XCTAssertNil(table.rowScaleRaw)
    }

    func testPopupTableGridScaleRoundTripStoresNilAtOne() {
        let container = makeContainer()
        let context = container.mainContext
        let table = PopupTable(name: "Water Deities")
        context.insert(table)

        table.columnScale = 1.4
        try? context.save()
        let scaled = ((try? context.fetch(FetchDescriptor<PopupTable>())) ?? []).first
        XCTAssertEqual(scaled?.columnScale, 1.4)
        XCTAssertEqual(scaled?.gridScaleRaw, 1.4)
        XCTAssertEqual(scaled?.rowScale, 1.0)

        scaled?.columnScale = 1.0
        scaled?.rowScale = 0.8
        try? context.save()
        let mixed = ((try? context.fetch(FetchDescriptor<PopupTable>())) ?? []).first
        XCTAssertEqual(mixed?.columnScale, 1.0)
        XCTAssertNil(mixed?.gridScaleRaw)
        XCTAssertEqual(mixed?.rowScale, 0.8)
        XCTAssertEqual(mixed?.rowScaleRaw, 0.8)

        mixed?.rowScale = 1.0
        try? context.save()
        let reset = ((try? context.fetch(FetchDescriptor<PopupTable>())) ?? []).first
        XCTAssertEqual(reset?.columnScale, 1.0)
        XCTAssertEqual(reset?.rowScale, 1.0)
        XCTAssertNil(reset?.gridScaleRaw)
        XCTAssertNil(reset?.rowScaleRaw)
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

    func eraBy(name: String, _ context: ModelContext) -> Era? {
        (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == name })))?.first
    }

    func figureBy(name: String, _ context: ModelContext) -> Figure? {
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

    // MARK: - AuthService

    func testRegisterCreatesUserWithHashedPassword() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        let user = try AuthService.register(name: "Rogier", password: "test1234", context: context)

        XCTAssertEqual(user.name, "Rogier")
        XCTAssertFalse(user.passwordHash.isEmpty)
        XCTAssertFalse(user.passwordSalt.isEmpty)
        XCTAssertNotEqual(user.passwordHash, "test1234", "password must never be stored in plaintext")

        let all = try context.fetch(FetchDescriptor<User>())
        XCTAssertEqual(all.count, 1)
    }

    func testRegisterRejectsDuplicateNameCaseInsensitive() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        _ = try AuthService.register(name: "Rogier", password: "test1234", context: context)
        XCTAssertThrowsError(try AuthService.register(name: "rogier", password: "other1234", context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .nameTaken)
        }
    }

    func testRegisterRejectsShortNameAndPassword() {
        let container = makeContainer()
        let context = ModelContext(container)

        XCTAssertThrowsError(try AuthService.register(name: "R", password: "test1234", context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .nameTooShort)
        }
        XCTAssertThrowsError(try AuthService.register(name: "Rogier", password: "abc", context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .passwordTooShort)
        }
    }

    func testLoginSucceedsWithCorrectPassword() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        _ = try AuthService.register(name: "Rogier", password: "test1234", context: context)

        let user = try AuthService.login(name: "  rogier  ", password: "test1234", context: context)
        XCTAssertEqual(user.name, "Rogier")
        XCTAssertNotNil(user.lastLoginAt)
    }

    func testLoginFailsWithWrongPassword() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        _ = try AuthService.register(name: "Rogier", password: "test1234", context: context)

        XCTAssertThrowsError(try AuthService.login(name: "Rogier", password: "wrongpass", context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .invalidCredentials)
        }
    }

    func testLoginFailsForUnknownUser() {
        let container = makeContainer()
        let context = ModelContext(container)

        XCTAssertThrowsError(try AuthService.login(name: "Nobody", password: "test1234", context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .invalidCredentials)
        }
    }

    func testDeactivatedUserCannotLogIn() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        let backup = try AuthService.createUser(name: "Backup", password: "test1234", isAdmin: true, actor: nil, context: context)
        let user = try AuthService.register(name: "Rogier", password: "test1234", context: context)
        try AuthService.deactivate(user, actor: backup, context: context)
        XCTAssertFalse(user.isAccountActive)

        XCTAssertThrowsError(try AuthService.login(name: "Rogier", password: "test1234", context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .accountDeactivated)
        }

        try AuthService.reactivate(user, actor: backup, context: context)
        XCTAssertTrue(user.isAccountActive)
        XCTAssertNotNil(try AuthService.login(name: "Rogier", password: "test1234", context: context))
    }

    func testCannotDeactivateLastActiveAccount() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        let chief = try AuthService.createUser(name: "Chief", password: "test1234", isAdmin: true, actor: nil, context: context)
        let deputy = try AuthService.createUser(name: "Deputy", password: "test1234", isAdmin: true, actor: chief, context: context)
        let worker = try AuthService.createUser(name: "Worker", password: "test1234", isAdmin: false, actor: chief, context: context)

        try AuthService.deactivate(worker, actor: chief, context: context)
        try AuthService.deactivate(deputy, actor: chief, context: context)
        XCTAssertTrue(chief.isAccountActive)

        XCTAssertThrowsError(try AuthService.deactivate(chief, actor: deputy, context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .lastActiveAdmin)
        }
        XCTAssertTrue(chief.isAccountActive)

        try AuthService.reactivate(deputy, actor: chief, context: context)
        try AuthService.deactivate(chief, actor: deputy, context: context)
        XCTAssertFalse(chief.isAccountActive)
    }

    func testCannotDeactivateSelf() throws {
        let container = makeContainer()
        let context = ModelContext(container)
        let chief = try AuthService.createUser(name: "Chief", password: "test1234", isAdmin: true, actor: nil, context: context)

        XCTAssertThrowsError(try AuthService.deactivate(chief, actor: chief, context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .cannotDeactivateSelf)
        }
    }

    func testOnlyAdminsCanManageAccountsAndCreateUsers() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        let admin = try AuthService.createUser(name: "Chief", password: "test1234", isAdmin: true, actor: nil, context: context)
        let plain = try AuthService.createUser(name: "Worker", password: "test1234", isAdmin: false, actor: admin, context: context)
        XCTAssertTrue(admin.isAdministrator)
        XCTAssertFalse(plain.isAdministrator)

        XCTAssertThrowsError(try AuthService.deactivate(admin, actor: plain, context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .notAuthorized)
        }
        try AuthService.deactivate(plain, actor: admin, context: context)
        XCTAssertFalse(plain.isAccountActive)

        XCTAssertThrowsError(try AuthService.createUser(name: "Third", password: "test1234", isAdmin: false, actor: plain, context: context)) { error in
            XCTAssertEqual(error as? AuthServiceError, .notAuthorized)
        }
    }

    func testFirstUserIsPromotedToAdminByMigration() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        let first = try AuthService.register(name: "Alice", password: "test1234", context: context)
        let second = try AuthService.register(name: "Bob", password: "test1234", context: context)
        XCTAssertFalse(first.isAdministrator)

        Migration.ensureFirstUserIsAdmin(context: context)
        XCTAssertTrue(first.isAdmin ?? false)
        XCTAssertFalse(second.isAdministrator)
    }

    func testFirstUserIsAdminMigrationKeepsAtLeastOneAdmin() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        let first = try AuthService.register(name: "Alice", password: "test1234", context: context)
        let second = try AuthService.register(name: "Bob", password: "test1234", context: context)
        XCTAssertFalse(first.isAdministrator)

        Migration.ensureFirstUserIsAdmin(context: context)
        XCTAssertTrue(first.isAdmin ?? false)
        XCTAssertFalse(second.isAdministrator)

        first.isAdmin = false
        try? context.save()

        Migration.ensureFirstUserIsAdmin(context: context)
        XCTAssertTrue(first.isAdmin ?? false, "store must never be left without an administrator")
        XCTAssertFalse(second.isAdministrator, "earliest-created user is promoted, not others")
    }

    func testHasAnyUser() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        XCTAssertFalse(AuthService.hasAnyUser(context: context))
        _ = try AuthService.register(name: "Rogier", password: "test1234", context: context)
        XCTAssertTrue(AuthService.hasAnyUser(context: context))
    }

    // MARK: - ActivityLogger

    func testActivityLoggerRecordsEntryWithUserAttribution() throws {
        let container = makeContainer()
        let context = ModelContext(container)
        let user = try AuthService.register(name: "Rogier", password: "test1234", context: context)
        let session = UserSession(currentUser: user)

        ActivityLogger.record(action: .created, entityType: "Figure", entityName: "Enki", details: "via form", context: context, session: session)

        let entries = try context.fetch(FetchDescriptor<ActivityLogEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.user?.persistentModelID, user.persistentModelID, "entry must reference the user by key")
        XCTAssertEqual(entries.first?.displayUserName, "Rogier")
        XCTAssertEqual(entries.first?.actionType, .created)
        XCTAssertEqual(entries.first?.entityType, "Figure")
        XCTAssertEqual(entries.first?.linkedEntityName, "Enki")
        XCTAssertEqual(entries.first?.details, "via form")
        XCTAssertEqual((user.activityLogEntries ?? []).count, 1, "inverse side must be linked")
    }

    func testActivityLoggerFallsBackToUnknownWithoutSession() {
        let container = makeContainer()
        let context = ModelContext(container)

        ActivityLogger.record(action: .updated, entityType: "Place", entityName: "Uruk", context: context, session: nil)

        let entries = try? context.fetch(FetchDescriptor<ActivityLogEntry>())
        XCTAssertEqual(entries?.count, 1)
        XCTAssertEqual(entries?.first?.userName, ActivityLogger.unknownUserName)
        XCTAssertEqual(entries?.first?.actionType, .updated)
    }

    func testActivityLoggerRecordsAllActionTypes() {
        let container = makeContainer()
        let context = ModelContext(container)
        let session = UserSession()

        ActivityLogger.record(action: .created, entityType: "Event", entityName: "The Flood", context: context, session: session)
        ActivityLogger.record(action: .updated, entityType: "Event", entityName: "The Flood", context: context, session: session)
        ActivityLogger.record(action: .deleted, entityType: "Event", entityName: "The Flood", context: context, session: session)

        let entries = (try? context.fetch(FetchDescriptor<ActivityLogEntry>())) ?? []
        XCTAssertEqual(entries.map(\.actionType), [.created, .updated, .deleted])
    }

    func testActivityLogEntriesSurviveUserDeletion() throws {
        let container = makeContainer()
        let context = ModelContext(container)
        let user = try AuthService.register(name: "Temp", password: "test1234", context: context)
        let session = UserSession(currentUser: user)

        ActivityLogger.record(action: .created, entityType: "Figure", entityName: "Inanna", context: context, session: session)

        context.delete(user)
        try? context.save()

        let entries = (try? context.fetch(FetchDescriptor<ActivityLogEntry>())) ?? []
        XCTAssertEqual(entries.count, 1, "audit entries must survive user deletion")
        XCTAssertEqual(entries.first?.user, nil, "link is nullified when user is hard-deleted")
        XCTAssertEqual(entries.first?.displayUserName, "Temp", "name snapshot keeps attribution readable")
    }

    func testActivityLogUserLinkBackfillMigration() throws {
        let container = makeContainer()
        let context = ModelContext(container)
        let user = try AuthService.register(name: "Rogier", password: "test1234", context: context)

        let legacyEntry = ActivityLogEntry(userName: "rogier", action: .updated, entityType: "Place", entityName: "Uruk")
        context.insert(legacyEntry)
        let orphanEntry = ActivityLogEntry(userName: "Ghost", action: .deleted, entityType: "Event", entityName: "The Flood")
        context.insert(orphanEntry)
        try? context.save()

        Migration.ensureActivityLogUserLinks(context: context)

        XCTAssertEqual(legacyEntry.user?.persistentModelID, user.persistentModelID, "legacy entry must be linked by snapshot name")
        XCTAssertNil(orphanEntry.user, "entries without a matching user stay unlinked")
        XCTAssertEqual(orphanEntry.displayUserName, "Ghost")
    }

    // MARK: - ReignLength parsing (additional)

    func testReignLengthParseReigningForYears() {
        let result = ReignLength.parse(from: "A king who was possibly reigning for 5,200 years.")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.years, 5200)
    }

    func testReignLengthParseReignedWithoutFor() {
        let result = ReignLength.parse(from: "He reigned 120 years.")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.years, 120)
    }

    func testReignLengthParseRuledForYears() {
        let result = ReignLength.parse(from: "She ruled for 36 years.")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.years, 36)
    }

    func testReignLengthParsePossiblyReigningFor() {
        let result = ReignLength.parse(from: "Possibly reigning for 400 years.")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.years, 400)
    }

    func testReignLengthParseCommaInNumber() {
        let result = ReignLength.parse(from: "(Listed reign: 36,000 years.)")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.years, 36000)
    }

    func testReignLengthParseEmptyDescription() {
        XCTAssertNil(ReignLength.parse(from: ""))
    }

    func testReignLengthParseNoReignInfo() {
        XCTAssertNil(ReignLength.parse(from: "A deity of water and wisdom."))
    }

    // MARK: - SKLDatePropagator

    func testSKLDatePropagatorComputeReturnsEmptyForEmptyInput() {
        let timelines = SKLDatePropagator.compute(figures: [], eraOrder: [:])
        XCTAssertTrue(timelines.isEmpty)
    }

    func testSKLDatePropagatorComputeGroupsByEra() {
        let kishEra = Era(name: "First dynasty of Kish", orderIndex: 11)
        let akkadEra = Era(name: "Dynasty of Akkad", orderIndex: 25)
        let f1 = Figure(name: "Etana", birthDate: MythologicalDate(year: nil, era: "First dynasty of Kish", isApproximate: true))
        let f2 = Figure(name: "Sargon", birthDate: MythologicalDate(year: nil, era: "Dynasty of Akkad", isApproximate: true))
        let eraOrder = ["First dynasty of Kish": 11, "Dynasty of Akkad": 25]

        let timelines = SKLDatePropagator.compute(figures: [f2, f1], eraOrder: eraOrder)

        XCTAssertEqual(timelines.count, 2)
        let names = timelines.map(\.name)
        XCTAssertTrue(names.contains("First dynasty of Kish"))
        XCTAssertTrue(names.contains("Dynasty of Akkad"))
    }

    func testSKLDatePropagatorComputeUsesExplicitBirthDeathDates() {
        let f = Figure(
            name: "Entemena",
            birthDate: MythologicalDate(year: -2440, era: "Early Dynastic Period"),
            deathDate: MythologicalDate(year: -2425, era: "Early Dynastic Period")
        )
        let eraOrder = ["Early Dynastic Period": 9]
        let timelines = SKLDatePropagator.compute(figures: [f], eraOrder: eraOrder)

        XCTAssertEqual(timelines.first?.reigns.first?.startBCE, -2440)
        XCTAssertEqual(timelines.first?.reigns.first?.endBCE, -2425)
    }

    func testSKLDatePropagatorExtractsBCEFromDescription() {
        let f = Figure(
            name: "Ur-Namma",
            figureDescription: "Ruler who reigned c. 2047–2030 BC.",
            birthDate: MythologicalDate(year: nil, era: "Third dynasty of Ur", isApproximate: true)
        )
        let eraOrder = ["Third dynasty of Ur": 29]
        let timelines = SKLDatePropagator.compute(figures: [f], eraOrder: eraOrder)

        XCTAssertEqual(timelines.first?.reigns.first?.startBCE, -2047)
        XCTAssertEqual(timelines.first?.reigns.first?.endBCE, -2030)
    }

    func testSKLDatePropagatorIgnoresBCEWithoutReignKeyword() {
        let f = Figure(
            name: "Event guy",
            figureDescription: "Associated with a battle c. 2000–1990 BC in the region.",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true)
        )
        let eraOrder = ["Test Era": 0]
        let timelines = SKLDatePropagator.compute(figures: [f], eraOrder: eraOrder)

        XCTAssertNil(timelines.first?.reigns.first?.startBCE, "BCE dates not preceded by reign keyword must be ignored")
    }

    func testSKLDatePropagatorBCEWithShortSuffixCountsAsReignDate() {
        let f = Figure(
            name: "King X",
            figureDescription: "Ruled c. 2000–1980 BC (short)",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true)
        )
        let eraOrder = ["Test Era": 0]
        let timelines = SKLDatePropagator.compute(figures: [f], eraOrder: eraOrder)

        XCTAssertEqual(timelines.first?.reigns.first?.startBCE, -2000)
        XCTAssertEqual(timelines.first?.reigns.first?.endBCE, -1980)
    }

    func testSKLDatePropagatorBCEAtEndOfDescriptionCountsAsReignDate() {
        let f = Figure(
            name: "King Y",
            figureDescription: "Reigned c. 1900–1880 BC.",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true)
        )
        let eraOrder = ["Test Era": 0]
        let timelines = SKLDatePropagator.compute(figures: [f], eraOrder: eraOrder)

        XCTAssertEqual(timelines.first?.reigns.first?.startBCE, -1900)
        XCTAssertEqual(timelines.first?.reigns.first?.endBCE, -1880)
    }

    func testSKLDatePropagatorPropagatesForwardFromAnchor() {
        let anchor = Figure(
            name: "Anchor",
            figureDescription: "Reigned c. 2100–2090 BC.",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true),
            orderIndex: 0
        )
        let follower = Figure(
            name: "Follower",
            figureDescription: "Reigned 30 years.",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true),
            orderIndex: 1
        )
        let eraOrder = ["Test Era": 0]
        let timelines = SKLDatePropagator.compute(figures: [anchor, follower], eraOrder: eraOrder)
        let reigns = timelines.first?.reigns ?? []

        XCTAssertEqual(reigns[0].startBCE, -2100)
        XCTAssertEqual(reigns[0].endBCE, -2090)
        XCTAssertEqual(reigns[1].startBCE, -2090, "follower starts where anchor ended")
        XCTAssertEqual(reigns[1].endBCE, -2060, "2090 − 30 = 2060")
    }

    func testSKLDatePropagatorPropagatesBackwardFromAnchor() {
        let predecessor = Figure(
            name: "Predecessor",
            figureDescription: "Reigned 20 years.",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true),
            orderIndex: 0
        )
        let anchor = Figure(
            name: "Anchor",
            figureDescription: "Reigned c. 2050–2040 BC.",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true),
            orderIndex: 1
        )
        let eraOrder = ["Test Era": 0]
        let timelines = SKLDatePropagator.compute(figures: [predecessor, anchor], eraOrder: eraOrder)
        let reigns = timelines.first?.reigns ?? []

        XCTAssertEqual(reigns[0].startBCE, -2070, "predecessor ends at 2050, starts 20 years earlier")
        XCTAssertEqual(reigns[0].endBCE, -2050)
        XCTAssertEqual(reigns[1].startBCE, -2050)
        XCTAssertEqual(reigns[1].endBCE, -2040)
    }

    func testSKLDatePropagatorBreaksForwardChainOnMissingReignLength() {
        let anchor = Figure(
            name: "Anchor",
            figureDescription: "Reigned c. 2100–2090 BC.",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true),
            orderIndex: 0
        )
        let noReign = Figure(
            name: "No Reign",
            figureDescription: "A mythological figure with no duration.",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true),
            orderIndex: 1
        )
        let follower = Figure(
            name: "Follower",
            figureDescription: "Reigned 10 years.",
            birthDate: MythologicalDate(year: nil, era: "Test Era", isApproximate: true),
            orderIndex: 2
        )
        let eraOrder = ["Test Era": 0]
        let timelines = SKLDatePropagator.compute(figures: [anchor, noReign, follower], eraOrder: eraOrder)
        let reigns = timelines.first?.reigns ?? []

        XCTAssertEqual(reigns[0].startBCE, -2100)
        XCTAssertNil(reigns[1].startBCE, "chain broken at no-reign figure")
        XCTAssertNil(reigns[1].endBCE)
        XCTAssertNil(reigns[2].startBCE, "downstream figures also nil")
    }

    func testSKLDatePropagatorEmptyEraMapsToAntediluvian() {
        let f = Figure(name: "Ancient", birthDate: MythologicalDate(year: nil, era: "", isApproximate: true))
        let timelines = SKLDatePropagator.compute(figures: [f], eraOrder: [:])

        XCTAssertEqual(timelines.first?.name, "Antediluvian")
    }

    func testSKLDatePropagatorSortsByEraOrder() {
        let f1 = Figure(name: "A", birthDate: MythologicalDate(year: nil, era: "Dynasty of Akkad", isApproximate: true))
        let f2 = Figure(name: "B", birthDate: MythologicalDate(year: nil, era: "First dynasty of Kish", isApproximate: true))
        let eraOrder = ["First dynasty of Kish": 11, "Dynasty of Akkad": 25]
        let timelines = SKLDatePropagator.compute(figures: [f1, f2], eraOrder: eraOrder)

        XCTAssertEqual(timelines.map(\.name), ["First dynasty of Kish", "Dynasty of Akkad"])
    }

    func testSKLDatePropagatorUnknownEraGoesToEnd() {
        let f1 = Figure(name: "A", birthDate: MythologicalDate(year: nil, era: "Known Era", isApproximate: true))
        let f2 = Figure(name: "B", birthDate: MythologicalDate(year: nil, era: "Unknown Era", isApproximate: true))
        let eraOrder = ["Known Era": 5]
        let timelines = SKLDatePropagator.compute(figures: [f1, f2], eraOrder: eraOrder)

        XCTAssertEqual(timelines.last?.name, "Unknown Era", "unknown era gets Int.max and sorts last")
    }

    func testSKLDatePropagatorComputedReignDisplay() {
        let f = Figure(name: "X", birthDate: MythologicalDate(year: nil, era: "", isApproximate: true))
        let approx = SKLDatePropagator.ComputedReign(figure: f, startBCE: -2000, endBCE: -1980)
        XCTAssertTrue(approx.display.contains("c."))

        let exact = Figure(name: "Y", birthDate: MythologicalDate(year: nil, era: "", isApproximate: false))
        let exactReign = SKLDatePropagator.ComputedReign(figure: exact, startBCE: -2000, endBCE: -1980)
        XCTAssertFalse(exactReign.display.contains("c."))
        XCTAssertTrue(exactReign.display.contains("BC"))

        let incomplete = SKLDatePropagator.ComputedReign(figure: f, startBCE: nil, endBCE: -1980)
        XCTAssertEqual(incomplete.display, "")
    }

    func testSKLDatePropagatorDynastyTimelineTotalYearsUsesFigureReignYears() {
        let f1 = Figure(name: "A", figureDescription: "Reigned 20 years.", birthDate: MythologicalDate(year: nil, era: "Era", isApproximate: true), orderIndex: 0)
        f1.reignYears = 20
        let f2 = Figure(name: "B", figureDescription: "Reigned 30 years.", birthDate: MythologicalDate(year: nil, era: "Era", isApproximate: true), orderIndex: 1)
        f2.reignYears = nil
        let eraOrder = ["Era": 0]
        let timelines = SKLDatePropagator.compute(figures: [f1, f2], eraOrder: eraOrder)

        XCTAssertEqual(timelines.first?.totalYears, 50, "f1 uses reignYears=20, f2 parses 30 from description")
    }

    func testSKLDatePropagatorDynastyTimelineStartAndEndBCE() {
        let anchor = Figure(
            name: "Anchor",
            figureDescription: "Reigned c. 2100–2090 BC.",
            birthDate: MythologicalDate(year: nil, era: "Era", isApproximate: true),
            orderIndex: 0
        )
        let follower = Figure(
            name: "Follower",
            figureDescription: "Reigned 10 years.",
            birthDate: MythologicalDate(year: nil, era: "Era", isApproximate: true),
            orderIndex: 1
        )
        let eraOrder = ["Era": 0]
        let timelines = SKLDatePropagator.compute(figures: [anchor, follower], eraOrder: eraOrder)

        XCTAssertEqual(timelines.first?.startBCE, -2100)
        XCTAssertEqual(timelines.first?.endBCE, -2080)
    }

}
