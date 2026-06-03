import Foundation
import SwiftData

/// A direct association between a figure and a place, with a specific role.
/// E.g. Nanna/Sin is the patron deity of Ur, Gilgamesh is the ruler of Uruk.
@Model
final class FigurePlaceAssociation {
    var figure: Figure?
    var place: Place?
    var role: Role
    var source: String

    enum Role: String, Codable, CaseIterable, Hashable {
        case patronDeity = "Patron Deity"
        case ruler = "Ruler"
        case builder = "Builder"
        case founder = "Founder"
        case bornAt = "Born At"
        case diedAt = "Died At"
        case residentOf = "Resident Of"
        case imprisonedAt = "Imprisoned At"
        case worshippedAt = "Worshipped At"
        case exiledTo = "Exiled To"
    }

    init(
        figure: Figure? = nil,
        place: Place? = nil,
        role: Role = .patronDeity,
        source: String = ""
    ) {
        self.figure = figure
        self.place = place
        self.role = role
        self.source = source
    }
}
