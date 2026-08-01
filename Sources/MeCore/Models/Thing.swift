import Foundation
import SwiftData

@Model
package final class Thing {
    package var name: String
    package var thingDescription: String
    package var richDescription: Data?
    package var source: String

    @Relationship(deleteRule: .cascade, inverse: \ThingFigureAssociation.thing)
    package var figureAssociations: [ThingFigureAssociation] = []

    @Relationship(deleteRule: .cascade, inverse: \ThingPlaceAssociation.thing)
    package var placeAssociations: [ThingPlaceAssociation] = []

    @Relationship(deleteRule: .cascade, inverse: \ThingEventAssociation.thing)
    package var eventAssociations: [ThingEventAssociation] = []

    @Relationship(deleteRule: .nullify, inverse: \ImageAsset.things)
    package var images: [ImageAsset] = []

    @Relationship(deleteRule: .nullify, inverse: \Tag.things)
    package var tags: [Tag] = []

    @Relationship(deleteRule: .cascade, inverse: \StickyNote.thing)
    package var stickies: [StickyNote] = []

    /// Groups this thing belongs to
    @Relationship(deleteRule: .cascade, inverse: \FigureGroupAssociation.thing)
    package var groupAssociations: [FigureGroupAssociation] = []

    @Relationship(inverse: \ContentAttribution.thing)
    package var contentAttributions: [ContentAttribution]? = nil

    package var thingType: ThingType?

    package init(name: String = "", thingDescription: String = "", source: String = "") {
        self.name = name
        self.thingDescription = thingDescription
        self.source = source
    }
}
