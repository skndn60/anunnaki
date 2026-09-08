import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
    func makeKingshipFigure(name: String, reignStart: Int? = nil, reignEnd: Int? = nil, reignYears: Int? = nil) -> Figure {
        let figure = Figure(name: name)
        figure.reignStartYear = reignStart
        figure.reignEndYear = reignEnd
        figure.reignYears = reignYears
        return figure
    }

    func testKingshipNilWhenNoReignData() {
        let figure = makeKingshipFigure(name: "Enki")
        XCTAssertNil(figure.kingship)
    }

    func testKingshipPresentForListedDurationOnly() {
        let figure = makeKingshipFigure(name: "Alulim", reignYears: 28800)
        let kingship = figure.kingship
        XCTAssertNotNil(kingship)
        XCTAssertEqual(kingship?.listedReignYears, 28800)
        XCTAssertTrue(kingship?.hasListedDuration ?? false)
        XCTAssertFalse(kingship?.hasChronologicalSpan ?? true)
        XCTAssertNil(kingship?.reignSpanLabel)
    }

    func testKingshipPresentForChronologicalSpan() {
        let figure = makeKingshipFigure(name: "Hammurabi", reignStart: -1792, reignEnd: -1750)
        let kingship = figure.kingship
        XCTAssertNotNil(kingship)
        XCTAssertEqual(kingship?.reignStartYear, -1792)
        XCTAssertEqual(kingship?.reignEndYear, -1750)
        XCTAssertTrue(kingship?.hasChronologicalSpan ?? false)
        XCTAssertFalse(kingship?.hasListedDuration ?? true)
    }

    func testKingshipSpanLabelFullRange() {
        let figure = makeKingshipFigure(name: "Hammurabi", reignStart: -1792, reignEnd: -1750)
        XCTAssertEqual(figure.kingship?.reignSpanLabel, "1792\u{2013}1750 BCE")
    }

    func testKingshipSpanLabelOpenEnded() {
        let fromOnly = makeKingshipFigure(name: "Sargon", reignStart: -2334)
        XCTAssertEqual(fromOnly.kingship?.reignSpanLabel, "From 2334 BCE")

        let toOnly = makeKingshipFigure(name: "Rimush", reignEnd: -2270)
        XCTAssertEqual(toOnly.kingship?.reignSpanLabel, "To 2270 BCE")
    }

    func testKingshipAllFieldsTogether() {
        let figure = makeKingshipFigure(name: "Gudea", reignStart: -2144, reignEnd: -2124, reignYears: 20)
        let kingship = figure.kingship
        XCTAssertEqual(kingship?.reignStartYear, -2144)
        XCTAssertEqual(kingship?.reignEndYear, -2124)
        XCTAssertEqual(kingship?.listedReignYears, 20)
        XCTAssertTrue(kingship?.hasChronologicalSpan ?? false)
        XCTAssertTrue(kingship?.hasListedDuration ?? false)
        XCTAssertEqual(kingship?.reignSpanLabel, "2144\u{2013}2124 BCE")
    }

    func testKingshipEffectiveReignYearsPrefersStoredValue() {
        let figure = Figure(name: "A figure", figureDescription: "…(Listed reign: 28,800 years.)")
        figure.reignYears = 120
        XCTAssertEqual(figure.kingship?.effectiveReignYears, 120)
    }

    func testKingshipEffectiveReignYearsFallsBackToDescriptionProse() {
        let figure = Figure(name: "A king", figureDescription: "He ruled for around 670 years according to some versions.")
        XCTAssertEqual(figure.kingship?.effectiveReignYears, 670)
    }

    func testKingshipNilWhenDescriptionHasNoReignProse() {
        let figure = Figure(name: "A deity", figureDescription: "A deity of water and wisdom.")
        XCTAssertNil(figure.kingship)
    }
}
