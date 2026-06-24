import Foundation
import SwiftUI
import SwiftData

@Model
package final class PlacePlaceRoleType {
    package var name: String
    package var icon: String
    package var colorHex: String

    @Relationship(deleteRule: .deny, inverse: \PlacePlaceAssociation.roleType)
    package var associations: [PlacePlaceAssociation] = []

    package var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    package init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}
