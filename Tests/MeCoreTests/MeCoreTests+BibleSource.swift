import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
    // MARK: - Helpers

    /// A store in the shape an earlier build of the Nephilim migration left behind: the
    /// user's own "Bible - Genesis 6:4" row, quoting the verse, plus the four rows that
    /// build added by copying its shape — one source per verse.
    private func makePerVerseBibleStore() throws -> ModelContainer {
        let container = makeContainer()
        let context = container.mainContext

        let genesis = Source(
            name: "Bible - Genesis 6:4",
            sourceType: .modernTranslation,
            language: "English",
            sourceDescription: "The Nephilim were on the earth in those days, and also after that, when the sons of God came in to the daughters of mankind."
        )
        let numbers = Source(name: "Bible - Numbers 13:33", sourceType: .modernTranslation, language: "English",
                             sourceDescription: "The spies report the Anakim as coming from the Nephilim.")
        let deuteronomy = Source(name: "Bible - Deuteronomy 3:11", sourceType: .modernTranslation, language: "English",
                                 sourceDescription: "Og of Bashan as the last survivor of the remnant of the Rephaim.")
        let enoch = Source(name: "Book of Enoch (1 Enoch)", sourceType: .ancientText)
        let kingsList = Source(name: "Sumerian King List", sourceType: .kingList)
        for source in [genesis, numbers, deuteronomy, enoch, kingsList] { context.insert(source) }

        let nephilim = Figure(name: "Nephilim")
        let anakim = Figure(name: "Anakim")
        let og = Figure(name: "Og of Bashan")
        for figure in [nephilim, anakim, og] { context.insert(figure) }

        // Two citations whose verse is in the location, and one — the store's Mahalalel row —
        // whose verse lived only in the source's name and would be lost with it.
        context.insert(Citation(source: genesis, location: "Gen 6:4", note: "the Nephilim on the earth",
                                entityType: .figure, linkedEntityName: "Nephilim"))
        context.insert(Citation(source: numbers, location: "Num 13:22-33; 33", note: "the spies report the Anakim",
                                entityType: .figure, linkedEntityName: "Anakim"))
        context.insert(Citation(source: genesis, location: "", note: "the verse as the user cited it",
                                entityType: .figure, linkedEntityName: "Mahalalel"))
        context.insert(Citation(source: enoch, location: "1 Enoch 6:7", note: "the offspring of the holy angels",
                                entityType: .figure, linkedEntityName: "Nephilim"))
        context.insert(Attachment(source: deuteronomy, title: "Deuteronomy 3:11", url: ""))

        let memberOf = RelationshipType(name: "Member of", icon: "person.badge.plus", colorHex: "FF2600", category: "membership")
        context.insert(memberOf)
        context.insert(Relationship(fromFigure: og, toFigure: nephilim, relationshipType: memberOf,
                                    source: "Deuteronomy 3:11", sourceRef: deuteronomy))
        context.insert(Relationship(fromFigure: anakim, toFigure: nephilim, relationshipType: memberOf,
                                    source: "", sourceRef: numbers))

        try context.save()
        return container
    }

    // MARK: - The rule

    /// The matcher is what decides which rows get collapsed, so it is pinned to the one
    /// shape it was written for. A source the user named some other way must never match,
    /// however Bible-adjacent it looks.
    func testPerVerseBibleSourceNameOnlyMatchesTheShapeItCollapses() {
        for name in ["Bible - Genesis 6:4", "Bible - Numbers 13:33", "Bible - Deuteronomy 2:10",
                     "Bible - 1 Samuel 17:7"] {
            XCTAssertTrue(Migration.isPerVerseBibleSourceName(name), name)
            XCTAssertEqual(Migration.verseInPerVerseSourceName(name),
                           String(name.dropFirst("Bible - ".count)))
        }
        for name in ["Bible", "Bible - Genesis", "Bible - Pentateuch", "Holy Bible",
                     "Bible - King James Version", "The Bible of Kivah", "Torah", "Bible - 6:4"] {
            XCTAssertFalse(Migration.isPerVerseBibleSourceName(name), name)
        }
    }

    // MARK: - The collapse

    /// Five rows for one work become one, and every citation survives with its verse.
    func testCollapseBibleVersesIntoOneSourceLeavesOneRowAndKeepsEveryCitation() throws {
        let container = try makePerVerseBibleStore()
        let context = container.mainContext

        Migration.collapseBibleVersesIntoOneSource(context: context)
        try context.save()

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(sources.filter { $0.name == "Bible" }.count, 1)
        XCTAssertFalse(sources.contains { Migration.isPerVerseBibleSourceName($0.name) },
                       "no verse is a source row any more")
        XCTAssertEqual(sources.count, 3, "Bible, 1 Enoch and the King List")

        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        XCTAssertEqual(citations.count, 4, "the collapse deletes a citation only when it already has a twin")
        let bibleCitations = citations.filter { $0.source?.name == "Bible" }
        XCTAssertEqual(Set(bibleCitations.map(\.location)), ["Gen 6:4", "Num 13:22-33; 33", "Genesis 6:4"])
        XCTAssertTrue(
            bibleCitations.contains { $0.safeEntityName == "Mahalalel" && $0.location == "Genesis 6:4" },
            "a citation whose verse lived in the source's name keeps its verse, in the location"
        )
        XCTAssertTrue(
            citations.allSatisfy { $0.safeEntityType == .figure && !$0.safeEntityName.isEmpty },
            "the linked figure survives the move"
        )
    }

    /// The attachments and relationship keys are the other two sides that point at a source.
    /// `Source.citations` and `.attachments` cascade, so a collapse that forgot to re-point
    /// them would delete the user's evidence rather than move it.
    func testCollapseBibleVersesRepointsAttachmentsAndRelationshipKeys() throws {
        let container = try makePerVerseBibleStore()
        let context = container.mainContext

        Migration.collapseBibleVersesIntoOneSource(context: context)
        try context.save()

        let attachments = (try? context.fetch(FetchDescriptor<Attachment>())) ?? []
        XCTAssertEqual(attachments.count, 1, "an attachment is not lost with the source it hung on")
        XCTAssertEqual(attachments.first?.source?.name, "Bible")

        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(relationships.count, 2)
        XCTAssertTrue(relationships.allSatisfy { $0.sourceRef?.name == "Bible" })
        let anakimEdge = relationships.first { $0.fromFigure?.name == "Anakim" }
        XCTAssertEqual(
            anakimEdge?.source, "Numbers 13:33",
            "an edge whose verse string was empty gets it from the row name, so the key and the string agree"
        )
    }

    /// The store's own Genesis 6:4 quotation is user content and the row it lives on is being
    /// deleted, so it moves to the work row rather than going with it.
    func testCollapseBibleVersesKeepsTheStoresGenesisQuotation() throws {
        let container = try makePerVerseBibleStore()
        let context = container.mainContext

        Migration.collapseBibleVersesIntoOneSource(context: context)
        try context.save()

        let bible = (try? context.fetch(FetchDescriptor<Source>()))?
            .first { $0.name == "Bible" }
        let quote = "The Nephilim were on the earth in those days, and also after that, when the sons of God came in to the daughters of mankind."
        XCTAssertTrue(bible?.sourceDescription.contains(quote) == true,
                      "the quotation is preserved verbatim on the work row")
    }

    /// Running twice must not create a second work row, re-append citations, or resurrect a
    /// verse row — the chain runs on every launch.
    func testCollapseBibleVersesIsIdempotent() throws {
        let container = try makePerVerseBibleStore()
        let context = container.mainContext

        Migration.collapseBibleVersesIntoOneSource(context: context)
        try context.save()
        let firstSources = (try? context.fetchCount(FetchDescriptor<Source>())) ?? -1
        let firstCitations = (try? context.fetchCount(FetchDescriptor<Citation>())) ?? -1

        Migration.collapseBibleVersesIntoOneSource(context: context)
        Migration.collapseBibleVersesIntoOneSource(context: context)
        try context.save()

        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Source>())) ?? -1, firstSources)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Citation>())) ?? -1, firstCitations)
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(sources.filter { $0.name == "Bible" }.count, 1)
    }

    /// A store with no per-verse rows is left completely alone — the seeds already write the
    /// single work row, so a fresh install must not be touched.
    func testCollapseBibleVersesDoesNothingWhenThereAreNoVerseRows() throws {
        let container = makeContainer()
        let context = container.mainContext
        let enoch = Source(name: "Book of Enoch (1 Enoch)", sourceType: .ancientText)
        context.insert(enoch)
        try context.save()

        Migration.collapseBibleVersesIntoOneSource(context: context)
        try context.save()

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(sources.map(\.name), ["Book of Enoch (1 Enoch)"], "no work row invented")
    }

    /// The seeds, not just the repair: a store built from scratch must get one Bible source,
    /// or the next fresh install reintroduces the duplication.
    func testNephilimSeedsCreateOneBibleSourceRatherThanOnePerVerse() throws {
        let container = makeContainer()
        let context = container.mainContext
        try context.save()

        Migration.ensureNephilimCollectives(context: context)
        Migration.ensureNephilimCitations(context: context)
        Migration.ensureNephilimRelations(context: context)
        Migration.collapseBibleVersesIntoOneSource(context: context)
        try context.save()

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(sources.filter { $0.name == "Bible" }.count, 1)
        XCTAssertFalse(sources.contains { Migration.isPerVerseBibleSourceName($0.name) })

        let bibleCitations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
            .filter { $0.source?.name == "Bible" }
        XCTAssertEqual(Set(bibleCitations.map(\.linkedEntityName)),
                       ["Nephilim", "Anakim", "Rephaim", "Gibborim", "Emim", "Zuzim", "Og of Bashan",
                        "Hahyah", "Ohyah"])
        XCTAssertTrue(bibleCitations.allSatisfy { !$0.location.isEmpty }, "every one names its own verse")
    }
}
