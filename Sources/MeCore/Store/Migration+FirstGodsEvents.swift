import Foundation
import SwiftData

extension Migration {
    private struct FirstGodsWork: Codable {
        let name: String
        let type: String?
        let language: String?
        let period: String?
        let description: String?
        let url: String?
    }

    private struct FirstGodsCitation: Codable {
        let work: String
        let location: String
        let note: String?
    }

    private struct FirstGodsEvent: Codable {
        let name: String
        let type: String?
        let era: String
        let description: String
        let figures: [String]?
        let places: [String]?
        let citations: [FirstGodsCitation]?
    }

    private struct FirstGodsRoot: Codable {
        let works: [FirstGodsWork]
        let events: [FirstGodsEvent]
    }

    package static func ensureFirstGodsEventsExist(context: ModelContext) {
        let resourceURL: URL? = {
            if let u = Bundle.module.url(forResource: "mythological_events_firstgods", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "mythological_events_firstgods", withExtension: "json")
        }()
        guard let resourceURL, let data = try? Data(contentsOf: resourceURL),
              let root = try? JSONDecoder().decode(FirstGodsRoot.self, from: data) else { return }

        var sourcesByKey: [String: Source] = [:]
        for source in (try? context.fetch(FetchDescriptor<Source>())) ?? [] {
            let key = NameDuplicateCheck.normalizedKey(source.name)
            if sourcesByKey[key] == nil { sourcesByKey[key] = source }
        }

        for work in root.works {
            let key = NameDuplicateCheck.normalizedKey(work.name)
            guard sourcesByKey[key] == nil else { continue }
            let source = Source(
                name: work.name,
                sourceType: work.type.flatMap { Source.SourceType(rawValue: $0) } ?? .ancientText,
                author: "",
                language: work.language ?? "",
                period: work.period ?? "",
                sourceDescription: work.description ?? "",
                publicationInfo: "",
                url: work.url ?? ""
            )
            context.insert(source)
            sourcesByKey[key] = source
        }

        var figuresByKey: [String: Figure] = [:]
        for figure in (try? context.fetch(FetchDescriptor<Figure>())) ?? [] {
            let key = NameDuplicateCheck.normalizedKey(figure.name)
            if figuresByKey[key] == nil { figuresByKey[key] = figure }
        }

        var eventTypesByKey: [String: EventType] = [:]
        for type in (try? context.fetch(FetchDescriptor<EventType>())) ?? [] {
            let key = NameDuplicateCheck.normalizedKey(type.name)
            if eventTypesByKey[key] == nil { eventTypesByKey[key] = type }
        }

        var placesByKey: [String: Place] = [:]
        for place in (try? context.fetch(FetchDescriptor<Place>())) ?? [] {
            let key = NameDuplicateCheck.normalizedKey(place.name)
            if placesByKey[key] == nil { placesByKey[key] = place }
        }

        var existingEventKeys = Set(((try? context.fetch(FetchDescriptor<Event>())) ?? []).map {
            NameDuplicateCheck.normalizedKey($0.name)
        })
        let stickyText = "IMPORTED — needs review (first gods)"

        for spec in root.events {
            let key = NameDuplicateCheck.normalizedKey(spec.name)
            guard !existingEventKeys.contains(key) else { continue }

            let citations = spec.citations ?? []
            let primaryWork = citations
                .compactMap { sourcesByKey[NameDuplicateCheck.normalizedKey($0.work)]?.name }
                .first ?? ""

            let entity = Event(
                name: spec.name,
                eventType: spec.type.flatMap { eventTypesByKey[NameDuplicateCheck.normalizedKey($0)] },
                eventDescription: spec.description,
                date: MythologicalDate(startYear: nil, endYear: nil, era: spec.era, isApproximate: false),
                era: spec.era,
                source: primaryWork
            )
            context.insert(entity)

            for name in spec.figures ?? [] {
                if let figure = figuresByKey[NameDuplicateCheck.normalizedKey(name)] {
                    entity.involvedFigures.append(figure)
                }
            }
            for name in spec.places ?? [] {
                if let place = placesByKey[NameDuplicateCheck.normalizedKey(name)] {
                    entity.placeAssociations.append(EventPlaceAssociation(event: entity, place: place))
                }
            }
            for citation in citations {
                guard let source = sourcesByKey[NameDuplicateCheck.normalizedKey(citation.work)] else { continue }
                context.insert(Citation(
                    source: source,
                    location: citation.location,
                    note: citation.note ?? "",
                    entityType: .event,
                    linkedEntityName: spec.name
                ))
            }
            context.insert(StickyNote(text: stickyText, event: entity))
            existingEventKeys.insert(key)
        }

        Commit.save(context, "ensureFirstGodsEventsExist")
    }
}
