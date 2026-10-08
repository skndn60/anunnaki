import Foundation
import SwiftData

/// Represents a mythological or historical era for the timeline.
@Model
package final class Era {
    package var name: String
    package var orderIndex: Int
    package var eraDescription: String
    package var startDate: MythologicalDate
    package var endDate: MythologicalDate

    /// Group pages that represent this era (e.g. dynasty group pages).
    @Relationship
    package var groups: [FigureGroup]? = nil

    /// Author-drawn territory boundary as GeoJSON Polygon (migration-safe optional).
    package var boundaryGeoJSON: String? = nil

    package init(
        name: String = "",
        orderIndex: Int = 0,
        eraDescription: String = "",
        startDate: MythologicalDate = .unknown,
        endDate: MythologicalDate = .unknown
    ) {
        self.name = name
        self.orderIndex = orderIndex
        self.eraDescription = eraDescription
        self.startDate = startDate
        self.endDate = endDate
    }

    package var dateSpanLabel: String? {
        guard let range = EventChronology.eraRange(of: self) else { return nil }
        let approx = startDate.isApproximate || endDate.isApproximate
        return MythologicalDate(startYear: range.lowerBound, endYear: range.upperBound, isApproximate: approx).displayLabel
    }

    package var durationYears: Int? {
        guard let range = EventChronology.eraRange(of: self) else { return nil }
        let years = range.upperBound - range.lowerBound
        return years > 0 ? years : nil
    }
}
