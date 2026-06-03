import SwiftUI

extension Figure.FigureType {
    var color: Color {
        switch self {
        case .primordial: return .purple
        case .deity: return .blue
        case .semiDivine: return .orange
        case .human: return .green
        }
    }

    var icon: String {
        switch self {
        case .primordial: return "sparkles"
        case .deity: return "star.fill"
        case .semiDivine: return "star.leadinghalf.filled"
        case .human: return "person.fill"
        }
    }
}
