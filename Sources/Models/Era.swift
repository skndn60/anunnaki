import Foundation
import SwiftData

/// Represents a mythological or historical era for the timeline.
@Model
final class Era {
    var name: String
    var orderIndex: Int
    var eraDescription: String
    var startDate: MythologicalDate
    var endDate: MythologicalDate

    init(
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
}
