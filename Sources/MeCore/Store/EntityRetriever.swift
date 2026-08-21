import Foundation
import SwiftData

/// Shared entity-matching vocabulary and retrieval helpers used by both the
/// deterministic `QueryEngine` and the `OllamaResolver` LLM fallback so name
/// and alias matching (and the context each builds) stay consistent.
///
/// The index knows every matchable name per entity — canonical name, alternate
/// names, and sort-name overrides — so a fix to matching semantics (e.g. alias
/// resolution) propagates to both retrieval paths automatically.
package struct RetrievalIndex {

    private let figures: [Figure]
    private let places: [Place]
    private let events: [Event]
    private let things: [Thing]
    private let alternateNames: [AlternateName]

    private let figureMatchables: [PersistentIdentifier: [String]]
    private let placeMatchables: [PersistentIdentifier: [String]]
    private let eventMatchables: [PersistentIdentifier: [String]]
    private let thingMatchables: [PersistentIdentifier: [String]]

    package init(
        figures: [Figure],
        places: [Place],
        events: [Event],
        things: [Thing],
        alternateNames: [AlternateName]
    ) {
        self.figures = figures
        self.places = places
        self.events = events
        self.things = things
        self.alternateNames = alternateNames

        var figureMap: [PersistentIdentifier: [String]] = [:]
        var placeMap: [PersistentIdentifier: [String]] = [:]
        for f in figures {
            var names = [f.name]
            for alt in alternateNames where alt.figure?.persistentModelID == f.persistentModelID {
                names.append(alt.name)
            }
            figureMap[f.persistentModelID] = names
        }
        for p in places {
            var names = [p.name]
            if let sort = p.sortName, !sort.isEmpty { names.append(sort) }
            for alt in alternateNames where alt.place?.persistentModelID == p.persistentModelID {
                names.append(alt.name)
            }
            placeMap[p.persistentModelID] = names
        }
        var eventMap: [PersistentIdentifier: [String]] = [:]
        for e in events {
            var names = [e.name]
            if let sort = e.sortName, !sort.isEmpty { names.append(sort) }
            eventMap[e.persistentModelID] = names
        }
        var thingMap: [PersistentIdentifier: [String]] = [:]
        for t in things { thingMap[t.persistentModelID] = [t.name] }

        self.figureMatchables = figureMap
        self.placeMatchables = placeMap
        self.eventMatchables = eventMap
        self.thingMatchables = thingMap
    }

    // MARK: - Mention matching

    private static let tokenStopWords: Set<String> = [
        "the", "and", "for", "with", "from", "this", "that", "was", "were",
        "who", "what", "when", "where", "why", "how", "are", "is", "in", "on",
        "at", "of", "a", "an", "to", "it", "its", "their", "them", "they"
    ]

    /// True if `query` references the matchable name `name` — case-insensitive
    /// containment in either direction, or a distinctive whole-word token
    /// shared by both (e.g. "flood" in "The Great Flood").
    package static func mentions(_ name: String, in query: String) -> Bool {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let n = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !q.isEmpty else { return false }
        if q.contains(n) || n.contains(q) { return true }
        let queryTokens = Set(q.split(whereSeparator: { !$0.isLetter }).map(String.init))
        for token in n.split(whereSeparator: { !$0.isLetter }).map(String.init) {
            if token.count >= 3 && !tokenStopWords.contains(token) && queryTokens.contains(token) {
                return true
            }
        }
        return false
    }

    package func figuresMentioned(in query: String) -> [Figure] {
        figures.filter { f in
            (figureMatchables[f.persistentModelID] ?? []).contains { Self.mentions($0, in: query) }
        }
    }

    package func placesMentioned(in query: String) -> [Place] {
        places.filter { p in
            (placeMatchables[p.persistentModelID] ?? []).contains { Self.mentions($0, in: query) }
        }
    }

    package func eventsMentioned(in query: String) -> [Event] {
        events.filter { e in
            (eventMatchables[e.persistentModelID] ?? []).contains { Self.mentions($0, in: query) }
        }
    }

    package func thingsMentioned(in query: String) -> [Thing] {
        things.filter { t in
            (thingMatchables[t.persistentModelID] ?? []).contains { Self.mentions($0, in: query) }
        }
    }

    // MARK: - Resolution

    /// Best single match for a name string, in order: exact canonical name,
    /// alternate-name match, canonical-name containment, query-word containment.
    package func resolveFigure(_ name: String) -> Figure? {
        let query = name.lowercased()
        if let match = figures.first(where: { $0.name.lowercased() == query }) { return match }
        if let match = figures.first(where: { f in
            (figureMatchables[f.persistentModelID] ?? []).contains {
                $0.lowercased() == query || $0.lowercased().contains(query)
            }
        }) { return match }
        if let match = figures.first(where: { $0.name.lowercased().contains(query) }) { return match }
        let queryWords = query.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if queryWords.count > 1,
           let match = figures.first(where: { queryWords.contains($0.name.lowercased()) }) {
            return match
        }
        return nil
    }

    package func resolvePlace(_ name: String) -> Place? {
        let query = name.lowercased()
        if let match = places.first(where: { $0.name.lowercased() == query }) { return match }
        return places.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }

    package func resolveEvent(_ name: String) -> Event? {
        let query = name.lowercased()
        if let match = events.first(where: { $0.name.lowercased() == query }) { return match }
        return events.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }

    package func resolveThing(_ name: String) -> Thing? {
        let query = name.lowercased()
        if let match = things.first(where: { $0.name.lowercased() == query }) { return match }
        return things.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }
}
