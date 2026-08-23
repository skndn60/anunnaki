import Foundation
import SwiftData

/// One persisted row of the Data Integrity work queue. Scan results are
/// written here so they survive relaunches; rows leave only via Fix or
/// Dismiss (or by running a new Scan).
@Model
package final class IntegrityFinding {
    /// `ConsistencyFinding.Kind.rawValue`, or `"issue.<IssueKind>"` for the
    /// structural checks.
    package var kindRaw: String
    package var severityRaw: String
    /// "Figure", "Relationship", … — empty for structural issue rows.
    package var entityKind: String
    /// Engine entityName, or the issue title for structural rows. Part of the
    /// dismissal signature; must stay stable across relaunches.
    package var entityKey: String
    /// finding.message, or the issue description for structural rows.
    package var detail: String
    package var createdAt: Date

    package init(
        kindRaw: String, severityRaw: String, entityKind: String,
        entityKey: String, detail: String, createdAt: Date = .now
    ) {
        self.kindRaw = kindRaw
        self.severityRaw = severityRaw
        self.entityKind = entityKind
        self.entityKey = entityKey
        self.detail = detail
        self.createdAt = createdAt
    }

    package var signature: String {
        FindingDismissal.signature(kindRaw: kindRaw, entityKey: entityKey)
    }
}
