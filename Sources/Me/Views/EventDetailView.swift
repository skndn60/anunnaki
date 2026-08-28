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
    @State private var showThingLinkPopover = false
    @State private var thingSearchText = ""
    @State private var selectedThingForLink: Thing?
    @State private var selectedThingRole: ThingEventRoleType?
    @Query(sort: \ThingEventRoleType.name) private var thingRoleTypes: [ThingEventRoleType]
    @State private var editFigureAssociation: EventFigureAssociation?
    @State private var editDisplayName = ""
    @State private var showEditDisplayName = false
    @State private var showAddAttribution = false
    @State private var editingAttribution: ContentAttribution?
    @State private var showDescriptionEditor = false
    @State private var editRichDescription: Data? = nil
    @State private var editPlainDescription = ""

    private var figureDisplayList: [(figure: Figure, displayName: String?, association: EventFigureAssociation?)] {
        var result: [(figure: Figure, displayName: String?, association: EventFigureAssociation?)] = event.involvedFigures.map { (figure: $0, displayName: nil, association: nil) }
        for assoc in event.figureAssociations ?? [] {
            if let figure = assoc.figure, !result.contains(where: { $0.figure.persistentModelID == figure.persistentModelID }) {
                result.append((figure: figure, displayName: assoc.displayName, association: assoc))
            }
        }
        return result
    }

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

                    Button {
                        editRichDescription = event.richDescription
                        editPlainDescription = event.eventDescription
                        showDescriptionEditor = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit description")
                }
                .sheet(isPresented: $showDescriptionEditor) {
                    DescriptionEditorSheet(
                        entityName: event.name,
                        richDescription: $editRichDescription,
                        plainDescription: $editPlainDescription
                    )
                    .onDisappear {
                        event.richDescription = editRichDescription
                        event.eventDescription = editPlainDescription
                        try? modelContext.save()
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
                if !event.eventDescription.isEmpty || event.richDescription != nil {
                    AttributedPropertyView(attributions: eventAttributions, propertyName: "eventDescription") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            LinkedDescription(text: event.eventDescription, richData: event.richDescription)
                                .font(.body)
                        }
                    }
                }

                // Attributions
                ContentAttributionSection(
                    attributions: eventAttributions,
                    onAdd: { showAddAttribution = true },
                    onEdit: { editingAttribution = $0 },
                    onDelete: { attribution in
                        modelContext.delete(attribution)
                        try? modelContext.save()
                    }
                )

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

                    if figureDisplayList.isEmpty {
                        Text("No figures linked")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(figureDisplayList, id: \.figure.persistentModelID) { item in
                            let figure = item.figure
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
                                        Text(item.displayName ?? figure.name)
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

                                Spacer()

                                if let assoc = item.association {
                                    Button(action: { editFigureAssociation(assoc) }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Edit display name")
                                }

                                Button(role: .destructive, action: { removeFigure(item) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Remove from event")
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
                        Text("Associated Places")
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

                // Associated Things
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Things")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Button(action: { showThingLinkPopover = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .help("Link a thing")
                        .popover(isPresented: $showThingLinkPopover) {
                            EventThingLinkPopover(
                                event: event,
                                searchText: $thingSearchText,
                                selectedThing: $selectedThingForLink,
                                selectedRole: $selectedThingRole,
                                roleTypes: thingRoleTypes,
                                isPresented: $showThingLinkPopover
                            )
                            .frame(width: 340, height: 400)
                        }
                    }

                    if event.thingAssociations.isEmpty {
                        Text("No things linked")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(event.thingAssociations) { assoc in
                            if let thing = assoc.thing {
                                HStack(spacing: 8) {
                                    Image(systemName: thing.thingType?.icon ?? "shippingbox")
                                        .font(.callout)
                                        .foregroundStyle(thing.thingType?.color ?? .brown)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(thing.name)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                        HStack(spacing: 4) {
                                            Text(assoc.roleType?.displayName(isReverse: true) ?? "—")
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(RoundedRectangle(cornerRadius: 3).fill(Color.brown.opacity(0.12)))
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
                        event.images.append(asset)
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

                // Groups
                EntityGroupsSection(
                    associations: event.groupAssociations,
                    event: event,
                    onJoinWithPropagation: { group in
                        let summary = group.addEventWithPropagation(event: event, in: modelContext)
                        try? modelContext.save()
                    },
                    onRemoveWithDepropagation: { assoc in
                        if let eventToRemove = assoc.event, let group = assoc.group {
                            let removedNames = group.removeEventWithDepropagation(event: eventToRemove, in: modelContext)
                            try? modelContext.save()
                        } else {
                            modelContext.delete(assoc)
                            try? modelContext.save()
                        }
                    }
                )

                Spacer()
            }
            .padding(20)
            .textSelection(.enabled)
        }
        .sheet(isPresented: $showEditDisplayName) {
            if let assoc = editFigureAssociation {
                VStack(spacing: 12) {
                    Text("Edit display name")
                        .font(.headline)
                    TextField("Display name", text: $editDisplayName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel") { showEditDisplayName = false }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("Save") {
                            assoc.displayName = editDisplayName.isEmpty ? nil : editDisplayName
                            try? modelContext.save()
                            showEditDisplayName = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: 320)
            }
        }
        .sheet(isPresented: $showAddAttribution) {
            ContentAttributionFormView(attribution: nil)
        }
        .sheet(item: $editingAttribution) { attribution in
            ContentAttributionFormView(attribution: attribution)
        }
    }

    private var eventIcon: String { event.eventType?.icon ?? "bolt" }

    private var eventAttributions: [ContentAttribution] {
        let all: [ContentAttribution] = modelContext.fetchAll()
        return all.filter { $0.event == event }
    }

    private var eventCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == event.name && $0.safeEntityType == .event }
    }

    private var eventColor: Color { event.eventType?.color ?? .gray }

    private func removeFigure(_ item: (figure: Figure, displayName: String?, association: EventFigureAssociation?)) {
        if let assoc = item.association {
            event.figureAssociations?.removeAll { $0.persistentModelID == assoc.persistentModelID }
            modelContext.delete(assoc)
        } else {
            event.involvedFigures.removeAll { $0.persistentModelID == item.figure.persistentModelID }
        }
        try? modelContext.save()
    }

    private func editFigureAssociation(_ assoc: EventFigureAssociation) {
        editFigureAssociation = assoc
        editDisplayName = assoc.displayName ?? ""
        showEditDisplayName = true
    }
}

// MARK: - Figure Link Popover

private struct EventFigureLinkPopover: View {
    let event: Event
    @Binding var searchText: String
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var selectedFigure: Figure?
    @State private var selectedFigureResult: FigureSearchResult?
    @State private var selectedDisplayName: String = ""
    @State private var isCustomName = false
    @State private var customName = ""

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var linkedFigureIDs: Set<PersistentIdentifier> {
        var ids = Set(event.involvedFigures.map(\.persistentModelID))
        for assoc in event.figureAssociations ?? [] {
            if let figure = assoc.figure {
                ids.insert(figure.persistentModelID)
            }
        }
        return ids
    }

    private var filteredFigures: [FigureSearchResult] {
        let available = allFigures.filter { !linkedFigureIDs.contains($0.persistentModelID) }
        return searchFigures(available, query: searchText)
    }

    private var displayNameOptions: [String] {
        guard let figure = selectedFigure else { return [] }
        var options = [figure.name]
        options += figure.alternateNames.map(\.name)
        return options
    }

    var body: some View {
        VStack(spacing: 12) {
            if let figure = selectedFigure {
                // Confirmation step
                HStack(spacing: 8) {
                    Circle()
                        .fill(figure.figureType?.color.opacity(0.2) ?? .gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(Text(figure.gender.symbol).font(.system(size: 12)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedFigureResult?.displayName ?? figure.name).font(.callout).fontWeight(.medium)
                        if !figure.title.isEmpty {
                            Text(figure.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button { selectedFigure = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Display as:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Display name", selection: $selectedDisplayName) {
                        ForEach(displayNameOptions, id: \.self) { name in
                            Text(name == figure.name ? "\(figure.name) (default)" : name).tag(name)
                        }
                        Divider()
                        Text("Custom…").tag("__custom__")
                    }
                    .pickerStyle(.menu)

                    if isCustomName {
                        TextField("Enter custom name", text: $customName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.bordered)
                    Button("Link") { linkFigure(figure) }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                // Search step
                TextField("Search figures…", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if filteredFigures.isEmpty {
                    Text("No matching figures")
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 20)
                } else {
                    List(filteredFigures) { result in
                        Button(action: { selectFigure(result.figure) }) {
                            HStack(spacing: 10) {
                                Text(result.figure.gender.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                Text(result.displayName)
                                    .font(.body)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .onChange(of: selectedDisplayName) { _, newValue in
            isCustomName = newValue == "__custom__"
        }
    }

    private func selectFigure(_ figure: Figure) {
        let result = FigureSearchResult(figure: figure, matchedAlternateName: figure.matchedAlternateName(for: searchText))
        selectedFigure = figure
        selectedFigureResult = result
        selectedDisplayName = figure.name
        isCustomName = false
        customName = ""
    }

    private func linkFigure(_ figure: Figure) {
        let displayName: String?
        if isCustomName {
            displayName = customName.isEmpty ? nil : customName
        } else {
            displayName = selectedDisplayName == figure.name ? nil : selectedDisplayName
        }
        let assoc = EventFigureAssociation(
            event: event,
            figure: figure,
            displayName: displayName
        )
        modelContext.insert(assoc)
        if event.figureAssociations == nil {
            event.figureAssociations = []
        }
        event.figureAssociations?.append(assoc)
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
            TextField("Search places…", text: $searchText)
                .textFieldStyle(.roundedBorder)

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

// MARK: - Thing Link Popover

private struct EventThingLinkPopover: View {
    let event: Event
    @Binding var searchText: String
    @Binding var selectedThing: Thing?
    @Binding var selectedRole: ThingEventRoleType?
    let roleTypes: [ThingEventRoleType]
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext

    private var allThings: [Thing] {
        (try? modelContext.fetch(FetchDescriptor<Thing>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredThings: [Thing] {
        let linked = Set(event.thingAssociations.compactMap { $0.thing?.persistentModelID })
        let available = allThings.filter { !linked.contains($0.persistentModelID) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search things\u{2026}", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if filteredThings.isEmpty {
                Text("No matching things")
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(filteredThings, id: \.persistentModelID) { thing in
                    Button(action: { selectedThing = thing }) {
                        HStack(spacing: 10) {
                            Image(systemName: thing.thingType?.icon ?? "shippingbox")
                                .font(.caption)
                                .foregroundStyle(thing.thingType?.color ?? .brown)
                                .frame(width: 16)
                            Text(thing.name)
                                .font(.body)
                            Spacer()
                            if selectedThing?.persistentModelID == thing.persistentModelID {
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
                        Text("Select\u{2026}").tag(nil as ThingEventRoleType?)
                        ForEach(roleTypes, id: \.persistentModelID) { role in
                            HStack(spacing: 6) {
                                Image(systemName: role.icon)
                                Text(role.name)
                            }
                            .tag(role as ThingEventRoleType?)
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
                    .disabled(selectedThing == nil)
                }
            }
        }
        .padding()
    }

    private func createAssociation() {
        guard let thing = selectedThing else { return }
        let assoc = ThingEventAssociation(
            thing: thing,
            event: event,
            roleType: selectedRole,
            source: ""
        )
        modelContext.insert(assoc)
        try? modelContext.save()
    }
}
