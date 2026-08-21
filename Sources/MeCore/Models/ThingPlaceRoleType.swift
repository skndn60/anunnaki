import Foundation
import SwiftUI
import SwiftData

@Model
package final class ThingPlaceRoleType: RoleTypeDisplay {
    package var name: String
    package var icon: String
    package var colorHex: String
    /// How the role reads from the other side (e.g. a place's view of a thing
    /// location link). Optional for migration safety; falls back to `name`.
    package var reverseName: String?

    @Relationship(deleteRule: .deny, inverse: \ThingPlaceAssociation.roleType)
    package var associations: [ThingPlaceAssociation] = []

    package var color: Color {
        Color(hex: colorHex)
    }

    package init(name: String, icon: String, colorHex: String, reverseName: String? = nil) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.reverseName = reverseName
    }
}
