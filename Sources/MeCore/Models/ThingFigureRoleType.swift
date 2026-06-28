import Foundation
import SwiftUI
import SwiftData

@Model
package final class ThingFigureRoleType {
    package var name: String
    package var icon: String
    package var colorHex: String

    @Relationship(deleteRule: .deny, inverse: \ThingFigureAssociation.roleType)
    package var associations: [ThingFigureAssociation] = []

    package var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    package init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}
