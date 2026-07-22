import Foundation
import SwiftData

/// Represents a relationship between two figures.
@Model
package final class Relationship {
    package var relationshipType: RelationshipType?
    package var source: String

    package var fromFigure: Figure?
    package var toFigure: Figure?
    package var isPreferred: Bool?
    package var groupID: String = ""

    package init(
        fromFigure: Figure? = nil,
        toFigure: Figure? = nil,
        relationshipType: RelationshipType? = nil,
        source: String = "",
        isPreferred: Bool = false,
        groupID: String = ""
    ) {
        self.fromFigure = fromFigure
        self.toFigure = toFigure
        self.relationshipType = relationshipType
        self.source = source
        self.isPreferred = isPreferred
        self.groupID = groupID
    }
}
