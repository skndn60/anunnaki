import Foundation
import SwiftData

/// A single source attribution for one comparison-table cell. A cell may carry
/// several of these, so a single claim can be supported by multiple works.
/// The `source` records the citable work's name ("Enuma Elish", "SKL", …) and
/// `location` the specific point within it ("Tablet V, lines 120–143"), so a
/// reference is split into work + spot rather than conflated into one string.
/// `sourceRef` links to a `Source` row when one matches (case-insensitive) —
/// never auto-created.
@Model
package final class CellSource: Identifiable {
    /// Free-text citation name ("Enuma Elish", "SKL", "An = Anum Tablet IV", …).
    package var source: String
    /// Specific point within the source, e.g. "Tablet V, lines 120–143".
    /// Optional for migration safety.
    package var location: String?
    /// Linked Source row when a matching one exists.
    package var sourceRef: Source?
    /// The cell this attribution belongs to. Set links via the annotated side
    /// (`PopupTableCell.cellSources`) per the codebase convention.
    package var cell: PopupTableCell?

    package init(source: String = "", location: String? = nil, sourceRef: Source? = nil) {
        self.source = source
        self.location = location
        self.sourceRef = sourceRef
    }
}
