import SwiftUI

extension AlternateName.Tradition {
    package var color: Color {
        switch self {
        case .sumerian: return .blue
        case .akkadian: return .indigo
        case .babylonian: return .purple
        case .assyrian: return .red
        case .egyptian: return .orange
        case .hurrian: return .teal
        case .hittite: return .brown
        case .canaanite: return .green
        case .greek: return .cyan
        case .hebrew: return .mint
        case .persian: return .pink
        case .other: return .gray
        }
    }
}
