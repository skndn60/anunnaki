import Foundation
import SwiftData

/// Represents a relationship between two figures.
@Model
final class Relationship {
    var relationshipType: RelationshipType
    var source: String

    var fromFigure: Figure?
    var toFigure: Figure?

    enum RelationshipType: String, Codable, CaseIterable, Hashable {
        case father = "Father"
        case mother = "Mother"
        case spouse = "Spouse"
        case consort = "Consort"
        case sibling = "Sibling"
        case uncle = "Uncle"
        case aunt = "Aunt"
        case creator = "Creator"
    }

    init(
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
