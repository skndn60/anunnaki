import Foundation
import SwiftData

/// Represents a location — a city, temple, region, or cosmic realm.
@Model
package final class Place {
    package var name: String
    package var placeType: PlaceType?
    package var modernLocation: String // e.g. "Southern Iraq", "Tell al-Muqayyar"
    package var placeDescription: String
    package var richDescription: Data?
    package var source: String
    package var isConcept: Bool
    package var latitude: Double? // nil for cosmic/mythological places
    package var longitude: Double?

    package var sortName: String?

    package var foundedDate: MythologicalDate?

    /// Figures associated with this place
    @Relationship(deleteRule: .cascade, inverse: \FigurePlaceAssociation.place)
    package var figureAssociations: [FigurePlaceAssociation] = []

    /// Events associated with this place
    @Relationship(deleteRule: .cascade, inverse: \EventPlaceAssociation.place)
    package var eventAssociations: [EventPlaceAssociation] = []

    /// Tags attached to this place
    @Relationship(deleteRule: .nullify, inverse: \Tag.places)
    package var tags: [Tag] = []

    /// Alternate names for this place
    @Relationship(deleteRule: .cascade, inverse: \AlternateName.place)
    package var alternateNames: [AlternateName] = []

    /// Things associated with this place
    @Relationship(deleteRule: .cascade, inverse: \ThingPlaceAssociation.place)
    package var thingAssociations: [ThingPlaceAssociation] = []

    /// Images attached to this place
    @Relationship(deleteRule: .nullify, inverse: \ImageAsset.places)
    package var images: [ImageAsset] = []

    /// Sticky notes attached to this place
    @Relationship(deleteRule: .cascade, inverse: \StickyNote.place)
    package var stickies: [StickyNote] = []

    @Relationship(inverse: \ContentAttribution.place)
    package var contentAttributions: [ContentAttribution]? = nil

    package init(
        name: String = "",
        placeType: PlaceType? = nil,
        modernLocation: String = "",
        placeDescription: String = "",
        source: String = "",
        isConcept: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.name = name
        self.placeType = placeType
        self.modernLocation = modernLocation
        self.placeDescription = placeDescription
        self.source = source
        self.isConcept = isConcept
        self.latitude = latitude
        self.longitude = longitude
    }
}
