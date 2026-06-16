import Foundation
import SwiftData

/// Represents a relationship between two figures.
@Model
package final class Relationship {
    package var relationshipType: RelationshipType
    package var source: String

    package var fromFigure: Figure?
    package var toFigure: Figure?

    package enum RelationshipType: String, Codable, CaseIterable, Hashable {
        case father = "Father"
        case mother = "Mother"
        case spouse = "Spouse"
        case consort = "Consort"
        case sibling = "Sibling"
        case uncle = "Uncle"
        case aunt = "Aunt"
        case creator = "Creator"
        case commander = "Commander"
        case servant = "Servant"
        case ally = "Ally"
        case enemy = "Enemy"
        case worshipper = "Worshipper"
    }

    package init(
        fromFigure: Figure? = nil,
        toFigure: Figure? = nil,
        relationshipType: RelationshipType = .father,
        source: String = ""
    ) {
        self.fromFigure = fromFigure
        self.toFigure = toFigure
        self.relationshipType = relationshipType
        self.source = source
    }
}
