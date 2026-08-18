import SwiftUI
import SwiftData

/// Detail panel showing all properties of a selected place.
struct PlaceDetailView: View {
    let place: Place
    var onSelectFigure: ((Figure) -> Void)?
    var onSelectEvent: ((Event) -> Void)?
    var onSelectImage: ((ImageAsset) -> Void)?
    var backLabel: String?
    var onBack: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var altToDelete: AlternateName?
    @State private var showDeleteAltConfirm = false
    @State private var showAddAltSheet = false
    @State private var showFigureLinkPopover = false
    @State private var figureSearchText = ""
    @State private var selectedFigureForLink: FigureSearchResult?
    @State private var selectedFigureRole: FigurePlaceRoleType?
    @State private var showEventLinkPopover = false
    @State private var eventSearchText = ""
    @State private var selectedEventForLink: Event?
    @State private var selectedEventRole: EventPlaceRoleType?
    @State private var showAddAttribution = false
    @State private var editingAttribution: ContentAttribution?
    @State private var showDescriptionEditor = false
    @State private var editRichDescription: Data? = nil
    @State private var editPlainDescription = ""

    private var relatedEvents: [Event] {
        place.eventAssociations.compactMap { $0.event }
    }

    private var relatedFigures: [Figure] {
        let figureSet = relatedEvents.flatMap { $0.involvedFigures }
        var seen = Set<PersistentIdentifier>()
        return figureSet.filter { seen.insert($0.persistentModelID).inserted }
    }

    private var placeAssociations: [PlacePlaceAssociation] {
        let all: [PlacePlaceAssociation] = modelContext.fetchAll()
        return all.filter { $0.fromPlace == place || $0.toPlace == place }
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
                        .fill(Color.teal.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: placeIcon)
                                .foregroundStyle(.teal)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.title2.bold())
                        Text(place.placeType?.name ?? "City")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if place.isConcept {
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

                    if place.latitude != nil, place.longitude != nil {
                        MapPreviewPopoverButton(place: place)
                    }

                    Button {
                        editRichDescription = place.richDescription
                        editPlainDescription = place.placeDescription
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
                        entityName: place.name,
                        richDescription: $editRichDescription,
                        plainDescription: $editPlainDescription
                    )
                    .onDisappear {
                        place.richDescription = editRichDescription
                        place.placeDescription = editPlainDescription
                        try? modelContext.save()
                    }
                }

                // Stickies
                StickyNoteSection(stickies: place.stickies) { text in
                    let note = StickyNote(text: text, place: place)
                    modelContext.insert(note)
                }

                Divider()

                // Properties
                LazyVGrid(columns: [GridItem(.fixed(110), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                    if !place.source.isEmpty {
                        PropertyRow(label: "Source", value: place.source)
                    }
                    if let founded = place.foundedDate, founded != .unknown {
                        PropertyRow(label: "Founded", value: founded.displayLabel)
                    }
                }
                if !place.modernLocation.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Modern Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(place.modernLocation)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }

                // Historical map
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Map")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    HistoricalMapView(place: place)
                        .frame(height: 260)
                }

