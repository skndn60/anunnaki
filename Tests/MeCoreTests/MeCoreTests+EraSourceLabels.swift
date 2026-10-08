import XCTest
import SwiftData
@testable import MeCore

extension MeCoreTests {
    private func makeEraCitation(_ sourceName: String, _ location: String, for eraName: String) -> Citation {
        Citation(
            source: Source(name: sourceName),
            location: location,
            note: "",
            entityType: .era,
            linkedEntityName: eraName
        )
    }

    func testEraSourceNumeralReadsTheOrdinalFromTheCitation() {
        let container = makeContainer()
        let context = container.mainContext
        let chaldean = Era(name: "Chaldean Dynasty", orderIndex: 56)
        context.insert(chaldean)
        let citation = makeEraCitation("List of kings of Babylon", "Dynasty X", for: "Chaldean Dynasty")
        context.insert(citation)

        XCTAssertEqual(EraSourceLabels.numeral(for: chaldean, in: [citation]), "Dynasty X")
    }

    /// The Sumerian dynasties are numbered by a different work and have no such
    /// citation, so the suffix is absent rather than wrong.
    func testEraSourceNumeralIsNilWhenNoSourceNumbersTheEra() {
        let container = makeContainer()
        let context = container.mainContext
        let kish = Era(name: "First dynasty of Kish", orderIndex: 11)
        context.insert(kish)

        XCTAssertNil(EraSourceLabels.numeral(for: kish, in: []))
    }

    /// A citation location that is not a numeral must not be read as one.
    func testEraSourceNumeralIgnoresLocationsThatAreNotDynastyNumerals() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Kassite Dynasty of Babylon", orderIndex: 49)
        context.insert(era)

        XCTAssertNil(EraSourceLabels.numeral(for: era, in: [
            makeEraCitation("Some Work", "Babylon under foreign rule", for: "Kassite Dynasty of Babylon"),
            makeEraCitation("Other Work", "", for: "Kassite Dynasty of Babylon"),
            makeEraCitation("Third Work", "Dynasty", for: "Kassite Dynasty of Babylon"),
        ]))
    }

    /// Citations on other entity types carry locations of every shape and must not be
    /// scanned for era numerals.
    func testEraSourceNumeralIgnoresCitationsForOtherEntityTypes() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Bazi Dynasty", orderIndex: 52)
        context.insert(era)
        let figureCitation = Citation(
            source: Source(name: "List of kings of Babylon"),
            location: "Dynasty VI",
            entityType: .figure,
            linkedEntityName: "Bazi Dynasty"
        )
        context.insert(figureCitation)

        XCTAssertNil(EraSourceLabels.numeral(for: era, in: [figureCitation]))
    }

    /// A figure citation and an era citation can share a linked name; only the era one
    /// counts, or every ruler would inherit their dynasty's numeral.
    func testEraSourceNumeralPrefersTheEraCitationOverAFigureCitation() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Elamite Dynasty", orderIndex: 53)
        context.insert(era)
        let figureCitation = Citation(
            source: Source(name: "List of kings of Babylon"),
            location: "Dynasty VII",
            entityType: .figure,
            linkedEntityName: "Elamite Dynasty"
        )
        let eraCitation = makeEraCitation("List of kings of Babylon", "Dynasty VII", for: "Elamite Dynasty")
        context.insert(figureCitation)
        context.insert(eraCitation)

        XCTAssertEqual(EraSourceLabels.numeral(for: era, in: [figureCitation, eraCitation]), "Dynasty VII")
    }

    /// The source's own label is shown, not our reading of it: an arabic numeral is
    /// passed through rather than converted.
    func testEraSourceNumeralPassesThroughTheSourcesOwnLabel() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Second Dynasty of the Sealand", orderIndex: 51)
        context.insert(era)
        let citation = makeEraCitation("Some Chronology", "Dynasty 8", for: "Second Dynasty of the Sealand")
        context.insert(citation)

        XCTAssertEqual(EraSourceLabels.numeral(for: era, in: [citation]), "Dynasty 8")
    }

    /// A locator appended to the heading still resolves — the section number is its own
    /// whitespace-delimited token.
    func testEraSourceNumeralReadsTheHeadingWhenTheLocationAlsoCarriesALocator() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Chaldean Dynasty", orderIndex: 56)
        context.insert(era)
        let citation = makeEraCitation("List of kings of Babylon", "Dynasty X, cols. 12-20", for: "Chaldean Dynasty")
        context.insert(citation)

        XCTAssertEqual(EraSourceLabels.numeral(for: era, in: [citation]), "Dynasty X")
    }

    /// The batch form must agree with the single form, which is the property the list
    /// view relies on to avoid a per-row scan.
    func testEraSourceNumeralsMatchTheSingleEraLookup() {
        let container = makeContainer()
        let context = container.mainContext
        let chaldean = Era(name: "Chaldean Dynasty", orderIndex: 56)
        let sealand = Era(name: "First Dynasty of the Sealand", orderIndex: 48)
        let kish = Era(name: "First dynasty of Kish", orderIndex: 11)
        context.insert(chaldean)
        context.insert(sealand)
        context.insert(kish)
        let citations = [
            makeEraCitation("List of kings of Babylon", "Dynasty X", for: "Chaldean Dynasty"),
            makeEraCitation("List of kings of Babylon", "Dynasty II", for: "First Dynasty of the Sealand"),
        ]
        for citation in citations { context.insert(citation) }
        try? context.save()

        let batch = EraSourceLabels.numerals(for: [chaldean, sealand, kish], in: citations)
        XCTAssertEqual(batch[chaldean.persistentModelID], EraSourceLabels.numeral(for: chaldean, in: citations))
        XCTAssertEqual(batch[sealand.persistentModelID], EraSourceLabels.numeral(for: sealand, in: citations))
        XCTAssertNil(batch[kish.persistentModelID])
        XCTAssertEqual(batch.count, 2)
    }

    /// A user's own spelling of the era still resolves: the era and the citation are
    /// matched on normalized key, as everywhere else in the store.
    func testEraSourceNumeralToleratesUserSpellingVariants() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Chaldean Dynasty", orderIndex: 56)
        context.insert(era)
        let citation = makeEraCitation("List of kings of Babylon", "Dynasty X", for: "Chaldean Dynasty")
        context.insert(citation)

        let renamed = Era(name: "  chaldean  dynasty ", orderIndex: 56)
        XCTAssertEqual(EraSourceLabels.numeral(for: renamed, in: [citation]), "Dynasty X")
    }

    /// Two eras must not collapse onto one numeral when a citation names only one of
    /// them — the batch map keys on identity, not on the matched string.
    func testEraSourceNumeralsDoNotLeakBetweenSimilarlyNamedEras() {
        let container = makeContainer()
        let context = container.mainContext
        let first = Era(name: "Second Dynasty of Babylon", orderIndex: 54)
        let second = Era(name: "Second Dynasty of the Sealand", orderIndex: 51)
        context.insert(first)
        context.insert(second)
        let citations = [
            makeEraCitation("List of kings of Babylon", "Dynasty VIII", for: "Second Dynasty of Babylon"),
            makeEraCitation("List of kings of Babylon", "Dynasty V", for: "Second Dynasty of the Sealand"),
        ]
        for citation in citations { context.insert(citation) }
        try? context.save()

        let batch = EraSourceLabels.numerals(for: [first, second], in: citations)
        XCTAssertEqual(batch[first.persistentModelID], "Dynasty VIII")
        XCTAssertEqual(batch[second.persistentModelID], "Dynasty V")
    }
}
