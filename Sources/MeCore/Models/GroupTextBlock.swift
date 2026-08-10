import Foundation
import SwiftData

/// A free-form prose block that can be interleaved among a group's members so a
/// group page reads like a book chapter ("create a Story").
@Model
package final class GroupTextBlock: Identifiable {
    /// The group this prose block belongs to.
    package var group: FigureGroup?

    /// Optional heading shown above the prose.
    package var title: String

    /// The prose body.
    package var text: String

    /// Rich-text version of `text` (RTF). Optional for migration safety.
    package var richText: Data?

    /// Position of this block within the group's unified member+text spine.
    /// Nil means "no explicit position". Optional for migration safety.
    package var orderIndex: Int?

/// Maximum width (pt) for the rendered prose. Nil = fill the page column.
    /// Optional for migration safety.
    package var maxWidth: Double?

    /// Horizontal alignment for the rendered prose ("left" / "center" / "right").
    /// Optional (nil = left) for migration safety.
    package var alignmentRawValue: String?

    /// Title size preset ("small" / "medium" / "large" / "xlarge").
    /// Optional (nil = medium) for migration safety.
    package var titleSizeRawValue: String?

    package var alignment: TextBlockAlignment {
        TextBlockAlignment(rawValue: alignmentRawValue ?? "") ?? .left
    }

    package var titleSize: TextBlockTitleSize {
        TextBlockTitleSize(rawValue: titleSizeRawValue ?? "") ?? .medium
    }

    package enum TextBlockAlignment: String {
        case left, center, right
    }

    package enum TextBlockTitleSize: String, Codable, CaseIterable {
        case small, medium, large, xlarge

        package var displayName: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .xlarge: return "X-Large"
            }
        }
    }

    package init(
        group: FigureGroup? = nil,
        title: String = "",
        text: String = "",
        richText: Data? = nil,
        orderIndex: Int? = nil,
        maxWidth: Double? = nil,
        alignment: TextBlockAlignment = .left,
        titleSize: TextBlockTitleSize = .medium
    ) {
        self.group = group
        self.title = title
        self.text = text
        self.richText = richText
        self.orderIndex = orderIndex
        self.maxWidth = maxWidth
        self.alignmentRawValue = alignment.rawValue
        self.titleSizeRawValue = titleSize.rawValue
    }
}