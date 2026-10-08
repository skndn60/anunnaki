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
        ("Uruk Period", 35),
        ("Jemdet Nasr Period", 36),
        ("Mitanni", 37),
        ("Karduniaš (Kassite Babylonia)", 38),
        ("Middle Assyrian Period", 39),
        ("Late Bronze Age Collapse", 40),
        ("Neo-Babylonian Empire", 41),
        ("Achaemenid Empire", 42),
        ("Macedonian Empire", 43),
        ("Seleucid Empire", 44),
        ("Parthian Empire", 45),
        ("Roman and Byzantine Mesopotamia", 46),
        ("Sassanid Empire", 47),
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

    // MARK: - Migration.ensureFirstBabylonianDynasty

    func testEnsureFirstBabylonianDynastyCreatesEraRosterSourcesAndLineage() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        try? context.save()

        Migration.ensureFirstBabylonianDynasty(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let era = eras.first { $0.name == Migration.firstBabylonianEraName }
        XCTAssertNotNil(era)
        XCTAssertEqual(era?.orderIndex, 31)
        XCTAssertEqual(era?.startDate.startYear, -1894)
        XCTAssertEqual(era?.endDate.endYear, -1595)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let roster = figures
            .filter { $0.era?.persistentModelID == era?.persistentModelID }
            .sorted { $0.orderIndex < $1.orderIndex }
        XCTAssertEqual(roster.count, 11)
        XCTAssertEqual(roster.map(\.name), Migration.firstBabylonianRulers.map(\.name))
        XCTAssertEqual(roster[5].name, "Hammurabi", "Hammurabi must be the sixth ruler, not the fourth")
        XCTAssertEqual(roster.first?.reignStartYear, -1894)
        XCTAssertEqual(roster.last?.reignEndYear, -1595)
        XCTAssertTrue(roster.allSatisfy { $0.birthDate.era == Migration.firstBabylonianEraName })

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let kingList = sources.first { $0.name == "Babylonian King List A" }
        XCTAssertNotNil(kingList)
        XCTAssertEqual(kingList?.sourceType, .kingList)

        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        let figureCitations = citations.filter { $0.source?.persistentModelID == kingList?.persistentModelID && $0.entityType == .figure }
        XCTAssertEqual(figureCitations.count, 11)
        XCTAssertTrue(citations.contains { $0.source?.persistentModelID == kingList?.persistentModelID && $0.entityType == .era })

        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let fatherLinks = relationships.filter { $0.relationshipType?.name == "Father" && $0.sourceRef?.persistentModelID == kingList?.persistentModelID }
        XCTAssertEqual(fatherLinks.count, 10, "eleven kings form ten father→son links")
    }

    func testEnsureFirstBabylonianDynastyIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        try? context.save()

        Migration.ensureFirstBabylonianDynasty(context: context)
        Migration.ensureFirstBabylonianDynasty(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []

        XCTAssertEqual(eras.filter { $0.name == Migration.firstBabylonianEraName }.count, 1)
        XCTAssertEqual(figures.filter { $0.era?.name == Migration.firstBabylonianEraName }.count, 11)
        XCTAssertEqual(sources.filter { $0.name == "Babylonian King List A" }.count, 1)
        XCTAssertEqual(citations.filter { $0.entityType == .figure }.count, 22, "two sources cite each of the eleven kings")
        XCTAssertEqual(relationships.filter { $0.relationshipType?.name == "Father" }.count, 10)
    }

    func testEnsureFirstBabylonianDynastyMatchesSpellingVariantsAndPreservesUserData() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        let otherEra = Era(name: "My Custom Era", orderIndex: 90)
        let custom = Figure(name: "Hammurabi", title: "Custom Title", gender: .male, birthDate: MythologicalDate(era: "My Custom Era"))
        custom.era = otherEra
        custom.updateKingship(reignStartYear: -1700, reignEndYear: -1680, reignYears: 20)
        context.insert(otherEra)
        context.insert(custom)
        try? context.save()

        Migration.ensureFirstBabylonianDynasty(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.filter { NameDuplicateCheck.normalizedKey($0.name) == "hammurabi" }.count, 1, "spelling-normalized match must not duplicate")
        XCTAssertEqual(custom.era?.persistentModelID, otherEra.persistentModelID, "a user-filed ruler keeps a non-superseding era")
        XCTAssertEqual(custom.title, "Custom Title")
        XCTAssertEqual(custom.reignStartYear, -1700)
        XCTAssertEqual(custom.reignYears, 20)
        let roster = figures.filter { $0.era?.name == Migration.firstBabylonianEraName }
        XCTAssertEqual(roster.count, 10, "the user-filed Hammurabi stays out of the new era")
    }

    func testFixEraOrderIndicesPinsFirstBabylonianLaneAndShiftsLaterLanes() {
        let container = makeContainer()
        let context = container.mainContext

        Migration.ensureFirstBabylonianDynasty(context: context)
        Migration.ensureHistoricalPeriodEras(context: context)
        Migration.ensureTimelineMacroEras(context: context)
        Migration.fixEraOrderIndices(context: context)
        Migration.fixEraOrderIndices(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let byName = Dictionary(eras.map { ($0.name, $0.orderIndex) }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(byName["First Dynasty of Babylon"], 31)
        XCTAssertEqual(byName["Old Assyrian Period"], 32)
        XCTAssertEqual(byName["Old Babylonian Period"], 33)
        XCTAssertEqual(byName["Neo-Assyrian Period"], 34)
        XCTAssertEqual(byName["Uruk Period"], 35)
        XCTAssertEqual(byName["Sassanid Empire"], 47)
    }

    func testEnrichSKLDataDoesNotCiteNonSKLHistoricalFigures() {
        let container = makeContainer()
        let context = container.mainContext
        let humanType = FigureType(name: "Human", icon: "person.fill", colorHex: "34C759")
        context.insert(humanType)
        context.insert(Source(name: "Sumerian King List", sourceType: .kingList))
        let kishEra = Era(name: "First dynasty of Kish", orderIndex: 11)
        let babylonEra = Era(name: Migration.firstBabylonianEraName, orderIndex: 31)
        context.insert(kishEra)
        context.insert(babylonEra)
        let sklKing = Figure(name: "Etana", figureType: humanType, birthDate: MythologicalDate(era: "First dynasty of Kish"))
        sklKing.era = kishEra
        let babylon = Figure(name: "Hammurabi", figureType: humanType, birthDate: MythologicalDate(era: Migration.firstBabylonianEraName))
        babylon.era = babylonEra
        context.insert(sklKing)
        context.insert(babylon)
        try? context.save()

        Migration.enrichSKLData(context: context)

        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        let sklCitations = citations.filter { $0.source?.name == "Sumerian King List" }
        XCTAssertTrue(sklCitations.contains { $0.linkedEntityName == "Etana" }, "the SKL king keeps an SKL citation")
        XCTAssertFalse(sklCitations.contains { $0.linkedEntityName == "Hammurabi" }, "a later dynasty's king must not inherit an SKL citation")
    }

    func testEnsureDynastyGroupsBuildsFirstBabylonianSubgroup() {
        let container = makeContainer()
        let context = container.mainContext
        let humanType = FigureType(name: "Human", icon: "person.fill", colorHex: "34C759")
        context.insert(humanType)
        let era = Era(name: Migration.firstBabylonianEraName, orderIndex: 31)
        context.insert(era)
        let king = Figure(name: "Sumu-abum", figureType: humanType, birthDate: MythologicalDate(era: Migration.firstBabylonianEraName))
        king.era = era
        context.insert(king)
        try? context.save()

        Migration.ensureDynastyGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        let subgroup = groups.first { $0.name == Migration.firstBabylonianEraName }
        XCTAssertNotNil(subgroup)
        XCTAssertEqual(subgroup?.era?.persistentModelID, era.persistentModelID)
        XCTAssertTrue(subgroup?.figureAssociations.contains { $0.figure?.persistentModelID == king.persistentModelID } ?? false)
    }

    func testEnsureDynastyBoundariesCoversFirstBabylonianDynasty() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: Migration.firstBabylonianEraName, orderIndex: 31))
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let era = (try? context.fetch(FetchDescriptor<Era>()))?.first { $0.name == Migration.firstBabylonianEraName }
        guard let json = era?.boundaryGeoJSON?.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any],
              let coordinates = object["coordinates"] as? [[[Double]]],
              let ring = coordinates.first else {
            XCTFail("First Dynasty of Babylon must get a boundary")
            return
        }
        XCTAssertEqual(ring.first, ring.last, "ring must be closed")
        XCTAssertTrue(pointInRing((44.42, 32.54), ring), "Babylon must fall inside the dynasty territory")
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

    // MARK: - Migration.ensureBabylonianKingListDynasties

    func testEnsureBabylonianKingListCreatesEveryDynastyAndRuler() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        try? context.save()

        Migration.ensureFirstBabylonianDynasty(context: context)
        Migration.ensureBabylonianKingListDynasties(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        for dynasty in Migration.babylonianDynasties {
            XCTAssertEqual(
                eras.filter { $0.name == dynasty.name }.count, 1,
                "expected exactly one era named \(dynasty.name)"
            )
        }

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var byKey: [String: Figure] = [:]
        for figure in figures { byKey[NameDuplicateCheck.normalizedKey(figure.name)] = figure }

        for ruler in Migration.babylonianKingListRulers {
            XCTAssertNotNil(
                byKey[NameDuplicateCheck.normalizedKey(ruler.name)],
                "\(ruler.name) is missing after the import"
            )
        }
        XCTAssertEqual(Migration.babylonianKingListRulers.count, 115)
    }

    func testBabylonianKingListIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        try? context.save()

        Migration.ensureFirstBabylonianDynasty(context: context)
        Migration.ensureBabylonianKingListDynasties(context: context)
        let erasAfterFirst = ((try? context.fetch(FetchDescriptor<Era>())) ?? []).count
        let figuresAfterFirst = ((try? context.fetch(FetchDescriptor<Figure>())) ?? []).count

        Migration.ensureBabylonianKingListDynasties(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(eras.count, erasAfterFirst, "a second pass must not add eras")
        XCTAssertEqual(figures.count, figuresAfterFirst, "a second pass must not add figures")
        for dynasty in Migration.babylonianDynasties {
            XCTAssertEqual(eras.filter { $0.name == dynasty.name }.count, 1, "duplicate era \(dynasty.name)")
        }
    }

    func testBabylonianKingListReusesTheFirstDynastyEraInsteadOfDuplicatingIt() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        try? context.save()

        Migration.ensureFirstBabylonianDynasty(context: context)
        Migration.ensureBabylonianKingListDynasties(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        XCTAssertEqual(
            eras.filter { $0.name == Migration.firstBabylonianEraName }.count, 1,
            "two seeders must not each create a First Dynasty of Babylon era"
        )
        XCTAssertEqual(
            eras.filter { $0.name == "Amorite dynasty of Babylon" }.count, 0,
            "Dynasty I must land in the era ensureFirstBabylonianDynasty owns"
        )

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let dynastyIRulers = Migration.babylonianKingListRulers.filter { $0.dynasty == 1 }
        XCTAssertEqual(dynastyIRulers.count, 11)
        let era = eras.first { $0.name == Migration.firstBabylonianEraName }
        let roster = figures.filter { $0.era?.persistentModelID == era?.persistentModelID }
        XCTAssertEqual(roster.count, 11)
    }

    func testBabylonianKingListDatesAreNegativeForBCEAndNilWhereTheTableHasNone() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        try? context.save()

        Migration.ensureBabylonianKingListDynasties(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var byName: [String: Figure] = [:]
        for figure in figures { byName[figure.name] = figure }

        XCTAssertEqual(byName["Gandash"]?.reignStartYear, -1729)
        XCTAssertEqual(byName["Gandash"]?.reignEndYear, -1704)
        XCTAssertEqual(byName["Nabonidus"]?.reignStartYear, -556)

        // The Sealand and middle Kassite kings are printed "??" in the table, so a
        // negative or positive year here would be one we invented.
        XCTAssertNil(byName["Abi-Rattash"]?.reignStartYear)
        XCTAssertNil(byName["Kashtiliash II"]?.reignStartYear)
        XCTAssertNil(byName["Itti-ili-nibi"]?.reignStartYear)
        XCTAssertNil(byName["Damqi-ilishu"]?.reignStartYear)

        for ruler in Migration.babylonianKingListRulers {
            guard let start = ruler.startYear else { continue }
            XCTAssertLessThan(start, 0, "\(ruler.name) is BCE and must be stored negative")
        }
    }

    func testBabylonianKingListStoresInterruptedReignsAsTheOuterSpanWithANote() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        try? context.save()

        Migration.ensureBabylonianKingListDynasties(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var byName: [String: Figure] = [:]
        for figure in figures { byName[figure.name] = figure }

        // Sennacherib holds Babylon -705..-703 and again -689..-681 with Esarhaddon
        // in between. Figure has one reign span, so the span is the bounding box and
        // the description has to say why it is not continuous.
        XCTAssertEqual(byName["Sennacherib"]?.reignStartYear, -705)
        XCTAssertEqual(byName["Sennacherib"]?.reignEndYear, -681)
        XCTAssertTrue(
            byName["Sennacherib"]?.figureDescription.contains("two reigns") == true,
            "the interruption must be recorded in the description"
        )

        for name in ["Ashurbanipal", "Marduk-apla-iddina II"] {
            XCTAssertTrue(
                byName[name]?.figureDescription.contains("two reigns") == true,
                "\(name) held the throne twice and the note must say so"
            )
        }
    }

    func testBabylonianKingListDoesNotDeriveLineageFromSuccession() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        context.insert(RelationshipType(name: "Father", icon: "arrow.down", colorHex: "007AFF", category: "parent", reverseName: "Son of"))
        try? context.save()

        Migration.ensureBabylonianKingListDynasties(context: context)

        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let kingListFatherLinks = relationships.filter {
            $0.relationshipType?.name == "Father"
                && $0.sourceRef?.name == "Babylonian King List A"
                && ($0.toFigure?.name == "Kurigalzu I" || $0.toFigure?.name == "Kashtiliash I")
        }
        XCTAssertTrue(
            kingListFatherLinks.isEmpty,
            "a king list gives succession, not filiation; adjacent rows must not become father→son"
        )
    }

    func testBabylonianKingListKeepsAKingInTheEraTheUserChose() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        let assyrian = Era(name: "Neo-Assyrian Period", orderIndex: 34)
        context.insert(assyrian)
        let usurper = Figure(name: "Marduk-apla-iddina II", title: "Chaldean chief")
        usurper.era = assyrian
        usurper.birthDate = MythologicalDate(year: -720, era: "Neo-Assyrian Period", isApproximate: true)
        context.insert(usurper)
        try? context.save()

        Migration.ensureBabylonianKingListDynasties(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let kept = figures.first { $0.name == "Marduk-apla-iddina II" }
        XCTAssertEqual(kept?.era?.name, "Neo-Assyrian Period", "the user's era choice must win")
        XCTAssertEqual(kept?.title, "Chaldean chief", "existing prose must survive")
        XCTAssertEqual(kept?.reignStartYear, -722, "a blank regnal field may still be filled")
    }

    func testBabylonianKingListMatchesExistingSpellingVariants() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        context.insert(Figure(name: "Ea-Gamil", title: "Sealand king"))
        try? context.save()

        Migration.ensureBabylonianKingListDynasties(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.filter { $0.name == "Ea-Gamil" }.count, 1)
        XCTAssertEqual(
            figures.first { $0.name == "Ea-Gamil" }?.reignStartYear, -1484,
            "the user's spelling must be kept and its blank regnal field filled"
        )
    }

    func testBabylonianKingListCitesTheKingListAndTheModernChronologySeparately() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        try? context.save()

        Migration.ensureBabylonianKingListDynasties(context: context)

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let kingList = sources.first { $0.name == "Babylonian King List A" }
        let chronology = sources.first { $0.name == "List of kings of Babylon" }
        XCTAssertNotNil(kingList)
        XCTAssertNotNil(chronology, "the regnal dates need a source of their own")
        XCTAssertNotEqual(
            kingList?.persistentModelID, chronology?.persistentModelID,
            "the ancient succession and the modern regnal dates are different claims"
        )

        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        let datedCitations = citations.filter {
            $0.source?.persistentModelID == chronology?.persistentModelID && $0.entityType == .figure
        }
        XCTAssertGreaterThan(datedCitations.count, 0)
        XCTAssertTrue(citations.allSatisfy { $0.source?.name != "Babylonian King List A" || $0.location.hasPrefix("Dynasty") })
    }

    func testBabylonianDynastyErasDoNotDriftUnderFixEraOrderIndices() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigureType(name: "Human", icon: "person.fill", colorHex: "34C759"))
        try? context.save()

        Migration.ensureFirstBabylonianDynasty(context: context)
        Migration.ensureBabylonianKingListDynasties(context: context)
        let dynastyNames = Set(Migration.babylonianDynasties.map(\.name))
        let before = ((try? context.fetch(FetchDescriptor<Era>())) ?? [])
            .filter { dynastyNames.contains($0.name) }
            .reduce(into: [String: Int]()) { $0[$1.name] = $1.orderIndex }

        Migration.fixEraOrderIndices(context: context)

        let after = ((try? context.fetch(FetchDescriptor<Era>())) ?? [])
            .filter { dynastyNames.contains($0.name) }
            .reduce(into: [String: Int]()) { $0[$1.name] = $1.orderIndex }

        XCTAssertEqual(before, after, "an era missing from fixEraOrderIndices gains +1 on every launch")
        XCTAssertEqual(
            after.count, Migration.babylonianDynasties.count,
            "all ten dynasties must be pinned in fixEraOrderIndices, Dynasty I included"
        )
    }

    func testBabylonianDynastyOrderIndexesDoNotCollideWithTheExistingPostSKLLane() {
        let reserved = Set(0...47)
        for dynasty in Migration.babylonianDynasties where dynasty.number != 1 {
            let index = Migration.babylonianDynastyOrderIndex[dynasty.name] ?? -1
            XCTAssertFalse(
                reserved.contains(index),
                "\(dynasty.name) at \(index) would renumber eras the user already has"
            )
        }
    }

    /// The propagator groups every figure in the store by `birthDate.era`, and a
    /// group with no explicitly dated member yields `startBCE: nil` for all of it.
    /// Assigning that nil through emptied the reign years of the imported
    /// Babylonian kings on every launch while their era and prose survived. This
    /// pins adopt-if-absent: a real date is filled in, an absent one is left alone.
    func testEnrichSKLDataDoesNotClearReignYearsItCannotCompute() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Kassite Dynasty of Babylon", orderIndex: 49)
        context.insert(era)
        let dated = Figure(name: "Ulamburiash")
        dated.birthDate = MythologicalDate(startYear: -1831, endYear: -1831, era: "Kassite Dynasty of Babylon")
        context.insert(dated)
        let imported = Figure(name: "Harba-Shipak")
        imported.birthDate = MythologicalDate(era: "Kassite Dynasty of Babylon")
        imported.reignStartYear = -1761
        imported.reignEndYear = -1755
        context.insert(imported)
        try? context.save()

        Migration.enrichSKLData(context: context)

        XCTAssertEqual(imported.reignStartYear, -1761)
        XCTAssertEqual(imported.reignEndYear, -1755)
    }

    /// The other half: a genuinely undated figure in a dated group still gets filled
    /// by propagation, so the guard above does not disable the feature it protects.
    func testEnrichSKLDataStillFillsAReignItCanCompute() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Third dynasty of Ur", orderIndex: 29))
        let dated = Figure(name: "Ur-Nammu")
        dated.birthDate = MythologicalDate(startYear: -2112, era: "Third dynasty of Ur")
        dated.deathDate = MythologicalDate(startYear: -2095, era: "Third dynasty of Ur")
        context.insert(dated)
        let propagated = Figure(name: "Šulgi")
        propagated.figureDescription = "Second king of the Third dynasty of Ur. Reigned 48 years."
        propagated.birthDate = MythologicalDate(era: "Third dynasty of Ur")
        context.insert(propagated)
        try? context.save()

        Migration.enrichSKLData(context: context)

        // The exact BCE arithmetic is the propagator's own concern and is unit-tested
        // with the real SKL data; what this pins is that adopt-if-absent did not turn
        // the propagation off.
        XCTAssertNotNil(propagated.reignStartYear, "propagation still fills a reign it can compute")
        XCTAssertNotNil(propagated.reignEndYear)
    }

    // MARK: - Migration: fixFoundingOfEriduEra

    private func insertEriduEraFixture(context: ModelContext, year: Int, era: String) -> Event {
        context.insert(Era(
            name: "Anunnaki on Earth",
            orderIndex: 1,
            startDate: MythologicalDate(startYear: -445000, endYear: -445000, era: "Anunnaki on Earth"),
            endDate: MythologicalDate(year: -200000, era: "Anunnaki on Earth")
        ))
        context.insert(Era(
            name: "Post-Flood Kingdoms",
            orderIndex: 8,
            startDate: MythologicalDate(startYear: -27000, endYear: -27000, era: "Post-Flood Kingdoms"),
            endDate: MythologicalDate(year: -2900, era: "Post-Flood Kingdoms")
        ))
        let event = Event(
            name: "Founding of Eridu",
            eventDescription: "The first city was established by the gods. Kingship first descended from heaven here.",
            date: MythologicalDate(startYear: year, endYear: nil, era: era, isApproximate: true),
            era: era,
            source: "Sumerian King List"
        )
        context.insert(event)
        try? context.save()
        return event
    }

    func testFixFoundingOfEriduEraMovesAnOutOfBandDateIntoItsContainingEra() {
        let container = makeContainer()
        let context = container.mainContext
        let event = insertEriduEraFixture(context: context, year: -5400, era: "Anunnaki on Earth")

        Migration.fixFoundingOfEriduEra(context: context)

        XCTAssertEqual(event.date.era, "Post-Flood Kingdoms")
        XCTAssertEqual(event.era, "Post-Flood Kingdoms")
    }

    func testFixFoundingOfEriduEraLeavesTheDateItselfUntouched() {
        let container = makeContainer()
        let context = container.mainContext
        let event = insertEriduEraFixture(context: context, year: -5400, era: "Anunnaki on Earth")

        Migration.fixFoundingOfEriduEra(context: context)

        XCTAssertEqual(event.date.startYear, -5400)
        XCTAssertNil(event.date.endYear)
        XCTAssertTrue(event.date.isApproximate)
        XCTAssertEqual(event.eventDescription, "The first city was established by the gods. Kingship first descended from heaven here.")
    }

    func testFixFoundingOfEriduEraIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let event = insertEriduEraFixture(context: context, year: -5400, era: "Anunnaki on Earth")

        Migration.fixFoundingOfEriduEra(context: context)
        Migration.fixFoundingOfEriduEra(context: context)

        XCTAssertEqual(event.date.era, "Post-Flood Kingdoms")
        XCTAssertEqual(event.era, "Post-Flood Kingdoms")
        XCTAssertEqual(event.date.startYear, -5400)
    }

    func testFixFoundingOfEriduEraLeavesADateInsideTheBandAlone() {
        let container = makeContainer()
        let context = container.mainContext
        let event = insertEriduEraFixture(context: context, year: -445000, era: "Anunnaki on Earth")

        Migration.fixFoundingOfEriduEra(context: context)

        XCTAssertEqual(event.date.era, "Anunnaki on Earth")
        XCTAssertEqual(event.era, "Anunnaki on Earth")
        XCTAssertEqual(event.date.startYear, -445000)
    }

    func testFixFoundingOfEriduEraLeavesOtherEventsAlone() {
        let container = makeContainer()
        let context = container.mainContext
        _ = insertEriduEraFixture(context: context, year: -5400, era: "Anunnaki on Earth")
        let other = Event(
            name: "The great Flood",
            date: MythologicalDate(startYear: -30000, endYear: nil, era: "The Great Flood", isApproximate: true),
            era: "The Great Flood"
        )
        context.insert(other)
        try? context.save()

        Migration.fixFoundingOfEriduEra(context: context)

        XCTAssertEqual(other.date.era, "The Great Flood")
        XCTAssertEqual(other.era, "The Great Flood")
    }

    // MARK: - Migration: ensureFirstGodsEventsExist

    private func insertFirstGodsFigures(context: ModelContext) {
        for name in ["Nammu", "An", "Ki", "Anunnaki", "Enlil", "Enki", "Inanna", "Utu", "Ninurta"] {
            context.insert(Figure(name: name))
        }
        for name in ["Heaven", "Earth", "Eridu", "Abzu", "Nippur"] {
            context.insert(Place(name: name))
        }
        try? context.save()
    }

    func testFirstGodsEventsImportCreatesSixUndatedEventsInTheFirstGodsEra() {
        let container = makeContainer()
        let context = container.mainContext
        SeedData.ensureTypesExist(context: context)
        insertFirstGodsFigures(context: context)

        Migration.ensureFirstGodsEventsExist(context: context)

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertEqual(events.count, 6, "expected the six first-gods events, got \(events.map(\.name))")

        let expected = [
            "Nammu gives birth to heaven and earth",
            "The Anuna gods are born",
            "Separation of heaven and earth",
            "Enki founds his house in the Abzu at Eridu",
            "Enki establishes the world order",
            "Enlil founds the E-kur at Nippur"
        ]
        let byName = Dictionary(uniqueKeysWithValues: events.map { ($0.name, $0) })
        for name in expected {
            guard let event = byName[name] else {
                XCTFail("missing imported event \(name)")
                continue
            }
            XCTAssertNil(event.date.startYear, "\(name) must be undated")
            XCTAssertNil(event.date.endYear, "\(name) must be undated")
            XCTAssertEqual(event.era, "Age of the First Gods", name)
            XCTAssertEqual(event.date.era, "Age of the First Gods", name)
            XCTAssertNotNil(event.eventType, "\(name) must link an existing event type")
        }

        guard let separation = byName["Separation of heaven and earth"] else {
            return XCTFail("missing Separation of heaven and earth")
        }
        XCTAssertEqual(Set(separation.involvedFigures.map(\.name)), ["An", "Enlil"])
        XCTAssertEqual(Set(separation.placeAssociations.compactMap { $0.place?.name }), ["Heaven", "Earth"])

        let stickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        XCTAssertEqual(stickies.filter { $0.text == "IMPORTED — needs review (first gods)" }.count, 6)
    }

    func testFirstGodsEventsImportCitesWorksAndReusesExistingSourceRows() {
        let container = makeContainer()
        let context = container.mainContext
        SeedData.ensureTypesExist(context: context)
        insertFirstGodsFigures(context: context)
        let existingWork = Source(
            name: "Enki and the World Order (t.1.1.3)",
            sourceDescription: "the user's own row"
        )
        context.insert(existingWork)
        try? context.save()

        Migration.ensureFirstGodsEventsExist(context: context)

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let matches = sources.filter { $0.name == "Enki and the World Order (t.1.1.3)" }
        XCTAssertEqual(matches.count, 1, "check-by-name must not duplicate an existing work")
        XCTAssertEqual(matches[0].sourceDescription, "the user's own row", "an existing work's metadata must not be overwritten")

        let hoe = sources.first { $0.name == "The Song of the Hoe (t.5.5.4)" }
        XCTAssertNotNil(hoe, "missing works must be created")
        XCTAssertFalse(hoe?.url.isEmpty ?? true, "created ETCSL works should carry their URL")

        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        XCTAssertEqual(citations.count, 8, "expected 8 citations across the six events, got \(citations.count)")
        XCTAssertTrue(citations.allSatisfy { $0.entityType == .event })
        XCTAssertTrue(citations.allSatisfy { !$0.location.isEmpty })
        XCTAssertEqual(citations.filter { $0.source?.name == "Enki and the World Order (t.1.1.3)" }.count, 2)
        XCTAssertEqual(citations.filter { $0.source?.name == "The Song of the Hoe (t.5.5.4)" }.count, 2)
        XCTAssertTrue(citations.contains { $0.source?.name == "Wikipedia" && $0.linkedEntityName == "Nammu gives birth to heaven and earth" })
    }

    func testFirstGodsEventsImportIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        SeedData.ensureTypesExist(context: context)
        context.insert(Figure(name: "Enlil"))
        try? context.save()

        Migration.ensureFirstGodsEventsExist(context: context)
        let firstEvents = ((try? context.fetch(FetchDescriptor<Event>())) ?? []).count
        let firstCitations = ((try? context.fetch(FetchDescriptor<Citation>())) ?? []).count
        let firstSources = ((try? context.fetch(FetchDescriptor<Source>())) ?? []).count
        XCTAssertEqual(firstEvents, 6, "events must import even when most involved figures are absent")

        Migration.ensureFirstGodsEventsExist(context: context)
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<Event>())) ?? []).count, firstEvents)
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<Citation>())) ?? []).count, firstCitations)
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<Source>())) ?? []).count, firstSources)
    }

    // MARK: - Migration: ensurePunishmentEventTypeAndBindings

    private func insertBindingFixture(context: ModelContext, typeName: String) -> (battle: EventType, azazel: Event, watchers: Event, other: Event) {
        let type = EventType(name: typeName, icon: "shield.righthalf.filled", colorHex: "FF3B30")
        context.insert(type)
        let azazel = Event(name: "The Binding of Azazel")
        let watchers = Event(name: "The Binding of the Watchers")
        let other = Event(name: "The Battle of Qarqar")
        for event in [azazel, watchers, other] {
            context.insert(event)
            type.events.append(event)
        }
        try? context.save()
        return (type, azazel, watchers, other)
    }

    func testPunishmentEventTypeAndBindingsRetypesTheTwoBindingEvents() {
        let container = makeContainer()
        let context = container.mainContext
        let fixture = insertBindingFixture(context: context, typeName: "Battle")

        Migration.ensurePunishmentEventTypeAndBindings(context: context)

        let types = (try? context.fetch(FetchDescriptor<EventType>())) ?? []
        let punishment = types.first { $0.name == "Punishment" }
        XCTAssertNotNil(punishment, "Punishment type must be created")
        XCTAssertEqual(punishment?.icon, "lock.fill")
        XCTAssertEqual(fixture.azazel.eventType?.name, "Punishment")
        XCTAssertEqual(fixture.watchers.eventType?.name, "Punishment")
        XCTAssertEqual(fixture.other.eventType?.name, "Battle", "unrelated battle events must not move")
        XCTAssertFalse(fixture.battle.events.contains { $0 == fixture.azazel }, "the old type must release the retyped event")
        XCTAssertTrue(punishment?.events.contains { $0 == fixture.watchers } == true)
    }

    func testPunishmentMigrationLeavesAUserChosenTypeAlone() {
        let container = makeContainer()
        let context = container.mainContext
        let fixture = insertBindingFixture(context: context, typeName: "Descent")

        Migration.ensurePunishmentEventTypeAndBindings(context: context)

        XCTAssertEqual(fixture.azazel.eventType?.name, "Descent", "a type the user chose must not be overwritten")
        XCTAssertEqual(fixture.watchers.eventType?.name, "Descent")
    }

    func testPunishmentMigrationIsIdempotentAndPreservesExistingType() {
        let container = makeContainer()
        let context = container.mainContext
        let existing = EventType(name: "Punishment", icon: "star", colorHex: "000000")
        context.insert(existing)
        let fixture = insertBindingFixture(context: context, typeName: "Battle")

        Migration.ensurePunishmentEventTypeAndBindings(context: context)
        Migration.ensurePunishmentEventTypeAndBindings(context: context)

        let types = (try? context.fetch(FetchDescriptor<EventType>())) ?? []
        XCTAssertEqual(types.filter { $0.name == "Punishment" }.count, 1, "must reuse, not duplicate, an existing Punishment type")
        XCTAssertEqual(types.first { $0.name == "Punishment" }?.icon, "star", "an existing type's metadata must not be overwritten")
        XCTAssertEqual(fixture.azazel.eventType?.name, "Punishment")
        XCTAssertEqual(fixture.watchers.eventType?.name, "Punishment")
    }
}
