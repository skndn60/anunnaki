import XCTest
import MeCore

extension MeCoreTests {
    func testEntitySearchScoreTiers() {
        XCTAssertEqual(EntitySearch.score(query: "enki", primary: "Enki"), 100)
        XCTAssertEqual(EntitySearch.score(query: "enki", primary: "Enkidu"), 80)
        XCTAssertEqual(EntitySearch.score(query: "enki", primary: "Lord Enki"), 60)
        XCTAssertEqual(EntitySearch.score(query: "enki", primary: "Tenkim"), 40)
    }

    func testEntitySearchScoreFoldsDiacriticsAndPunctuation() {
        XCTAssertEqual(EntitySearch.score(query: "istaran", primary: "Ištaran"), 100)
        XCTAssertEqual(EntitySearch.score(query: "IŠTARAN", primary: "Istaran"), 100)
        XCTAssertEqual(EntitySearch.score(query: "atrahasis", primary: "Atra-Hasis"), 100)
        XCTAssertEqual(EntitySearch.score(query: "atr'a.hasis", primary: "AtraHasis"), 100)
    }

    func testEntitySearchScoreKeepsSpacesAsWordBoundaries() {
        XCTAssertNil(EntitySearch.score(query: "atra hasis", primary: "Atra-Hasis"))
        XCTAssertNil(EntitySearch.score(query: "ninnibru", primary: "Nin Nibru"))
        XCTAssertEqual(EntitySearch.score(query: "nin nibru", primary: "Great Nin Nibru"), 60)
    }

    func testEntitySearchSecondaryFieldsScoreBelowPrimary() {
        let direct = EntitySearch.score(query: "nibru", primary: "Nibru")
        let viaSecondary = EntitySearch.score(query: "nibru", primary: "Shuruppak", secondary: ["Nibru"])
        XCTAssertEqual(direct, 100)
        XCTAssertEqual(viaSecondary, 75)
        let bestSecondary = EntitySearch.score(query: "ur", primary: "Enlil", secondary: ["Bur", "Ur"])
        XCTAssertEqual(bestSecondary, 75)
    }

    func testEntitySearchScoreNilOnNoMatchOrEmptyQuery() {
        XCTAssertNil(EntitySearch.score(query: "enki", primary: "Inanna"))
        XCTAssertNil(EntitySearch.score(query: "", primary: "Enki"))
        XCTAssertNil(EntitySearch.score(query: "   ", primary: "Enki"))
        XCTAssertNil(EntitySearch.score(query: "---", primary: "Enki"))
        XCTAssertNil(EntitySearch.score(query: "enki", primary: ""))
    }

    func testEntitySearchMatchesIsFoldAware() {
        XCTAssertTrue(EntitySearch.matches(query: "Atrahasis", primary: "Atra-Hasis"))
        XCTAssertTrue(EntitySearch.matches(query: "štaran", primary: "Istaran", secondary: []))
        XCTAssertTrue(EntitySearch.matches(query: "modern location", primary: "Ur", secondary: ["Modern Location"]))
        XCTAssertFalse(EntitySearch.matches(query: "enlil", primary: "Enki"))
        XCTAssertFalse(EntitySearch.matches(query: "", primary: "Enki"))
    }

    func testEntitySearchBestMatchReturnsWinningOriginalSpelling() {
        XCTAssertEqual(EntitySearch.bestMatch(query: "ur", in: ["Urim", "Bur"]), "Urim")
        XCTAssertEqual(EntitySearch.bestMatch(query: "ur", in: ["Ur", "Urim"]), "Ur")
        XCTAssertEqual(EntitySearch.bestMatch(query: "ninlil", in: ["Nin-Magir", "Ninlil"]), "Ninlil")
        XCTAssertNil(EntitySearch.bestMatch(query: "", in: ["Urim"]))
        XCTAssertNil(EntitySearch.bestMatch(query: "zzz", in: ["Urim"]))
        XCTAssertNil(EntitySearch.bestMatch(query: "ur", in: []))
    }
}
