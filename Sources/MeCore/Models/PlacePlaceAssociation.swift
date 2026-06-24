import Foundation
import SwiftData

/// A relationship between two places.
/// E.g. E-kur is located within Nippur, Eridu is near Ur.
@Model
package final class PlacePlaceAssociation {
    package var fromPlace: Place?
    package var toPlace: Place?
    package var roleType: PlacePlaceRoleType?
    package var source: String

    package init(
        fromPlace: Place? = nil,
        toPlace: Place? = nil,
        roleType: PlacePlaceRoleType? = nil,
        source: String = ""
    ) {
        self.fromPlace = fromPlace
        self.toPlace = toPlace
        self.roleType = roleType
        self.source = source
    }
}
