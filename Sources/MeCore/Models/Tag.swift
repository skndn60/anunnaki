import Foundation
import SwiftData

@Model
package final class Tag {
    package var name: String
    package var colorHex: String?
    package var images: [ImageAsset] = []
    package var figures: [Figure] = []
    package var places: [Place] = []
    package var events: [Event] = []
    package var things: [Thing] = []

    package init(name: String, colorHex: String? = nil) {
        self.name = name
        self.colorHex = colorHex
    }
}
