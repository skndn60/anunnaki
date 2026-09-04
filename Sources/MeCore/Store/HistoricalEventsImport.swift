import Foundation
import SwiftData

// Codable mirrors for historical_events_{a,b,c}.json — a curated tranche of
// documented Mesopotamian events (Early Dynastic → fall of Nineveh, 612 BCE)
// plus the kings they involve that are missing from the store.
private struct HistoricalKingImport: Codable {
    let name: String
    let era: String
    let title: String
    let gender: String
    let reignStartYear: Int?
    let reignEndYear: Int?
    let description: String
    let source: String
}

private struct HistoricalEventImport: Codable {
    let name: String
    let type: String
    let era: String
    let year: Int?
    let approximate: Bool?
    let description: String
    let source: String
    let figures: [String]?
    let city: String?
}

private struct HistoricalEventsRoot: Codable {
    let kings: [HistoricalKingImport]
    let events: [HistoricalEventImport]
}

extension Migration {
    /// Import the curated documented-events tranche from historical_events_{a,b,c}.json.
    /// Creates missing kings first (linked to their dynasty era where one exists),
    /// then events (era string, existing event type, involved figures by name,
    /// optional city association). Additive + idempotent; every new row gets an
    /// "IMPORTED — needs review" sticky note.
    package static func ensureHistoricalEventsImportExist(context: ModelContext) {
        let resourceNames = ["historical_events_a", "historical_events_b", "historical_events_c"]
        var roots: [HistoricalEventsRoot] = []
        for name in resourceNames {
            let url: URL? = {
                if let u = Bundle.module.url(forResource: name, withExtension: "json") { return u }
                return Bundle.main.url(forResource: name, withExtension: "json")
            }()
            guard let url, let data = try? Data(contentsOf: url),
                  let root = try? JSONDecoder().decode(HistoricalEventsRoot.self, from: data) else {
                continue
            }
            roots.append(root)
        }
        guard !roots.isEmpty else { return }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var figuresByLower: [String: Figure] = [:]
        for figure in allFigures where figuresByLower[figure.name.lowercased()] == nil {
            figuresByLower[figure.name.lowercased()] = figure
        }

        let erasByLower: [String: Era] = {
            var map: [String: Era] = [:]
            for era in (try? context.fetch(FetchDescriptor<Era>())) ?? [] {
                map[era.name.lowercased()] = era
            }
            return map
        }()

        let figureTypesByLower: [String: FigureType] = {
            var map: [String: FigureType] = [:]
            for type in (try? context.fetch(FetchDescriptor<FigureType>())) ?? [] {
                map[type.name.lowercased()] = type
            }
            return map
        }()

        let eventTypesByLower: [String: EventType] = {
            var map: [String: EventType] = [:]
            for type in (try? context.fetch(FetchDescriptor<EventType>())) ?? [] {
                map[type.name.lowercased()] = type
            }
            return map
        }()

        let placesByLower: [String: Place] = {
            var map: [String: Place] = [:]
            for place in (try? context.fetch(FetchDescriptor<Place>())) ?? [] {
                if map[place.name.lowercased()] == nil {
                    map[place.name.lowercased()] = place
                }
            }
            return map
        }()

        var existingEventNames = Set((try? context.fetch(FetchDescriptor<Event>()))?.map { $0.name.lowercased() } ?? [])
        let kingSticky = "IMPORTED — needs review"
        let eventSticky = "IMPORTED — needs review (historical events)"

        for root in roots {
            for king in root.kings {
                let key = king.name.lowercased()
                guard figuresByLower[key] == nil else { continue }
                let figure = Figure(
                    name: king.name,
                    title: king.title,
                    figureType: figureTypesByLower["human"],
                    gender: Figure.Gender(rawValue: king.gender) ?? .unknown,
                    figureDescription: king.description,
                    source: king.source
                )
                figure.reignStartYear = king.reignStartYear
                figure.reignEndYear = king.reignEndYear
                if !king.era.isEmpty {
                    figure.era = erasByLower[king.era.lowercased()]
                }
                context.insert(figure)
                figuresByLower[key] = figure
                context.insert(StickyNote(text: kingSticky, figure: figure))
            }

            for event in root.events {
                let key = event.name.lowercased()
                guard !existingEventNames.contains(key) else { continue }
                let involved = (event.figures ?? []).compactMap { figuresByLower[$0.lowercased()] }
                let entity = Event(
                    name: event.name,
                    eventType: eventTypesByLower[event.type.lowercased()],
                    eventDescription: event.description,
                    date: MythologicalDate(
                        startYear: event.year,
                        endYear: event.year,
                        era: event.era,
                        isApproximate: event.approximate ?? false
                    ),
                    era: event.era,
                    source: event.source
                )
                context.insert(entity)
                if !involved.isEmpty {
                    entity.involvedFigures.append(contentsOf: involved)
                }
                if let city = event.city, !city.isEmpty, let place = placesByLower[city.lowercased()] {
                    entity.placeAssociations.append(EventPlaceAssociation(event: entity, place: place))
                }
                context.insert(StickyNote(text: eventSticky, event: entity))
                existingEventNames.insert(key)
            }
        }
        try? context.save()
    }
}