                // Description
                if !place.placeDescription.isEmpty || place.richDescription != nil {
                    AttributedPropertyView(attributions: placeAttributions, propertyName: "placeDescription") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            LinkedDescription(text: place.placeDescription, richData: place.richDescription)
                                .font(.body)
                        }
                    }
                }

                // Attributions
                ContentAttributionSection(
                    attributions: placeAttributions,
                    onAdd: { showAddAttribution = true },
                    onEdit: { editingAttribution = $0 },
                    onDelete: { attribution in
                        modelContext.delete(attribution)
                        try? modelContext.save()
                    }
                )

                // Alternate Names
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Also Known As")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Button {
                            showAddAltSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .help("Add alternate name")
                    }

                    if place.alternateNames.isEmpty {
                        Text("No alternate names")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(place.alternateNames) { altName in
                            HStack(spacing: 8) {
                                Text(altName.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text(altName.tradition.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                                Text(altName.nameType.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Button(action: {
                                    altToDelete = altName
                                    showDeleteAltConfirm = true
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help("Delete alternate name")
                            }
                            if !altName.note.isEmpty {
                                Text(altName.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                }

                // Place associations (containment, proximity, etc.)
                if !placeAssociations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Related Places")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(placeAssociations) { assoc in
                            HStack(spacing: 8) {
                                if assoc.fromPlace == place {
                                    Text(assoc.toPlace?.name ?? "?")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                    Text(assoc.roleType?.name ?? "—")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("←")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(place.name)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(place.name)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                    Text("→")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(assoc.roleType?.name ?? "—")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(assoc.fromPlace?.name ?? "?")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                Text(assoc.source)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                // Events at this place
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Events Here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Button(action: { showEventLinkPopover = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .help("Link an event")
                        .popover(isPresented: $showEventLinkPopover) {
                            PlaceEventLinkPopover(
                                place: place,
                                searchText: $eventSearchText,
                                selectedEvent: $selectedEventForLink,
                                selectedRole: $selectedEventRole,
                                isPresented: $showEventLinkPopover
                            )
                            .frame(width: 340, height: 400)
                        }
                    }

                    if relatedEvents.isEmpty {
                        Text("No events linked")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(relatedEvents) { event in
                            HStack(spacing: 8) {
                                Image(systemName: eventIcon(event.eventType))
                                    .font(.caption)
                                    .foregroundStyle(eventColor(event.eventType))
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    Button(action: { onSelectEvent?(event) }) {
                                        Text(event.name)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.accentColor)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                    .pointingHand()
                                    Text(event.date.displayLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // All figures (direct associations + event-derived)
                let allFigures = { () -> [Figure] in
                    let direct = place.figureAssociations.compactMap { $0.figure }
                    var seen = Set<PersistentIdentifier>()
                    var result: [Figure] = []
                    for fig in direct + relatedFigures {
                        if seen.insert(fig.persistentModelID).inserted {
                            result.append(fig)
                        }
                    }
                    return result
                }()

                let figureDisplayNames: [PersistentIdentifier: String] = Dictionary(
                    uniqueKeysWithValues: place.figureAssociations.compactMap { assoc in
                        guard let fig = assoc.figure, let name = assoc.displayName, !name.isEmpty else { return nil }
                        return (fig.persistentModelID, name)
                    }
                )

                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Associated Figures")
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
                            PlaceFigureLinkPopover(
                                place: place,
                                searchText: $figureSearchText,
                                selectedFigure: $selectedFigureForLink,
                                selectedRole: $selectedFigureRole,
                                isPresented: $showFigureLinkPopover
                            )
                            .frame(width: 340, height: 400)
                        }
                    }

                    if allFigures.isEmpty {
                        Text("No figures linked")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        FlowLayout(spacing: 6) {
                            ForEach(allFigures) { figure in
                                Button(action: { onSelectFigure?(figure) }) {
                                    HStack(spacing: 3) {
                                        Text(figure.gender.symbol)
                                            .font(.system(size: 9))
                                        Text(figureDisplayNames[figure.persistentModelID].map { "\(figure.name) as \($0)" } ?? figure.name)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(figure.figureType?.color.opacity(0.1) ?? .gray.opacity(0.1))
                                    )
                                }
                                .buttonStyle(.plain)
                                .pointingHand()
                            }
                        }
                    }
                }

                // Images
                Divider()
                ImageGallery(
                    title: "Images",
                    images: place.images,
                    onLinkImage: { asset in
                        asset.places.append(place)
                    },
                    onSelectImage: onSelectImage
                )

                // Tags
                if !place.tags.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        FlowLayout(spacing: 4) {
                            ForEach(place.tags) { tag in
                                TagTokenView(tag: tag)
                            }
                        }
                    }
                }

                // Groups
                EntityGroupsSection(
                    associations: place.groupAssociations,
                    onCreateAssociation: { group in
                        let assoc = FigureGroupAssociation(place: place)
                        modelContext.insert(assoc)
                        place.groupAssociations.append(assoc)
                        group.figureAssociations.append(assoc)
                        try? modelContext.save()
                    }
                )

                // Citations
                if !placeCitations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sources & Citations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(placeCitations) { citation in
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
            }
            .padding(20)
            .textSelection(.enabled)
        }
        .alert("Delete Alternate Name?", isPresented: $showDeleteAltConfirm, presenting: altToDelete) { altName in
            Button("Delete", role: .destructive) {
                modelContext.delete(altName)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { altName in
            Text("Delete \"\(altName.name)\" (\(altName.tradition.rawValue)) from \(altName.place?.name ?? "?")?")
        }
        .sheet(isPresented: $showAddAltSheet) {
            AlternateNameFormView(alternateName: nil, preSelectedPlace: place)
        }
        .sheet(isPresented: $showAddAttribution) {
            ContentAttributionFormView(attribution: nil)
        }
        .sheet(item: $editingAttribution) { attribution in
            ContentAttributionFormView(attribution: attribution)
        }
    }

    private var placeIcon: String { place.placeType?.icon ?? "mappin" }

    private var placeAttributions: [ContentAttribution] {
        let all: [ContentAttribution] = modelContext.fetchAll()
        return all.filter { $0.place == place }
    }

    private var placeCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == place.name && $0.safeEntityType == .place }
    }

    private func eventIcon(_ type: EventType?) -> String { type?.icon ?? "bolt" }

    private func eventColor(_ type: EventType?) -> Color { type?.color ?? .gray }

}

/// Simple flow layout for wrapping chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Figure Link Popover

private struct PlaceFigureLinkPopover: View {
    let place: Place
    @Binding var searchText: String
    @Binding var selectedFigure: FigureSearchResult?
    @Binding var selectedRole: FigurePlaceRoleType?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var allRoles: [FigurePlaceRoleType] = []
    @State private var comments: String = ""

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredFigures: [FigureSearchResult] {
        let linked = Set(place.figureAssociations.compactMap { $0.figure?.persistentModelID })
        let available = allFigures.filter { !linked.contains($0.persistentModelID) }
        return searchFigures(available, query: searchText)
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search figures…", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if filteredFigures.isEmpty {
                Text("No matching figures")
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(filteredFigures) { result in
                    Button(action: { selectedFigure = result }) {
                        HStack(spacing: 10) {
                            Text(result.figure.gender.symbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                            Text(result.displayName)
                                .font(.body)
                            Spacer()
                            if selectedFigure?.figure.persistentModelID == result.figure.persistentModelID {
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
                        Text("Select…").tag(nil as FigurePlaceRoleType?)
                        ForEach(allRoles, id: \.persistentModelID) { role in
                            HStack(spacing: 6) {
                                Image(systemName: role.icon)
                                Text(role.name)
                            }
                            .tag(role as FigurePlaceRoleType?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Comments:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. first antediluvian king", text: $comments)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
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
                    .disabled(selectedFigure == nil || selectedRole == nil)
                }
            }
        }
        .padding()
        .onAppear {
            allRoles = (try? modelContext.fetch(FetchDescriptor<FigurePlaceRoleType>(sortBy: [SortDescriptor(\.name)]))) ?? []
        }
    }

    private func createAssociation() {
        guard let figure = selectedFigure?.figure, let role = selectedRole else { return }
        let assoc = FigurePlaceAssociation(comments: comments.isEmpty ? nil : comments)
        assoc.displayName = selectedFigure?.matchedAlternateName
        modelContext.insert(assoc)
        place.figureAssociations.append(assoc)
        figure.placeAssociations.append(assoc)
        role.associations.append(assoc)
        try? modelContext.save()
    }
}

// MARK: - Event Link Popover

private struct PlaceEventLinkPopover: View {
    let place: Place
    @Binding var searchText: String
    @Binding var selectedEvent: Event?
    @Binding var selectedRole: EventPlaceRoleType?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var allRoles: [EventPlaceRoleType] = []

    private var allEvents: [Event] {
        (try? modelContext.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredEvents: [Event] {
        let linked = Set(place.eventAssociations.compactMap { $0.event?.persistentModelID })
        let available = allEvents.filter { !linked.contains($0.persistentModelID) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search events…", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if filteredEvents.isEmpty {
                Text("No matching events")
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(filteredEvents, id: \.persistentModelID) { event in
                    Button(action: { selectedEvent = event }) {
                        HStack(spacing: 10) {
                            Image(systemName: event.eventType?.icon ?? "bolt")
                                .font(.caption)
                                .foregroundStyle(event.eventType?.color ?? .gray)
                                .frame(width: 16)
                            Text(event.name)
                                .font(.body)
                            Spacer()
                            if selectedEvent?.persistentModelID == event.persistentModelID {
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
                    .disabled(selectedEvent == nil || selectedRole == nil)
                }
            }
        }
        .padding()
        .onAppear {
            allRoles = (try? modelContext.fetch(FetchDescriptor<EventPlaceRoleType>(sortBy: [SortDescriptor(\.name)]))) ?? []
        }
    }

    private func createAssociation() {
        guard let event = selectedEvent, let role = selectedRole else { return }
        let assoc = EventPlaceAssociation()
        modelContext.insert(assoc)
        place.eventAssociations.append(assoc)
        event.placeAssociations.append(assoc)
        role.associations.append(assoc)
        try? modelContext.save()
    }
}
