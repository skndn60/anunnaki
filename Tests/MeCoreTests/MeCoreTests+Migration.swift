import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
    // MARK: - Migration: ensureCoverageExemptFlags

    func testEnsureCoverageExemptFlagsSetsExemptForEligibleTypes() {
        let container = makeContainer()
        let context = container.mainContext
        let primordialType = FigureType(name: "Primordial", icon: "circle", colorHex: "000")
        let humanType = FigureType(name: "Human", icon: "person", colorHex: "007AFF")
        context.insert(primordialType)
        context.insert(humanType)

        let tiamat = Figure(name: "Tiamat", figureType: primordialType)
        let enki = Figure(name: "Enki", figureType: FigureType(name: "Deity", icon: "star", colorHex: "FF9500"))
        let sargon = Figure(name: "Sargon", figureType: humanType)
        context.insert(tiamat); context.insert(enki); context.insert(sargon)
        try? context.save()

        Migration.ensureCoverageExemptFlags(context: context)

        XCTAssertTrue(tiamat.coverageExempt == true, "Primordial must be coverage exempt")
        XCTAssertTrue(enki.coverageExempt == true, "Deity must be coverage exempt")
        XCTAssertNil(sargon.coverageExempt, "Human must not be coverage exempt")
    }

    func testEnsureCoverageExemptFlagsSkipsAlreadyExempt() {
        let container = makeContainer()
        let context = container.mainContext
        let primordialType = FigureType(name: "Primordial", icon: "circle", colorHex: "000")
        context.insert(primordialType)
        let tiamat = Figure(name: "Tiamat", figureType: primordialType)
        tiamat.coverageExempt = true
        context.insert(tiamat)
        try? context.save()

        Migration.ensureCoverageExemptFlags(context: context)

        XCTAssertTrue(tiamat.coverageExempt == true, "already exempt figure stays exempt")
    }

    func testEnsureCoverageExemptFlagsIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let primordialType = FigureType(name: "Primordial", icon: "circle", colorHex: "000")
        context.insert(primordialType)
        let tiamat = Figure(name: "Tiamat", figureType: primordialType)
        context.insert(tiamat)
        try? context.save()

        Migration.ensureCoverageExemptFlags(context: context)
        Migration.ensureCoverageExemptFlags(context: context)

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(allFigures.filter { $0.coverageExempt == true }.count, 1)
    }

    // MARK: - Migration: ensureSKLDomain

    func testEnsureSKLDomainBackfillsEmptyDomainFromTitle() {
        let container = makeContainer()
        let context = container.mainContext
        let fig = Figure(name: "Etana", title: "King of First dynasty of Kish", domain: "")
        context.insert(fig)
        try? context.save()

        Migration.ensureSKLDomain(context: context)

        XCTAssertEqual(fig.domain, "Kingship of Kish")
    }

    func testEnsureSKLDomainDoesNotOverwriteExistingDomain() {
        let container = makeContainer()
        let context = container.mainContext
        let fig = Figure(name: "Etana", title: "King of First dynasty of Kish", domain: "Custom Domain")
        context.insert(fig)
        try? context.save()

        Migration.ensureSKLDomain(context: context)

        XCTAssertEqual(fig.domain, "Custom Domain")
    }

    func testEnsureSKLDomainDoesNothingForUnknownTitle() {
        let container = makeContainer()
        let context = container.mainContext
        let fig = Figure(name: "Enki", title: "God of Water", domain: "")
        context.insert(fig)
        try? context.save()

        Migration.ensureSKLDomain(context: context)

        XCTAssertEqual(fig.domain, "")
    }

    func testEnsureSKLDomainHandlesAllDynastyTitles() {
        let container = makeContainer()
        let context = container.mainContext
        let titles: [(title: String, expectedDomain: String)] = [
            ("King of Dynasty of Akkad", "Kingship of Akkad"),
            ("King of Third dynasty of Ur", "Kingship of Ur"),
            ("King of Dynasty of Isin", "Kingship of Isin"),
            ("King of Gutian rule", "Kingship of Gutium"),
        ]
        for (title, _) in titles {
            context.insert(Figure(name: UUID().uuidString, title: title))
        }
        try? context.save()

        Migration.ensureSKLDomain(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for (title, expected) in titles {
            let fig = figures.first { $0.title == title }
            XCTAssertEqual(fig?.domain, expected, "\(title) must map to \(expected)")
        }
    }

    // MARK: - Migration: fixAllyIcon

    func testFixAllyIconUpdatesHandshakeToPerson2Fill() {
        let container = makeContainer()
        let context = container.mainContext
        let allyType = RelationshipType(name: "Ally", icon: "handshake", colorHex: "34C759", category: "social")
        context.insert(allyType)
        try? context.save()

        Migration.fixAllyIcon(context: context)

        let updated = (try? context.fetch(FetchDescriptor<RelationshipType>()))?.first
        XCTAssertEqual(updated?.icon, "person.2.fill")
    }

    func testFixAllyIconDoesNothingForAlreadyCorrectIcon() {
        let container = makeContainer()
        let context = container.mainContext
        let allyType = RelationshipType(name: "Ally", icon: "person.2.fill", colorHex: "34C759", category: "social")
        context.insert(allyType)
        try? context.save()

        Migration.fixAllyIcon(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<RelationshipType>()))?.first
        XCTAssertEqual(fetched?.icon, "person.2.fill")
    }

    func testFixAllyIconDoesNotTouchOtherTypes() {
        let container = makeContainer()
        let context = container.mainContext
        let enemyType = RelationshipType(name: "Enemy", icon: "flame", colorHex: "FF3B30", category: "social")
        context.insert(enemyType)
        try? context.save()

        Migration.fixAllyIcon(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<RelationshipType>()))?.first
        XCTAssertEqual(fetched?.icon, "flame")
    }

    // MARK: - Migration: extractAlternateNamesFromDescriptions

    func testExtractAlternateNamesCreatesAltNames() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Hermani", figureDescription: "One of the Watchers. Also known as Hermoni.")
        context.insert(figure)
        try? context.save()

        Migration.extractAlternateNamesFromDescriptions(context: context)

        let alts = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertEqual(alts.count, 1)
        XCTAssertEqual(alts.first?.name, "Hermoni")
        XCTAssertEqual(alts.first?.figure?.name, "Hermani")
    }

    func testExtractAlternateNamesCleansDescription() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "X", figureDescription: "Some text. Also known as AltName. Extra info.")
        context.insert(figure)
        try? context.save()

        Migration.extractAlternateNamesFromDescriptions(context: context)

        XCTAssertFalse(figure.figureDescription.contains("Also known as"))
        XCTAssertTrue(figure.figureDescription.hasSuffix("."))
    }

    func testExtractAlternateNamesSkipsEmptyDescription() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "X", figureDescription: "")
        context.insert(figure)
        try? context.save()

        Migration.extractAlternateNamesFromDescriptions(context: context)

        let alts = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertTrue(alts.isEmpty)
    }

    func testExtractAlternateNamesSkipsNoMatch() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "X", figureDescription: "A plain description with no aliases.")
        context.insert(figure)
        try? context.save()

        Migration.extractAlternateNamesFromDescriptions(context: context)

        let alts = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertTrue(alts.isEmpty)
    }

    func testExtractAlternateNamesIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "X", figureDescription: "Also known as Alt.")
        context.insert(figure)
        try? context.save()

        Migration.extractAlternateNamesFromDescriptions(context: context)
        Migration.extractAlternateNamesFromDescriptions(context: context)

        let alts = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertEqual(alts.count, 1)
    }

    // MARK: - Migration: ensureCommanderFigureTypeExists

    func testEnsureCommanderFigureTypeCreatesTypeIfMissing() {
        let container = makeContainer()
        let context = container.mainContext

        Migration.ensureCommanderFigureTypeExists(context: context)

        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        XCTAssertEqual(types.first { $0.name == "Commander" }?.icon, "chevron.left.forwardslash.chevron.right")
    }

    func testEnsureCommanderFigureTypeReusesExisting() {
        let container = makeContainer()
        let context = container.mainContext
        let existing = FigureType(name: "Commander", icon: "custom.icon", colorHex: "FF0000")
        context.insert(existing)
        try? context.save()

        Migration.ensureCommanderFigureTypeExists(context: context)

        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        XCTAssertEqual(types.filter { $0.name == "Commander" }.count, 1)
        XCTAssertEqual(types.first { $0.name == "Commander" }?.icon, "custom.icon", "existing type must not be overwritten")
    }

    func testEnsureCommanderFigureTypeReassignsWatcherChiefs() {
        let container = makeContainer()
        let context = container.mainContext
        let igigiType = FigureType(name: "Igigi", icon: "eye", colorHex: "000")
        context.insert(igigiType)
        let samyaza = Figure(name: "Samyaza", figureType: igigiType)
        let azazel = Figure(name: "Azazel", figureType: igigiType)
        let enki = Figure(name: "Enki")
        context.insert(samyaza); context.insert(azazel); context.insert(enki)
        try? context.save()

        Migration.ensureCommanderFigureTypeExists(context: context)

        let commanderType = (try? context.fetch(FetchDescriptor<FigureType>()))?.first { $0.name == "Commander" }
        XCTAssertEqual(samyaza.figureType?.persistentModelID, commanderType?.persistentModelID)
        XCTAssertEqual(azazel.figureType?.persistentModelID, commanderType?.persistentModelID)
        XCTAssertNil(enki.figureType, "non-Watcher figure is untouched")
    }

    func testEnsureCommanderFigureTypeRevertsNonCommanderNames() {
        let container = makeContainer()
        let context = container.mainContext
        let igigiType = FigureType(name: "Igigi", icon: "eye", colorHex: "000")
        context.insert(igigiType)
        let penemue = Figure(name: "Penemue", figureType: igigiType)
        context.insert(penemue)
        try? context.save()

        Migration.ensureCommanderFigureTypeExists(context: context)

        let commanderType = (try? context.fetch(FetchDescriptor<FigureType>()))?.first { $0.name == "Commander" }
        XCTAssertNotEqual(penemue.figureType?.persistentModelID, commanderType?.persistentModelID, "non-canonical name must stay Igigi")
    }

    // MARK: - Migration: ensureArchangelsExist

    func testEnsureArchangelsExistCreatesMissingArchangels() {
        let container = makeContainer()
        let context = container.mainContext

        Migration.ensureArchangelsExist(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let names = Set(figures.map(\.name))
        XCTAssertTrue(names.contains("Michael"))
        XCTAssertTrue(names.contains("Gabriel"))
        XCTAssertTrue(names.contains("Uriel"))
        XCTAssertEqual(figures.count, 7, "all 7 archangels created")
    }

    func testEnsureArchangelsExistSkipsExisting() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Michael"))
        try? context.save()

        Migration.ensureArchangelsExist(context: context)

        let Michaels = (try? context.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.name == "Michael" }))) ?? []
        XCTAssertEqual(Michaels.count, 1)
    }

    func testEnsureArchangelsExistCreatesArchangelFigureType() {
        let container = makeContainer()
        let context = container.mainContext

        Migration.ensureArchangelsExist(context: context)

        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        XCTAssertEqual(types.first { $0.name == "Archangel" }?.icon, "star.fill")
    }

    // MARK: - Migration: ensureMissingCommanderFiguresExist

    func testEnsureMissingCommanderFiguresCreatesHermaniAndYehadiel() {
        let container = makeContainer()
        let context = container.mainContext
        let commanderType = FigureType(name: "Commander", icon: "shield", colorHex: "EF4444")
        context.insert(commanderType)
        context.insert(Figure(name: "Samyaza", figureType: commanderType))
        try? context.save()

        Migration.ensureMissingCommanderFiguresExist(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let names = Set(figures.map(\.name))
        XCTAssertTrue(names.contains("Hermani"))
        XCTAssertTrue(names.contains("Yehadiel"))
    }

    func testEnsureMissingCommanderFiguresSkipsExisting() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Hermani"))
        context.insert(Figure(name: "Yehadiel"))
        try? context.save()

        Migration.ensureMissingCommanderFiguresExist(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.filter { ["Hermani", "Yehadiel"].contains($0.name) }.count, 2)
    }

    func testEnsureMissingCommanderFiguresCreatesCommanderRelationshipFromSamyaza() {
        let container = makeContainer()
        let context = container.mainContext
        let commanderRelType = RelationshipType(name: "Commander", icon: "shield", colorHex: "FFCC00", category: "military")
        context.insert(commanderRelType)
        let samyaza = Figure(name: "Samyaza")
        context.insert(samyaza)
        try? context.save()

        Migration.ensureMissingCommanderFiguresExist(context: context)

        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let targets = rels.compactMap { $0.toFigure?.name }
        XCTAssertTrue(targets.contains("Hermani"))
        XCTAssertTrue(targets.contains("Yehadiel"))
        XCTAssertTrue(rels.allSatisfy { $0.fromFigure?.name == "Samyaza" })
    }

    // MARK: - Migration: ensureDumuziFamilyExists

    func testEnsureDumuziFamilyExistsCreatesDuttur() {
        let container = makeContainer()
        let context = container.mainContext
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        context.insert(deityType)
        let motherType = RelationshipType(name: "Mother", icon: "arrow.down", colorHex: "FF2D55", category: "parent")
        let fatherType = RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent")
        context.insert(motherType)
        context.insert(fatherType)
        context.insert(Figure(name: "Enki"))
        context.insert(Figure(name: "Dumuzi"))
        context.insert(Figure(name: "Geshtinanna"))
        try? context.save()

        Migration.ensureDumuziFamilyExists(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertTrue(figures.contains { $0.name == "Duttur" })
    }

    func testEnsureDumuziFamilyExistsCreatesParentRelationships() {
        let container = makeContainer()
        let context = container.mainContext
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        context.insert(deityType)
        let motherType = RelationshipType(name: "Mother", icon: "arrow.down", colorHex: "FF2D55", category: "parent")
        let fatherType = RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent")
        context.insert(motherType)
        context.insert(fatherType)
        context.insert(Figure(name: "Enki"))
        context.insert(Figure(name: "Dumuzi"))
        context.insert(Figure(name: "Geshtinanna"))
        try? context.save()

        Migration.ensureDumuziFamilyExists(context: context)

        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertTrue(rels.contains { $0.fromFigure?.name == "Enki" && $0.toFigure?.name == "Dumuzi" })
        XCTAssertTrue(rels.contains { $0.fromFigure?.name == "Duttur" && $0.toFigure?.name == "Dumuzi" })
        XCTAssertTrue(rels.contains { $0.fromFigure?.name == "Enki" && $0.toFigure?.name == "Geshtinanna" })
        XCTAssertTrue(rels.contains { $0.fromFigure?.name == "Duttur" && $0.toFigure?.name == "Geshtinanna" })
    }

    func testEnsureDumuziFamilyExistsIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        context.insert(deityType)
        let motherType = RelationshipType(name: "Mother", icon: "arrow.down", colorHex: "FF2D55", category: "parent")
        let fatherType = RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent")
        context.insert(motherType)
        context.insert(fatherType)
        context.insert(Figure(name: "Enki"))
        context.insert(Figure(name: "Dumuzi"))
        context.insert(Figure(name: "Geshtinanna"))
        try? context.save()

        Migration.ensureDumuziFamilyExists(context: context)
        Migration.ensureDumuziFamilyExists(context: context)

        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let fromEnkiToDumuzi = rels.filter { $0.fromFigure?.name == "Enki" && $0.toFigure?.name == "Dumuzi" }
        XCTAssertEqual(fromEnkiToDumuzi.count, 1, "no duplicate relationships")
    }

    func testEnsureDumuziFamilyExistsSkipsIfAlreadyLinked() {
        let container = makeContainer()
        let context = container.mainContext
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        context.insert(deityType)
        let motherType = RelationshipType(name: "Mother", icon: "arrow.down", colorHex: "FF2D55", category: "parent")
        let fatherType = RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent")
        context.insert(motherType)
        context.insert(fatherType)
        let enki = Figure(name: "Enki")
        let dumuzi = Figure(name: "Dumuzi")
        context.insert(enki)
        context.insert(dumuzi)
        context.insert(Figure(name: "Geshtinanna"))
        context.insert(Relationship(fromFigure: enki, toFigure: dumuzi, relationshipType: fatherType))
        try? context.save()

        Migration.ensureDumuziFamilyExists(context: context)

        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let fatherRels = rels.filter { $0.relationshipType?.name == "Father" }
        XCTAssertEqual(fatherRels.count, 2, "existing Enki→Dumuzi skipped, new Enki→Geshtinanna added")
    }

    // MARK: - Migration: removeAutoGeneratedStickies

    func testRemoveAutoGeneratedStickiesRemovesMissingPrefix() {
        let container = makeContainer()
        let context = container.mainContext
        let fig = Figure(name: "Enki")
        context.insert(fig)
        let autoSticky = StickyNote(text: "Missing place association", figure: fig)
        let manualSticky = StickyNote(text: "Check this cult center", figure: fig)
        context.insert(autoSticky)
        context.insert(manualSticky)
        try? context.save()

        Migration.removeAutoGeneratedStickies(context: context)

        let stickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        XCTAssertEqual(stickies.count, 1)
        XCTAssertEqual(stickies.first?.text, "Check this cult center")
    }

    func testRemoveAutoGeneratedStickiesIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let fig = Figure(name: "Enki")
        context.insert(fig)
        context.insert(StickyNote(text: "Missing link", figure: fig))
        try? context.save()

        Migration.removeAutoGeneratedStickies(context: context)
        Migration.removeAutoGeneratedStickies(context: context)

        let stickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        XCTAssertTrue(stickies.isEmpty)
    }

    // MARK: - Migration.backfillBuziDescription

    func testBackfillBuziDescriptionFillsEmpty() {
        let container = makeContainer()
        let context = container.mainContext
        let buzi = Figure(name: "Buzi")
        context.insert(buzi)
        try? context.save()

        Migration.backfillBuziDescription(context: context)

        XCTAssertFalse(buzi.figureDescription.isEmpty)
        XCTAssertTrue(buzi.figureDescription.contains("Ezekiel"))
    }

    func testBackfillBuziDescriptionSkipsNonEmpty() {
        let container = makeContainer()
        let context = container.mainContext
        let buzi = Figure(name: "Buzi", figureDescription: "Custom description")
        context.insert(buzi)
        try? context.save()

        Migration.backfillBuziDescription(context: context)

        XCTAssertEqual(buzi.figureDescription, "Custom description")
    }

    func testBackfillBuziDescriptionNoBuziNoCrash() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Enki"))
        try? context.save()

        Migration.backfillBuziDescription(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.count, 1)
    }

    // MARK: - Migration.ensureBidirectionalRelationshipConsistency

    func testEnsureBidirectionalConsistencyCreatesReverseLink() {
        let container = makeContainer()
        let context = container.mainContext
        let spouseType = RelationshipType(name: "Spouse", icon: "heart", colorHex: "FF3B30", category: "partner")
        context.insert(spouseType)
        let enki = Figure(name: "Enki")
        let ninhursag = Figure(name: "Ninhursag")
        context.insert(enki)
        context.insert(ninhursag)
        context.insert(Relationship(fromFigure: enki, toFigure: ninhursag, relationshipType: spouseType, source: "test"))
        try? context.save()

        Migration.ensureBidirectionalRelationshipConsistency(context: context)

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(edges.count, 2)
        XCTAssertTrue(edges.contains { $0.fromFigure === ninhursag && $0.toFigure === enki })
        XCTAssertTrue(edges.contains { $0.fromFigure === enki && $0.toFigure === ninhursag })
    }

    func testEnsureBidirectionalConsistencyIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let spouseType = RelationshipType(name: "Spouse", icon: "heart", colorHex: "FF3B30", category: "partner")
        context.insert(spouseType)
        let enki = Figure(name: "Enki")
        let ninhursag = Figure(name: "Ninhursag")
        context.insert(enki)
        context.insert(ninhursag)
        context.insert(Relationship(fromFigure: enki, toFigure: ninhursag, relationshipType: spouseType, source: "test"))
        try? context.save()

        Migration.ensureBidirectionalRelationshipConsistency(context: context)
        Migration.ensureBidirectionalRelationshipConsistency(context: context)

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(edges.count, 2)
    }

    func testEnsureBidirectionalConsistencyDoesNotDoubleNonMutual() {
        let container = makeContainer()
        let context = container.mainContext
        let fatherType = RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent")
        context.insert(fatherType)
        let anu = Figure(name: "Anu")
        let enlil = Figure(name: "Enlil")
        context.insert(anu)
        context.insert(enlil)
        context.insert(Relationship(fromFigure: anu, toFigure: enlil, relationshipType: fatherType, source: "test"))
        try? context.save()

        Migration.ensureBidirectionalRelationshipConsistency(context: context)

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(edges.count, 1, "Father is not a mutual type and must not gain a reverse edge")
    }

    // MARK: - Migration.fixEraTypos

    func testFixEraTyposCorrectsGuthianToGutian() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Gutian rule", orderIndex: 700)
        context.insert(era)
        let figure = Figure(name: "Inkishush")
        figure.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Guthian rule")
        figure.deathDate = MythologicalDate(startYear: nil, endYear: nil, era: "Guthian rule")
        figure.era = nil
        context.insert(figure)
        try? context.save()

        Migration.fixEraTypos(context: context)

        XCTAssertEqual(figure.birthDate.era, "Gutian rule")
        XCTAssertEqual(figure.deathDate.era, "Gutian rule")
        XCTAssertEqual(figure.era?.name, "Gutian rule")
    }

    // MARK: - Migration.ensureFigureGroupKinds

    func testEnsureFigureGroupKindsSetsKindFromName() {
        let container = makeContainer()
        let context = container.mainContext
        let enoch = FigureGroup(name: "Book of Enoch")
        let skl = FigureGroup(name: "SKL Kings")
        let standard = FigureGroup(name: "Divine Council")
        context.insert(enoch)
        context.insert(skl)
        context.insert(standard)
        try? context.save()

        Migration.ensureFigureGroupKinds(context: context)

        XCTAssertEqual(enoch.kind, .enoch)
        XCTAssertEqual(skl.kind, .skl)
        XCTAssertEqual(standard.kind, .standard)
    }

    // MARK: - Migration.ensureDefaultFigureGroups

    func testEnsureDefaultFigureGroupsCreatesDefaults() {
        let container = makeContainer()
        let context = container.mainContext

        Migration.ensureDefaultFigureGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        XCTAssertEqual(groups.count, 6)
        let names = groups.map(\.name)
        XCTAssertTrue(names.contains("Divine Council"))
        XCTAssertTrue(names.contains("Sumerian Pantheon"))
        XCTAssertTrue(names.contains("SKL Kings"))
        XCTAssertTrue(names.contains("Book of Enoch"))
    }

    func testEnsureDefaultFigureGroupsSkipsIfGroupsExist() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureGroup(name: "My Custom Group"))
        try? context.save()

        Migration.ensureDefaultFigureGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.name, "My Custom Group")
    }

    // MARK: - Migration.removeFloodPlaceholder

    func testRemoveFloodPlaceholderRemovesEmptyGroup() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureGroup(name: "The Flood", kind: .flood))
        try? context.save()

        Migration.removeFloodPlaceholder(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        XCTAssertTrue(groups.isEmpty)
    }

    func testRemoveFloodPlaceholderPreservesGroupWithFigure() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "The Flood", kind: .flood)
        context.insert(group)
        let figure = Figure(name: "Ziusudra")
        context.insert(figure)
        let assoc = FigureGroupAssociation(figure: figure)
        group.figureAssociations.append(assoc)
        try? context.save()

        Migration.removeFloodPlaceholder(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.name, "The Flood")
    }

    // MARK: - Migration.markPreExistingSyncretisms

    func testMarkPreExistingSyncretismsAddsSticky() {
        let container = makeContainer()
        let context = container.mainContext
        let ninhursag = Figure(name: "Ninhursag")
        context.insert(ninhursag)
        try? context.save()

        Migration.markPreExistingSyncretisms(context: context)

        XCTAssertEqual(ninhursag.stickies.count, 1)
        XCTAssertTrue(ninhursag.stickies.first?.text.hasPrefix("FROM 26-08-2026 IMPORT") ?? false)
    }

    func testMarkPreExistingSyncretismsIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let ninhursag = Figure(name: "Ninhursag")
        context.insert(ninhursag)
        try? context.save()

        Migration.markPreExistingSyncretisms(context: context)
        Migration.markPreExistingSyncretisms(context: context)

        XCTAssertEqual(ninhursag.stickies.count, 1)
    }

    // MARK: - Migration.alignNergalErraSyncretism

    func testAlignNergalErraSyncretismReTypesIrra() {
        let container = makeContainer()
        let context = container.mainContext
        let nergal = Figure(name: "Nergal")
        let erra = Figure(name: "Erra")
        context.insert(nergal)
        context.insert(erra)
        let irra = AlternateName(figure: nergal, name: "Irra", tradition: .akkadian, nameType: .epithet, note: "sometimes used as his title")
        context.insert(irra)
        try? context.save()

        Migration.alignNergalErraSyncretism(context: context)

        XCTAssertEqual(irra.nameType, .syncretism)
        XCTAssertEqual(nergal.stickies.count, 1)
        XCTAssertEqual(erra.stickies.count, 1)
    }

    func testAlignNergalErraSyncretismIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let nergal = Figure(name: "Nergal")
        let erra = Figure(name: "Erra")
        context.insert(nergal)
        context.insert(erra)
        context.insert(AlternateName(figure: nergal, name: "Irra", tradition: .akkadian, nameType: .syncretism))
        try? context.save()

        Migration.alignNergalErraSyncretism(context: context)
        Migration.alignNergalErraSyncretism(context: context)

        XCTAssertEqual(nergal.stickies.count, 1)
        XCTAssertEqual(erra.stickies.count, 1)
    }

    // MARK: - Migration.deduplicateAsalluhiAsarluhi

    func testDeduplicateAsalluhiAsarluhiMergesAndKeepsCanonicalMother() {
        let container = makeContainer()
        let context = container.mainContext
        let enki = Figure(name: "Enki")
        let damkina = Figure(name: "Damkina")
        let ninhursag = Figure(name: "Ninhursag")
        let motherType = RelationshipType(name: "Mother", icon: "arrow.down", colorHex: "FF2D55", category: "parent")
        let fatherType = RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent")
        context.insert(enki); context.insert(damkina); context.insert(ninhursag)
        context.insert(motherType); context.insert(fatherType)

        let asalluhi = Figure(name: "Asalluhi", figureDescription: "Eridu's god of incantation")
        let asarluhi = Figure(name: "Asarluhi", figureDescription: "Asarluhi was originally a local god of the village of Kuara")
        context.insert(asalluhi); context.insert(asarluhi)
        context.insert(Relationship(fromFigure: enki, toFigure: asalluhi, relationshipType: fatherType, source: "test"))
        context.insert(Relationship(fromFigure: damkina, toFigure: asalluhi, relationshipType: motherType, source: "test"))
        context.insert(Relationship(fromFigure: enki, toFigure: asarluhi, relationshipType: fatherType, source: "test"))
        context.insert(Relationship(fromFigure: ninhursag, toFigure: asarluhi, relationshipType: motherType, source: "test"))
        context.insert(AlternateName(figure: asalluhi, name: "Asaralimnuna", tradition: .sumerian, nameType: .epithet, note: "byname in incantation texts"))
        context.insert(AlternateName(figure: asarluhi, name: "Asaralimnuna", tradition: .sumerian, nameType: .spelling, note: "byname in incantation texts"))
        context.insert(AlternateName(figure: asalluhi, name: "Asalluhe", tradition: .sumerian, nameType: .spelling))
        context.insert(AlternateName(figure: asalluhi, name: "Asarluhi", tradition: .sumerian, nameType: .spelling, note: "self-referencing"))
        try? context.save()

        Migration.deduplicateAsalluhiAsarluhi(context: context)

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(allFigures.filter { $0.name == "Asarluhi" }.count, 1)
        XCTAssertTrue(allFigures.contains { $0.name == "Asarluhi" }, "keeper survives")
        XCTAssertFalse(allFigures.contains { $0.name == "Asalluhi" }, "duplicate folded in")

        let sarluhis = allFigures.filter { $0.name == "Asarluhi" }.first
        let motherRel = ((try? context.fetch(FetchDescriptor<Relationship>())) ?? []).filter { $0.toFigure === sarluhis }
        XCTAssertEqual(motherRel.filter { $0.relationshipType?.name == "Mother" }.count, 1, "single canonical mother")
        XCTAssertTrue(motherRel.contains { $0.fromFigure === damkina }, "Damkina is the canonical mother")
        XCTAssertTrue(sarluhis?.alternateNames.contains { $0.name == "Asalluhe" } ?? false, "unique alternate folded in")
        XCTAssertFalse(sarluhis?.alternateNames.contains { $0.name == "Asarluhi" } ?? false, "self-referencing alternate removed")
        XCTAssertEqual(sarluhis?.alternateNames.count ?? 0, 2, "Asaralimnuna deduped to one row, Asalluhe kept")
    }

    func testDeduplicateAsalluhiAsarluhiIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let enki = Figure(name: "Enki")
        let damkina = Figure(name: "Damkina")
        let motherType = RelationshipType(name: "Mother", icon: "arrow.down", colorHex: "FF2D55", category: "parent")
        let fatherType = RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent")
        context.insert(enki); context.insert(damkina)
        context.insert(motherType); context.insert(fatherType)
        let asalluhi = Figure(name: "Asalluhi")
        let asarluhi = Figure(name: "Asarluhi")
        context.insert(asalluhi); context.insert(asarluhi)
        context.insert(Relationship(fromFigure: enki, toFigure: asalluhi, relationshipType: fatherType, source: "test"))
        context.insert(Relationship(fromFigure: damkina, toFigure: asalluhi, relationshipType: motherType, source: "test"))
        context.insert(Relationship(fromFigure: enki, toFigure: asarluhi, relationshipType: fatherType, source: "test"))
        try? context.save()

        Migration.deduplicateAsalluhiAsarluhi(context: context)
        Migration.deduplicateAsalluhiAsarluhi(context: context)

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(allFigures.filter { $0.name == "Asarluhi" }.count, 1)
        XCTAssertFalse(allFigures.contains { $0.name == "Asalluhi" })
        XCTAssertNoThrow(Migration.deduplicateAsalluhiAsarluhi(context: context), "second run is a no-op, no crash")
    }

    // MARK: - Migration.ensureCanonicalDeityFamilies

    func testEnsureCanonicalDeityFamiliesCreatesSpouseLink() {
        let container = makeContainer()
        let context = container.mainContext
        let motherType = RelationshipType(name: "Mother", icon: "arrow.down", colorHex: "FF2D55", category: "parent")
        let fatherType = RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent")
        let spouseType = RelationshipType(name: "Spouse", icon: "heart", colorHex: "FF3B30", category: "partner")
        context.insert(motherType)
        context.insert(fatherType)
        context.insert(spouseType)
        let father = Figure(name: "Enki")
        let mother = Figure(name: "Damkina")
        let child = Figure(name: "Asarluhi")
        context.insert(father)
        context.insert(mother)
        context.insert(child)
        context.insert(Relationship(fromFigure: father, toFigure: child, relationshipType: fatherType, source: "test"))
        context.insert(Relationship(fromFigure: mother, toFigure: child, relationshipType: motherType, source: "test"))
        try? context.save()

        Migration.ensureCanonicalDeityFamilies(context: context)

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let spouses = edges.filter { $0.relationshipType?.name == "Spouse" }
        XCTAssertEqual(spouses.count, 1)
        XCTAssertTrue(spouses.contains { $0.fromFigure === father && $0.toFigure === mother })
    }

}
