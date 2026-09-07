import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
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

    // MARK: - Collectives

    func testEnsureCollectivesCreatesGroupAndHumanCollectives() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        Migration.ensureCollectives(context: context)

        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        XCTAssertEqual(Set(types.map(\.name)), Set(["Human Collective", "Mixed Collective"]), "collective types created")

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let top = groups.first(where: { $0.name == "Collectives" && $0.parentGroup == nil }) else {
            return XCTFail("Collectives group missing")
        }
        XCTAssertEqual(top.kind, .standard)
        XCTAssertEqual(top.entityType, .figure)
        XCTAssertEqual(top.sortMode, .ordered)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(Set(figures.map(\.name)), Set(["Sumerians", "Akkadians", "Gutians", "Amorites", "Babylonians", "Assyrians", "Elamites", "Hurrians", "Kassites", "Hittites"]))
        for figure in figures {
            XCTAssertEqual(figure.figureType?.name, "Human Collective")
            XCTAssertEqual(figure.gender, .unknown)
        }

        let memberNames = top.sortedAssociations.compactMap { $0.figure?.name }
        XCTAssertEqual(memberNames, ["Sumerians", "Akkadians", "Gutians", "Amorites", "Babylonians", "Assyrians", "Elamites", "Hurrians", "Kassites", "Hittites"], "members in curated order")
    }

    func testEnsureCollectivesFoldsInExistingDivineCollectives() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensureDivineCollectives(context: context)
        try? context.save()

        Migration.ensureCollectives(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let top = groups.first(where: { $0.name == "Collectives" }) else {
            return XCTFail("Collectives group missing")
        }
        let memberNames = Set(top.sortedAssociations.compactMap { $0.figure?.name })
        XCTAssertTrue(memberNames.contains("Anunnaki"), "divine collective folded into group")
        XCTAssertTrue(memberNames.contains("Igigi"), "divine collective folded into group")
        XCTAssertTrue(memberNames.contains("Akkadians"), "human collectives added alongside")
    }

    func testEnsureCollectivesIsIdempotentAndPreservesUserData() {
        let container = makeContainer()
        let context = container.mainContext
        let userType = FigureType(name: "Human Collective", icon: "star", colorHex: "000000")
        context.insert(userType)
        let userAkkadians = Figure(name: "Akkadians", figureType: userType, gender: .unknown, figureDescription: "User's own description")
        context.insert(userAkkadians)
        try? context.save()

        Migration.ensureCollectives(context: context)
        Migration.ensureCollectives(context: context)

        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        XCTAssertEqual(types.count, 2, "no duplicate types")

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let top = groups.first(where: { $0.name == "Collectives" }) else {
            return XCTFail("Collectives group missing")
        }
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let akkadians = figures.first { $0.name == "Akkadians" }
        XCTAssertEqual(akkadians?.figureDescription, "User's own description", "existing figure untouched")
        XCTAssertEqual(akkadians?.figureType?.persistentModelID, userType.persistentModelID, "user's type reused, not replaced")
        XCTAssertEqual(top.sortedAssociations.filter { $0.figure?.name == "Akkadians" }.count, 1, "no duplicate membership across runs")
    }

    func testEnsureCollectiveMembersCreatesFiguresAndLinks() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Old Babylonian Period", orderIndex: 32))
        context.insert(Era(name: "Old Assyrian Period", orderIndex: 31))
        context.insert(Era(name: "Neo-Assyrian Period", orderIndex: 33))
        Migration.ensureCollectives(context: context)
        try? context.save()

        Migration.ensureCollectiveMembers(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertTrue(figures.contains { $0.name == "Sennacherib" }, "Assyrian king created")
        XCTAssertTrue(figures.contains { $0.name == "Samsu-iluna" }, "Babylonian king created")

        guard let assyrians = figures.first(where: { $0.name == "Assyrians" }) else {
            return XCTFail("Assyrians collective missing")
        }
        let memberRels = assyrians.incomingRelationships.filter { $0.relationshipType?.name == "Member of" }
        let memberNames = Set(memberRels.compactMap { $0.fromFigure?.name })
        XCTAssertEqual(memberNames, Set(["Shamshi-Adad I", "Shalmaneser III", "Tiglath-Pileser III", "Sennacherib", "Esarhaddon", "Ashurbanipal"]), "Assyrian members linked")

        let relTypes = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        XCTAssertTrue(relTypes.contains { $0.name == "Member of" }, "Member of relationship type created")

        let sennacherib = figures.first { $0.name == "Sennacherib" }
        XCTAssertNil(sennacherib?.figureType, "individual collective member should not have Human Collective type")
        XCTAssertEqual(sennacherib?.era?.name, "Neo-Assyrian Period", "era linked")
        XCTAssertEqual(sennacherib?.gender, .unknown)
    }

    func testFixHumanCollectiveMemberTypesClearsMembersButPreservesGroups() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensureCollectives(context: context)
        try? context.save()

        Migration.ensureCollectiveMembers(context: context)

        // Simulate the old buggy behavior: assign "Human Collective" to an individual member.
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let humanCollective = figures.compactMap { $0.figureType }.first { $0.name == "Human Collective" }
        guard let humanCollective else { return XCTFail("Human Collective type missing") }
        if let member = figures.first(where: { $0.name == "Ashurbanipal" }) {
            member.figureType = humanCollective
        }
        try? context.save()

        Migration.fixHumanCollectiveMemberTypes(context: context)

        let updated = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let ashurbanipal = updated.first { $0.name == "Ashurbanipal" }
        XCTAssertNil(ashurbanipal?.figureType, "individual member type cleared by corrective migration")

        let assyrians = updated.first { $0.name == "Assyrians" }
        XCTAssertEqual(assyrians?.figureType?.name, "Human Collective", "collective group keeps Human Collective type")
    }

    func testEnsureCollectiveMembersIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensureCollectives(context: context)
        try? context.save()

        Migration.ensureCollectiveMembers(context: context)
        Migration.ensureCollectiveMembers(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let sennacherib = figures.first { $0.name == "Sennacherib" }
        XCTAssertEqual(sennacherib?.outgoingRelationships.count, 1, "no duplicate member relationship across runs")

        let relTypes = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        XCTAssertEqual(relTypes.filter { $0.name == "Member of" }.count, 1, "no duplicate relationship type")
    }

    func testEnsureCollectiveMembersLinksExistingKings() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensureCollectives(context: context)
        let sargon = Figure(name: "Sargon of Akkad", gender: .unknown, figureDescription: "")
        context.insert(sargon)
        let hammurabi = Figure(name: "Hammurabi", gender: .unknown, figureDescription: "")
        context.insert(hammurabi)
        try? context.save()

        Migration.ensureCollectiveMembers(context: context)
        Migration.ensureCollectiveMembers(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let sargonFig = figures.first { $0.name == "Sargon of Akkad" }
        let akkadians = figures.first { $0.name == "Akkadians" }
        let hammurabiFig = figures.first { $0.name == "Hammurabi" }
        let babylonians = figures.first { $0.name == "Babylonians" }
        XCTAssertEqual(sargonFig?.outgoingRelationships.filter { $0.relationshipType?.name == "Member of" && $0.toFigure?.persistentModelID == akkadians?.persistentModelID }.count, 1, "Sargon linked to Akkadians exactly once")
        XCTAssertEqual(hammurabiFig?.outgoingRelationships.filter { $0.relationshipType?.name == "Member of" && $0.toFigure?.persistentModelID == babylonians?.persistentModelID }.count, 1, "Hammurabi linked to Babylonians exactly once")
    }

    func testEnsureCollectiveAlternateNamesAddsAliases() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensureDivineCollectives(context: context)
        Migration.ensureCollectives(context: context)
        try? context.save()

        Migration.ensureCollectiveAlternateNames(context: context)
        Migration.ensureCollectiveAlternateNames(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let akkadians = figures.first { $0.name == "Akkadians" }
        XCTAssertEqual(Set(akkadians?.alternateNames.map(\.name) ?? []), Set(["Akkadeans", "Agadeans"]), "Akkadian aliases added once")

        let amorites = figures.first { $0.name == "Amorites" }
        XCTAssertEqual(Set(amorites?.alternateNames.map(\.name) ?? []), Set(["Amurru", "Martu", "Westerners"]), "Amorite aliases added")

        let hittites = figures.first { $0.name == "Hittites" }
        XCTAssertEqual(Set(hittites?.alternateNames.map(\.name) ?? []), Set(["Hatti", "Nesites"]), "Hittite aliases added")

        let anunnaki = figures.first { $0.name == "Anunnaki" }
        XCTAssertTrue((anunnaki?.alternateNames ?? []).contains { $0.name == "Anunnaku" }, "divine collective alias added")
    }

    func testEnsureCollectiveTerritoryCreatesRolesPlacesAndLinks() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensureCollectives(context: context)
        context.insert(Place(name: "Assur", placeType: nil, modernLocation: "Qal'at Sherqat"))
        context.insert(Place(name: "Nineveh", placeType: nil, modernLocation: "Mosul"))
        try? context.save()

        Migration.ensureCollectiveTerritory(context: context)
        Migration.ensureCollectiveTerritory(context: context)

        let roles = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
        XCTAssertTrue(Set(roles.map(\.name)).isSuperset(of: ["Homeland", "Capital", "Territory"]), "territory roles created once")

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let assyrians = figures.first { $0.name == "Assyrians" }
        let assyrianLinks = assyrians?.placeAssociations ?? []
        XCTAssertEqual(assyrianLinks.filter { $0.place?.name == "Assur" && $0.roleType?.name == "Homeland" }.count, 1, "Assur homeland linked once")
        XCTAssertEqual(assyrianLinks.filter { $0.place?.name == "Nineveh" && $0.roleType?.name == "Capital" }.count, 1, "Nineveh capital linked once")
        XCTAssertEqual(assyrianLinks.count, 3, "no duplicate links across runs")

        let hattusa = places.first { $0.name == "Hattusa" }
        XCTAssertNotNil(hattusa, "missing Hittite capital created")
        XCTAssertEqual(hattusa?.placeType?.name, "City")
        let hittites = figures.first { $0.name == "Hittites" }
        XCTAssertEqual(hittites?.placeAssociations.filter { $0.place?.name == "Hattusa" && $0.roleType?.name == "Capital" }.count, 1, "Hattusa capital linked")
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

    func seedEverydayLifeTypeTables(context: ModelContext) {
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
        XCTAssertEqual(events.count, 9)
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
        XCTAssertEqual(stickies.count, 27, "one sticky on each created figure, place, and event")
        XCTAssertEqual(Set(stickies.map(\.text)), Set(["Import daily life events"]))
        XCTAssertEqual(stickies.filter { $0.figure != nil }.count, 12)
        XCTAssertEqual(stickies.filter { $0.place != nil }.count, 6)
        XCTAssertEqual(stickies.filter { $0.event != nil }.count, 9)
    }

    func testEverydayLifeEpisodesAreIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)

        Migration.ensureEverydayLifeEpisodes(context: context)
        Migration.ensureEverydayLifeEpisodes(context: context)

        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Figure>())) ?? -1, 12)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Event>())) ?? -1, 9)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Place>())) ?? -1, 6)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, 4)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<FigurePlaceAssociation>())) ?? -1, 12)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<StickyNote>())) ?? -1, 27)
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
        XCTAssertEqual(events.count, 9, "eight imports plus the user's own Poor Man of Nippur")
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

    func testEverydayLifeThingsSeedsYaleCulinaryTablets() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)

        Migration.ensureEverydayLifeThings(context: context)

        let things = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        XCTAssertEqual(things.count, 1)
        let yale = things.first
        XCTAssertEqual(yale?.name, "Yale Culinary Tablets")
        XCTAssertEqual(yale?.thingType?.name, "Text")
        XCTAssertEqual(yale?.source, "YBC 4644 et al.; Jean Bottéro, Textes culinaires mésopotamiens")
        XCTAssertTrue(yale?.thingDescription.contains("tuh'u") ?? false)

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertTrue(events.isEmpty, "the tablets are a Thing, never an Event")

        Migration.ensureEverydayLifeThings(context: context)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Thing>())) ?? -1, 1, "idempotent")
    }

    func testExistingYaleEventConvertedToThing() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)

        let event = Event(
            name: "Yale Culinary Tablets",
            eventDescription: "Three Babylonian tablets; the world's oldest surviving recipes.",
            date: MythologicalDate(year: -1730, era: "Old Babylonian Period", isApproximate: true),
            era: "Old Babylonian Period",
            source: "YBC 4644 et al.; Jean Bottéro, Textes culinaires mésopotamiens"
        )
        context.insert(event)
        context.insert(Citation(
            source: nil,
            location: "YBC 4644 et al.",
            note: "note",
            entityType: .event,
            linkedEntityName: "Yale Culinary Tablets"
        ))
        try? context.save()

        Migration.convertYaleCulinaryTabletsEventToThing(context: context)

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertTrue(events.isEmpty, "the imported Event is removed")

        let things = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        XCTAssertEqual(things.count, 1)
        XCTAssertEqual(things.first?.name, "Yale Culinary Tablets")
        XCTAssertEqual(things.first?.thingDescription, "Three Babylonian tablets; the world's oldest surviving recipes.")
        XCTAssertEqual(things.first?.source, "YBC 4644 et al.; Jean Bottéro, Textes culinaires mésopotamiens")
        XCTAssertEqual(things.first?.thingType?.name, "Text")

        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        XCTAssertTrue(citations.isEmpty, "the dangling auto-generated citation is dropped")

        Migration.convertYaleCulinaryTabletsEventToThing(context: context)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Thing>())) ?? -1, 1, "idempotent: no duplicate after the event is gone")
    }

    // MARK: - Lugal-irra & Meslamta-ea split

    func figureByKey(_ context: ModelContext, _ name: String) -> Figure? {
        ((try? context.fetch(FetchDescriptor<Figure>())) ?? []).first {
            DuplicateMerger.normalizationKey($0.name) == DuplicateMerger.normalizationKey(name)
        }
    }

    func deityType(_ context: ModelContext) -> FigureType {
        if let existing = try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate { $0.name == "Deity" })).first {
            return existing
        }
        let created = FigureType(name: "Deity", icon: "star.fill", colorHex: "007AFF")
        context.insert(created)
        return created
    }

    func testSplitLugalIrraMeslamtaeaSplitsPairIntoTwoTwins() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)
        let type = deityType(context)

        context.insert(Figure(name: "Lugalirra", figureType: type, gender: .male, domain: "Underworld",
                              figureDescription: "'Great king' — underworld god, twin brother of Meslamtaea.", source: "ORACC AMGG"))
        context.insert(Figure(name: "Lugal-irra and Meslamta-ea", figureType: type, gender: .male,
                              domain: "Twin underworld gods guarding doorways; the constellation Gemini",
                              figureDescription: "Lugal-irra and Meslamta-ea are a set of twin gods who were worshipped in Kisiga."))
        try? context.save()

        Migration.splitLugalIrraMeslamtaea(context: context)

        XCTAssertNil(figureByKey(context, "Lugal-irra and Meslamta-ea"), "merged pair row is removed")
        XCTAssertNotNil(figureByKey(context, "Lugalirra"), "individual twin kept")
        let meslam = figureByKey(context, "Meslamta-ea")
        XCTAssertNotNil(meslam, "individual twin created")
        XCTAssertEqual(meslam?.gender, .male)
        XCTAssertEqual(meslam?.figureType?.name, "Deity")
        XCTAssertTrue(meslam?.figureDescription.contains("gatekeepers") ?? false)
        let alts = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertTrue(alts.contains { $0.figure === meslam && $0.name == "Meslamtaea" },
                      "Meslamtaea spelling variant attached")

        let twinType = (try? context.fetch(FetchDescriptor<RelationshipType>()))?.first { $0.name == "Twin" }
        XCTAssertNotNil(twinType, "Twin relationship type created")
        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let lugalirra = figureByKey(context, "Lugalirra")!
        XCTAssertEqual(edges.count, 1, "single canonical edge, not a mirrored pair")
        XCTAssertEqual(edges.first?.fromFigure, lugalirra, "canonical direction Lugalirra → Meslamta-ea")
        XCTAssertEqual(edges.first?.toFigure, meslam)

        Migration.splitLugalIrraMeslamtaea(context: context)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, 1, "idempotent: no extra twin edges")
    }

    func testSplitLugalIrraMeslamtaeaCollapsesExistingMirroredPair() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)
        let type = deityType(context)
        let pair = Figure(name: "Lugal-irra and Meslamta-ea", figureType: type, gender: .male,
                          domain: "Twin underworld gods", figureDescription: "pair")
        context.insert(pair)
        let lugalirra = Figure(name: "Lugalirra", figureType: type, gender: .male, domain: "Underworld")
        context.insert(lugalirra)
        let twinType = RelationshipType(name: "Twin", icon: "person.2.fill", colorHex: "FF9500", category: "sibling", reverseName: "Twin")
        context.insert(twinType)
        let meslam = Figure(name: "Meslamta-ea", figureType: type, gender: .male, domain: "Underworld")
        context.insert(meslam)
        context.insert(Relationship(fromFigure: lugalirra, toFigure: meslam, relationshipType: twinType))
        context.insert(Relationship(fromFigure: meslam, toFigure: lugalirra, relationshipType: twinType))
        try? context.save()

        Migration.splitLugalIrraMeslamtaea(context: context)

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(edges.count, 1, "mirrored pair collapsed to a single canonical edge")
        XCTAssertEqual(edges.first?.fromFigure, lugalirra)
        XCTAssertEqual(edges.first?.toFigure, meslam)
    }

    func testSplitLugalIrraMeslamtaeaCreatesMissingLugalirra() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)
        let type = deityType(context)

        context.insert(Figure(name: "Lugal-irra and Meslamta-ea", figureType: type, gender: .male,
                              domain: "Twin underworld gods", figureDescription: "pair"))
        try? context.save()

        Migration.splitLugalIrraMeslamtaea(context: context)

        let lugalirra = figureByKey(context, "Lugalirra")
        XCTAssertNotNil(lugalirra)
        XCTAssertTrue(lugalirra?.figureDescription.contains("'Great king'") ?? false)
        let alts = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertTrue(alts.contains { $0.figure === lugalirra && $0.name == "Lugal-irra" },
                      "hyphenated spelling variant attached")
    }

    func testSplitLugalIrraMeslamtaeaLinksExistingIndividualsWithoutPair() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)
        let type = deityType(context)

        context.insert(Figure(name: "Lugalirra", figureType: type, gender: .male, domain: "Underworld"))
        context.insert(Figure(name: "Meslamta-ea", figureType: type, gender: .male, domain: "Underworld"))
        try? context.save()

        Migration.splitLugalIrraMeslamtaea(context: context)

        XCTAssertNil(figureByKey(context, "Lugal-irra and Meslamta-ea"))
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Figure>())) ?? -1, 2, "no new figures")
        let twinType = (try? context.fetch(FetchDescriptor<RelationshipType>()))?.first { $0.name == "Twin" }
        XCTAssertNotNil(twinType)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, 1,
                       "single canonical twin edge established")
    }

    func testSplitEnkiNinkiSplitsPairIntoTwoFigures() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)
        let primordial = (try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate { $0.name == "Primordial" })))?.first
        XCTAssertNotNil(primordial)

        let pair = Figure(name: "Enki and Ninki", figureType: primordial, gender: .unknown,
                          domain: "Primordial pair of the Abzu; ancestors of Enlil",
                          figureDescription: "Enki and Ninki were two primordial beings regarded as the first generation among the ancestors of Enlil.")
        context.insert(pair)
        for name in ["primordial", "pair", "ancestors", "enlil", "abzu"] {
            let tag = Tag(name: name)
            context.insert(tag)
            pair.tags.append(tag)
        }
        let pantheon = Pantheon(name: "Mesopotamian")
        context.insert(pantheon)
        pair.pantheons.append(pantheon)
        context.insert(AlternateName(figure: pair, name: "Enki-Ninki", tradition: .sumerian, nameType: .spelling, note: "Hyphenated form of the pair"))
        try? context.save()

        Migration.splitEnkiNinkiPair(context: context)

        XCTAssertNil(figureByKey(context, "Enki and Ninki"), "merged pair row removed")
        let enki = figureByKey(context, "Enki (Primordial)")
        let ninki = figureByKey(context, "Ninki")
        XCTAssertNotNil(enki, "primordial Enki created")
        XCTAssertNotNil(ninki, "Ninki created")
        XCTAssertEqual(enki?.gender, .male)
        XCTAssertEqual(ninki?.gender, .female)
        XCTAssertEqual(enki?.figureType?.name, "Primordial")
        XCTAssertEqual(ninki?.figureType?.name, "Primordial")

        let alts = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        XCTAssertTrue(alts.isEmpty, "hyphenated pair alternate name dropped")

        let spouseType = (try? context.fetch(FetchDescriptor<RelationshipType>()))?.first { $0.name == "Spouse" }
        XCTAssertNotNil(spouseType)
        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(edges.count, 2, "both spouse directions established")
        let enkiEdge = edges.filter { $0.fromFigure?.persistentModelID == enki?.persistentModelID }
        let ninkiEdge = edges.filter { $0.fromFigure?.persistentModelID == ninki?.persistentModelID }
        XCTAssertEqual(enkiEdge.count, 1)
        XCTAssertEqual(ninkiEdge.count, 1)

        let sharedTagNames = ["primordial", "ancestors", "enlil", "abzu"]
        for figure in [enki, ninki] {
            let tagNames = Set((figure?.tags ?? []).map { $0.name.lowercased() })
            for name in sharedTagNames { XCTAssertTrue(tagNames.contains(name), "\(name) re-tagged on \(figure?.name ?? "?")") }
            XCTAssertFalse(tagNames.contains("pair"), "'pair' tag not carried onto individuals")
            XCTAssertTrue((figure?.pantheons ?? []).contains { $0.name == "Mesopotamian" },
                          "Mesopotamian pantheon carried onto \(figure?.name ?? "?")")
        }
    }

    func testSplitEnkiNinkiIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)
        let primordial = (try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate { $0.name == "Primordial" })))?.first

        context.insert(Figure(name: "Enki and Ninki", figureType: primordial, gender: .unknown,
                              domain: "Primordial pair of the Abzu; ancestors of Enlil",
                              figureDescription: "pair"))
        try? context.save()

        Migration.splitEnkiNinkiPair(context: context)
        Migration.splitEnkiNinkiPair(context: context)

        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Figure>())) ?? -1, 2, "no extra figures on re-run")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, 2, "no extra spouse edges on re-run")
    }

    func testSplitEnkiNinkiLinksExistingIndividualsWithoutPair() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)
        let primordial = (try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate { $0.name == "Primordial" })))?.first
        XCTAssertNotNil(primordial)

        context.insert(Figure(name: "Enki (Primordial)", figureType: primordial, gender: .male, domain: "Abzu"))
        context.insert(Figure(name: "Ninki", figureType: primordial, gender: .female, domain: "Abzu"))
        try? context.save()

        Migration.splitEnkiNinkiPair(context: context)

        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Figure>())) ?? -1, 2, "no new figures when pair absent")
        let spouseType = (try? context.fetch(FetchDescriptor<RelationshipType>()))?.first { $0.name == "Spouse" }
        XCTAssertNotNil(spouseType)
        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(edges.count, 2, "both spouse directions established between split figures")
    }

    func testSplitEnkiNinkiSkipsWhenNothingPresent() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        seedEverydayLifeTypeTables(context: context)

        Migration.splitEnkiNinkiPair(context: context)

        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Figure>())) ?? -1, 0)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, 0)
    }

}
