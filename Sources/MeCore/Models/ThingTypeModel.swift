import Foundation
import SwiftUI
import SwiftData

@Model
package final class ThingType {
    package var name: String
    package var icon: String
    package var colorHex: String

    @Relationship(deleteRule: .deny, inverse: \Thing.thingType)
    package var things: [Thing] = []

    package var color: Color {
        Color(hex: colorHex)
    }

    package init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}
