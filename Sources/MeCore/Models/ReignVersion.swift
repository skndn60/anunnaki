import Foundation
import SwiftData

/// A competing variant of a figure's reign, kept alongside the canonical
/// single values stored on `Figure` (`reignStartYear` / `reignEndYear` /
/// `reignYears`). The Sumerian King List's manuscript copies disagree in places
/// (e.g. Kullassina-bel "960 years (or 900 in some copies)", Etana "1,500 years
/// (some copies read 635)"), and the Ur-Isin king list trades short reigns with
/// the SKL (Būr-Sîn 21 vs 22, Iter-pisha and Ur-du-kuga 4 vs 3). Each row
/// carries the variant figure plus a free-text attribution so queries, the
/// timeline, and the date propagator continue to read only the canonical values.
@Model
package final class ReignVersion {
    /// Variant reign duration in years.
    package var years: Int?

    /// Variant chronological span (e.g. an alternate chronology edition).
    package var startYear: Int?
    package var endYear: Int?

    /// Free-text attribution of the variant, e.g. "some copies of the Sumerian
    /// King List" or "Ur-Isin king list". Display-only; never a join key.
    package var tradition: String

    /// Free-text clarifying note (display only).
    package var note: String

    package var isApproximate: Bool

    package var figure: Figure?

    package init(
        years: Int? = nil,
        startYear: Int? = nil,
        endYear: Int? = nil,
        tradition: String = "",
        note: String = "",
        isApproximate: Bool = false,
        figure: Figure? = nil
    ) {
        self.years = years
        self.startYear = startYear
        self.endYear = endYear
        self.tradition = tradition
        self.note = note
        self.isApproximate = isApproximate
        self.figure = figure
    }

    /// "900 years (some copies of the Sumerian King List)" for durations,
    /// "1728–1686 BCE (Short chronology)" for spans. Mirrors the BCE styling of
    /// `Kingship.reignSpanLabel`.
    package var displayLabel: String {
        let value: String
        if let years {
            value = "\(years) years"
        } else if let start = startYear, let end = endYear {
            value = "\(abs(start))\u{2013}\(abs(end)) BCE"
        } else if let start = startYear {
            value = "From \(abs(start)) BCE"
        } else if let end = endYear {
            value = "To \(abs(end)) BCE"
        } else {
            value = "Unknown length"
        }
        if !tradition.isEmpty {
            return "\(value) (\(tradition))"
        }
        return value
    }
}