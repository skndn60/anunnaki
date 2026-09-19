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

    package var coverageExempt: Bool?
    package var coverageReviewedAt: Date?

    /// True when the place has no known coordinates because its actual site has
    /// not been identified (ancient places whose remnants are lost). Such places
    /// are exempt from the "place without coordinates" check.
    package var coordinatesUnknown: Bool?

    package var sortName: String?

    /// True when the place is a culturally significant landmark worth showing in
    /// overview maps even when minor places are hidden. Optional for migration
    /// safety; nil behaves as "not marked major".
    package var isMajor: Bool?

    /// MapLibre zoom threshold (0–14) at which this pin appears on the
    /// Mesopotamia map. Level 0 = always visible on the overview; higher levels
    /// reveal only as you zoom deeper. Optional for migration safety; nil falls
    /// back to `mapZoomLevel` defaults (major→0, minor→5).
    package var zoomLevel: Int?

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

    /// Groups this place belongs to
    @Relationship(deleteRule: .cascade, inverse: \FigureGroupAssociation.place)
    package var groupAssociations: [FigureGroupAssociation] = []

    @Relationship(inverse: \ContentAttribution.place)
    package var contentAttributions: [ContentAttribution]? = nil

    /// Hand-authored territory silhouette (GeoJSON Polygon string) for region
    /// places that have no dynasty era to inherit from (Mesopotamia, Cedar Forest,
    /// Dilmun, Lebanon…), backfilled by `Migration.ensurePlaceBoundaries`.
    /// Wins over the inherited dynasty-era boundary. Optional for migration safety.
    package var storedBoundaryGeoJSON: String?

    /// Effective territory silhouette (GeoJSON Polygon string): a stored
    /// hand-authored boundary wins over the dynasty boundary inherited from the
    /// era of a linked dynasty group.
    package var boundaryGeoJSON: String? {
        if let stored = storedBoundaryGeoJSON, !stored.isEmpty { return stored }
        return boundarySilhouette?.geoJSON
    }

    /// Name of the era the territory silhouette came from (nil when the boundary
    /// is hand-authored or no silhouette exists).
    package var boundarySourceEraName: String? {
        boundarySilhouette?.eraName
    }

    private var boundarySilhouette: (geoJSON: String, eraName: String)? {
        groupAssociations.lazy
            .compactMap { assoc in
                guard let group = assoc.group, let era = group.era,
                      let geo = era.boundaryGeoJSON, !geo.isEmpty else { return nil }
                return (geo, era.name)
            }
            .first
    }

    /// Effective zoom threshold: explicit stored `zoomLevel` wins; otherwise
    /// majors are always visible (level 0) and other places default to level 8
    /// (hidden on the whole-region overview, revealed on the first zoom-in).
    package var mapZoomLevel: Int {
        if let zoomLevel { return zoomLevel }
        return (isMajor ?? false) ? 0 : 8
    }

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
