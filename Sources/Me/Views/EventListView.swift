import SwiftUI
import SwiftData

/// Input screen for managing events.
struct EventListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query private var events: [Event]
    @State private var showingAddSheet = false
    @State private var editingEvent: Event?
    @State private var selectedEventID: PersistentIdentifier?
    @State private var sortOrder: EventSortOrder = .name
    @State private var imageDetailImage: ImageAsset?
    @AppStorage("eventDetailWidth") private var detailWidth: Double = 320
    @State private var showDeleteConfirm = false
    @Query(sort: \EventType.name) private var eventTypes: [EventType]

    enum EventSortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
        case date = "Date"
    }

    private var selectedEvent: Event? {
        guard let id = selectedEventID else { return nil }
        return sortedEvents.first { $0.persistentModelID == id }
    }

    private var backLabel: String? {
        guard let history = coordinator?.history, history.count >= 2 else { return nil }
        return history[history.count - 2].name
    }

    private var backAction: (() -> Void)? {
        guard let history = coordinator?.history, history.count >= 2 else { return nil }
        let index = history.count - 2
        return { self.coordinator?.navigateToHistory(at: index) }
    }

    private var sortedEvents: [Event] {
        switch sortOrder {
        case .name: return events.sorted { $0.name < $1.name }
        case .type: return events.sorted { $0.eventType?.name ?? "" < $1.eventType?.name ?? "" }
        case .date: return events.sorted { $0.date.sortValue < $1.date.sortValue }
        }
    }

    private var groupedEvents: [(key: String, events: [Event])] {
        let sorted = sortedEvents
        var groups: [(key: String, events: [Event])] = []
        var currentKey: String?
        for event in sorted {
            let key: String = {
                switch sortOrder {
                case .name: return String(event.name.uppercased().prefix(1))
                case .type: return event.eventType?.name ?? "?"
                case .date: return event.date.era.isEmpty ? "Unknown" : event.date.era
                }
            }()
            if key != currentKey {
                groups.append((key: key, events: []))
                currentKey = key
            }
            groups[groups.count - 1].events.append(event)
        }
        return groups
    }

    private func selectEvent(_ id: PersistentIdentifier) {
        selectedEventID = id
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Events")
                        .font(.title2.bold())
                    Spacer()
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(EventSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .frame(width: 130)
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Event", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                // Breadcrumbs
                let coordinatorHistory = coordinator?.history ?? []
                if !coordinatorHistory.isEmpty {
                    BreadcrumbBar(
                        breadcrumbs: coordinatorHistory.map { Breadcrumb(id: $0.id, name: $0.name, icon: $0.item.icon) },
                        onNavigate: { index in coordinator?.navigateToHistory(at: index) },
                        onClear: { coordinator?.history.removeAll() }
                    )
                }
                EventTypeLegend(types: eventTypes)
                    .padding(.horizontal)
                    .padding(.vertical, 4)

                Divider()

                if events.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No events yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Add battles, quests, divine decrees, and other mythological events.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $selectedEventID) {
                        ForEach(groupedEvents, id: \.key) { group in
                            Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
                                ForEach(group.events) { event in
                                    EventRow(event: event)
                                        .tag(event.persistentModelID)
                                }
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .onChange(of: selectedEventID) { _, newValue in
                        if let id = newValue { selectEvent(id) }
                    }
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            if let event = selectedEvent {
                ResizableDivider(width: $detailWidth, range: 200...800)
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        IconActionButton(icon: "pencil", color: .accentColor) {
                            editingEvent = event
                        }
                        IconActionButton(icon: "trash", color: .red) {
                            showDeleteConfirm = true
                        }
                        Spacer()
                        Button(action: { selectedEventID = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    EventDetailView(
                        event: event,
                        onSelectFigure: { figure in
                            coordinator?.pushHistory(id: event.persistentModelID, name: event.name, item: .events)
                            coordinator?.navigateToFigure(figure.persistentModelID, name: figure.name, recordHistory: false)
                        },
                        onSelectPlace: { place in
                            coordinator?.pushHistory(id: event.persistentModelID, name: event.name, item: .events)
                            coordinator?.navigateToPlace(place.persistentModelID, name: place.name, recordHistory: false)
                        },
                        onSelectImage: { imageDetailImage = $0 },
                        backLabel: backLabel,
                        onBack: backAction
                    )
                }
                .frame(width: detailWidth)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            EventFormView(event: nil)
        }
        .sheet(item: $editingEvent) { event in
            EventFormView(event: event)
        }

        .onChange(of: imageDetailImage) { _, newValue in
            if let image = newValue {
                openWindow(id: "image-detail", value: image.persistentModelID)
                imageDetailImage = nil
            }
        }
        .alert("Delete Event?", isPresented: $showDeleteConfirm, presenting: selectedEvent) { event in
            Button("Delete", role: .destructive) { deleteEvent(event) }
            Button("Cancel", role: .cancel) {}
        } message: { event in
            Text("Delete \"\(event.name)\"? This cannot be undone.")
        }
        .onAppear {
            consumePendingNavigation()
        }
        .onChange(of: coordinator?.pendingEventID) { _, _ in
            consumePendingNavigation()
        }
    }

    private func consumePendingNavigation() {
        guard let id = coordinator?.consumePendingEventID() else { return }
        if events.contains(where: { $0.persistentModelID == id }) {
            selectEvent(id)
        }
    }

    private func deleteEvent(_ event: Event) {
        if selectedEventID == event.persistentModelID { selectedEventID = nil }
        withAnimation { modelContext.delete(event) }
    }
}

struct EventRow: View {
    let event: Event

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.eventType?.icon ?? "bolt")
                .font(.caption)
                .foregroundStyle(event.eventType?.color ?? .gray)
                .frame(width: 16)
            Text(event.name)
                .fontWeight(.medium)
                Text(event.eventType?.name ?? "Other")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill((event.eventType?.color ?? .gray).opacity(0.12)))
            if event.isConcept {
                Text("Concept")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(.orange.opacity(0.12)))
            }
            if event.stickies.contains(where: { !$0.isResolved }) {
                Circle()
                    .fill(.yellow)
                    .frame(width: 10, height: 10)
            }
            if let firstPlace = event.placeAssociations.first?.place {
                Text(firstPlace.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if event.placeAssociations.count > 1 {
                    Text("+\(event.placeAssociations.count - 1)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(event.date.displayLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Event Form

struct EventFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @Query(sort: \EventType.name) private var eventTypes: [EventType]
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query(sort: \EventPlaceRoleType.name) private var eventPlaceRoleTypes: [EventPlaceRoleType]

    let event: Event?

    @State private var name = ""
    @State private var eventType: EventType? = nil
    @State private var eventDescription = ""
    @State private var date: MythologicalDate = .unknown
    @State private var era = ""
    @State private var source = ""
    @State private var selectedFigureIDs: Set<PersistentIdentifier> = []
    @State private var figureSearchText = ""
    @State private var placeSelections: [PlaceSelection] = []
    @State private var placeSearchText = ""
    @State private var selectedTags: [Tag] = []

    private struct PlaceSelection: Identifiable {
        let id = UUID()
        var place: Place
        var roleType: EventPlaceRoleType?
    }

    private var isEditing: Bool { event != nil }

    private var selectedFigures: [Figure] {
        figures.filter { selectedFigureIDs.contains($0.persistentModelID) }
    }

    private var filteredFigures: [Figure] {
        guard !figureSearchText.isEmpty else { return [] }
        return figures.filter {
            !selectedFigureIDs.contains($0.persistentModelID) &&
            $0.name.localizedCaseInsensitiveContains(figureSearchText)
        }
    }

    private var filteredPlaces: [Place] {
        guard !placeSearchText.isEmpty else { return [] }
        let selectedIDs = Set(placeSelections.map(\.place.persistentModelID))
        return places.filter {
            !selectedIDs.contains($0.persistentModelID) &&
            $0.name.localizedCaseInsensitiveContains(placeSearchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Event" : "Add Event")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Event Details") {
                    TextField("Name", text: $name, prompt: Text("e.g. Slaying of Tiamat"))
                    Picker("Type", selection: $eventType) {
                        ForEach(eventTypes, id: \.persistentModelID) { type in
                            Text(type.name).tag(type as EventType?)
                        }
                    }
                    Picker("Era", selection: $era) {
                        Text("None").tag("")
                        ForEach(eras) { eraItem in
                            Text(eraItem.name).tag(eraItem.name)
                        }
                    }
                    TextField("Source", text: $source, prompt: Text("e.g. Enuma Elish, Tablet IV"))
                }

                Section("Locations") {
                    if !placeSelections.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(Array(placeSelections.enumerated()), id: \.element.id) { index, _ in
                                HStack(spacing: 4) {
                                    Text(placeSelections[index].place.name)
                                        .font(.caption)
                                    Picker("", selection: Binding(
                                        get: { placeSelections[index].roleType },
                                        set: { placeSelections[index].roleType = $0 }
                                    )) {
                                        Text("Select").tag(nil as EventPlaceRoleType?)
                                        ForEach(eventPlaceRoleTypes) { rt in
                                            Text(rt.name).tag(rt as EventPlaceRoleType?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(width: 120)
                                    Button {
                                        placeSelections.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.quaternary.opacity(0.3))
                                .cornerRadius(4)
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        TextField("Search locations…", text: $placeSearchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(6)
                    .background(.quaternary.opacity(0.15))
                    .cornerRadius(6)

                    if !placeSearchText.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                if filteredPlaces.isEmpty {
                                    Button {
                                        let place = Place(name: placeSearchText, isConcept: true)
                                        modelContext.insert(place)
                                        placeSelections.append(PlaceSelection(place: place, roleType: nil))
                                        placeSearchText = ""
                                    } label: {
                                        Label("Create \"\(placeSearchText)\" as new place", systemImage: "plus.circle")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    ForEach(filteredPlaces) { place in
                                        Button {
                                            placeSelections.append(PlaceSelection(place: place, roleType: nil))
                                            placeSearchText = ""
                                        } label: {
                                            Text(place.name)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }
                }

                MythologicalDateEditor(label: "Date", date: $date)

                Section("Involved Figures") {
                    if !selectedFigureIDs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(selectedFigures) { figure in
                                    HStack(spacing: 2) {
                                        Text(figure.name)
                                            .font(.caption)
                                        if figure.isConcept {
                                            Text("C")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.orange)
                                                .padding(.horizontal, 2)
                                        }
                                        Button {
                                            selectedFigureIDs.remove(figure.persistentModelID)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                                .font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.quaternary.opacity(0.3))
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        TextField("Search figures…", text: $figureSearchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(6)
                    .background(.quaternary.opacity(0.15))
                    .cornerRadius(6)

                    if !figureSearchText.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                if filteredFigures.isEmpty {
                                    Button {
                                        let fig = Figure(name: figureSearchText, isConcept: true)
                                        modelContext.insert(fig)
                                        selectedFigureIDs.insert(fig.persistentModelID)
                                        figureSearchText = ""
                                    } label: {
                                        Label("Create \"\(figureSearchText)\" as new figure", systemImage: "plus.circle")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    ForEach(filteredFigures) { figure in
                                        Button {
                                            selectedFigureIDs.insert(figure.persistentModelID)
                                            figureSearchText = ""
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(figure.gender.symbol)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text(figure.name)
                                            }
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }
                }

                Section("Description") {
                    TextEditor(text: $eventDescription)
                        .frame(minHeight: 60)
                }

                Section("Tags") {
                    TagEditorView(tags: $selectedTags)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 540, height: 700)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let event else { return }
        name = event.name
        eventType = event.eventType
        eventDescription = event.eventDescription
        date = event.date
        era = event.era
        source = event.source
        selectedFigureIDs = Set(event.involvedFigures.map(\.persistentModelID))
        placeSelections = event.placeAssociations.compactMap { assoc in
            guard let place = assoc.place else { return nil }
            return PlaceSelection(place: place, roleType: assoc.roleType)
        }
        selectedTags = event.tags
    }

    private func save() {
        let selectedFigs = figures.filter { selectedFigureIDs.contains($0.persistentModelID) }
        if let event {
            event.name = name
            event.eventType = eventType
            event.eventDescription = eventDescription
            event.date = date
            event.era = era
            event.source = source
            event.isConcept = false
            event.involvedFigures = selectedFigs
            for assoc in event.placeAssociations { modelContext.delete(assoc) }
            event.placeAssociations = placeSelections.map { sel in
                let assoc = EventPlaceAssociation(event: event, place: sel.place, roleType: sel.roleType)
                modelContext.insert(assoc)
                return assoc
            }
            event.tags = selectedTags
            RecentEditStore.trackEdit(entityType: "Event", entityName: event.name)
        } else {
            let newEvent = Event(
                name: name, eventType: eventType,
                eventDescription: eventDescription,
                date: date, era: era, source: source,
                involvedFigures: selectedFigs
            )
            newEvent.tags = selectedTags
            modelContext.insert(newEvent)
            RecentEditStore.trackEdit(entityType: "Event", entityName: newEvent.name)
            for sel in placeSelections {
                let assoc = EventPlaceAssociation(event: newEvent, place: sel.place, roleType: sel.roleType)
                modelContext.insert(assoc)
            }
        }
        dismiss()
    }
}
