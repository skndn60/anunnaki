import Foundation
import SwiftData

/// Result of a query — what entity was matched and all related data.
enum QueryResult {
    case figure(FigureDossier)
    case place(PlaceDossier)
    case event(EventDossier)
    case figureList(String, [Figure]) // e.g. "children of Anu"
    case noMatch(String)
}

struct FigureDossier {
    let figure: Figure
    let parents: [Figure]
    let children: [Figure]
    let spouses: [Figure]
    let createdBy: [Figure]
    let created: [Figure]
    let events: [Event]
    let places: [Place]
    let placeAssociations: [FigurePlaceAssociation]
    let citations: [Citation]
}

struct PlaceDossier {
    let place: Place
    let events: [Event]
    let figures: [Figure]
}

struct EventDossier {
    let event: Event
    let figures: [Figure]
    let place: Place?
}

/// Resolves natural language queries against the database.
class QueryEngine {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func query(_ input: String) -> QueryResult {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Try to match "children of X", "who are the children of X"
        if let parentName = extractPattern(text, patterns: ["children of ", "sons of ", "daughters of "]) {
            if let figure = resolveFigure(parentName) {
                let children = findChildren(of: figure)
                return .figureList("Children of \(figure.name)", children)
            }
        }

        // Try to match "parents of X", "father of X", "mother of X"
        if let childName = extractPattern(text, patterns: ["parents of ", "father of ", "mother of "]) {
            if let figure = resolveFigure(childName) {
                let parents = findParents(of: figure)
                return .figureList("Parents of \(figure.name)", parents)
            }
        }

        // Try to match "what happened at X", "events at X"
        if let placeName = extractPattern(text, patterns: ["happened at ", "events at ", "happened in "]) {
            if let place = resolvePlace(placeName) {
                return .place(buildPlaceDossier(place))
            }
        }

        // Try to match "who is also known as X", "who is X"
        if let altName = extractPattern(text, patterns: ["also known as ", "known as "]) {
            if let figure = resolveFigureByAlternateName(altName) {
                return .figure(buildFigureDossier(figure))
            }
        }

        // Try direct entity match
        if let figure = resolveFigure(text) {
            return .figure(buildFigureDossier(figure))
        }
        if let place = resolvePlace(text) {
            return .place(buildPlaceDossier(place))
        }
        if let event = resolveEvent(text) {
            return .event(buildEventDossier(event))
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
                return .figure(buildFigureDossier(figure))
            }
            if let place = resolvePlace(cleaned) {
                return .place(buildPlaceDossier(place))
            }
            if let event = resolveEvent(cleaned) {
                return .event(buildEventDossier(event))
            }
        }

        return .noMatch(input)
    }

    // MARK: - Entity Resolution

    private func resolveFigure(_ name: String) -> Figure? {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
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
        let altNames = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        let query = name.lowercased()
        if let match = altNames.first(where: { $0.name.lowercased() == query || $0.name.lowercased().contains(query) }) {
            return match.figure
        }
        return nil
    }

    private func resolvePlace(_ name: String) -> Place? {
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let query = name.lowercased()
        if let match = places.first(where: { $0.name.lowercased() == query }) {
            return match
        }
        return places.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }

    private func resolveEvent(_ name: String) -> Event? {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let query = name.lowercased()
        if let match = events.first(where: { $0.name.lowercased() == query }) {
            return match
        }
        return events.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }

    // MARK: - Dossier Builders

    private func buildFigureDossier(_ figure: Figure) -> FigureDossier {
        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []

        let parents = relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }

        let children = relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }

        let spouses = relationships
            .filter { $0.relationshipType == .spouse && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }

        let createdBy = relationships
            .filter { $0.relationshipType == .creator && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }

        let created = relationships
            .filter { $0.relationshipType == .creator && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }

        let figureEvents = events.filter { $0.involvedFigures.contains(where: { $0.persistentModelID == figure.persistentModelID }) }

        let figurePlaces = Array(Set(figureEvents.compactMap { $0.place }))

        let figureCitations = citations.filter { $0.safeEntityName == figure.name && $0.safeEntityType == .figure }

        return FigureDossier(
            figure: figure, parents: parents, children: children,
            spouses: spouses, createdBy: createdBy, created: created,
            events: figureEvents, places: figurePlaces,
            placeAssociations: figure.placeAssociations,
            citations: figureCitations
        )
    }

    private func buildPlaceDossier(_ place: Place) -> PlaceDossier {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let placeEvents = events.filter { $0.place?.persistentModelID == place.persistentModelID }
        let figures = Array(Set(placeEvents.flatMap { $0.involvedFigures }))
        return PlaceDossier(place: place, events: placeEvents, figures: figures)
    }

    private func buildEventDossier(_ event: Event) -> EventDossier {
        return EventDossier(event: event, figures: event.involvedFigures, place: event.place)
    }

    // MARK: - Relationship Queries

    private func findChildren(of figure: Figure) -> [Figure] {
        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        return relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func findParents(of figure: Figure) -> [Figure] {
        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        return relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
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
}
