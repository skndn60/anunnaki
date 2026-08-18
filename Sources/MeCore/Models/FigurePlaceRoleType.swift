import Foundation
import SwiftUI
import SwiftData

@Model
package final class FigurePlaceRoleType: Equatable {
    package var name: String
    package var icon: String
    package var colorHex: String

    @Relationship(deleteRule: .deny, inverse: \FigurePlaceAssociation.roleType)
    package var associations: [FigurePlaceAssociation] = []

    package var color: Color {
        Color(hex: colorHex)
    }

    package init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    package static func == (lhs: FigurePlaceRoleType, rhs: FigurePlaceRoleType) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }
}
