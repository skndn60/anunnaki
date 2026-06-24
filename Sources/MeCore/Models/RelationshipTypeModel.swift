import Foundation
import SwiftUI
import SwiftData

@Model
package final class RelationshipType {
    package var name: String
    package var icon: String
    package var colorHex: String
    package var category: String

    @Relationship(deleteRule: .deny, inverse: \Relationship.relationshipType)
    package var relationships: [Relationship] = []

    package var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    package init(name: String, icon: String, colorHex: String, category: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.category = category
    }
}
