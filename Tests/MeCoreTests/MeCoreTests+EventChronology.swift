import XCTest
import SwiftData
@testable import MeCore

extension MeCoreTests {
    private func makeEra(name: String, startYear: Int?, endYear: Int? = nil) -> Era {
        Era(
            name: name,
            startDate: MythologicalDate(year: startYear, era: name, isApproximate: true),
            endDate: MythologicalDate(year: endYear ?? startYear, era: name, isApproximate: true)
        )
    }

    func testEffectiveEraPrefersDateEraAndFallsBackToEventEra() {
        let both = Event(name: "Both", date: MythologicalDate(era: "Creation"), era: "Creation of Mankind")
        XCTAssertEqual(EventChronology.effectiveEra(of: both), "Creation")

        let eventEraOnly = Event(name: "EventEra", date: .unknown, era: "Antediluvian Period")
        XCTAssertEqual(EventChronology.effectiveEra(of: eventEraOnly), "Antediluvian Period")

        let dateEraOnly = Event(name: "DateEra", date: MythologicalDate(era: "The Great Flood"), era: "")
        XCTAssertEqual(EventChronology.effectiveEra(of: dateEraOnly), "The Great Flood")

        let neither = Event(name: "Neither", date: .unknown, era: "")
        XCTAssertEqual(EventChronology.effectiveEra(of: neither), "")
    }

    func testEffectiveYearUsesEventYearBeforeEraFallback() {
        let bounds = ["early dynastic period": -2900]
        let dated = Event(name: "Dated", date: MythologicalDate(year: -2700, era: "Early Dynastic Period"))
        XCTAssertEqual(EventChronology.effectiveYear(of: dated, eraBounds: bounds), -2700)
    }

    func testEffectiveYearFallsBackToEraBoundWhenYearMissing() {
        let bounds = ["antediluvian period": -269200]
        let eraOnly = Event(name: "EraOnly", date: MythologicalDate(era: "Antediluvian Period"), era: "Antediluvian Period")
        XCTAssertEqual(EventChronology.effectiveYear(of: eraOnly, eraBounds: bounds), -269200)

        let eventEraOnly = Event(name: "EventEraOnly", date: .unknown, era: "Antediluvian Period")
        XCTAssertEqual(EventChronology.effectiveYear(of: eventEraOnly, eraBounds: bounds), -269200)
    }

    func testEffectiveYearIsNilWithoutYearOrKnownEra() {
        let noYearNoEra = Event(name: "Nothing", date: .unknown, era: "")
        XCTAssertNil(EventChronology.effectiveYear(of: noYearNoEra, eraBounds: [:]))

        let unlistedEra = Event(name: "Unlisted", date: .unknown, era: "Era Not In List")
        XCTAssertNil(EventChronology.effectiveYear(of: unlistedEra, eraBounds: [:]))
    }

    func testEraBoundsUsesEarliestYearAndCaseInsensitiveKeys() {
        let inverted = makeEra(name: "Antediluvian Period", startYear: -28000, endYear: -269200)
        let undated = makeEra(name: "Antediluvian", startYear: nil)
        let normal = makeEra(name: "Neo-Assyrian Period", startYear: -911, endYear: -609)

        let bounds = EventChronology.eraBounds(from: [inverted, undated, normal])

        XCTAssertEqual(bounds["antediluvian period"], -269200)
        XCTAssertEqual(bounds["neo-assyrian period"], -911)
        XCTAssertNil(bounds["antediluvian"])
    }

    func testEraBoundsKeepsEarliestYearWhenTwoErasShareAName() {
        let first = makeEra(name: "Dup", startYear: -1000)
        let second = makeEra(name: "Dup", startYear: -2000)
        let bounds = EventChronology.eraBounds(from: [first, second])
        XCTAssertEqual(bounds["dup"], -2000)
    }

    func testOrderDateGroupsChronologicalErasThenUndatedErasThenUnknown() {
        let bounds = [
            "antediluvian period": -269200,
            "neo-assyrian period": -911
        ]
        let keys = ["Unknown", "Neo-Assyrian Period", "Custom Undated Era", "Antediluvian Period"]
        XCTAssertEqual(
            EventChronology.orderDateGroups(keys, eraBounds: bounds),
            ["Antediluvian Period", "Neo-Assyrian Period", "Custom Undated Era", "Unknown"]
        )
    }

    func testOrderDateGroupsSortsSameRankKeysAlphabetically() {
        let bounds = ["era b": -100, "era a": -100]
        let keys = ["Unknown", "Era B", "Era A"]
        XCTAssertEqual(
            EventChronology.orderDateGroups(keys, eraBounds: bounds),
            ["Era A", "Era B", "Unknown"]
        )
    }

