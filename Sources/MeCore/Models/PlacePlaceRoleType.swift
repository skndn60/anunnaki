import Foundation
import SwiftUI
import SwiftData

@Model
package final class PlacePlaceRoleType: Equatable, RoleTypeDisplay {
    package var name: String
    package var icon: String
    package var colorHex: String
    /// How the role reads from the other side (e.g. a place's view of a
    /// containment link). Optional for migration safety; falls back to `name`.
    package var reverseName: String?

    @Relationship(deleteRule: .deny, inverse: \PlacePlaceAssociation.roleType)
    package var associations: [PlacePlaceAssociation] = []

    package var color: Color {
        Color(hex: colorHex)
    }

    package init(name: String, icon: String, colorHex: String, reverseName: String? = nil) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.reverseName = reverseName
    }

    package static func == (lhs: PlacePlaceRoleType, rhs: PlacePlaceRoleType) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }
}
