import Foundation
import SwiftData

/// Represents a location — a city, temple, region, or cosmic realm.
@Model
package final class Place {
    package var name: String
    package var placeType: PlaceType?
    package var modernLocation: String // e.g. "Southern Iraq", "Tell al-Muqayyar"
    package var placeDescription: String
    package var source: String
    package var isConcept: Bool
    package var latitude: Double? // nil for cosmic/mythological places
    package var longitude: Double?

    /// Figures associated with this place
    @Relationship(deleteRule: .cascade, inverse: \FigurePlaceAssociation.place)
    package var figureAssociations: [FigurePlaceAssociation] = []

    /// Events associated with this place
    @Relationship(deleteRule: .cascade, inverse: \EventPlaceAssociation.place)
    package var eventAssociations: [EventPlaceAssociation] = []

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
