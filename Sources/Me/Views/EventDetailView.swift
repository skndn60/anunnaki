import SwiftUI
import SwiftData

/// Detail panel showing all properties of a selected event.
struct EventDetailView: View {
    let event: Event
    var onSelectFigure: ((Figure) -> Void)?
    var onSelectPlace: ((Place) -> Void)?
    var onSelectImage: ((ImageAsset) -> Void)?
    var backLabel: String?
    var onBack: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @State private var showFigureLinkPopover = false
    @State private var figureSearchText = ""
    @State private var showPlaceLinkPopover = false
    @State private var placeSearchText = ""
    @State private var selectedPlaceForLink: Place?
    @State private var selectedPlaceRole: EventPlaceRoleType?

    private var involvedFigures: [Figure] { event.involvedFigures }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let backLabel, let onBack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.caption2.weight(.semibold))
                            Text("Back to \(backLabel)")
                                .font(.caption)
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .pointingHand()
                }

                // Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(eventColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: eventIcon)
                                .foregroundStyle(eventColor)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.name)
                            .font(.title2.bold())
                        Text(event.eventType?.name ?? "Other")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if event.isConcept {
                        Text("Concept")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(.orange.opacity(0.12))
                            )
                    }
                }

                // Stickies
                StickyNoteSection(stickies: event.stickies) { text in
                    let note = StickyNote(text: text, event: event)
                    modelContext.insert(note)
                }

                Divider()

                // Properties
                LazyVGrid(columns: [GridItem(.fixed(80), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                    PropertyRow(label: "Date", value: event.date.displayLabel)
                    if !event.era.isEmpty {
                        PropertyRow(label: "Era", value: event.era)
                    }
                    if !event.source.isEmpty {
                        PropertyRow(label: "Source", value: event.source)
                    }
                }

                // Description
                if !event.eventDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(event.eventDescription)
                            .font(.body)
                    }
                }

                // Involved Figures
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Involved Figures")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Button(action: { showFigureLinkPopover = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .help("Link a figure")
                        .popover(isPresented: $showFigureLinkPopover) {
                            EventFigureLinkPopover(
                                event: event,
                                searchText: $figureSearchText,
                                isPresented: $showFigureLinkPopover
                            )
                            .frame(width: 340, height: 400)
                        }
                    }

                    if involvedFigures.isEmpty {
                        Text("No figures linked")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(involvedFigures) { figure in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(figure.figureType?.color.opacity(0.2) ?? .gray.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Text(figure.gender.symbol)
                                            .font(.system(size: 12))
                                    )

                                VStack(alignment: .leading, spacing: 1) {
                                    Button(action: { onSelectFigure?(figure) }) {
                                        Text(figure.name)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.accentColor)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                    .pointingHand()
                                    if !figure.title.isEmpty {
                                        Text(figure.title)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }

                                Text(figure.figureType?.name ?? "Unknown")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Citations
                if !eventCitations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sources & Citations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(eventCitations) { citation in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundStyle(.brown)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(citation.source?.name ?? "Unknown"), \(citation.safeLocation)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(citation.safeNote)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                        }
                    }
                }

                // Associated places
                let associatedPlaces = event.placeAssociations
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Locations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Button(action: { showPlaceLinkPopover = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .help("Link a place")
                        .popover(isPresented: $showPlaceLinkPopover) {
                            EventPlaceLinkPopover(
                                event: event,
                                searchText: $placeSearchText,
                                selectedPlace: $selectedPlaceForLink,
                                selectedRole: $selectedPlaceRole,
                                isPresented: $showPlaceLinkPopover
                            )
                            .frame(width: 340, height: 400)
                        }
                    }

                    if associatedPlaces.isEmpty {
                        Text("No locations linked")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(associatedPlaces) { assoc in
                            if let place = assoc.place {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.callout)
                                        .foregroundStyle(.teal)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Button(action: { onSelectPlace?(place) }) {
                                            Text(place.name)
                                                .font(.callout)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.accentColor)
                                                .underline()
                                        }
                                        .buttonStyle(.plain)
                                        .pointingHand()
                                        HStack(spacing: 4) {
                                            Text(assoc.roleType?.name ?? "—")
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(RoundedRectangle(cornerRadius: 3).fill(Color.teal.opacity(0.12)))
                                            if !place.modernLocation.isEmpty {
                                                Text(place.modernLocation)
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Images
                Divider()
                ImageGallery(
                    title: "Images",
                    images: event.images,
                    onLinkImage: { asset in
                        asset.events.append(event)
                    },
                    onSelectImage: onSelectImage
                )

                // Tags
                if !event.tags.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        FlowLayout(spacing: 4) {
                            ForEach(event.tags) { tag in
                                TagTokenView(tag: tag)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .textSelection(.enabled)
        }
    }

    private var eventIcon: String { event.eventType?.icon ?? "bolt" }

    private var eventCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == event.name && $0.safeEntityType == .event }
    }

    private var eventColor: Color { event.eventType?.color ?? .gray }

}

// MARK: - Figure Link Popover

private struct EventFigureLinkPopover: View {
    let event: Event
    @Binding var searchText: String
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredFigures: [Figure] {
        let linked = Set(event.involvedFigures.map(\.persistentModelID))
        let available = allFigures.filter { !linked.contains($0.persistentModelID) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search figures…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(.textBackgroundColor))
            .cornerRadius(6)

            if filteredFigures.isEmpty {
                Text("No matching figures")
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(filteredFigures, id: \.persistentModelID) { figure in
                    Button(action: { linkFigure(figure) }) {
                        HStack(spacing: 10) {
                            Text(figure.gender.symbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                            Text(figure.name)
                                .font(.body)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private func linkFigure(_ figure: Figure) {
        event.involvedFigures.append(figure)
        try? modelContext.save()
        isPresented = false
    }
}

// MARK: - Place Link Popover

private struct EventPlaceLinkPopover: View {
    let event: Event
    @Binding var searchText: String
    @Binding var selectedPlace: Place?
    @Binding var selectedRole: EventPlaceRoleType?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var allRoles: [EventPlaceRoleType] = []

    private var allPlaces: [Place] {
        (try? modelContext.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredPlaces: [Place] {
        let linked = Set(event.placeAssociations.compactMap { $0.place?.persistentModelID })
        let available = allPlaces.filter { !linked.contains($0.persistentModelID) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search places…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(.textBackgroundColor))
            .cornerRadius(6)

            if filteredPlaces.isEmpty {
                Text("No matching places")
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(filteredPlaces, id: \.persistentModelID) { place in
                    Button(action: { selectedPlace = place }) {
                        HStack(spacing: 10) {
                            Image(systemName: place.placeType?.icon ?? "mappin")
                                .font(.caption)
                                .foregroundStyle(.teal)
                                .frame(width: 16)
                            Text(place.name)
                                .font(.body)
                            if !place.modernLocation.isEmpty {
                                Text(place.modernLocation)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            if selectedPlace?.persistentModelID == place.persistentModelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Text("Role:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Role", selection: $selectedRole) {
                        Text("Select…").tag(nil as EventPlaceRoleType?)
                        ForEach(allRoles, id: \.persistentModelID) { role in
                            HStack(spacing: 6) {
                                Image(systemName: role.icon)
                                Text(role.name)
                            }
                            .tag(role as EventPlaceRoleType?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.bordered)
                    Button("Link") {
                        createAssociation()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedPlace == nil || selectedRole == nil)
                }
            }
        }
        .padding()
        .onAppear {
            allRoles = (try? modelContext.fetch(FetchDescriptor<EventPlaceRoleType>(sortBy: [SortDescriptor(\.name)]))) ?? []
        }
    }

    private func createAssociation() {
        guard let place = selectedPlace, let role = selectedRole else { return }
        let assoc = EventPlaceAssociation()
        modelContext.insert(assoc)
        event.placeAssociations.append(assoc)
        place.eventAssociations.append(assoc)
        role.associations.append(assoc)
        try? modelContext.save()
    }
}
