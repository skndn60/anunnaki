import Foundation
import SwiftData

/// Represents a location — a city, temple, region, or cosmic realm.
@Model
final class Place {
    var name: String
    var placeType: PlaceType
    var modernLocation: String // e.g. "Southern Iraq", "Tell al-Muqayyar"
    var placeDescription: String
    var source: String
    var latitude: Double? // nil for cosmic/mythological places
    var longitude: Double?

    /// Figures associated with this place
    @Relationship(deleteRule: .cascade, inverse: \FigurePlaceAssociation.place)
    var figureAssociations: [FigurePlaceAssociation] = []

    enum PlaceType: String, Codable, CaseIterable, Hashable {
        case city = "City"
        case temple = "Temple"
        case region = "Region"
        case cosmicRealm = "Cosmic Realm"
        case mountain = "Mountain"
        case river = "River"
        case underworld = "Underworld"
    }

    init(
        name: String = "",
        placeType: PlaceType = .city,
        modernLocation: String = "",
        placeDescription: String = "",
        source: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.name = name
        self.placeType = placeType
        self.modernLocation = modernLocation
        self.placeDescription = placeDescription
        self.source = source
        self.latitude = latitude
        self.longitude = longitude
    }
}
