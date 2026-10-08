import SwiftUI
import SwiftData

enum GlobalSearchDestination {
    case list(NavigationItem)
    case entity(NavigationItem, id: PersistentIdentifier, name: String)
}

struct GlobalSearchView: View {
    let searchText: String
    var onNavigate: ((GlobalSearchDestination) -> Void)?

    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @Query private var events: [Event]
    @Query private var sources: [Source]
    @Query private var eras: [Era]
    @Query private var things: [Thing]

    private var hasQuery: Bool { !EntitySearch.fold(searchText).isEmpty }

    private func ranked<T>(_ items: [T], _ fields: (T) -> (String, [String])) -> [T] {
        items.compactMap { item -> (T, Int, String)? in
            let field = fields(item)
            guard let s = EntitySearch.score(query: searchText, primary: field.0, secondary: field.1) else { return nil }
            return (item, s, field.0)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.2.localizedCaseInsensitiveCompare(rhs.2) == .orderedAscending
        }
        .map(\.0)
    }

    private var matchedFigures: [Figure] {
        guard hasQuery else { return [] }
        return ranked(figures) { figure in
            (figure.name,
             [figure.title, figure.domain, figure.figureType?.name ?? ""] + figure.alternateNames.map(\.name))
        }
    }

    private var matchedPlaces: [Place] {
        guard hasQuery else { return [] }
        return ranked(places) { place in
            (place.name,
             [place.modernLocation, place.placeType?.name ?? ""] + place.alternateNames.map(\.name))
        }
    }

    private var matchedEvents: [Event] {
        guard hasQuery else { return [] }
        return ranked(events) { event in
            (event.name, [event.eventType?.name ?? "", event.eventDescription])
        }
    }

    private var matchedThings: [Thing] {
        guard hasQuery else { return [] }
        return ranked(things) { thing in
            (thing.name, [thing.thingDescription, thing.source])
        }
    }

    private var matchedSources: [Source] {
        guard hasQuery else { return [] }
        return ranked(sources) { source in
            (source.name, [source.author])
        }
    }

    private var matchedEras: [Era] {
        guard hasQuery else { return [] }
        return ranked(eras) { era in
            (era.name, [])
        }
    }

    private var totalCount: Int {
        matchedFigures.count + matchedPlaces.count + matchedEvents.count + matchedSources.count + matchedEras.count + matchedThings.count
    }

    var body: some View {
        VStack(spacing: 0) {
            if totalCount == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(searchText)\"")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !matchedFigures.isEmpty {
                        Section("Figures (\(matchedFigures.count))") {
                            ForEach(matchedFigures, id: \.persistentModelID) { figure in
                                Button {
                                    onNavigate?(.entity(.figures, id: figure.persistentModelID, name: figure.name))
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(figure.figureType?.color ?? .gray)
                                            .frame(width: 10, height: 10)
                                        Text(figure.name)
                                            .font(.body)
                                        if let alias = figure.matchedAlternateName(for: searchText) {
                                            Text("as \(alias)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(figure.figureType?.name ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !matchedPlaces.isEmpty {
                        Section("Places (\(matchedPlaces.count))") {
                            ForEach(matchedPlaces, id: \.persistentModelID) { place in
                                Button {
                                    onNavigate?(.entity(.places, id: place.persistentModelID, name: place.name))
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(place.placeType?.color ?? .teal)
                                            .frame(width: 10, height: 10)
                                        Text(place.name)
                                            .font(.body)
                                        if let alias = place.matchedAlternateName(for: searchText) {
                                            Text("as \(alias)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(place.placeType?.name ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !matchedEvents.isEmpty {
                        Section("Events (\(matchedEvents.count))") {
                            ForEach(matchedEvents, id: \.persistentModelID) { event in
                                Button {
                                    onNavigate?(.entity(.events, id: event.persistentModelID, name: event.name))
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(event.eventType?.color ?? .orange)
                                            .frame(width: 10, height: 10)
                                        Text(event.name)
                                            .font(.body)
                                        Spacer()
                                        Text(event.eventType?.name ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !matchedThings.isEmpty {
                        Section("Things (\(matchedThings.count))") {
                            ForEach(matchedThings, id: \.persistentModelID) { thing in
                                Button {
                                    onNavigate?(.entity(.things, id: thing.persistentModelID, name: thing.name))
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "cube.box")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                        VStack(alignment: .leading) {
                                            Text(thing.name)
                                                .font(.body)
                                            if !thing.thingDescription.isEmpty {
                                                Text(thing.thingDescription)
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !matchedSources.isEmpty {
                        Section("Sources (\(matchedSources.count))") {
                            ForEach(matchedSources, id: \.persistentModelID) { source in
                                Button {
                                    onNavigate?(.list(.sources))
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "books.vertical")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                        VStack(alignment: .leading) {
                                            Text(source.name)
                                                .font(.body)
                                            Text(source.author)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !matchedEras.isEmpty {
                        Section("Eras (\(matchedEras.count))") {
                            ForEach(matchedEras, id: \.persistentModelID) { era in
                                Button {
                                    onNavigate?(.list(.eras))
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                        Text(era.name)
                                            .font(.body)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}
