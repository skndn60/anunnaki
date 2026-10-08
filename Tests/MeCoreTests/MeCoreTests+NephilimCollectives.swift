import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
    // MARK: - Figures and type

    /// "Nephilim" is the general name for the antediluvian giants, so it is modelled as the
    /// umbrella collective — but the store's own "Nephilim" type holds the named giants as
    /// well, and those are persons. A type cannot be both, so the peoples move to a collective
    /// type of their own and the individuals stay where the user put them.
    func testEnsureNephilimCollectivesSplitsPeoplesFromIndividuals() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureFigureTypeCategories(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(
            figures.map(\.name).sorted(),
            ["Anakim", "Emim", "Gibborim", "Hahyah", "Nephilim", "Og of Bashan", "Ohyah", "Rephaim", "Zuzim"]
        )

        let peoples = ["Nephilim", "Anakim", "Rephaim", "Emim", "Zuzim"]
        for name in peoples {
            let figure = figures.first { $0.name == name }
            XCTAssertEqual(figure?.figureType?.name, "Mythical Collective", "\(name) is a people, on the collective type")
            XCTAssertTrue(figure?.isCollective == true, "\(name) is a collective, so it has members and not parents")
        }
        for name in ["Hahyah", "Ohyah", "Og of Bashan"] {
            let figure = figures.first { $0.name == name }
            XCTAssertEqual(figure?.figureType?.name, "Nephilim", "\(name) is a person, on the user's own type")
            XCTAssertTrue(figure?.isCollective == false, "\(name) keeps his parent slots")
            XCTAssertEqual(figure?.gender, .male)
        }
        // gibborim is a common noun, not a people, so it does not belong on the collective
        // type: a collective is defined by having members instead of parents, and a word has
        // neither. It is kept as a figure so it stays findable.
        let gibborim = figures.first { $0.name == "Gibborim" }
        XCTAssertEqual(gibborim?.figureType?.name, "Nephilim")
        XCTAssertTrue(gibborim?.isCollective == false, "gibborim is an epithet for the Nephilim, not a tribe")
        XCTAssertFalse(figures.allSatisfy { $0.figureDescription.isEmpty }, "every seeded figure carries a description")
    }

    /// The regression this whole split exists for. The store's "Nephilim" type carries three
    /// named giants, so categorising it would give each of them a membership strip and take
    /// away their parent slots — the category error in the opposite direction from the one
    /// the categorisation was meant to fix.
    func testEnsureFigureTypeCategoriesNeverCategorisesTheNephilimType() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let type = FigureType(name: "Nephilim", icon: "person.3.fill", colorHex: "FF2600")
        context.insert(type)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureFigureTypeCategories(context: context)

        XCTAssertNil(type.category, "a type holding named giants is not a collective")
        XCTAssertEqual(
            Set(type.figures.map(\.name)),
            ["Hahyah", "Ohyah", "Og of Bashan", "Gibborim"],
            "the peoples are moved off it, leaving only persons and the one word that is not a people"
        )
    }

    /// The peoples were filed on the "Nephilim" type alongside the three named giants. Moving
    /// them off that type is the correction, and it is the only way they can gain the roll
    /// that `isCollective` reads.
    func testEnsureNephilimCollectivesMovesPeoplesOffTheNamedGiantsType() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let type = FigureType(name: "Nephilim", icon: "person.3.fill", colorHex: "FF2600")
        let anakim = Figure(name: "Anakim", figureType: type, gender: .unknown)
        let ohyah = Figure(name: "Ohyah", figureType: type, gender: .male)
        context.insert(type)
        context.insert(anakim)
        context.insert(ohyah)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureFigureTypeCategories(context: context)

        XCTAssertEqual(anakim.figureType?.name, "Mythical Collective", "a people cannot stay on a type of persons")
        XCTAssertTrue(anakim.isCollective)
        XCTAssertEqual(ohyah.figureType?.name, "Nephilim", "a person stays where the user filed him")
        XCTAssertFalse(ohyah.isCollective)
    }

    /// The umbrella was typed "Divine Collective" by hand, which is factually wrong and would
    /// render a father/mother lineage strip on the Nephilim. It is moved onto the collective
    /// type — but only off a collective type, so a type the user chose deliberately on some
    /// other basis is never clobbered.
    func testEnsureNephilimCollectivesMovesOffACollectiveTypeOnly() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let divine = FigureType(name: "Divine Collective", icon: "person.3.fill", colorHex: "FFD478", category: "collective")
        let semiDivine = FigureType(name: "Semi-Divine", icon: "star.leadinghalf.filled", colorHex: "FF9500")
        let umbrella = Figure(name: "Nephilim", figureType: divine, gender: .unknown)
        let handPicked = Figure(name: "Rephaim", figureType: semiDivine, gender: .unknown)
        context.insert(divine)
        context.insert(semiDivine)
        context.insert(umbrella)
        context.insert(handPicked)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)

        XCTAssertEqual(umbrella.figureType?.name, "Mythical Collective", "the Nephilim are not a divine council")
        XCTAssertEqual(handPicked.figureType?.name, "Semi-Divine", "a non-collective type the user chose is not overridden")
    }

    /// The store's own "Nephilim" type carries a typo'd SF Symbol, which renders as a missing
    /// glyph wherever the type is shown. Only the icon is repaired; the colour is the user's.
    func testEnsureNephilimCollectivesRepairsTheTypeIconTypo() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let type = FigureType(name: "Nephilim", icon: "peron.3", colorHex: "FFD478")
        context.insert(type)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)

        XCTAssertEqual(type.icon, "person.3.fill")
        XCTAssertEqual(type.colorHex, "FFD478", "the colour is left alone")
    }

    /// Filling a field the user has already written is a data change, not a repair.
    func testEnsureNephilimCollectivesNeverOverwritesUserText() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let existing = Figure(name: "Anakim", figureType: nil, gender: .unknown, figureDescription: "My own note about the Anakim.")
        context.insert(existing)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)

        XCTAssertEqual(existing.figureDescription, "My own note about the Anakim.")
        XCTAssertEqual(existing.title, "The Anakim of the Canaanite Hill Country", "an empty title is still filled")
    }

    /// The flood is the dividing line in this material, so the era is seeded per figure. Og of
    /// Bashan and the Transjordan peoples outlive the antediluvian age — the spies meet the
    /// Anakim in the wilderness, several centuries on — and Rephaim is the one figure whose
    /// survival is the whole point: every Rephaim in the Hebrew Bible is post-flood. Dating
    /// Rephaim before the flood was a mistake, and this migration also corrects the value it
    /// wrote itself earlier, without touching an era the user chose.
    func testEnsureNephilimCollectivesDatesEachFigureAcrossTheFlood() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let watch = Era(name: "Age of the Watchers", eraDescription: "")
        let postFlood = Era(name: "Post-Flood Kingdoms", eraDescription: "")
        context.insert(watch)
        context.insert(postFlood)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        func figure(_ name: String) -> Figure? { figures.first { $0.name == name } }
        for name in ["Nephilim", "Gibborim", "Hahyah", "Ohyah"] {
            XCTAssertEqual(figure(name)?.era?.name, "Age of the Watchers", "\(name) is ended by the flood")
            XCTAssertEqual(figure(name)?.source, "Book of Enoch (1 Enoch)", "\(name) is told of in 1 Enoch")
        }
        XCTAssertEqual(figure("Rephaim")?.era?.name, "Post-Flood Kingdoms",
                       "the Repha'îm are a post-flood category — they survive the flood")
        XCTAssertEqual(figure("Rephaim")?.source, Migration.bibleSourceName,
                       "the Enochic usage stays a citation, so Rephaim leaves the Enoch view")
        for name in ["Anakim", "Emim", "Zuzim", "Og of Bashan"] {
            XCTAssertNil(figure(name)?.era, "\(name) is Hebrew Bible only and is not dated to an era the store has")
            XCTAssertEqual(figure(name)?.source, Migration.bibleSourceName,
                           "\(name) must not claim a source it does not come from — EnochView selects on this string")
        }
    }

    /// The `Figure.source` mirror had drifted from the `Source` row it points at: this
    /// migration wrote the label "Hebrew Bible" while the work is one row named `Bible`. The
    /// string is a display mirror and never the join, so the drift was invisible to every
    /// foreign key in the store. It is corrected only when it still holds what this migration
    /// wrote, and the correction is what keeps `EnochView`'s `contains("Enoch")` test true
    /// for the Enochic figures and false for these.
    func testEnsureNephilimCollectivesBringsTheSourceMirrorBackInLine() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        // All three exist before the run, so there is exactly one figure per name and
        // `first { $0.name == … }` cannot match a row this migration went on to create.
        let drifted = Figure(name: "Anakim", title: "", figureDescription: "a user description")
        drifted.source = "Hebrew Bible"
        context.insert(drifted)

        let correct = Figure(name: "Nephilim", title: "", figureDescription: "a user description")
        correct.source = "Book of Enoch (1 Enoch)"
        context.insert(correct)

        let own = Figure(name: "Emim", title: "", figureDescription: "a user description")
        own.source = "my own note about the Moabites"
        context.insert(own)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertEqual(figures.first { $0.name == "Anakim" }?.source, Migration.bibleSourceName,
                       "a value this migration wrote is corrected to the one Source row")
        XCTAssertEqual(figures.first { $0.name == "Nephilim" }?.source, "Book of Enoch (1 Enoch)",
                       "a source that is already right is left alone")
        XCTAssertEqual(figures.first { $0.name == "Emim" }?.source, "my own note about the Moabites",
                       "a user's own text in this field is never overwritten")
    }

    /// The only era this migration is allowed to take back is the one it wrote itself. An era
    /// the user set by hand is never overwritten, which is what makes the correction above safe.
    func testEnsureNephilimCollectivesCorrectsItsOwnEraButNotTheUsers() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let watch = Era(name: "Age of the Watchers", eraDescription: "")
        let postFlood = Era(name: "Post-Flood Kingdoms", eraDescription: "")
        let bronzeAge = Era(name: "Late Bronze Age", eraDescription: "")
        context.insert(watch)
        context.insert(postFlood)
        context.insert(bronzeAge)
        let rephaim = Figure(name: "Rephaim", figureType: nil, gender: .unknown)
        rephaim.era = watch
        let handPicked = Figure(name: "Anakim", figureType: nil, gender: .unknown)
        handPicked.era = bronzeAge
        context.insert(rephaim)
        context.insert(handPicked)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)

        XCTAssertEqual(rephaim.era?.name, "Post-Flood Kingdoms", "the pre-flood value this migration wrote is corrected")
        XCTAssertEqual(handPicked.era?.name, "Late Bronze Age", "an era the user chose is not touched")
    }

    // MARK: - Relations

    /// The hierarchy the Hebrew Bible gives, which is not the one the Sephardic tradition and
    /// 1 Enoch give: the Repha'îm are a category of Transjordan peoples with a real roll
    /// (Deut 2:11, 2:20, 3:11), and the Nephilim keep the one contested edge Num 13:33 makes.
    func testEnsureNephilimRelationsRecordsTheRephaimRollAndOneContestedEdge() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        Migration.ensureRelationTypesExist(context: context)
        Migration.ensureCollectiveMembers(context: context)
        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimCitations(context: context)
        Migration.ensureNephilimRelations(context: context)
        Migration.ensureFigureTypeCategories(context: context)
        try? context.save()

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let nephilim = figures.first { $0.name == "Nephilim" }
        let rephaim = figures.first { $0.name == "Rephaim" }
        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertNotNil(nephilim)
        XCTAssertNotNil(rephaim)

        XCTAssertEqual(
            Set(collectiveMembers(of: rephaim!, from: rels).map(\.name)),
            ["Anakim", "Emim", "Zuzim", "Og of Bashan"],
            "Deut 2:11 counts the Emim with the Repha'îm, 2:20 does the same for Ammon's Zamzummim, 3:11 makes Og the remnant"
        )
        XCTAssertEqual(
            collectiveMembers(of: nephilim!, from: rels).map(\.name), ["Anakim"],
            "Numbers 13:33 is the only text that puts anyone inside the Nephilim, and it is the one the Septuagint omits"
        )

        XCTAssertEqual(rels.filter { $0.relationshipType?.name == "Local form of" }.count, 0,
                       "no Torah text equates the Repha'îm with the Nephilim, so no synonymy edge is asserted")
    }

    /// The Emim and the Zuzim were the misreading this change corrects. Deuteronomy 2:11 and
    /// 2:20 do not merely set them beside the Repha'îm, they count them with them; an earlier
    /// build of this migration read them as deliberately unlinked and said so in a sticky.
    func testEnsureNephilimRelationsCountsEmimAndZuzimWithTheRephaim() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        Migration.ensureRelationTypesExist(context: context)
        Migration.ensureCollectiveMembers(context: context)
        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimCitations(context: context)
        Migration.ensureNephilimRelations(context: context)
        Migration.ensureNephilimGroup(context: context)
        Migration.ensureFigureTypeCategories(context: context)
        try? context.save()

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let nephilim = figures.first { $0.name == "Nephilim" }!
        let rephaim = figures.first { $0.name == "Rephaim" }!
        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        for name in ["Emim", "Zuzim"] {
            let figure = figures.first { $0.name == name }!
            XCTAssertTrue(
                figure.outgoingRelationships.allSatisfy { $0.toFigure?.persistentModelID != nephilim.persistentModelID },
                "\(name) is counted with the Repha'îm, not with the antediluvian generation"
            )
            XCTAssertTrue(
                figure.outgoingRelationships.contains { $0.toFigure?.persistentModelID == rephaim.persistentModelID },
                "\(name) is a member of the Repha'îm on the strength of Deuteronomy"
            )
        }
        for name in ["Hahyah", "Ohyah"] {
            let figure = figures.first { $0.name == name }!
            XCTAssertTrue(
                figure.outgoingRelationships.allSatisfy { $0.toFigure?.persistentModelID != nephilim.persistentModelID },
                "\(name) is a person named by 1 Enoch, and the Enochic lists give no membership"
            )
        }

        let stickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        for name in ["Emim", "Zuzim"] {
            let sticky = stickies.first { $0.figure?.name == name }
            XCTAssertNotNil(sticky, "\(name) is told that the earlier reading was corrected")
            XCTAssertFalse(sticky?.text.contains("on purpose") == true,
                           "the old sticky claimed the omission was deliberate, which is no longer the model")
        }
    }

    /// Deuteronomy 3:11 — "behold, this is the remnant of the Rephaim" — is the one verse
    /// that puts a person inside a people's roll, so it is the one membership that is not a
    /// peoples-to-umbrella edge.
    func testEnsureNephilimRelationsLinksOgAsAMemberOfTheRephaim() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        Migration.ensureRelationTypesExist(context: context)
        Migration.ensureCollectiveMembers(context: context)
        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimCitations(context: context)
        Migration.ensureNephilimRelations(context: context)
        Migration.ensureFigureTypeCategories(context: context)
        try? context.save()

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let rephaim = figures.first { $0.name == "Rephaim" }!
        let og = figures.first { $0.name == "Og of Bashan" }!
        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []

        XCTAssertEqual(
            Set(collectiveMembers(of: rephaim, from: rels).map(\.name)),
            ["Anakim", "Emim", "Zuzim", "Og of Bashan"],
            "Og is one of four: the Repha'îm roll is built from the Deuteronomic notes, not from one verse"
        )
        let membership = og.outgoingRelationships.first { $0.relationshipType?.name == "Member of" }
        XCTAssertEqual(membership?.source, "Deuteronomy 3:11")
        XCTAssertEqual(membership?.sourceRef?.name, "Bible", "attributed through the key, not a string")
    }

    /// The membership direction is what makes the member roll work at all, and
    /// `RelationshipFormView` refuses to write it backwards.
    func testEnsureNephilimRelationsWritesMembershipMemberToCollective() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        Migration.ensureCollectiveMembers(context: context)
        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimCitations(context: context)
        Migration.ensureNephilimRelations(context: context)
        Migration.ensureFigureTypeCategories(context: context)
        try? context.save()

        let rels = (try? context.fetch(FetchDescriptor<Relationship>()))?
            .filter { $0.relationshipType?.name == "Member of" } ?? []
        // The Anakim are a member twice over — the Repha'îm on Deuteronomy, the Nephilim on
        // Numbers 13:33 — and both rows must point at a collective, or the form would refuse
        // to let the user draw the second one.
        let anakimMemberships = rels.filter { $0.fromFigure?.name == "Anakim" }
        XCTAssertEqual(Set(anakimMemberships.compactMap { $0.toFigure?.name }), ["Rephaim", "Nephilim"])
        XCTAssertTrue(anakimMemberships.allSatisfy { $0.toFigure?.isCollective == true },
                      "every membership points at a collective, so the form would accept the row")
        XCTAssertTrue(anakimMemberships.allSatisfy { $0.toFigure?.persistentModelID != $0.fromFigure?.persistentModelID },
                      "a collective is never its own member")
    }

    // MARK: - The flood

    /// Two flood events sit in the store and they are not the same story. "The great Flood" is
    /// the Sumerian one — Enlil, Enki, Ziusudra's ark — and says nothing about giants;
    /// "The Deluge Judgment" is 1 Enoch 10 and is the judgment on the Watchers' corruption.
    /// Anchoring the Nephilim to the wrong one would be a category error, so the migration
    /// uses only the Enochic event and the test pins which one.
    func testEnsureNephilimFloodUsesTheEnochicDelugeNotTheSumerianFlood() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let sumerian = Event(name: "The great Flood", eventDescription: "Enlil decreed the destruction of mankind by flood.")
        let enochic = Event(name: "The Deluge Judgment", eventDescription: "The flood as the judgment for the corruption of the Watchers and the Nephilim.")
        context.insert(sumerian)
        context.insert(enochic)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimFlood(context: context)

        XCTAssertEqual(sumerian.figureAssociations?.count ?? 0, 0, "the Sumerian flood is not about giants")
        XCTAssertEqual(enochic.figureAssociations?.count ?? 0, 5)
    }

    /// The point the whole linkage exists for: the flood is what separates the generation from
    /// its survivors, and the roll of roles has to say which is which.
    func testEnsureNephilimFloodRecordsDestroyedAndSurvived() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        context.insert(Event(name: "The Deluge Judgment", eventDescription: ""))
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimFlood(context: context)

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let deluge = events.first { $0.name == "The Deluge Judgment" }!
        func role(_ figure: String) -> String? {
            deluge.figureAssociations?.first { $0.figure?.name == figure }?.roleType?.name
        }
        for name in ["Nephilim", "Hahyah", "Ohyah"] {
            XCTAssertEqual(role(name), "destroyed by", "\(name) is ended by the flood")
        }
        XCTAssertNil(role("Gibborim"), "gibborim is an epithet for the Nephilim, so a second row would count one people twice")
        for name in ["Rephaim", "Og of Bashan"] {
            XCTAssertEqual(role(name), "survived", "\(name) is the post-flood remnant")
        }

        let roles = (try? context.fetch(FetchDescriptor<EventFigureRoleType>())) ?? []
        XCTAssertEqual(Set(roles.map(\.name)), ["destroyed by", "survived"],
                       "the store had no event-figure role vocabulary at all")
        XCTAssertTrue(roles.allSatisfy { $0.reverseName != nil },
                      "a role with a reverse name reads correctly from the event's side too")
    }

    /// The association helper dedupes, so a second launch adds nothing.
    func testEnsureNephilimFloodIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        context.insert(Event(name: "The Deluge Judgment", eventDescription: ""))
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimFlood(context: context)
        Migration.ensureNephilimFlood(context: context)

        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<EventFigureAssociation>())) ?? -1, 5)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<EventFigureRoleType>())) ?? -1, 2)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<StickyNote>())) ?? -1, 1)
    }

    /// A store whose flood event was renamed out of recognition gets no links rather than links
    /// to whichever flood event happens to be lying around.
    func testEnsureNephilimFloodDoesNothingWithoutItsEvent() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        context.insert(Event(name: "A Rainfall", eventDescription: ""))
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimFlood(context: context)

        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<EventFigureAssociation>())) ?? -1, 0)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<EventFigureRoleType>())) ?? -1, 0)
    }

    // MARK: - Citations, group, idempotence

    func testEnsureNephilimCitationsCreatesSourcesAndCitesEachFigure() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let enoch = Source(name: "Book of Enoch (1 Enoch)", sourceType: .ancientText)
        let jubilees = Source(name: "Book of Jubilees", sourceType: .ancientText)
        context.insert(enoch)
        context.insert(jubilees)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimCitations(context: context)
        Migration.ensureNephilimRelations(context: context)

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(sources.filter { $0.name == "Bible" }.count, 1,
                       "one row for the whole work, cited per verse rather than duplicated per verse")
        XCTAssertFalse(sources.contains { Migration.isPerVerseBibleSourceName($0.name) },
                       "a verse is a location in a citation, not a source of its own")
        XCTAssertEqual(sources.count, 3, "the Bible, 1 Enoch and Jubilees")

        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        let cited = Set(citations.map(\.linkedEntityName))
        XCTAssertTrue(cited.isSuperset(of: [
            "Nephilim", "Anakim", "Rephaim", "Gibborim", "Emim", "Zuzim", "Hahyah", "Ohyah", "Og of Bashan"
        ]))
        for citation in citations {
            XCTAssertEqual(citation.entityType, .figure, "entityType is the raw value 'Figure', not 'figure'")
            XCTAssertNotNil(citation.source, "a citation is attributed through the source key, never a string")
        }
    }

    /// Only what the Enochic books actually name goes in a section of 1 Enoch. The Transjordan
    /// material — Anakim, Emim, Zuzim, Og — is Hebrew Bible only, and filing it under Enoch
    /// would assert a source it does not come from.
    func testEnsureNephilimGroupAddsTheEnochicFiguresOnly() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let enoch = FigureGroup(name: "The Book of Enoch", groupDescription: "", icon: "book", colorHex: "FBBF24", kind: .enoch)
        context.insert(enoch)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimGroup(context: context)

        let subgroup = (try? context.fetch(FetchDescriptor<FigureGroup>()))?
            .first { $0.name == "Children of the Watchers" }
        XCTAssertNotNil(subgroup, "found by kind, not by the name, which the store and the seeder spell differently")
        XCTAssertEqual(subgroup?.parentGroup?.name, "The Book of Enoch")
        XCTAssertEqual(
            Set(subgroup?.figureAssociations.compactMap { $0.figure?.name } ?? []),
            ["Nephilim", "Hahyah", "Ohyah"],
            "the Repha'îm are a post-flood people and gibborim is a word, so neither is a child of the Watchers"
        )
        for name in ["Og of Bashan", "Rephaim", "Anakim", "Emim", "Zuzim"] {
            XCTAssertFalse(subgroup?.figureAssociations.contains { $0.figure?.name == name } ?? true,
                           "\(name) is not Enochic material")
        }
    }

    func testEnsureNephilimGroupAddsReviewNotes() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let enoch = FigureGroup(name: "The Book of Enoch", groupDescription: "", icon: "book", colorHex: "FBBF24", kind: .enoch)
        context.insert(enoch)
        try? context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimGroup(context: context)

        let stickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        XCTAssertEqual(stickies.count, 12,
                       "eight decisions about the model, plus one per figure whose own description you wrote and which now describes the old model")
        XCTAssertTrue(stickies.allSatisfy { $0.text.hasPrefix(Migration.nephilimStickyPrefix) })
    }

    /// A deleted sticky records a dismissal so the migration does not put it back.
    func testEnsureNephilimGroupHonoursADismissedReviewNote() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        let enoch = FigureGroup(name: "The Book of Enoch", groupDescription: "", icon: "book", colorHex: "FBBF24", kind: .enoch)
        context.insert(enoch)
        try? context.save()
        Migration.ensureNephilimCollectives(context: context)

        let nephilim = (try? context.fetch(FetchDescriptor<Figure>()))?.first { $0.name == "Nephilim" }
        let key = DuplicateMerger.normalizationKey(nephilim?.name ?? "Nephilim")
        context.insert(StickyDismissal(textPrefix: Migration.nephilimStickyPrefix, entityKey: key))
        try? context.save()

        Migration.ensureNephilimGroup(context: context)

        let stickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        XCTAssertTrue(stickies.allSatisfy { $0.figure?.name != "Nephilim" }, "the dismissed note is not recreated")
    }

    /// Two launches must not double anything: the chain runs in full on every start.
    func testNephilimChainIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        Migration.ensureRelationTypesExist(context: context)
        Migration.ensureDivineCollectives(context: context)
        Migration.ensureCollectiveMembers(context: context)

        func runChain() {
            Migration.ensureNephilimCollectives(context: context)
            Migration.ensureNephilimCitations(context: context)
            Migration.ensureNephilimRelations(context: context)
            Migration.ensureNephilimFlood(context: context)
            Migration.ensureNephilimGroup(context: context)
            Migration.ensureFigureTypeCategories(context: context)
        }
        runChain()
        runChain()

        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<FigureType>())) ?? -1, 3,
                       "the collective type, the named-giants type, and Divine Collective")
        let seeded = ((try? context.fetch(FetchDescriptor<Figure>())) ?? [])
            .filter { ["Nephilim", "Anakim", "Rephaim", "Gibborim", "Emim", "Zuzim", "Hahyah", "Ohyah", "Og of Bashan"].contains($0.name) }
        XCTAssertEqual(seeded.count, 9, "the divine-collective seed brings its own figures; only this set is counted")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, 5,
                       "four members of the Repha'îm, plus the one contested Anakim edge into the Nephilim")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Source>())) ?? -1, 1, "the Bible, as one work")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<StickyNote>())) ?? -1, 12)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<AlternateName>())) ?? -1, 4,
                       "two spellings of the names, the gibborim epithet, and the Septuagint's gigantes")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Citation>())) ?? -1, 12)
    }

    // MARK: - Withdrawing the old synonymy edges

    /// The only deletion this migration performs, so it gets the most careful test there is.
    /// A store that ran the earlier build carries two `Local form of` edges pointing at the
    /// Nephilim; they assert an equivalence no Torah text makes and they are withdrawn. The
    /// test builds that old shape by hand, so it does not depend on the earlier build still
    /// existing to be reproduced.
    func testEnsureNephilimRelationsWithdrawsTheSynonymyEdgesItSeeded() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        Migration.ensureRelationTypesExist(context: context)
        Migration.ensureCollectiveMembers(context: context)
        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimCitations(context: context)
        try? context.save()

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let nephilim = figures.first { $0.name == "Nephilim" }!
        // The earlier build created this type; this one does not, because it no longer writes
        // synonymy edges at all. A store that ran the earlier build still has it.
        let localFormOf = RelationshipType(
            name: "Local form of", icon: "magnifyingglass.circle", colorHex: "7980FF",
            category: "social", reverseName: "General form of"
        )
        context.insert(localFormOf)
        let bible = (try? context.fetch(FetchDescriptor<Source>()))?
            .first { $0.name == Migration.bibleSourceName }!

        // Exactly the shape the earlier build wrote.
        for name in ["Rephaim", "Gibborim"] {
            let figure = figures.first { $0.name == name }!
            context.insert(Relationship(
                fromFigure: figure, toFigure: nephilim, relationshipType: localFormOf,
                source: "Deuteronomy 3:11", sourceRef: bible
            ))
        }
        // And one the user drew: same two ends, but their own source and no `Source` key.
        let userEdge = Relationship(
            fromFigure: figures.first { $0.name == "Rephaim" }!, toFigure: nephilim,
            relationshipType: localFormOf, source: "my own comparison"
        )
        context.insert(userEdge)
        try? context.save()
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, 3)

        Migration.ensureNephilimRelations(context: context)
        try? context.save()

        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let synonyms = rels.filter {
            $0.relationshipType?.name == "Local form of" &&
            $0.toFigure?.persistentModelID == nephilim.persistentModelID
        }
        XCTAssertEqual(synonyms.count, 1, "only the seeded row is withdrawn")
        XCTAssertEqual(synonyms.first?.source, "my own comparison", "a user's own row of the same shape survives")
        // Identity is asserted on the content, not on `persistentModelID`: CoreData recycles
        // the object ID of a deleted row, and here the freed ID was handed straight back to
        // the surviving row's replacement, so two equal IDs proved nothing either way.

        XCTAssertEqual(
            Set(collectiveMembers(of: figures.first { $0.name == "Rephaim" }!, from: rels).map(\.name)),
            ["Anakim", "Emim", "Zuzim", "Og of Bashan"]
        )

        Migration.ensureNephilimRelations(context: context)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, 6,
                       "re-running withdraws nothing further and adds nothing twice")
    }

    /// The notes are append-only, so a store that ran the earlier build ends up with two on
    /// each figure: one stating the withdrawn model, one withdrawing it. Only the earlier text
    /// is deleted, matched in full, and only on the figure it was written for.
    func testWithdrawSupersededNephilimNotesRemovesOnlyTheEarlierText() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()
        Migration.ensureRelationTypesExist(context: context)
        Migration.ensureCollectiveMembers(context: context)
        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimCitations(context: context)
        Migration.ensureNephilimRelations(context: context)
        Migration.ensureNephilimFlood(context: context)
        Migration.ensureNephilimGroup(context: context)
        try? context.save()

        let before = (try? context.fetchCount(FetchDescriptor<StickyNote>())) ?? -1
        XCTAssertEqual(before, 12, "only the current notes exist in a store that never ran the old build")
        Migration.withdrawSupersededNephilimNotes(context: context)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<StickyNote>())) ?? -1, 12,
                       "nothing to withdraw, nothing removed")

        // A note of your own on one of these figures, and one of ours with a different wording.
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let repHaim = figures.first { $0.name == "Rephaim" }!
        context.insert(StickyNote(text: "a note you wrote yourself", figure: repHaim))
        context.insert(StickyNote(
            text: "\(Migration.nephilimStickyPrefix) — an earlier wording that is not the one we wrote",
            figure: repHaim
        ))
        try? context.save()
        let withExtras = (try? context.fetchCount(FetchDescriptor<StickyNote>())) ?? -1

        Migration.withdrawSupersededNephilimNotes(context: context)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<StickyNote>())) ?? -1, withExtras,
                       "a fixed list of seven texts removes nothing here, because none of these are one of them")

        let remaining = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        XCTAssertTrue(remaining.contains { $0.text == "a note you wrote yourself" })
        XCTAssertTrue(remaining.contains { $0.text.contains("not the one we wrote") },
                      "the list is a fixed set of seven exact strings, so a reworded note is not on it and stays")
    }

    /// The withdrawals must be idempotent on their own, and must not touch the Enoch subgroup
    /// or the flood links when there is nothing to withdraw — the store's other deletions sit
    /// on the same figures.
    func testEnsureNephilimWithdrawalsAreIdempotentAndNarrow() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        func runChain() {
            Migration.ensureRelationTypesExist(context: context)
            Migration.ensureCollectiveMembers(context: context)
            Migration.ensureNephilimCollectives(context: context)
            Migration.ensureNephilimCitations(context: context)
            Migration.ensureNephilimRelations(context: context)
            Migration.ensureNephilimFlood(context: context)
            Migration.ensureNephilimGroup(context: context)
            Migration.ensureFigureTypeCategories(context: context)
            Commit.save(context, "nephilimChain")
        }
        runChain()
        let afterFirst = (try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1
        let floodAfterFirst = (try? context.fetchCount(FetchDescriptor<EventFigureAssociation>())) ?? -1
        let groupAfterFirst = (try? context.fetchCount(FetchDescriptor<FigureGroupAssociation>())) ?? -1

        runChain()
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Relationship>())) ?? -1, afterFirst)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<EventFigureAssociation>())) ?? -1, floodAfterFirst,
                       "the gibborim flood row is not removed a second time, and not resurrected")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<FigureGroupAssociation>())) ?? -1, groupAfterFirst,
                       "Rephaim and gibborim do not re-enter 'Children of the Watchers'")

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for name in ["Rephaim", "Gibborim"] {
            let associations = figures.first { $0.name == name }?.groupAssociations ?? []
            XCTAssertTrue(associations.allSatisfy { $0.group?.name != "Children of the Watchers" },
                          "\(name) stays out of the Enochic subgroup")
        }
    }
}
