import Foundation
import SwiftUI
import SwiftData

@Model
package final class EventPlaceRoleType: Equatable {
    package var name: String
    package var icon: String
    package var colorHex: String

    @Relationship(deleteRule: .deny, inverse: \EventPlaceAssociation.roleType)
    package var associations: [EventPlaceAssociation] = []

    package var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    package init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    package static func == (lhs: EventPlaceRoleType, rhs: EventPlaceRoleType) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }
}
