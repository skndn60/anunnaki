import Foundation
import SwiftData

/// Represents a deity, semi-divine being, or human in the mythological lineage.
@Model
final class Figure {
    var name: String
    var title: String
    var figureType: FigureType
    var gender: Gender
    var domain: String
    var figureDescription: String
    var birthDate: MythologicalDate
    var deathDate: MythologicalDate
    var source: String

    /// Relationships where this figure is the parent/source
    @Relationship(deleteRule: .cascade, inverse: \Relationship.fromFigure)
    var outgoingRelationships: [Relationship] = []

    /// Relationships where this figure is the child/target
    @Relationship(deleteRule: .cascade, inverse: \Relationship.toFigure)
    var incomingRelationships: [Relationship] = []

    /// Alternate names and cross-cultural equivalents
    @Relationship(deleteRule: .cascade, inverse: \AlternateName.figure)
    var alternateNames: [AlternateName] = []

    /// Images attached to this figure
    @Relationship(deleteRule: .cascade, inverse: \FigureImage.figure)
    var images: [FigureImage] = []

    /// Places associated with this figure (patron deity of, ruler of, etc.)
    @Relationship(deleteRule: .cascade, inverse: \FigurePlaceAssociation.figure)
    var placeAssociations: [FigurePlaceAssociation] = []

    enum FigureType: String, Codable, CaseIterable, Hashable {
        case deity = "Deity"
        case semiDivine = "Semi-Divine"
        case human = "Human"
        case primordial = "Primordial"
    }

    enum Gender: String, Codable, CaseIterable, Hashable {
        case male = "Male"
        case female = "Female"
        case nonBinary = "Non-Binary"
        case unknown = "Unknown"

        var symbol: String {
            switch self {
            case .male: return "♂"
            case .female: return "♀"
            case .nonBinary: return "⚧"
            case .unknown: return "?"
            }
        }
    }

    init(
        name: String = "",
        title: String = "",
        figureType: FigureType = .deity,
        gender: Gender = .unknown,
        domain: String = "",
        figureDescription: String = "",
        birthDate: MythologicalDate = .unknown,
        deathDate: MythologicalDate = .unknown,
        source: String = ""
    ) {
        self.name = name
        self.title = title
        self.figureType = figureType
        self.gender = gender
        self.domain = domain
        self.figureDescription = figureDescription
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.source = source
    }
}
