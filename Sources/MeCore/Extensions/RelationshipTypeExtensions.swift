import SwiftUI

extension Relationship.RelationshipType {
    package var color: Color {
        switch self {
        case .father: return .blue
        case .mother: return .pink
        case .spouse: return .red
        case .consort: return .purple
        case .sibling: return .orange
        case .uncle: return .teal
        case .aunt: return .teal
        case .creator: return .purple
        case .commander: return .yellow
        case .servant: return .brown
        case .ally: return .green
        case .enemy: return .red
        case .worshipper: return .indigo
        }
    }

    package var icon: String {
        switch self {
        case .father: return "arrow.down"
        case .mother: return "arrow.down"
        case .spouse: return "heart"
        case .consort: return "heart.circle"
        case .sibling: return "arrow.left.arrow.right"
        case .uncle: return "person.line.dotted.person"
        case .aunt: return "person.line.dotted.person"
        case .creator: return "wand.and.stars"
        case .commander: return "shield.lefthalf.filled"
        case .servant: return "hand.raised"
        case .ally: return "handshake"
        case .enemy: return "flame"
        case .worshipper: return "heart.circle.fill"
        }
    }
}