    func testDerivedEraSkipsCatchAllErasWhenSpecificEraContainsYear() {
        let postFlood = makeEra(name: "Post-Flood Kingdoms", startYear: -27000, endYear: -2900)
        let uruk = makeEra(name: "Uruk Period", startYear: -3500, endYear: -3100)
        let event = Event(name: "Destruction by fire of Bad Tibira", date: MythologicalDate(year: -3500))
        XCTAssertEqual(EventChronology.derivedEra(of: event, from: [uruk, postFlood]), "Uruk Period")
    }

    func testDerivedEraFallsBackToCatchAllWhenNothingElseFits() {
        let postFlood = makeEra(name: "Post-Flood Kingdoms", startYear: -27000, endYear: -2900)
        let uruk = makeEra(name: "Uruk Period", startYear: -3500, endYear: -3100)
        let deepPast = Event(name: "DeepPast", date: MythologicalDate(year: -20000))
        XCTAssertEqual(EventChronology.derivedEra(of: deepPast, from: [uruk, postFlood]), "Post-Flood Kingdoms")
    }

    func testCatchAllDetectionUsesWidthThreshold() {
        let postFlood = makeEra(name: "Post-Flood Kingdoms", startYear: -27000, endYear: -2900)
        let greatFlood = makeEra(name: "The Great Flood", startYear: -28000, endYear: -27000)
        let uruk = makeEra(name: "Uruk Period", startYear: -3500, endYear: -3100)
        let undated = Era(name: "Antediluvian")
        XCTAssertTrue(EventChronology.isCatchAll(postFlood))
        XCTAssertFalse(EventChronology.isCatchAll(greatFlood))
        XCTAssertFalse(EventChronology.isCatchAll(uruk))
        XCTAssertFalse(EventChronology.isCatchAll(undated))
    }

    func testDerivedEraTieBreaksAlphabetically() {
        let eraA = makeEra(name: "Era A", startYear: -100, endYear: -50)
        let eraB = makeEra(name: "Era B", startYear: -100, endYear: -50)
        let tied = Event(name: "Tied", date: MythologicalDate(year: -70))
        XCTAssertEqual(EventChronology.derivedEra(of: tied, from: [eraB, eraA]), "Era A")
    }

    func testDerivedEraIsEmptyWithoutDateOrContainingEra() {
        let era = makeEra(name: "Era A", startYear: -100, endYear: -50)
        let undated = Event(name: "Undated", date: .unknown)
        XCTAssertEqual(EventChronology.derivedEra(of: undated, from: [era]), "")

        let outside = Event(name: "Outside", date: MythologicalDate(year: -10))
        XCTAssertEqual(EventChronology.derivedEra(of: outside, from: [era]), "")

        let undatedEra = Era(name: "Antediluvian")
        XCTAssertEqual(EventChronology.derivedEra(of: outside, from: [undatedEra]), "")
    }

    func testEffectiveEraWithErasNeverOverridesHandSetEra() {
        let postFlood = makeEra(name: "Post-Flood Kingdoms", startYear: -27000, endYear: -2900)
        let uruk = makeEra(name: "Uruk Period", startYear: -3500, endYear: -3100)

        let eventEraSet = Event(name: "EventEraSet", date: MythologicalDate(year: -3500), era: "Post-Flood Kingdoms")
        XCTAssertEqual(EventChronology.effectiveEra(of: eventEraSet, from: [uruk, postFlood]), "Post-Flood Kingdoms")

        let dateEraSet = Event(name: "DateEraSet", date: MythologicalDate(year: -3500, era: "Uruk Period"), era: "Post-Flood Kingdoms")
        XCTAssertEqual(EventChronology.effectiveEra(of: dateEraSet, from: [uruk, postFlood]), "Uruk Period")

        let undatedEraSet = Event(name: "UndatedEraSet", date: .unknown, era: "Post-Flood Kingdoms")
        XCTAssertEqual(EventChronology.effectiveEra(of: undatedEraSet, from: [uruk, postFlood]), "Post-Flood Kingdoms")
    }

    func testEraRangeHandlesInvertedStoredBounds() {
        let inverted = Era(
            name: "Inverted",
            startDate: MythologicalDate(year: -2400),
            endDate: MythologicalDate(year: -2450)
        )
        let range = EventChronology.eraRange(of: inverted)
        XCTAssertEqual(range, -2450 ... -2400)

        let event = Event(name: "InRange", date: MythologicalDate(year: -2420))
        XCTAssertEqual(EventChronology.derivedEra(of: event, from: [inverted]), "Inverted")
    }
}
