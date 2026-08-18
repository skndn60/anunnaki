import Foundation
import SwiftUI
import SwiftData

@Model
package final class EventFigureRoleType: Equatable {
    package var name: String
    package var icon: String
    package var colorHex: String

    @Relationship(deleteRule: .deny, inverse: \EventFigureAssociation.roleType)
    package var associations: [EventFigureAssociation] = []

    package var color: Color {
        Color(hex: colorHex)
    }

    package init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    package static func == (lhs: EventFigureRoleType, rhs: EventFigureRoleType) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }
}
