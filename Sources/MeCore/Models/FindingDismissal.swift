import Foundation
import SwiftData

/// A user's explicit "reviewed this, don't flag me again" decision. Data
/// Integrity findings are recomputed on every scan; a dismissal suppresses the
/// matching finding by signature until the user clears dismissals.
@Model
package final class FindingDismissal {
    /// `ConsistencyFinding.Kind.rawValue` or `"issue.<IssueKind>"` for the
    /// structural checks in DataIntegrityView.
    package var kindRaw: String
    package var entityKey: String
    package var createdAt: Date

    package init(kindRaw: String, entityKey: String, createdAt: Date = .now) {
        self.kindRaw = kindRaw
        self.entityKey = entityKey
        self.createdAt = createdAt
    }

    package static func signature(kindRaw: String, entityKey: String) -> String {
        "\(kindRaw)|\(entityKey)"
    }

    package var signature: String {
        Self.signature(kindRaw: kindRaw, entityKey: entityKey)
    }
}
