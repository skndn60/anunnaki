import SwiftUI

extension Event.EventType {
    var color: Color {
        switch self {
        case .creation: return .purple
        case .battle: return .red
        case .flood: return .blue
        case .descent: return .indigo
        case .quest: return .orange
        case .founding: return .teal
        case .death: return .gray
        case .ascension: return .yellow
        case .decree: return .green
        case .other: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .creation: return "sparkles"
        case .battle: return "shield"
        case .flood: return "water.waves"
        case .descent: return "arrow.down.circle"
        case .quest: return "figure.walk"
        case .founding: return "building.2"
        case .death: return "xmark.circle"
        case .ascension: return "arrow.up.circle"
        case .decree: return "scroll"
        case .other: return "bolt"
        }
    }
}
