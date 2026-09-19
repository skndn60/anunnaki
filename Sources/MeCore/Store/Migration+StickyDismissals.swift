import Foundation
import SwiftData

extension Migration {
    /// Text prefixes of stickies that migrations auto-create as review flags.
    /// Deleting one in the UI records a dismissal (prefix + entity key) so the
    /// migration never re-creates it on a future launch.
    package static let autoStickyPrefixes: [String] = [
        "FROM 26-08-2026 IMPORT",
        "IMPORTED — needs review",
        "IMPORTED — needs review (historical events)",
        "IMPORTED FROM ORACC",
        "Import daily life events",
        "Nergal and Erra are treated as the same deity (syncretism). Historically Erra's cult ran in parallel for centuries (Erra Epic, 8th c. BC) before the name settled as an aspect of Nergal.",
    ]

    package static func isStickyDismissed(textPrefix: String, entityKey: String, context: ModelContext) -> Bool {
        let dismissals = (try? context.fetch(FetchDescriptor<StickyDismissal>())) ?? []
        let target = StickyDismissal.signature(textPrefix: textPrefix, entityKey: entityKey)
        return dismissals.contains { $0.signature == target }
    }

    /// Records a dismissal for a deleted sticky note when its text matches a
    /// known auto-generated review prefix. No-op for user-typed stickies.
    package static func recordStickyDismissal(for note: StickyNote, context: ModelContext) {
        guard let prefix = autoStickyPrefixes.first(where: { note.text.hasPrefix($0) }),
              let entityKey = stickyEntityKey(for: note) else { return }
        guard !isStickyDismissed(textPrefix: prefix, entityKey: entityKey, context: context) else { return }
        context.insert(StickyDismissal(textPrefix: prefix, entityKey: entityKey))
    }

    private static func stickyEntityKey(for note: StickyNote) -> String? {
        if let figure = note.figure { return DuplicateMerger.normalizationKey(figure.name) }
        if let place = note.place { return DuplicateMerger.normalizationKey(place.name) }
        if let event = note.event { return DuplicateMerger.normalizationKey(event.name) }
        if let thing = note.thing { return DuplicateMerger.normalizationKey(thing.name) }
        return nil
    }
}