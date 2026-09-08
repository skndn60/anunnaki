import Foundation

package struct Kingship {
    package let reignStartYear: Int?
    package let reignEndYear: Int?
    package let listedReignYears: Int?

    /// Reign length parsed from the description prose when `listedReignYears` is
    /// nil (see `ReignLength.parse`). Resolved once by the `Figure.kingship`
    /// accessor so callers never parse descriptions themselves.
    package let descriptionReignYears: Int?

    package init(reignStartYear: Int?, reignEndYear: Int?, listedReignYears: Int?, descriptionReignYears: Int?) {
        self.reignStartYear = reignStartYear
        self.reignEndYear = reignEndYear
        self.listedReignYears = listedReignYears
        self.descriptionReignYears = descriptionReignYears
    }

    /// The effective reign duration in years: the stored listed value, falling
    /// back to the description parser.
    package var effectiveReignYears: Int? {
        listedReignYears ?? descriptionReignYears
    }

    package var hasChronologicalSpan: Bool {
        reignStartYear != nil || reignEndYear != nil
    }

    package var hasListedDuration: Bool {
        listedReignYears != nil
    }

    package var reignSpanLabel: String? {
        switch (reignStartYear, reignEndYear) {
        case let (start?, end?):
            return "\(abs(start))\u{2013}\(abs(end)) BCE"
        case let (start?, nil):
            return "From \(abs(start)) BCE"
        case let (nil, end?):
            return "To \(abs(end)) BCE"
        default:
            return nil
        }
    }
}

package extension Figure {
    var kingship: Kingship? {
        let parsed = reignYears == nil ? ReignLength.parse(from: figureDescription)?.years : nil
        guard reignStartYear != nil || reignEndYear != nil || reignYears != nil || parsed != nil else { return nil }
        return Kingship(
            reignStartYear: reignStartYear,
            reignEndYear: reignEndYear,
            listedReignYears: reignYears,
            descriptionReignYears: parsed
        )
    }

    /// Replaces all three stored reign columns in one go. The single write path
    /// for kingship data — callers never touch `reignStartYear`/`reignEndYear`/
    /// `reignYears` directly.
    func updateKingship(reignStartYear: Int?, reignEndYear: Int?, reignYears: Int?) {
        self.reignStartYear = reignStartYear
        self.reignEndYear = reignEndYear
        self.reignYears = reignYears
    }

    /// Merges reign data from another figure, keeping this figure's values where
    /// they are already set (used when collapsing a duplicate into a keeper).
    func adoptMissingKingshipFields(from other: Figure) {
        if reignStartYear == nil { reignStartYear = other.reignStartYear }
        if reignEndYear == nil { reignEndYear = other.reignEndYear }
        if reignYears == nil { reignYears = other.reignYears }
    }
}
