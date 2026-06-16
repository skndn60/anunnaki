import Foundation
import SwiftUI
import SwiftData

@Model
package final class FigureType {
    package var name: String
    package var icon: String
    package var colorHex: String

    @Relationship(deleteRule: .deny, inverse: \Figure.figureType)
    package var figures: [Figure] = []

    package var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    package init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}

package extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hex: String {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return "000000" }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
