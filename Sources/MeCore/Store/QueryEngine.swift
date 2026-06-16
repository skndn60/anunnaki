import Foundation
import SwiftData

/// Result of a query — what entity was matched and all related data.
package enum QueryResult {
    case figure(FigureDossier)
    case place(PlaceDossier)
    case event(EventDossier)
    case figureList(String, [Figure]) // e.g. "children of Anu"
    case eventList(String, [Event])   // e.g. "events at Uruk"
    case placeList(String, [Place])   // e.g. "places associated with Enki"
    case noMatch(String)
}

/// Resolves natural language queries against the database.
package class QueryEngine {
    private let context: ModelContext

    package init(context: ModelContext) {
        self.context = context
    }

    package func query(_ input: String) -> QueryResult {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Try possessive patterns: "X's children", "Enki's parents", etc.
        if let parentName = extractPossessivePattern(text, suffixes: ["children", "sons", "daughters"]) {
            if let figure = resolveFigure(parentName) {
                let children = findChildren(of: figure)
                return .figureList("Children of \(figure.name)", children)
            }
        }
        if let childName = extractPossessivePattern(text, suffixes: ["parents", "father", "mother"]) {
            if let figure = resolveFigure(childName) {
                let parents = findParents(of: figure)
                return .figureList("Parents of \(figure.name)", parents)
            }
        }
        if let spouseName = extractPossessivePattern(text, suffixes: ["spouse", "spouses", "consort", "consorts"]) {
            if let figure = resolveFigure(spouseName) {
                let spouses = findSpouses(of: figure)
                return .figureList("Spouses of \(figure.name)", spouses)
            }
        }
        if let siblingName = extractPossessivePattern(text, suffixes: ["siblings", "brother", "sister", "sisters", "brothers"]) {
            if let figure = resolveFigure(siblingName) {
                let siblings = findSiblings(of: figure)
                return .figureList("Siblings of \(figure.name)", siblings)
            }
        }
        if let creatorName = extractPossessivePattern(text, suffixes: ["creator", "creators"]) {
            if let figure = resolveFigure(creatorName) {
                let creators = findCreators(of: figure)
                return .figureList("Creators of \(figure.name)", creators)
            }
        }
        if let creationName = extractPossessivePattern(text, suffixes: ["creations", "creation"]) {
            if let figure = resolveFigure(creationName) {
                let creations = findCreations(of: figure)
                return .figureList("Creations of \(figure.name)", creations)
            }
        }

        // Try possessive patterns for places: "Uruk's events", "Uruk's figures"
        if let placeName = extractPossessivePattern(text, suffixes: ["events", "figures"]) {
            if let place = resolvePlace(placeName) {
                let events = findEvents(byPlaceName: place.name)
                let isEventQuery = text.contains("'s events") || text.contains("'s event")
                if isEventQuery {
                    return .eventList("Events at \(place.name)", events)
                } else {
                    let figures = Array(Set(events.flatMap { $0.involvedFigures }))
                    return .figureList("Figures at \(place.name)", figures)
                }
            }
        }

        // Try possessive patterns for events: "Great Flood's figures", "Great Flood's places"
        if let eventName = extractPossessivePattern(text, suffixes: ["figures", "place", "places", "location", "locations"]) {
            if let event = resolveEvent(eventName) {
                let isPlaceQuery = text.contains("'s place") || text.contains("'s places") || text.contains("'s location") || text.contains("'s locations")
                if isPlaceQuery {
                    let places = event.placeAssociations.compactMap { $0.place }
                    if !places.isEmpty {
                        return .placeList("Places of \(event.name)", places)
                    }
                    return .noMatch(input)
                } else {
                    return .figureList("Figures in \(event.name)", event.involvedFigures)
                }
            }
        }

        // Try "children of X", "child of X", etc.
        if let parentName = extractPattern(text, patterns: ["children of ", "child of ", "sons of ", "son of ", "daughters of ", "daughter of "]) {
            if let figure = resolveFigure(parentName) {
                let children = findChildren(of: figure)
                return .figureList("Children of \(figure.name)", children)
            }
        }

        // Try "parents of X", "father of X", "mother of X"
        if let childName = extractPattern(text, patterns: ["parents of ", "parent of ", "father of ", "mother of "]) {
            if let figure = resolveFigure(childName) {
                let parents = findParents(of: figure)
                return .figureList("Parents of \(figure.name)", parents)
            }
        }

        // Try "siblings of X", "brother of X", "sister of X"
        if let siblingName = extractPattern(text, patterns: ["siblings of ", "sibling of ", "brother of ", "sister of "]) {
            if let figure = resolveFigure(siblingName) {
                let siblings = findSiblings(of: figure)
                return .figureList("Siblings of \(figure.name)", siblings)
            }
        }

        // Try "spouse of X", "consort of X"
        if let spouseName = extractPattern(text, patterns: ["spouse of ", "consort of "]) {
            if let figure = resolveFigure(spouseName) {
                let spouses = findSpouses(of: figure)
                return .figureList("Spouses of \(figure.name)", spouses)
            }
        }

        // Try "creator of X"
        if let creatorName = extractPattern(text, patterns: ["creator of "]) {
            if let figure = resolveFigure(creatorName) {
                let creators = findCreators(of: figure)
                return .figureList("Creators of \(figure.name)", creators)
            }
        }

        // Try "creations of X", "creation of X"
        if let creationName = extractPattern(text, patterns: ["creations of ", "creation of "]) {
            if let figure = resolveFigure(creationName) {
                let creations = findCreations(of: figure)
                return .figureList("Creations of \(figure.name)", creations)
            }
        }

        // Try "places of X", "associated places of X" for figures
        if let figureName = extractPattern(text, patterns: ["places of ", "associated places of "]) {
            if let figure = resolveFigure(figureName) {
                let places = figure.placeAssociations.compactMap { $0.place }
                return .placeList("Places associated with \(figure.name)", places)
            }
        }

        // Try "what happened at X", "events at X"
        if let placeName = extractPattern(text, patterns: ["happened at ", "events at ", "happened in "]) {
            if let place = resolvePlace(placeName) {
                return .place(context.buildPlaceDossier(place))
            }
        }

        // Try "figures at X", "figures in X" for places
        if let placeName = extractPattern(text, patterns: ["figures at ", "figures in "]) {
            if let place = resolvePlace(placeName) {
                let events = findEvents(byPlaceName: place.name)
                let figures = Array(Set(events.flatMap { $0.involvedFigures }))
                return .figureList("Figures at \(place.name)", figures)
            }
        }

        // Try "place of X", "location of X" for events
        if let eventName = extractPattern(text, patterns: ["place of ", "places of ", "location of ", "locations of "]) {
            if let event = resolveEvent(eventName) {
                let places = event.placeAssociations.compactMap { $0.place }
                if !places.isEmpty {
                    return .placeList("Places of \(event.name)", places)
                }
                return .noMatch(input)
            }
        }

        // Try "who is also known as X", "who is X"
        if let altName = extractPattern(text, patterns: ["also known as ", "known as "]) {
            if let figure = resolveFigureByAlternateName(altName) {
                let alias = matchedAliasName(for: figure, query: altName)
                return .figure(context.buildFigureDossier(figure, matchedAlias: alias ?? altName))
            }
        }

        // Try direct entity match
        if let figure = resolveFigure(text) {
            let alias = matchedAliasName(for: figure, query: text)
            return .figure(context.buildFigureDossier(figure, matchedAlias: alias))
        }
        if let place = resolvePlace(text) {
            return .place(context.buildPlaceDossier(place))
        }
        if let event = resolveEvent(text) {
            return .event(context.buildEventDossier(event))
        }

        // Try extracting entity name from question patterns
        let cleaned = text
            .replacingOccurrences(of: "what do we know about ", with: "")
            .replacingOccurrences(of: "tell me about ", with: "")
            .replacingOccurrences(of: "who is ", with: "")
            .replacingOccurrences(of: "who was ", with: "")
            .replacingOccurrences(of: "what is ", with: "")
            .replacingOccurrences(of: "where is ", with: "")
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)

        if !cleaned.isEmpty && cleaned != text {
            if let figure = resolveFigure(cleaned) {
                let alias = matchedAliasName(for: figure, query: cleaned)
                return .figure(context.buildFigureDossier(figure, matchedAlias: alias))
            }
            if let place = resolvePlace(cleaned) {
                return .place(context.buildPlaceDossier(place))
            }
            if let event = resolveEvent(cleaned) {
                return .event(context.buildEventDossier(event))
            }
        }

        return .noMatch(input)
    }

    // MARK: - Entity Resolution

    private func resolveFigure(_ name: String) -> Figure? {
        let figures = context.fetchAll() as [Figure]
        let query = name.lowercased()

        // Exact match
        if let match = figures.first(where: { $0.name.lowercased() == query }) {
            return match
        }
        // Contains match
        if let match = figures.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) }) {
            return match
        }
        // Alternate name match
        return resolveFigureByAlternateName(name)
    }

    private func resolveFigureByAlternateName(_ name: String) -> Figure? {
        let altNames = context.fetchAll() as [AlternateName]
        let query = name.lowercased()
        if let match = altNames.first(where: { $0.name.lowercased() == query || $0.name.lowercased().contains(query) }) {
            return match.figure
        }
        return nil
    }

    private func resolvePlace(_ name: String) -> Place? {
        let places = context.fetchAll() as [Place]
        let query = name.lowercased()
        if let match = places.first(where: { $0.name.lowercased() == query }) {
            return match
        }
        return places.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }

    private func resolveEvent(_ name: String) -> Event? {
        let events = context.fetchAll() as [Event]
        let query = name.lowercased()
        if let match = events.first(where: { $0.name.lowercased() == query }) {
            return match
        }
        return events.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }

    // MARK: - Relationship Queries

    private func findChildren(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func findParents(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findSpouses(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .spouse && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findSiblings(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .sibling && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findCreators(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .creator && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findCreations(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .creator && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func findEvents(byPlaceName placeName: String) -> [Event] {
        let places = context.fetchAll() as [Place]
        guard let place = places.first(where: { $0.name.lowercased() == placeName.lowercased() }) else { return [] }
        return place.eventAssociations.compactMap { $0.event }
    }

    /// Returns the alternate name that best matches the query text, if any.
    private func matchedAliasName(for figure: Figure, query: String) -> String? {
        let q = query.lowercased().trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
        return figure.alternateNames.first(where: {
            let name = $0.name.lowercased()
            return name == q || name.contains(q) || q.contains(name)
        })?.name
    }

    // MARK: - Helpers

    private func extractPattern(_ text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let range = text.range(of: pattern) {
                let extracted = String(text[range.upperBound...]).trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
                if !extracted.isEmpty { return extracted }
            }
        }
        return nil
    }

    /// Extract the entity name from possessive patterns like "X's children".
    /// Looks for "'s <suffix>" and returns the text before "'s".
    private func extractPossessivePattern(_ text: String, suffixes: [String]) -> String? {
        let lower = text.lowercased()
        for suffix in suffixes {
            let pattern = "'s \(suffix)"
            if let range = lower.range(of: pattern) {
                let extracted = String(lower[..<range.lowerBound]).trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
                if !extracted.isEmpty { return extracted }
            }
        }
        return nil
    }
}
