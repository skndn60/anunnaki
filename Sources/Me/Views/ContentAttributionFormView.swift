import SwiftUI
import SwiftData

struct ContentAttributionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let attribution: ContentAttribution?

    @State private var entityKind = "Figure"
    @State private var selectedFigure: FigureSearchResult?
    @State private var selectedPlace: Place?
    @State private var selectedEvent: Event?
    @State private var selectedThing: Thing?
    @State private var searchText = ""
    @State private var selectedSource: Source?
    @State private var propertyName = ""
    @State private var url = ""
    @State private var contentPreview = ""
    @State private var note = ""

    @Query(sort: \Source.name) private var sources: [Source]

    private var isEditing: Bool { attribution != nil }
    private var canSave: Bool {
        selectedFigure != nil || selectedPlace != nil || selectedEvent != nil || selectedThing != nil
    }
    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Attribution" : "Add Attribution")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Entity") {
                    Picker("Type", selection: $entityKind) {
                        Text("Figure").tag("Figure")
                        Text("Place").tag("Place")
                        Text("Event").tag("Event")
                        Text("Thing").tag("Thing")
                    }
                    .onChange(of: entityKind) { _, _ in
                        searchText = ""
                    }

                    entitySelector
                }

                Section("Property") {
                    Picker("Property", selection: $propertyName) {
                        Text("Select\u{2026}").tag("")
                        ForEach(availableProperties, id: \.self) { prop in
                            Text(propertyLabel(prop)).tag(prop)
                        }
                    }
                }

                Section("Source") {
                    Picker("Source", selection: $selectedSource) {
                        Text("None").tag(nil as Source?)
                        ForEach(sources) { source in
                            Text(source.name).tag(source as Source?)
                        }
                    }
                }

                Section("URL") {
                    TextField("https://\u{2026}", text: $url, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...2)
                        .textContentType(.URL)
                }

                Section("Content Preview") {
                    TextField("First ~100 characters\u{2026}", text: $contentPreview, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave || contentPreview.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onAppear { loadIfEditing() }
    }

    @ViewBuilder
    private var entitySelector: some View {
        switch entityKind {
        case "Figure":
            figureSearchList(
                entities: allFigures,
                selected: $selectedFigure
            )
        case "Place":
            entitySearchList(
                entities: allPlaces,
                searchKeyPath: \.name,
                selected: $selectedPlace,
                filter: { $0.name.localizedCaseInsensitiveContains(searchText) }
            )
        case "Event":
            entitySearchList(
                entities: allEvents,
                searchKeyPath: \.name,
                selected: $selectedEvent,
                filter: { $0.name.localizedCaseInsensitiveContains(searchText) }
            )
        case "Thing":
            entitySearchList(
                entities: allThings,
                searchKeyPath: \.name,
                selected: $selectedThing,
                filter: { $0.name.localizedCaseInsensitiveContains(searchText) }
            )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func figureSearchList(entities: [Figure], selected: Binding<FigureSearchResult?>) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search figures\u{2026}", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            if let figure = selected.wrappedValue {
                HStack(spacing: 4) {
                    Text(figure.displayName)
                        .font(.callout)
                    Button { selected.wrappedValue = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
            } else {
                let filtered = searchFigures(entities, query: searchText)
                if filtered.isEmpty {
                    Text("No matching figures")
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 10)
                } else {
                    List(filtered) { result in
                        Button(action: {
                            selected.wrappedValue = result
                            searchText = ""
                        }) {
                            HStack(spacing: 10) {
                                Text(result.displayName)
                                    .font(.body)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
        }
    }

    private func entitySearchList<T: PersistentModel>(
        entities: [T],
        searchKeyPath: KeyPath<T, String>,
        selected: Binding<T?>,
        filter: (T) -> Bool
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search \(entityKind.lowercased())s\u{2026}", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            if let entity = selected.wrappedValue {
                HStack(spacing: 4) {
                    Text(entity[keyPath: searchKeyPath])
                        .font(.callout)
                    Button { selected.wrappedValue = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
            } else {
                let filtered = searchText.isEmpty ? entities : entities.filter(filter)
                if filtered.isEmpty {
                    Text("No matching \(entityKind.lowercased())s")
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 10)
                } else {
                    List(filtered, id: \.persistentModelID) { entity in
                        Button(action: {
                            selected.wrappedValue = entity
                            searchText = ""
                        }) {
                            HStack(spacing: 10) {
                                Text(entity[keyPath: searchKeyPath])
                                    .font(.body)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
        }
    }

    private func loadIfEditing() {
        guard let attribution else { return }
        if let fig = attribution.figure {
            selectedFigure = FigureSearchResult(figure: fig, matchedAlternateName: attribution.figureDisplayName)
        }
        selectedPlace = attribution.place
        selectedEvent = attribution.event
        selectedThing = attribution.thing
        if attribution.figure != nil { entityKind = "Figure" }
        else if attribution.place != nil { entityKind = "Place" }
        else if attribution.event != nil { entityKind = "Event" }
        else if attribution.thing != nil { entityKind = "Thing" }
        selectedSource = attribution.source
        propertyName = attribution.propertyName ?? ""
        url = attribution.url ?? ""
        contentPreview = attribution.contentPreview
        note = attribution.note
    }

    private func save() {
        if let attribution {
            attribution.figure = selectedFigure?.figure
            attribution.figureDisplayName = selectedFigure?.matchedAlternateName
            attribution.place = selectedPlace
            attribution.event = selectedEvent
            attribution.thing = selectedThing
            attribution.source = selectedSource
            attribution.propertyName = propertyName
            attribution.url = url.isEmpty ? nil : url
            attribution.contentPreview = contentPreview
            attribution.note = note
        } else {
            let newAttribution = ContentAttribution(
                figure: selectedFigure?.figure,
                place: selectedPlace,
                event: selectedEvent,
                thing: selectedThing,
                source: selectedSource,
                propertyName: propertyName,
                url: url.isEmpty ? nil : url,
                contentPreview: contentPreview,
                note: note,
                figureDisplayName: selectedFigure?.matchedAlternateName
            )
            modelContext.insert(newAttribution)
        }
        try? modelContext.save()
        dismiss()
    }

    private var availableProperties: [String] {
        switch entityKind {
        case "Figure": return ["figureDescription", "title", "domain", "source", "causeOfDeath", "disambiguation"]
        case "Place": return ["placeDescription", "modernLocation", "source"]
        case "Event": return ["eventDescription", "era", "source", "sortName"]
        case "Thing": return ["thingDescription", "source"]
        default: return []
        }
    }

    private func propertyLabel(_ prop: String) -> String {
        switch prop {
        case "figureDescription", "placeDescription", "eventDescription", "thingDescription": return "Description"
        case "modernLocation": return "Modern Location"
        case "causeOfDeath": return "Cause of Death"
        case "sortName": return "Sort Name"
        case "disambiguation": return "Disambiguation"
        default: return prop.prefix(1).uppercased() + prop.dropFirst()
        }
    }

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var allPlaces: [Place] {
        (try? modelContext.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var allEvents: [Event] {
        (try? modelContext.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var allThings: [Thing] {
        (try? modelContext.fetch(FetchDescriptor<Thing>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
}

private func propertyDisplayLabel(_ prop: String) -> String {
    switch prop {
    case "figureDescription", "placeDescription", "eventDescription", "thingDescription": return "Description"
    case "modernLocation": return "Modern Location"
    case "causeOfDeath": return "Cause of Death"
    case "sortName": return "Sort Name"
    case "disambiguation": return "Disambiguation"
    default: return prop.prefix(1).uppercased() + prop.dropFirst()
    }
}

struct ContentAttributionSection: View {
    let attributions: [ContentAttribution]
    var onAdd: (() -> Void)?
    var onEdit: ((ContentAttribution) -> Void)?
    var onDelete: ((ContentAttribution) -> Void)?

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Attributions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Add attribution")
                }
            }

            if attributions.isEmpty {
                Text("No attributions recorded.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(attributions) { attribution in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "book.and.wrench")
                            .font(.caption)
                            .foregroundStyle(.teal)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(attribution.source?.name ?? "Unknown source")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                if let prop = attribution.propertyName, !prop.isEmpty {
                                    Text("\u{2192}")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(propertyDisplayLabel(prop))
                                        .font(.caption2)
                                        .foregroundStyle(.teal)
                                }
                                if !attribution.note.isEmpty {
                                    Text("\u{2022}")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(attribution.note)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Text(attribution.contentPreview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            if let url = attribution.url, !url.isEmpty, let linkURL = URL(string: url) {
                                Link(displayHost(url), destination: linkURL)
                                    .font(.caption2)
                            }
                        }
                        Spacer(minLength: 8)
                        if let onEdit {
                            Button(action: { onEdit(attribution) }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Edit attribution")
                        }
                        if let onDelete {
                            Button(action: { onDelete(attribution) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Remove attribution")
                        }
                    }
                }
            }
        }
    }
}

private func displayHost(_ url: String) -> String {
    URL(string: url)?.host() ?? url
}
