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

    func testMarkPreExistingSyncretismsDeletedStickyStaysDeleted() {
        let container = makeContainer()
        let context = container.mainContext
        let damkina = Figure(name: "Damkina")
        context.insert(damkina)
        try? context.save()

        Migration.markPreExistingSyncretisms(context: context)
        XCTAssertEqual(damkina.stickies.count, 1)

        if let note = damkina.stickies.first {
            Migration.recordStickyDismissal(for: note, context: context)
            context.delete(note)
        }
        try? context.save()

        Migration.markPreExistingSyncretisms(context: context)

        XCTAssertEqual(damkina.stickies.count, 0)
        let dismissals = (try? context.fetch(FetchDescriptor<StickyDismissal>())) ?? []
        XCTAssertEqual(dismissals.count, 1)
        XCTAssertEqual(dismissals.first?.entityKey, "damkina")
    }

    func testMarkPreExistingSyncretismsOtherFiguresStillFlagged() {
        let container = makeContainer()
        let context = container.mainContext
        let damkina = Figure(name: "Damkina")
        let ninhursag = Figure(name: "Ninhursag")
        context.insert(damkina)
        context.insert(ninhursag)
        try? context.save()

        Migration.markPreExistingSyncretisms(context: context)
        if let note = damkina.stickies.first {
            Migration.recordStickyDismissal(for: note, context: context)
            context.delete(note)
        }
        try? context.save()

        Migration.markPreExistingSyncretisms(context: context)

        XCTAssertEqual(damkina.stickies.count, 0)
        XCTAssertEqual(ninhursag.stickies.count, 1)
    }

    func testRecordStickyDismissalIgnoresUserTypedStickies() {
        let container = makeContainer()
        let context = container.mainContext
        let damkina = Figure(name: "Damkina")
        context.insert(damkina)
        let note = StickyNote(text: "Check this cult center", figure: damkina)
        context.insert(note)
        try? context.save()

        Migration.recordStickyDismissal(for: note, context: context)

        let dismissals = (try? context.fetch(FetchDescriptor<StickyDismissal>())) ?? []
        XCTAssertTrue(dismissals.isEmpty)
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

    func testAlignNergalErraDismissedStickyStaysDeleted() {
        let container = makeContainer()
        let context = container.mainContext
        let nergal = Figure(name: "Nergal")
        let erra = Figure(name: "Erra")
        context.insert(nergal)
        context.insert(erra)
        context.insert(AlternateName(figure: nergal, name: "Irra", tradition: .akkadian, nameType: .syncretism))
        try? context.save()

        Migration.alignNergalErraSyncretism(context: context)
        XCTAssertEqual(nergal.stickies.count, 1)
        XCTAssertEqual(erra.stickies.count, 1)

        if let note = nergal.stickies.first {
            Migration.recordStickyDismissal(for: note, context: context)
            context.delete(note)
        }
        try? context.save()

        Migration.alignNergalErraSyncretism(context: context)

        XCTAssertEqual(nergal.stickies.count, 0)
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

    // MARK: - Migration.ensureMeshKiAngGasherEra

    func testEnsureMeshKiAngGasherEraAssignsCanonicalUrukEra() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Mesh-ki-ang-gasher")
        context.insert(figure)
        try? context.save()

        Migration.ensureMeshKiAngGasherEra(context: context)

        XCTAssertEqual(figure.birthDate.era, "First rulers of Uruk")
    }

    func testEnsureMeshKiAngGasherEraPreservesExistingEra() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Mesh-ki-ang-gasher")
        figure.birthDate = MythologicalDate(year: nil, era: "User Set", isApproximate: true)
        context.insert(figure)
        try? context.save()

        Migration.ensureMeshKiAngGasherEra(context: context)

        XCTAssertEqual(figure.birthDate.era, "User Set", "existing era must not be overwritten")
    }

    func testEnsureMeshKiAngGasherEraIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Mesh-ki-ang-gasher")
        context.insert(figure)
        try? context.save()

        Migration.ensureMeshKiAngGasherEra(context: context)
        Migration.ensureMeshKiAngGasherEra(context: context)

        XCTAssertEqual(figure.birthDate.era, "First rulers of Uruk")
    }

    // MARK: - Migration.ensureTimelineMacroEras

    private static let timelineMacroEraConfigs: [(name: String, order: Int)] = [
        ("Uruk Period", 34),
        ("Jemdet Nasr Period", 35),
        ("Mitanni", 36),
        ("Karduniaš (Kassite Babylonia)", 37),
        ("Middle Assyrian Period", 38),
        ("Late Bronze Age Collapse", 39),
        ("Neo-Babylonian Empire", 40),
        ("Achaemenid Empire", 41),
        ("Macedonian Empire", 42),
        ("Seleucid Empire", 43),
        ("Parthian Empire", 44),
        ("Roman and Byzantine Mesopotamia", 45),
        ("Sassanid Empire", 46),
    ]

    func testEnsureTimelineMacroErasCreatesAllThirteen() {
        let container = makeContainer()
        let context = container.mainContext

        Migration.ensureTimelineMacroEras(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        XCTAssertEqual(eras.count, 13)
        let expected = Dictionary(uniqueKeysWithValues: Self.timelineMacroEraConfigs.map { ($0.name, $0.order) })
        for era in eras {
            XCTAssertEqual(era.orderIndex, expected[era.name], "\(era.name) must land on its canonical lane")
            XCTAssertNotNil(era.startDate.startYear, "\(era.name) needs a start year")
            XCTAssertNotNil(era.endDate.endYear, "\(era.name) needs an end year")
            XCTAssertFalse(era.eraDescription.isEmpty, "\(era.name) needs a description")
        }
    }

    func testEnsureTimelineMacroErasIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext

        Migration.ensureTimelineMacroEras(context: context)
        Migration.ensureTimelineMacroEras(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        XCTAssertEqual(eras.count, 13, "second run must not duplicate any macro era")
    }

    func testEnsureTimelineMacroErasLeavesExistingSameNameEraUntouched() {
        let container = makeContainer()
        let context = container.mainContext
        let custom = Era(name: "Seleucid Empire", orderIndex: 5, eraDescription: "user era")
        context.insert(custom)
        try? context.save()

        Migration.ensureTimelineMacroEras(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        XCTAssertEqual(eras.count, 13, "existing era must not be replaced with a new duplicate")
        let fetched = eras.first { $0.name == "Seleucid Empire" }
        XCTAssertEqual(fetched?.orderIndex, 5, "user's existing era keeps its lane")
        XCTAssertEqual(fetched?.eraDescription, "user era", "user's existing era keeps its data")
    }

    func testFixEraOrderIndicesPinsMacroEraLanes() {
        let container = makeContainer()
        let context = container.mainContext

        Migration.ensureTimelineMacroEras(context: context)
        Migration.fixEraOrderIndices(context: context)
        Migration.fixEraOrderIndices(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let expected = Dictionary(uniqueKeysWithValues: Self.timelineMacroEraConfigs.map { ($0.name, $0.order) })
        for era in eras {
            XCTAssertEqual(era.orderIndex, expected[era.name], "\(era.name) must never drift from its lane")
        }
    }

    // MARK: - Legendary dynasty windows (Kish I … Third Kish)

    func testFitLegendaryWindowSingleShareSpansWholeWindow() {
        let fitted = Migration.fitLegendaryWindow(shares: [900], earliestBCE: -2900, latestBCE: -2550)
        XCTAssertEqual(fitted.count, 1)
        XCTAssertEqual(fitted[0].start, -2900)
        XCTAssertEqual(fitted[0].end, -2550)
    }

    func testFitLegendaryWindowProportionalSharesWithinWindow() {
        let shares = [100, 100, 200]   // 25%, 25%, 50% of the 350-year span
        let fitted = Migration.fitLegendaryWindow(shares: shares, earliestBCE: -2900, latestBCE: -2550)
        XCTAssertEqual(fitted.count, 3)
        XCTAssertEqual(fitted[0].start, -2900)
        XCTAssertEqual(fitted[2].end, -2550)
        XCTAssertTrue(fitted[0].end > fitted[0].start)
        XCTAssertEqual(fitted[1].start, fitted[0].end, "slots must be contiguous")
        XCTAssertEqual(fitted[2].start, fitted[1].end, "slots must be contiguous")
        let firstSpan = fitted[0].end - fitted[0].start
        let secondSpan = fitted[1].end - fitted[1].start
        let thirdSpan = fitted[2].end - fitted[2].start
        XCTAssertLessThanOrEqual(abs(firstSpan - secondSpan), 1, "equal shares get spans within 1 of each other")
        XCTAssertLessThanOrEqual(abs(2 * firstSpan - thirdSpan), 2, "double share gets roughly double the span")
    }

    func testFitLegendaryWindowHandlesZeroSharesWithEqualSplit() {
        let fitted = Migration.fitLegendaryWindow(shares: [0, 0, 0], earliestBCE: -2500, latestBCE: -2300)
        XCTAssertEqual(fitted.count, 3)
        XCTAssertEqual(fitted[0].start, -2500)
        XCTAssertEqual(fitted[2].end, -2300)
        XCTAssertEqual(fitted.map { $0.end - $0.start }.reduce(0, +), 200, "slots must exactly tile the window")
        for slot in fitted {
            XCTAssertLessThanOrEqual(slot.end - slot.start, 67, "equal split stays within 1 of 200/3")
            XCTAssertGreaterThanOrEqual(slot.end - slot.start, 66)
        }
    }

    func testEnsureLegendaryDynastyWindowsDatesKingsAndMarksComputed() {
        let container = makeContainer()
        let context = container.mainContext
        let kish = ["Jushur", "Kullassina-bel", "Etana", "Enmebaragesi", "Aga of Kish"]
        for (index, name) in kish.enumerated() {
            let king = Figure(name: name)
            king.birthDate = MythologicalDate(year: nil, era: "First dynasty of Kish", isApproximate: true)
            king.orderIndex = index
            king.source = "Sumerian King List"
            king.reignYears = [1200, 960, 1500, 900, 625][index]
            context.insert(king)
        }
        try? context.save()

        Migration.ensureLegendaryDynastyWindows(context: context)

        let jushur = try! context.fetch(FetchDescriptor<Figure>()).first { $0.name == "Jushur" }!
        let aga = try! context.fetch(FetchDescriptor<Figure>()).first { $0.name == "Aga of Kish" }!
        XCTAssertEqual(jushur.birthDate.startYear, -2900)
        XCTAssertEqual(aga.deathDate.startYear, -2550)
        XCTAssertEqual(jushur.dateSource, Figure.DateSource.computed.rawValue)
        XCTAssertTrue(jushur.birthDate.isApproximate)
    }

    func testEnsureLegendaryDynastyWindowsIsIdempotentAndNeverOverwrites() {
        let container = makeContainer()
        let context = container.mainContext
        let king = Figure(name: "Etana")
        king.birthDate = MythologicalDate(year: -2900, era: "First dynasty of Kish", isApproximate: true)
        king.source = "Sumerian King List"
        king.reignYears = 1500
        context.insert(king)
        try? context.save()

        Migration.ensureLegendaryDynastyWindows(context: context)

        XCTAssertEqual(king.birthDate.startYear, -2900, "hand-entered dates are never clobbered")
    }

    func testEnsureLegendaryDynastyWindowsRefitsComputedDatesInRegnalOrder() {
        let container = makeContainer()
        let context = container.mainContext
        // Live-store bug: seed order had Gilgamesh/Lugalbanda before Mesh-ki-ang-gasher,
        // so fixSKLFigureOrder assigns the scrambled Uruk I orderIndex every launch.
        let canonical = ["Mesh-ki-ang-gasher", "Enmerkar", "Lugalbanda", "Dumuzid the Fisherman",
                         "Gilgamesh", "Ur-Nungal", "Udul-kalama", "La-ba'shum",
                         "En-nun-tarah-ana", "Mesh-he", "Melem-ana", "Lugal-kitun"]
        let reignYears: [Int?] = [nil, 420, 1200, 100, 126, 30, 15, 9, 8, 36, 6, 36]
        let scrambledOrder: [Int] = [2, 3, 1, 4, 0, 5, 6, 7, 8, 9, 10, 11]
        var kings: [Figure] = []
        for (index, name) in canonical.enumerated() {
            let king = Figure(name: name)
            king.birthDate = MythologicalDate(year: nil, era: "First rulers of Uruk", isApproximate: true)
            king.orderIndex = scrambledOrder[index]
            king.source = "Sumerian King List"
            king.reignYears = reignYears[index]
            context.insert(king)
            kings.append(king)
        }
        try? context.save()

        // First fit reproduces the scrambled layout: Gilgamesh ranked first gets the
        // earliest window, before his father Lugalbanda.
        Migration.ensureLegendaryDynastyWindows(context: context)
        let gilgameshFirst = kings.first { $0.name == "Gilgamesh" }!
        let lugalbandaFirst = kings.first { $0.name == "Lugalbanda" }!
        let enmerkarFirst = kings.first { $0.name == "Enmerkar" }!
        XCTAssertLessThan(gilgameshFirst.birthDate.startYear!, lugalbandaFirst.birthDate.startYear!,
                          "bug reproduced: scrambled orderIndex yields child-before-parent dates")

        // The seed/order fix (canonical per-era index) lands after the first fit;
        // a second run must REFIT because every dateSource is now .computed.
        for (index, king) in kings.enumerated() {
            king.orderIndex = index
        }
        Migration.ensureLegendaryDynastyWindows(context: context)

        let enmerkar = kings.first { $0.name == "Enmerkar" }!
        let lugalbanda = kings.first { $0.name == "Lugalbanda" }!
        let gilgamesh = kings.first { $0.name == "Gilgamesh" }!
        let lugalkitun = kings.first { $0.name == "Lugal-kitun" }!
        XCTAssertEqual(enmerkar.birthDate.startYear, -2700, "first king clamps to the window start")
        XCTAssertEqual(lugalbanda.birthDate.startYear, -2668, "first king's reign end contiguously carries forward")
        XCTAssertGreaterThanOrEqual(lugalbanda.birthDate.startYear!, enmerkar.deathDate.startYear!)
        XCTAssertGreaterThanOrEqual(gilgamesh.birthDate.startYear!, lugalbanda.deathDate.startYear!,
                                    "refit resolved the child-before-parent inversion")
        XCTAssertEqual(lugalkitun.deathDate.startYear, -2550, "last king clamps to the window end")
        XCTAssertEqual(gilgamesh.reignStartYear, gilgamesh.birthDate.startYear, "reign columns ride the fit")
        XCTAssertEqual(gilgamesh.reignEndYear, gilgamesh.deathDate.startYear)

        // Idempotent: a third run with the same canonical order rewrites identical values.
        Migration.ensureLegendaryDynastyWindows(context: context)
        XCTAssertEqual(gilgamesh.birthDate.startYear, gilgamesh.reignStartYear)
    }

    func testEnsureLegendaryDynastyWindowsRefitRespectsHandEnteredDates() {
        let container = makeContainer()
        let context = container.mainContext
        let handDated = Figure(name: "Enmerkar")
        handDated.birthDate = MythologicalDate(year: -2700, era: "First rulers of Uruk", isApproximate: true)
        handDated.deathDate = MythologicalDate(year: -2600, era: "First rulers of Uruk", isApproximate: true)
        handDated.source = "Sumerian King List"
        handDated.dateSource = Figure.DateSource.historical.rawValue
        context.insert(handDated)
        try? context.save()

        Migration.ensureLegendaryDynastyWindows(context: context)

        XCTAssertEqual(handDated.birthDate.startYear, -2700, "historical dates are never refit")
        XCTAssertEqual(handDated.deathDate.startYear, -2600)
    }

    func testResolveSeedCitationIdsReplacesUUIDsWithEntityNames() {
        let container = makeContainer()
        let context = container.mainContext
        guard let root = SeedData.loadRoot(),
              let firstFigure = root.figures.first else {
            XCTFail("seed unavailable in test target")
            return
        }
        let source = Source(name: "Enuma Elish", sourceType: .ancientText)
        context.insert(source)
        let uuidCit = Citation(source: source, location: "Tablet I", entityType: .figure, linkedEntityName: firstFigure.id)
        let plainCit = Citation(source: source, location: "Tablet II", entityType: .event, linkedEntityName: "Not a UUID")
        context.insert(uuidCit)
        context.insert(plainCit)
        try? context.save()

        Migration.resolveSeedCitationIds(context: context)

        XCTAssertEqual(uuidCit.linkedEntityName, firstFigure.name, "seed UUID resolved to the entity name")
        XCTAssertEqual(plainCit.linkedEntityName, "Not a UUID", "non-UUID values untouched")

        Migration.resolveSeedCitationIds(context: context)
        XCTAssertEqual(uuidCit.linkedEntityName, firstFigure.name, "idempotent — rerun changes nothing")
    }

    func testCorrectAnomalousGenealogyRemovesDumuziShepherdUrukParentEdges() {
        let container = makeContainer()
        let context = container.mainContext
        let fatherType = makeRelationType("Father", in: context)
        let motherType = makeRelationType("Mother", in: context)
        let lugalbanda = Figure(name: "Lugalbanda")
        lugalbanda.birthDate = MythologicalDate(year: -2668, era: "First rulers of Uruk", isApproximate: true)
        let ninsun = Figure(name: "Ninsun")
        let shepherd = Figure(name: "Dumuzi the Shepherd")
        shepherd.birthDate = MythologicalDate(year: -132400, era: "Antediluvian", isApproximate: true)
        for figure in [lugalbanda, ninsun, shepherd] {
            context.insert(figure)
        }
        context.insert(Relationship(fromFigure: lugalbanda, toFigure: shepherd, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: ninsun, toFigure: shepherd, relationshipType: motherType))
        context.insert(IntegrityFinding(kindRaw: "childBornBeforeParent", severityRaw: "warning",
                                        entityKind: "Figure", entityKey: "Lugalbanda", detail: "stale"))
        context.insert(IntegrityFinding(kindRaw: "childBornBeforeParent", severityRaw: "warning",
                                        entityKind: "Figure", entityKey: "Dumuzi the Shepherd", detail: "stale"))
        try? context.save()

        Migration.correctAnomalousGenealogy(context: context)

        let shepherdEdges = ((try? context.fetch(FetchDescriptor<Relationship>())) ?? []).filter {
            $0.toFigure?.name == "Dumuzi the Shepherd"
        }
        XCTAssertTrue(shepherdEdges.isEmpty, "antediluvian shepherd no longer parented to Uruk I kings")

        let stale = ((try? context.fetch(FetchDescriptor<IntegrityFinding>())) ?? []).filter {
            $0.kindRaw == "childBornBeforeParent"
        }
        XCTAssertTrue(stale.isEmpty, "stale persisted findings for fixed signatures cleared")
    }

    // MARK: - Migration: fixEgalmahCoordinates

    func testFixEgalmahCoordinatesCorrectsSeededValue() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "E-galmah", modernLocation: "Isin", latitude: 31.9, longitude: 44.5))
        let isin = Place(name: "Isin", modernLocation: "Tell Ishan al-Bahriyat, Iraq", latitude: 31.93351, longitude: 45.28521)
        context.insert(isin)
        try? context.save()

        Migration.fixEgalmahCoordinates(context: context)

        let egalmah = (try? context.fetch(FetchDescriptor<Place>()))?.first { $0.name == "E-galmah" }
        XCTAssertEqual(egalmah?.latitude ?? 0, isin.latitude ?? 0, accuracy: 0.00001)
        XCTAssertEqual(egalmah?.longitude ?? 0, isin.longitude ?? 0, accuracy: 0.00001)
    }

    func testFixEgalmahCoordinatesFallsBackWhenNoIsinPlace() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "E-galmah", modernLocation: "Isin", latitude: 31.9, longitude: 44.5))
        try? context.save()

        Migration.fixEgalmahCoordinates(context: context)

        let egalmah = (try? context.fetch(FetchDescriptor<Place>()))?.first { $0.name == "E-galmah" }
        XCTAssertEqual(egalmah?.latitude ?? 0, 31.93351, accuracy: 0.00001)
        XCTAssertEqual(egalmah?.longitude ?? 0, 45.28521, accuracy: 0.00001)
    }

    func testFixEgalmahCoordinatesSkipsUserCorrected() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "E-galmah", modernLocation: "Isin", latitude: 31.933, longitude: 45.267))
        try? context.save()

        Migration.fixEgalmahCoordinates(context: context)

        let egalmah = (try? context.fetch(FetchDescriptor<Place>()))?.first { $0.name == "E-galmah" }
        XCTAssertEqual(egalmah?.latitude ?? 0, 31.933, accuracy: 0.00001, "already-corrected coordinates untouched")
        XCTAssertEqual(egalmah?.longitude ?? 0, 45.267, accuracy: 0.00001)
    }

    func testFixEgalmahCoordinatesIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "E-galmah", modernLocation: "Isin", latitude: 31.9, longitude: 44.5))
        let isin = Place(name: "Isin", modernLocation: "Tell Ishan al-Bahriyat, Iraq", latitude: 31.93351, longitude: 45.28521)
        context.insert(isin)
        try? context.save()

        Migration.fixEgalmahCoordinates(context: context)
        Migration.fixEgalmahCoordinates(context: context)

        let egalmah = (try? context.fetch(FetchDescriptor<Place>()))?.first { $0.name == "E-galmah" }
        XCTAssertEqual(egalmah?.latitude ?? 0, 31.93351, accuracy: 0.00001)
        XCTAssertEqual(egalmah?.longitude ?? 0, 45.28521, accuracy: 0.00001)
    }

    func testFixEgalmahCoordinatesNoEgalmahNoCrash() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "Ur", modernLocation: "Tell al-Muqayyar, Iraq", latitude: 30.9626, longitude: 46.1034))
        try? context.save()

        Migration.fixEgalmahCoordinates(context: context)

        let ur = (try? context.fetch(FetchDescriptor<Place>()))?.first { $0.name == "Ur" }
        XCTAssertEqual(ur?.latitude ?? 0, 30.9626, accuracy: 0.00001)
        XCTAssertEqual(ur?.longitude ?? 0, 46.1034, accuracy: 0.00001)
    }

    // MARK: - Migration: ensureReignVersionBackfill

    private func makeReignBackfillKings(_ context: ModelContext) {
        for name in ["Kullassina-bel", "Etana", "Bur-Suen", "Iter-pisha", "Ur-du-kuga"] {
            let figure = Figure(name: name)
            figure.reignYears = 1
            context.insert(figure)
        }
        try? context.save()
    }

    func testEnsureReignVersionBackfillCreatesDocumentedVariants() {
        let container = makeContainer()
        let context = container.mainContext
        makeReignBackfillKings(context)

        Migration.ensureReignVersionBackfill(context: context)

        let versions = (try? context.fetch(FetchDescriptor<ReignVersion>())) ?? []
        XCTAssertEqual(versions.count, 5)
        let expectedYears: Set<Int?> = [900, 635, 22, 3, 3]
        XCTAssertEqual(Set(versions.map(\.years)), expectedYears)

        let kullassina = (try? context.fetch(FetchDescriptor<Figure>()))?.first { $0.name == "Kullassina-bel" }
        XCTAssertEqual(kullassina?.reignVersions.map(\.years), [900])
        XCTAssertEqual(kullassina?.reignVersions.first?.tradition, "Some copies of the Sumerian King List")

        let etana = (try? context.fetch(FetchDescriptor<Figure>()))?.first { $0.name == "Etana" }
        XCTAssertEqual(etana?.reignVersions.map(\.years), [635])

        let burSuen = (try? context.fetch(FetchDescriptor<Figure>()))?.first { $0.name == "Bur-Suen" }
        XCTAssertEqual(burSuen?.reignVersions.map(\.years), [22])
        XCTAssertEqual(burSuen?.reignVersions.first?.tradition, "Ur-Isin king list")

        let urDuKuga = (try? context.fetch(FetchDescriptor<Figure>()))?.first { $0.name == "Ur-du-kuga" }
        XCTAssertEqual(urDuKuga?.reignVersions.map(\.years), [3])
    }

    func testEnsureReignVersionBackfillIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        makeReignBackfillKings(context)

        Migration.ensureReignVersionBackfill(context: context)
        Migration.ensureReignVersionBackfill(context: context)

        let versions = (try? context.fetch(FetchDescriptor<ReignVersion>())) ?? []
        XCTAssertEqual(versions.count, 5)
    }

    func testEnsureReignVersionBackfillSkipsUnknownFigures() {
        let container = makeContainer()
        let context = container.mainContext
        let lugal = Figure(name: "Lugal-zage-si")
        lugal.reignYears = 25
        context.insert(lugal)
        try? context.save()

        Migration.ensureReignVersionBackfill(context: context)

        let versions = (try? context.fetch(FetchDescriptor<ReignVersion>())) ?? []
        XCTAssertTrue(versions.isEmpty)
    }

    func testEnsureReignVersionBackfillDoesNotDuplicateUserVariant() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Kullassina-bel")
        context.insert(figure)
        let userVariant = ReignVersion(years: 900, tradition: "Some copies of the Sumerian King List", note: "User-entered note")
        figure.reignVersions.append(userVariant)
        context.insert(userVariant)
        try? context.save()

        Migration.ensureReignVersionBackfill(context: context)

        XCTAssertEqual(figure.reignVersions.count, 1, "matched user variant must not be duplicated")
        XCTAssertEqual(figure.reignVersions.first?.note, "User-entered note")
    }

}
