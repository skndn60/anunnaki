import Foundation
import SwiftData

@Model
package final class Timeline: Identifiable {
    package var name: String
    package var timelineDescription: String
    package var orderIndex: Int
    package var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TimelineEntry.timeline)
    package var entries: [TimelineEntry] = []

    package var sortedEntries: [TimelineEntry] {
        (entries).sorted {
            let a = $0.orderIndex
            let b = $1.orderIndex
            if a != b { return a < b }
            return ($0.event?.name ?? "").localizedCaseInsensitiveCompare($1.event?.name ?? "") == .orderedAscending
        }
    }

    package func appendEntry(_ entry: TimelineEntry) {
        let maxIndex = sortedEntries.map(\.orderIndex).max() ?? -1
        entry.orderIndex = maxIndex + 1
        entries.append(entry)
    }

    package func moveEntry(_ entry: TimelineEntry, direction: Int) {
        var sorted = sortedEntries
        guard let idx = sorted.firstIndex(where: { $0.persistentModelID == entry.persistentModelID }) else { return }
        let newIdx = idx + direction
        guard sorted.indices.contains(newIdx) else { return }
        sorted.swapAt(idx, newIdx)
        for (i, e) in sorted.enumerated() { e.orderIndex = i }
    }

    package init(
        name: String = "",
        timelineDescription: String = "",
        orderIndex: Int = 0,
        createdAt: Date = .now,
        entries: [TimelineEntry] = []
    ) {
        self.name = name
        self.timelineDescription = timelineDescription
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.entries = entries
    }
}