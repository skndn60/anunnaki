import Foundation
import SwiftUI
import SwiftData

@Model
package final class EventPlaceRoleType: Equatable, RoleTypeDisplay {
    package var name: String
    package var icon: String
    package var colorHex: String
    /// How the role reads from the other side (e.g. a place's view of an event
    /// location link). Optional for migration safety; falls back to `name`.
    package var reverseName: String?

    @Relationship(deleteRule: .deny, inverse: \EventPlaceAssociation.roleType)
    package var associations: [EventPlaceAssociation] = []

    package var color: Color {
        Color(hex: colorHex)
    }

    package init(name: String, icon: String, colorHex: String, reverseName: String? = nil) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.reverseName = reverseName
    }

    package static func == (lhs: EventPlaceRoleType, rhs: EventPlaceRoleType) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }
}
