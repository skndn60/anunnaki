import SwiftUI
import SwiftData

struct GlobalSearchView: View {
    let searchText: String
    var onNavigateTo: ((NavigationItem) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @Query private var events: [Event]
    @Query private var sources: [Source]
    @Query private var eras: [Era]
    @Query private var things: [Thing]

    private var query: String { searchText.lowercased().trimmingCharacters(in: .whitespaces) }
    private var hasQuery: Bool { !query.isEmpty }

    private var matchedFigures: [Figure] {
        guard hasQuery else { return [] }
        return figures.filter { f in
            f.name.lowercased().contains(query) ||
            f.title.lowercased().contains(query) ||
            f.domain.lowercased().contains(query) ||
            (f.figureType?.name ?? "").lowercased().contains(query) ||
            f.alternateNames.contains { $0.name.lowercased().contains(query) }
        }
    }

    private var matchedPlaces: [Place] {
        guard hasQuery else { return [] }
        return places.filter {
            $0.name.lowercased().contains(query) ||
            $0.modernLocation.lowercased().contains(query) ||
            ($0.placeType?.name ?? "").lowercased().contains(query)
        }
    }

    private var matchedEvents: [Event] {
        guard hasQuery else { return [] }
        return events.filter {
            $0.name.lowercased().contains(query) ||
            ($0.eventType?.name ?? "").lowercased().contains(query)
        }
    }

    private var matchedThings: [Thing] {
        guard hasQuery else { return [] }
        return things.filter {
            $0.name.lowercased().contains(query) ||
            $0.thingDescription.lowercased().contains(query) ||
            $0.source.lowercased().contains(query)
        }
    }

    private var matchedSources: [Source] {
        guard hasQuery else { return [] }
        return sources.filter {
            $0.name.lowercased().contains(query) ||
            $0.author.lowercased().contains(query)
        }
    }

    private var matchedEras: [Era] {
        guard hasQuery else { return [] }
        return eras.filter { $0.name.lowercased().contains(query) }
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
                                    onNavigateTo?(.figures)
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(figure.figureType?.color ?? .gray)
                                            .frame(width: 10, height: 10)
                                        Text(figure.name)
                                            .font(.body)
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
                                    onNavigateTo?(.places)
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(place.placeType?.color ?? .teal)
                                            .frame(width: 10, height: 10)
                                        Text(place.name)
                                            .font(.body)
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
                                    onNavigateTo?(.events)
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
                                    onNavigateTo?(.things)
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
                                    onNavigateTo?(.sources)
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
                                    onNavigateTo?(.eras)
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
