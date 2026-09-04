import Foundation
import SwiftData

package struct ImportService {
    package let modelContext: ModelContext

    package init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Wikidata

    package func fetchWikidata(title: String) async -> (ParsedWikidata, [String])? {
        guard let wikidataID = try? await WikiClient().fetchWikidataID(title: title),
              let entity = try? await WikiClient().fetchWikidataEntity(id: wikidataID) else {
            return nil
        }

        let parser = WikidataParser()
        var parsed = parser.parse(entity)

        let relIDs = parsed.relationships.map(\.targetID)
        if !relIDs.isEmpty {
            let labels = (try? await WikiClient().resolveLabels(ids: relIDs)) ?? [:]
            parsed.relationships = parsed.relationships.map { rel in
                (rel.type, rel.targetID, labels[rel.targetID] ?? rel.targetID)
            }
        }

        var details: [String] = []
        if let ft = parsed.figureType { details.append("type: \(ft)") }
        if let g = parsed.gender { details.append("gender: \(g.rawValue)") }
        if !parsed.relationships.isEmpty { details.append("\(parsed.relationships.count) relationship(s)") }

        return (parsed, details)
    }

    // MARK: - Entity Matching

    package func matchFigure(query: String, in figures: [Figure]) -> Figure? {
        let mq = query.lowercased()
        return figures.first(where: { $0.name.lowercased() == mq })
            ?? figures.first(where: { $0.name.lowercased().contains(mq) || mq.contains($0.name.lowercased()) })
            ?? figures.first(where: { $0.alternateNames.contains(where: { $0.name.lowercased() == mq }) })
    }

    package func matchPlace(query: String, in places: [Place]) -> Place? {
        let mq = query.lowercased()
        return places.first(where: { $0.name.lowercased() == mq })
            ?? places.first(where: { $0.name.lowercased().contains(mq) || mq.contains($0.name.lowercased()) })
    }

    package func matchEvent(query: String, in events: [Event]) -> Event? {
        let mq = query.lowercased()
        return events.first(where: { $0.name.lowercased() == mq })
            ?? events.first(where: { $0.name.lowercased().contains(mq) || mq.contains($0.name.lowercased()) })
    }

    // MARK: - Entity Updates

    package func applyToFigure(_ figure: Figure, parsed: ParsedWikidata, extract: String, wikiURL: String, allFigures: [Figure]) {
        if let typeName = parsed.figureType {
            let allTypes: [FigureType] = modelContext.fetchAll()
            if let ft = allTypes.first(where: { $0.name == typeName }), figure.figureType == nil {
                figure.figureType = ft
            }
        }
        if let g = parsed.gender, figure.gender == .unknown { figure.gender = g }
        if figure.figureDescription.isEmpty { figure.figureDescription = extract }
        figure.source = wikiURL

        let allTypes: [RelationshipType] = modelContext.fetchAll()
        for rel in parsed.relationships {
            let targetName = rel.targetLabel.lowercased()
            if let target = allFigures.first(where: { $0.name.lowercased() == targetName }) {
                let isParent = rel.type == "father" || rel.type == "mother"
                let relationship = Relationship(
                    fromFigure: isParent ? target : figure,
                    toFigure: isParent ? figure : target,
                    relationshipType: allTypes.first(where: { $0.name.lowercased() == rel.type.lowercased() }),
                    source: wikiURL
                )
                modelContext.insert(relationship)
            }
        }
    }

    package func applyToPlace(_ place: Place, parsed: ParsedWikidata, extract: String, wikiURL: String) {
        if let typeName = parsed.placeType {
            let allTypes: [PlaceType] = modelContext.fetchAll()
            if let pt = allTypes.first(where: { $0.name == typeName }), place.placeType == nil {
                place.placeType = pt
            }
        }
        if place.placeDescription.isEmpty { place.placeDescription = extract }
        place.source = wikiURL
    }

    package func applyToEvent(_ event: Event, parsed: ParsedWikidata, extract: String, wikiURL: String) {
        if let typeName = parsed.eventType {
            let allTypes: [EventType] = modelContext.fetchAll()
            if let et = allTypes.first(where: { $0.name == typeName }), event.eventType == nil {
                event.eventType = et
            }
        }
        if event.eventDescription.isEmpty { event.eventDescription = extract }
        event.source = wikiURL
    }

    // MARK: - Source & Citation

    @discardableResult
    package func createCitation(sourceTitle: String, wikiURL: String, extract: String, entityName: String, entityType: Citation.EntityType) -> Citation {
        let source = Source(
            name: sourceTitle,
            sourceType: .other,
            author: "Wikipedia",
            language: "English",
            period: "Modern",
            sourceDescription: extract,
            publicationInfo: "Imported from Wikipedia",
            url: wikiURL
        )
        modelContext.insert(source)

        let citation = RelationshipManager(context: modelContext).addCitation(
            to: source,
            location: "Lead section",
            note: extract,
            entityType: entityType,
            linkedEntityName: entityName,
            dedupe: false
        )
        return citation
        return citation
    }

    package func createStandaloneSource(title: String, extract: String, wikiURL: String) {
        let source = Source(
            name: title,
            sourceType: .other,
            author: "Wikipedia",
            language: "English",
            period: "Modern",
            sourceDescription: extract,
            publicationInfo: "Imported from Wikipedia",
            url: wikiURL
        )
        modelContext.insert(source)
    }
}
