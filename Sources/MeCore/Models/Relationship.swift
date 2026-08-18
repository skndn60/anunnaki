import Foundation
import SwiftData

/// Represents a relationship between two figures.
@Model
package final class Relationship {
    package var relationshipType: RelationshipType?
    package var source: String

    /// The `Source` entity backing the free-text `source` string, linked by
    /// `Migration.ensureRelationshipSources`. Optional because legacy rows may
    /// not have been backfilled yet; the string remains the display fallback.
    package var sourceRef: Source?

    package var fromFigure: Figure?
    package var toFigure: Figure?
    package var isPreferred: Bool?
    package var groupID: String = ""

    package init(
        fromFigure: Figure? = nil,
        toFigure: Figure? = nil,
        relationshipType: RelationshipType? = nil,
        source: String = "",
        sourceRef: Source? = nil,
        isPreferred: Bool = false,
        groupID: String = ""
    ) {
        self.fromFigure = fromFigure
        self.toFigure = toFigure
        self.relationshipType = relationshipType
        self.source = source
        self.sourceRef = sourceRef
        self.isPreferred = isPreferred
        self.groupID = groupID
    }

    /// The entity-backed source name, falling back to the legacy free-text string.
    package var sourceDisplayName: String {
        if let name = sourceRef?.name, !name.isEmpty { return name }
        return source
    }

    /// The source URL when the backing `Source` has one.
    package var sourceURL: String? {
        guard let url = sourceRef?.url, !url.isEmpty else { return nil }
        return url
    }
}
