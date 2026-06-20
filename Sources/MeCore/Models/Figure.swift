import Foundation
import SwiftData

/// Represents a deity, semi-divine being, or human in the mythological lineage.
@Model
package final class Figure {
    package var name: String
    package var disambiguation: String?
    package var title: String
    package var figureType: FigureType?
    package var gender: Gender
    package var domain: String
    package var figureDescription: String
    package var birthDate: MythologicalDate
    package var deathDate: MythologicalDate
    package var source: String
    package var isConcept: Bool
    package var orderIndex: Int

    /// Relationships where this figure is the parent/source
    @Relationship(deleteRule: .cascade, inverse: \Relationship.fromFigure)
    package var outgoingRelationships: [Relationship] = []

    /// Relationships where this figure is the child/target
    @Relationship(deleteRule: .cascade, inverse: \Relationship.toFigure)
    package var incomingRelationships: [Relationship] = []

    /// Alternate names and cross-cultural equivalents
    @Relationship(deleteRule: .cascade, inverse: \AlternateName.figure)
    package var alternateNames: [AlternateName] = []

    /// Images attached to this figure
    @Relationship(deleteRule: .nullify, inverse: \ImageAsset.figures)
    package var images: [ImageAsset] = []

    /// Tags attached to this figure
    @Relationship(deleteRule: .nullify, inverse: \Tag.figures)
    package var tags: [Tag] = []

    /// Places associated with this figure (patron deity of, ruler of, etc.)
    @Relationship(deleteRule: .cascade, inverse: \FigurePlaceAssociation.figure)
    package var placeAssociations: [FigurePlaceAssociation] = []

    package enum Gender: String, Codable, CaseIterable, Hashable {
        case male = "Male"
        case female = "Female"
        case nonBinary = "Non-Binary"
        case unknown = "Unknown"

        package var symbol: String {
            switch self {
            case .male: return "♂"
            case .female: return "♀"
            case .nonBinary: return "⚧"
            case .unknown: return "?"
            }
        }
    }

    package init(
        name: String = "",
        disambiguation: String? = nil,
        title: String = "",
        figureType: FigureType? = nil,
        gender: Gender = .unknown,
        domain: String = "",
        figureDescription: String = "",
        birthDate: MythologicalDate = .unknown,
        deathDate: MythologicalDate = .unknown,
        source: String = "",
        isConcept: Bool = false,
        orderIndex: Int = 0
    ) {
        self.name = name
        self.disambiguation = disambiguation
        self.title = title
        self.figureType = figureType
        self.gender = gender
        self.domain = domain
        self.figureDescription = figureDescription
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.source = source
        self.isConcept = isConcept
        self.orderIndex = orderIndex
    }
}
