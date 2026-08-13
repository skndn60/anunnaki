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
    package var richDescription: Data?
    package var birthDate: MythologicalDate
    package var deathDate: MythologicalDate
    package var source: String
    package var causeOfDeath: String?
    package var isConcept: Bool
    package var orderIndex: Int
    package var coverageExempt: Bool?
    package var coverageReviewedAt: Date?
    package var reignStartYear: Int?
    package var reignEndYear: Int?
    /// Listed reign duration in years (e.g. the SKL's own figure). Distinct from
    /// `reignStartYear`/`reignEndYear`, which are a chronological date range.
    package var reignYears: Int?

    /// An epithet (praise-title) attached to the figure, e.g. Etana's
    /// "the shepherd who ascended to heaven and consolidated all the foreign countries".
    /// A title, not an alias, so it lives on the figure rather than as an AlternateName.
    package var epithet: String?

    @Relationship
    package var era: Era?

    /// Relationships where this figure is the parent/source
    @Relationship(deleteRule: .cascade, inverse: \Relationship.fromFigure)
    package var outgoingRelationships: [Relationship] = []

    /// Relationships where this figure is the child/target
    @Relationship(deleteRule: .cascade, inverse: \Relationship.toFigure)
    package var incomingRelationships: [Relationship] = []

    /// Alternate names and cross-cultural equivalents
    @Relationship(deleteRule: .cascade, inverse: \AlternateName.figure)
    package var alternateNames: [AlternateName] = []

    /// Alternate names ordered alphabetically by name (for display; the stored
    /// relationship array preserves insertion order).
    package var sortedAlternateNames: [AlternateName] {
        alternateNames.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Events this figure is involved in
    @Relationship(inverse: \Event.involvedFigures)
    package var events: [Event] = []

    /// Images attached to this figure
    @Relationship(deleteRule: .nullify, inverse: \ImageAsset.figures)
    package var images: [ImageAsset] = []

    /// Tags attached to this figure
    @Relationship(deleteRule: .nullify, inverse: \Tag.figures)
    package var tags: [Tag] = []

    /// Places associated with this figure (patron deity of, ruler of, etc.)
    @Relationship(deleteRule: .cascade, inverse: \FigurePlaceAssociation.figure)
    package var placeAssociations: [FigurePlaceAssociation] = []

    /// Things associated with this figure
    @Relationship(deleteRule: .cascade, inverse: \ThingFigureAssociation.figure)
    package var thingAssociations: [ThingFigureAssociation] = []

    /// Sticky notes attached to this figure
    @Relationship(deleteRule: .cascade, inverse: \StickyNote.figure)
    package var stickies: [StickyNote] = []

    /// Groups this figure belongs to
    @Relationship(deleteRule: .cascade, inverse: \FigureGroupAssociation.figure)
    package var groupAssociations: [FigureGroupAssociation] = []

    /// Pantheons this figure belongs to (many-to-many).
    @Relationship(deleteRule: .nullify, inverse: \Pantheon.figures)
    package var pantheons: [Pantheon] = []

    /// Per-pantheon display-name overrides (e.g. Enki appearing as "Ptah" in the Egyptian pantheon).
    @Relationship(deleteRule: .cascade, inverse: \FigurePantheonAssociation.figure)
    package var pantheonAssociations: [FigurePantheonAssociation]? = nil

    @Relationship(inverse: \ContentAttribution.figure)
    package var contentAttributions: [ContentAttribution]? = nil

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
        causeOfDeath: String? = nil,
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
        self.causeOfDeath = causeOfDeath
        self.isConcept = isConcept
        self.orderIndex = orderIndex
    }
}
