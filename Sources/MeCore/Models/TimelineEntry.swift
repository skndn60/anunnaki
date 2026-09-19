import Foundation
import SwiftData

@Model
package final class TimelineEntry: Identifiable {
    package var timeline: Timeline?
    package var event: Event?
    package var orderIndex: Int
    package var note: String

    @Relationship(deleteRule: .cascade, inverse: \GroupTextBlock.timelineEntry)
    package var blocks: [GroupTextBlock]? = nil

    package var sortedBlocks: [GroupTextBlock] {
        (blocks ?? []).sorted {
            let a = $0.orderIndex ?? Int.max
            let b = $1.orderIndex ?? Int.max
            if a != b { return a < b }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    package func appendBlock(_ block: GroupTextBlock) {
        if blocks == nil { blocks = [] }
        blocks?.append(block)
        let maxIndex = sortedBlocks.compactMap { $0.orderIndex }.max() ?? -1
        block.orderIndex = maxIndex + 1
    }

    package init(
        timeline: Timeline? = nil,
        event: Event? = nil,
        orderIndex: Int = 0,
        note: String = "",
        blocks: [GroupTextBlock]? = nil
    ) {
        self.timeline = timeline
        self.event = event
        self.orderIndex = orderIndex
        self.note = note
        self.blocks = blocks
    }
}