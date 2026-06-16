import Foundation
import SwiftData

/// A relationship between two places.
/// E.g. E-kur is located within Nippur, Eridu is near Ur.
@Model
package final class PlacePlaceAssociation {
    package var fromPlace: Place?
    package var toPlace: Place?
    package var role: Role
    package var source: String

    package enum Role: String, Codable, CaseIterable, Hashable {
        case locatedWithin = "Located Within"
        case nearTo = "Near To"
        case partOf = "Part Of"
        case ruledFrom = "Ruled From"
        case connectedTo = "Connected To"
        case opposedTo = "Opposed To"
    }

    package init(
        fromPlace: Place? = nil,
        toPlace: Place? = nil,
        role: Role = .locatedWithin,
        source: String = ""
    ) {
        self.fromPlace = fromPlace
        self.toPlace = toPlace
        self.role = role
        self.source = source
    }
}
