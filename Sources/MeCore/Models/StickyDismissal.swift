import Foundation
import SwiftData

/// A user's explicit "reviewed this auto-generated sticky, don't re-create it"
/// decision. Migration review flags are re-added on launch when missing; a
/// dismissal suppresses re-creation for (textPrefix, entity normalized name)
/// until the dismissal row itself is removed.
@Model
package final class StickyDismissal {
    package var textPrefix: String
    package var entityKey: String
    package var createdAt: Date

    package init(textPrefix: String, entityKey: String, createdAt: Date = .now) {
        self.textPrefix = textPrefix
        self.entityKey = entityKey
        self.createdAt = createdAt
    }

    package static func signature(textPrefix: String, entityKey: String) -> String {
        "\(textPrefix)|\(entityKey)"
    }

    package var signature: String {
        Self.signature(textPrefix: textPrefix, entityKey: entityKey)
    }
}