import Foundation
import SwiftUI
import SwiftData

@Model
package final class EventFigureRoleType: Equatable, RoleTypeDisplay {
    package var name: String
    package var icon: String
    package var colorHex: String
    /// How the role reads from the other side (e.g. a figure's view of an event
    /// involvement link). Optional for migration safety; falls back to `name`.
    package var reverseName: String?

    @Relationship(deleteRule: .deny, inverse: \EventFigureAssociation.roleType)
    package var associations: [EventFigureAssociation] = []

    package var color: Color {
        Color(hex: colorHex)
    }

    package init(name: String, icon: String, colorHex: String, reverseName: String? = nil) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.reverseName = reverseName
    }

    package static func == (lhs: EventFigureRoleType, rhs: EventFigureRoleType) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }
}
