import SwiftUI
import SwiftData

/// Input screen for managing events.
struct EventListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @State private var showingAddSheet = false
    @State private var editingEvent: Event?
    @State private var selectedEventID: PersistentIdentifier?
    @State private var sortOrder: EventSortOrder = .name
    @State private var breadcrumbs: [(id: PersistentIdentifier, name: String)] = []

    enum EventSortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
        case date = "Date"
    }

    private var selectedEvent: Event? {
        guard let id = selectedEventID else { return nil }
        return sortedEvents.first { $0.persistentModelID == id }
    }

    private var sortedEvents: [Event] {
        switch sortOrder {
        case .name: return events.sorted { $0.name < $1.name }
        case .type: return events.sorted { $0.eventType.rawValue < $1.eventType.rawValue }
        case .date: return events.sorted { $0.date.sortValue < $1.date.sortValue }
        }
    }

    private func selectEvent(_ id: PersistentIdentifier) {
        if let event = events.first(where: { $0.persistentModelID == id }) {
            if breadcrumbs.last?.id != id {
                breadcrumbs.append((id: id, name: event.name))
                if breadcrumbs.count > 12 { breadcrumbs.removeFirst() }
            }
        }
        selectedEventID = id
    }

    private func navigateToBreadcrumb(at index: Int) {
        let crumb = breadcrumbs[index]
        breadcrumbs = Array(breadcrumbs.prefix(index + 1))
        selectedEventID = crumb.id
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
                if !breadcrumbs.isEmpty {
                    BreadcrumbBar(breadcrumbs: breadcrumbs, onNavigate: navigateToBreadcrumb, onClear: { breadcrumbs.removeAll() })
                }

                EventTypeLegend()
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
                    List(sortedEvents, selection: $selectedEventID) { event in
                        EventRow(event: event)
                            .tag(event.persistentModelID)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .onChange(of: selectedEventID) { _, newValue in
                        if let id = newValue { selectEvent(id) }
                    }
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            if let event = selectedEvent {
                Divider()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        IconActionButton(icon: "pencil", color: .accentColor) {
                            editingEvent = event
                        }
                        IconActionButton(icon: "trash", color: .red) {
                            deleteEvent(event)
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
                    EventDetailView(event: event)
                }
                .frame(width: 320)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            EventFormView(event: nil)
        }
        .sheet(item: $editingEvent) { event in
            EventFormView(event: event)
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
            Image(systemName: event.eventType.icon)
                .font(.caption)
                .foregroundStyle(event.eventType.color)
                .frame(width: 16)
            Text(event.name)
                .fontWeight(.medium)
            Text(event.eventType.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(event.eventType.color.opacity(0.12)))
            if let place = event.place {
                Text(place.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    @Query(sort: \Era.orderIndex) private var eras: [Era]

    let event: Event?

    @State private var name = ""
    @State private var eventType: Event.EventType = .other
    @State private var eventDescription = ""
    @State private var date: MythologicalDate = .unknown
    @State private var era = ""
    @State private var source = ""
    @State private var selectedFigureIDs: Set<PersistentIdentifier> = []
    @State private var selectedPlace: Place?

    private var isEditing: Bool { event != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Event" : "Add Event")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Event Details") {
                    TextField("Name", text: $name, prompt: Text("e.g. Slaying of Tiamat"))
                    Picker("Type", selection: $eventType) {
                        ForEach(Event.EventType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    Picker("Era", selection: $era) {
                        Text("None").tag("")
                        ForEach(eras) { eraItem in
                            Text(eraItem.name).tag(eraItem.name)
                        }
                    }
                    Picker("Place", selection: $selectedPlace) {
                        Text("None").tag(nil as Place?)
                        ForEach(places) { place in
                            Text(place.name).tag(place as Place?)
                        }
                    }
                    TextField("Source", text: $source, prompt: Text("e.g. Enuma Elish, Tablet IV"))
                }

                MythologicalDateEditor(label: "Date", date: $date)

                Section("Involved Figures") {
                    ForEach(figures) { figure in
                        Toggle(isOn: Binding(
                            get: { selectedFigureIDs.contains(figure.persistentModelID) },
                            set: { isOn in
                                if isOn { selectedFigureIDs.insert(figure.persistentModelID) }
                                else { selectedFigureIDs.remove(figure.persistentModelID) }
                            }
                        )) {
                            HStack(spacing: 6) {
                                Text(figure.gender.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(figure.name)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }

                Section("Description") {
                    TextEditor(text: $eventDescription)
                        .frame(minHeight: 60)
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
        selectedPlace = event.place
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
            event.involvedFigures = selectedFigs
            event.place = selectedPlace
        } else {
            let newEvent = Event(
                name: name, eventType: eventType,
                eventDescription: eventDescription,
                date: date, era: era, source: source,
                involvedFigures: selectedFigs,
                place: selectedPlace
            )
            modelContext.insert(newEvent)
        }
        dismiss()
    }
}
