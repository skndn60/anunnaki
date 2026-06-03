import Foundation

/// A date representation that handles mythological and deep-historical timeframes.
/// Supports dates hundreds of thousands of years in the past, approximate dates,
/// and purely mythological time periods with no numeric year.
struct MythologicalDate: Codable, Hashable {
    /// Numeric year. Negative = BCE (e.g. -445000 = 445,000 BCE). Nil if purely mythological.
    var year: Int?

    /// The era this date belongs to (e.g. "Before the Flood", "Early Dynastic Period")
    var era: String

    /// Whether the date is approximate (most ancient dates are)
    var isApproximate: Bool

    /// Human-readable display label (e.g. "~445,000 BCE", "Mythological", "~2700 BCE")
    var displayLabel: String {
        if let year {
            let prefix = isApproximate ? "~" : ""
            if year < 0 {
                return "\(prefix)\(abs(year).formatted()) BCE"
            } else {
                return "\(prefix)\(year.formatted()) CE"
            }
        }
        return era.isEmpty ? "Unknown" : era
    }

    /// For sorting: returns the year if available, otherwise Int.min for mythological dates
    var sortValue: Int {
        year ?? Int.min
    }

    static let unknown = MythologicalDate(year: nil, era: "", isApproximate: true)
}
