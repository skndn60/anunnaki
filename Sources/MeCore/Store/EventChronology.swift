import Foundation

package enum EventChronology {
    private static let catchAllEraWidth = 1000

    package static func effectiveEra(of event: Event) -> String {
        if !event.date.era.isEmpty { return event.date.era }
        return event.era
    }

    package static func effectiveEra(of event: Event, from eras: [Era]) -> String {
        let explicit = effectiveEra(of: event)
        if !explicit.isEmpty { return explicit }
        return derivedEra(of: event, from: eras)
    }

    package static func derivedEra(of event: Event, from eras: [Era]) -> String {
        guard let year = event.date.startYear ?? event.date.endYear else { return "" }
        let containing = eras.filter { era in
            guard let range = eraRange(of: era) else { return false }
            return range.contains(year)
        }
        let specific = containing.filter { !isCatchAll($0) }
        return latestEnding(in: specific.isEmpty ? containing : specific)
    }

    package static func isCatchAll(_ era: Era) -> Bool {
        guard let range = eraRange(of: era) else { return false }
        return range.upperBound - range.lowerBound > catchAllEraWidth
    }

    private static func latestEnding(in eras: [Era]) -> String {
        var best: (name: String, end: Int)?
        for era in eras {
            guard let range = eraRange(of: era) else { continue }
            guard let current = best else {
                best = (era.name, range.upperBound)
                continue
            }
            if range.upperBound > current.end || (range.upperBound == current.end && era.name < current.name) {
                best = (era.name, range.upperBound)
            }
        }
        return best?.name ?? ""
    }

    package static func eraRange(of era: Era) -> ClosedRange<Int>? {
        let years = [
            era.startDate.startYear, era.startDate.endYear,
            era.endDate.startYear, era.endDate.endYear
        ].compactMap { $0 }
        guard let lo = years.min(), let hi = years.max() else { return nil }
        return lo...hi
    }

    package static func eraBounds(from eras: [Era]) -> [String: Int] {
        var bounds: [String: Int] = [:]
        for era in eras {
            guard let year = earliestYear(of: era) else { continue }
            let key = era.name.lowercased()
            bounds[key] = min(bounds[key] ?? .max, year)
        }
        return bounds
    }

    package static func earliestYear(of era: Era) -> Int? {
        [era.startDate.sortValue, era.endDate.sortValue]
            .filter { $0 != Int.min }
            .min()
    }

    package static func effectiveYear(of event: Event, eraBounds: [String: Int]) -> Int? {
        if let year = event.date.startYear ?? event.date.endYear { return year }
        let era = effectiveEra(of: event)
        guard !era.isEmpty else { return nil }
        return eraBounds[era.lowercased()]
    }

    package static func orderDateGroups(_ keys: [String], eraBounds: [String: Int]) -> [String] {
        keys.sorted { lhs, rhs in
            let lhsRank = groupRank(lhs, eraBounds: eraBounds)
            let rhsRank = groupRank(rhs, eraBounds: eraBounds)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhsRank == 0 {
                let lhsYear = eraBounds[lhs.lowercased()] ?? Int.max
                let rhsYear = eraBounds[rhs.lowercased()] ?? Int.max
                if lhsYear != rhsYear { return lhsYear < rhsYear }
            }
            return lhs < rhs
        }
    }

    private static func groupRank(_ key: String, eraBounds: [String: Int]) -> Int {
        if key == "Unknown" { return 2 }
        return eraBounds[key.lowercased()] != nil ? 0 : 1
    }
}
