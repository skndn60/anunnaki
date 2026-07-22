import Foundation
import SwiftUI
import SwiftData

@Model
package final class EventEventRoleType: Equatable {
    package var name: String
    package var icon: String
    package var colorHex: String

    @Relationship(deleteRule: .deny, inverse: \EventEventAssociation.roleType)
    package var associations: [EventEventAssociation] = []

    package var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    package init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    package static func == (lhs: EventEventRoleType, rhs: EventEventRoleType) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }
}
