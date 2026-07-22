import Foundation
import SwiftData

@Model
package final class BlindSpot {
    package var figureName: String
    package var blindSpotType: String
    package var category: String?
    package var spotDescription: String
    package var suggestedQuery: String?
    package var parentType: String?
    package var isResolved: Bool
    package var createdAt: Date
    package var agent: Agent?

    package var typeEnum: BlindSpotType {
        get { BlindSpotType(rawValue: blindSpotType) ?? .missingParent }
        set { blindSpotType = newValue.rawValue }
    }

    package var categoryEnum: BlindSpotCategory {
        get { BlindSpotCategory(rawValue: category ?? "") ?? .unresearched }
        set { category = newValue.rawValue }
    }

    package init(
        figureName: String = "",
        blindSpotType: BlindSpotType = .missingParent,
        category: BlindSpotCategory = .unresearched,
        spotDescription: String = "",
        suggestedQuery: String? = nil,
        isResolved: Bool = false,
        parentType: String? = nil,
        agent: Agent? = nil
    ) {
        self.figureName = figureName
        self.blindSpotType = blindSpotType.rawValue
        self.category = category.rawValue
        self.spotDescription = spotDescription
        self.suggestedQuery = suggestedQuery
        self.isResolved = isResolved
        self.parentType = parentType
        self.createdAt = Date()
        self.agent = agent
    }
}

package enum BlindSpotType: String, Codable, CaseIterable {
    case missingParent = "Missing Parent"
    case missingChild = "Missing Child"
    case missingPlace = "Missing Place Association"
    case missingEvent = "Missing Event"
}

package enum BlindSpotCategory: String, Codable, CaseIterable {
    case unresearched = "Unresearched"
    case knownGap = "Known Gap"
}
