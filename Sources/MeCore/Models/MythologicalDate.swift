import Foundation

/// A date representation that handles mythological and deep-historical timeframes.
/// Supports date ranges (e.g. "1240–1230 BCE"), approximate dates,
/// and purely mythological time periods with no numeric year.
package struct MythologicalDate: Codable, Hashable {
    /// Earliest possible year. Negative = BCE (e.g. -1240 = 1240 BCE). Nil if purely mythological.
    package var startYear: Int?
    /// Latest possible year. Same sign as startYear. Nil if only startYear is known.
    package var endYear: Int?

    /// The era this date belongs to (e.g. "Before the Flood", "Early Dynastic Period")
    package var era: String

    /// Whether the date is approximate (most ancient dates are)
    package var isApproximate: Bool

    /// Human-readable display label (e.g. "~445,000 BCE", "~1,240–1,230 BCE", "Mythological")
    package var displayLabel: String {
        let prefix = isApproximate ? "~" : ""

        if let start = startYear, let end = endYear, start != end {
            let startStr = formatYearAbs(start)
            let endStr = formatYearAbs(end)
            let suffix = start < 0 ? " BCE" : " CE"
            return "\(prefix)\(startStr)\u{2013}\(endStr)\(suffix)"
        }

        if let year = startYear ?? endYear {
            let absYear = abs(year)
            let formatted = NumberFormatter.localizedString(from: NSNumber(value: absYear), number: .decimal)
            if year < 0 {
                return "\(prefix)\(formatted) BCE"
            } else {
                return "\(prefix)\(formatted) CE"
            }
        }

        return era.isEmpty ? "Unknown" : era
    }

    /// For sorting: returns the earliest year if available, otherwise Int.min for mythological dates
    package var sortValue: Int {
        startYear ?? endYear ?? Int.min
    }

    package static let unknown = MythologicalDate(startYear: nil, endYear: nil, era: "", isApproximate: true)

    /// Convenience initializer for a single-year date (backward-compatible).
    package init(year: Int? = nil, era: String = "", isApproximate: Bool = false) {
        self.startYear = year
        self.endYear = year
        self.era = era
        self.isApproximate = isApproximate
    }

    package init(startYear: Int? = nil, endYear: Int? = nil, era: String = "", isApproximate: Bool = false) {
        if let s = startYear, let e = endYear, s > e {
            self.startYear = e
            self.endYear = s
        } else {
            self.startYear = startYear
            self.endYear = endYear
        }
        self.era = era
        self.isApproximate = isApproximate
    }

    private func formatYearAbs(_ year: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: abs(year)), number: .decimal)
    }
}
