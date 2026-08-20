import Foundation

/// Sequence-driven layout helpers for the post-flood timeline.
///
/// The Sumerian King List reliably provides the order of dynasties and the
/// order of rulers within each dynasty, but its reign lengths and any computed
/// absolute dates are propaganda-grade guesswork. When an era is a SKL dynasty,
/// the timeline should therefore place its ruler chips in reign sequence at
/// equal slots across the era's own band, ignoring dates for positioning.
package enum SKLTimelineLayout {

    /// An era is treated as a SKL dynasty when any of its figures is a SKL entry
    /// (matches how the rest of the codebase identifies SKL figures).
    package static func isDynastyEra(_ figures: [Figure]) -> Bool {
        figures.contains { $0.source.contains("Sumerian King List") }
    }

    /// The figures of a dynasty in SKL reign sequence (`orderIndex`), with a
    /// stable name tie-break for the few figures that share an orderIndex.
    package static func dynastyOrderedFigures(_ figures: [Figure]) -> [Figure] {
        figures.sorted { ($0.orderIndex, $0.name) < ($1.orderIndex, $1.name) }
    }

    /// Equal-slot center years for `count` rulers spread across a `span`-year band.
    /// `count` is clamped to at least 1; a non-positive span yields the band's start.
    package static func dynastySlotCenters(count: Int, spanYears: Int) -> [Int] {
        let n = max(1, count)
        let span = max(1, spanYears)
        guard n > 1 else { return [span / 2] }
        return (0..<n).map { i in
            Int((CGFloat(i) + 0.5) / CGFloat(n) * CGFloat(span))
        }
    }
}