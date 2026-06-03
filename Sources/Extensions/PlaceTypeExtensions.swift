import SwiftUI

extension Place.PlaceType {
    var color: Color {
        return .teal
    }

    var icon: String {
        switch self {
        case .city: return "building.2"
        case .temple: return "building.columns"
        case .region: return "map"
        case .cosmicRealm: return "sparkles"
        case .mountain: return "mountain.2"
        case .river: return "water.waves"
        case .underworld: return "arrow.down.to.line"
        }
    }
}
