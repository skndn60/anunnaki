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

    /// Qualifier for single-year dates
    package var qualifier: DateQualifier

    private enum CodingKeys: String, CodingKey {
        case startYear, endYear, era, isApproximate, qualifier
    }

    package enum DateQualifier: String, Codable, CaseIterable {
        case exact
        case after
        case before

        package var label: String {
            switch self {
            case .exact: return "Exact"
            case .after: return "After"
            case .before: return "Before"
            }
        }
    }

    /// Human-readable display label (e.g. "~445,000 BCE", "~1,240–1,230 BCE", "Mythological")
    package var displayLabel: String {
        let prefix = isApproximate ? "~" : ""

        if let start = startYear, let end = endYear, start != end {
            let startStr = formatYearAbs(start)
            let endStr = formatYearAbs(end)
            let suffix = start < 0 ? " BCE" : " CE"
            return "\(prefix)\(startStr) \u{2013} \(endStr)\(suffix)"
        }

        if let year = startYear ?? endYear {
            let suffix = year < 0 ? " BCE" : " CE"
            let qual = qualifier == .exact ? "" : qualifier.rawValue + " "
            return "\(prefix)\(qual)\(formatYearAbs(year))\(suffix)"
        }

        return era.isEmpty ? "Unknown" : era
    }

    /// For sorting: returns the earliest year if available, otherwise Int.min for mythological dates
    package var sortValue: Int {
        startYear ?? endYear ?? Int.min
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startYear = try container.decodeIfPresent(Int.self, forKey: .startYear)
        endYear = try container.decodeIfPresent(Int.self, forKey: .endYear)
        era = try container.decodeIfPresent(String.self, forKey: .era) ?? ""
        isApproximate = try container.decodeIfPresent(Bool.self, forKey: .isApproximate) ?? false
        qualifier = try container.decodeIfPresent(DateQualifier.self, forKey: .qualifier) ?? .exact
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(startYear, forKey: .startYear)
        try container.encodeIfPresent(endYear, forKey: .endYear)
        try container.encode(era, forKey: .era)
        try container.encode(isApproximate, forKey: .isApproximate)
        try container.encode(qualifier, forKey: .qualifier)
    }

    package static let unknown = MythologicalDate(startYear: nil, endYear: nil, era: "", isApproximate: true)

    /// Convenience initializer for a single-year date (backward-compatible).
    package init(year: Int? = nil, era: String = "", isApproximate: Bool = false) {
        self.startYear = year
        self.endYear = year
        self.era = era
        self.isApproximate = isApproximate
        self.qualifier = .exact
    }

    package init(startYear: Int? = nil, endYear: Int? = nil, era: String = "", isApproximate: Bool = false, qualifier: DateQualifier = .exact) {
        if let s = startYear, let e = endYear, s > e {
            self.startYear = e
            self.endYear = s
        } else {
            self.startYear = startYear
            self.endYear = endYear
        }
        self.era = era
        self.isApproximate = isApproximate
        self.qualifier = qualifier
    }

    private func formatYearAbs(_ year: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: NSNumber(value: abs(year))) ?? "\(abs(year))"
    }
}
