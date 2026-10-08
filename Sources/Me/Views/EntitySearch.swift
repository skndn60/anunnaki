import SwiftUI
import SwiftData

/// Typed figure search result: carries the matched alternate name (if the query
/// hit a figure alias) so pickers can show "Enki as Ea" instead of the bare name.
struct FigureSearchResult: Identifiable, Equatable {
    let figure: Figure
    let matchedAlternateName: String?

    var id: PersistentIdentifier { figure.persistentModelID }

    var displayName: String {
        if let alt = matchedAlternateName {
            return "\(figure.name) as \(alt)"
        }
        return figure.name
    }
}

extension Figure {
    func matchedAlternateName(for query: String) -> String? {
        EntitySearch.bestMatch(query: query, in: alternateNames.map(\.name))
    }
}

func searchFigures(_ figures: [Figure], query: String) -> [FigureSearchResult] {
    guard !EntitySearch.fold(query).isEmpty else {
        return figures.map { FigureSearchResult(figure: $0, matchedAlternateName: nil) }
    }
    return figures.compactMap { figure in
        if EntitySearch.matches(query: query, primary: figure.name) {
            return FigureSearchResult(figure: figure, matchedAlternateName: nil)
        }
        if let alt = figure.matchedAlternateName(for: query) {
            return FigureSearchResult(figure: figure, matchedAlternateName: alt)
        }
        return nil
    }
}

/// Typed place search result: carries the matched alternate name (if the query
/// hit a place alias) so pickers can show "Ur as Urim" like figures do.
struct PlaceSearchResult: Identifiable, Equatable {
    let place: Place
    let matchedAlternateName: String?

    var id: PersistentIdentifier { place.persistentModelID }

    var displayName: String {
        if let alt = matchedAlternateName {
            return "\(place.name) as \(alt)"
        }
        return place.name
    }
}

extension Place {
    func matchedAlternateName(for query: String) -> String? {
        EntitySearch.bestMatch(query: query, in: alternateNames.map(\.name))
    }
}

/// Matches places by name, modern location, or alternate name. Mirrors
/// `searchFigures` in returning a typed result so alternate-name matches can
/// be displayed ("Name as Alt").
func searchPlaces(_ places: [Place], query: String) -> [PlaceSearchResult] {
    guard !EntitySearch.fold(query).isEmpty else {
        return places.map { PlaceSearchResult(place: $0, matchedAlternateName: nil) }
    }
    return places.compactMap { place in
        if EntitySearch.matches(query: query, primary: place.name, secondary: [place.modernLocation]) {
            return PlaceSearchResult(place: place, matchedAlternateName: nil)
        }
        if let alt = place.matchedAlternateName(for: query) {
            return PlaceSearchResult(place: place, matchedAlternateName: alt)
        }
        return nil
    }
}

/// Matches events by name or description. Events carry no alternate names.
func searchEvents(_ events: [Event], query: String) -> [Event] {
    guard !EntitySearch.fold(query).isEmpty else { return events }
    return events.filter { event in
        EntitySearch.matches(query: query, primary: event.name, secondary: [event.eventDescription])
    }
}

/// Matches things by name or description. Things carry no alternate names.
func searchThings(_ things: [Thing], query: String) -> [Thing] {
    guard !EntitySearch.fold(query).isEmpty else { return things }
    return things.filter { thing in
        EntitySearch.matches(query: query, primary: thing.name, secondary: [thing.thingDescription])
    }
}
