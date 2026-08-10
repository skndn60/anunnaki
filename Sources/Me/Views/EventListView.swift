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
    @State private var selectedTypeFilters: Set<String> = []
    @Query(sort: \EventType.name) private var eventTypes: [EventType]
    @State private var showDescriptionEditor = false
    @State private var editRichDescription: Data? = nil
    @State private var editPlainDescription = ""

    enum EventSortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
        case date = "Date"
    }

    private var selectedEvent: Event? {
        guard let id = selectedEventID else { return nil }
        return filteredEvents.first { $0.persistentModelID == id }
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

    private var filteredEvents: [Event] {
        var result = events
        if !selectedTypeFilters.isEmpty {
            result = result.filter { selectedTypeFilters.contains($0.eventType?.name ?? "") }
        }
        switch sortOrder {
        case .name: return result.sorted { ($0.sortName ?? sortName(for: $0.name)) < ($1.sortName ?? sortName(for: $1.name)) }
        case .type: return result.sorted { $0.eventType?.name ?? "" < $1.eventType?.name ?? "" }
        case .date: return result.sorted { $0.date.sortValue < $1.date.sortValue }
        }
    }

    private var groupedEvents: [(key: String, events: [Event])] {
        Dictionary(grouping: filteredEvents) { event in
            switch sortOrder {
            case .name: String((event.sortName ?? sortName(for: event.name)).uppercased().prefix(1))
            case .type: event.eventType?.name ?? "?"
            case .date: event.date.era.isEmpty ? "Unknown" : event.date.era
            }
        }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, events: $0.value.sorted { ($0.sortName ?? sortName(for: $0.name)) < ($1.sortName ?? sortName(for: $1.name)) }) }
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
                if !eventTypes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(eventTypes) { type in
                                typeFilterButton(type)
                            }
                            if !selectedTypeFilters.isEmpty {
                                Button("Clear") { selectedTypeFilters.removeAll() }
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 4)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }

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
                    ScrollViewReader { proxy in
                        List(selection: $selectedEventID) {
                            ForEach(groupedEvents, id: \.key) { group in
                                eventGroupSection(group)
                            }
                        }
                        .listStyle(.inset(alternatesRowBackgrounds: true))
                        .onChange(of: selectedEventID) { _, newValue in
                            if let id = newValue {
                                DispatchQueue.main.async {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            Group {
                if let event = selectedEvent {
                    // ResizableDivider(width: $detailWidth, range: 200...800)
                    VStack(spacing: 0) {
                        DetailToolbar(
                            onEdit: { editingEvent = event },
                            onDelete: { showDeleteConfirm = true },
                            onClose: { selectedEventID = nil },
                            onEditDescription: {
                                editRichDescription = event.richDescription
                                editPlainDescription = event.eventDescription
                                showDescriptionEditor = true
                            }
                        )
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
                            onSelectImage: { imageDetailImage = $0 }
                        )
                    }
                    .frame(width: detailWidth)
                    .frame(maxHeight: .infinity)
                    .background(.thinMaterial)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: selectedEventID)
        }
        .sheet(isPresented: $showingAddSheet) {
            EventFormView(event: nil)
        }
        .sheet(item: $editingEvent) { event in
            EventFormView(event: event)
        }
        .sheet(isPresented: $showDescriptionEditor) {
            if let event = selectedEvent {
                DescriptionEditorSheet(
                    entityName: event.name,
                    richDescription: $editRichDescription,
                    plainDescription: $editPlainDescription,
                    onSave: {
                        event.richDescription = editRichDescription
                        event.eventDescription = editPlainDescription
                        try? modelContext.save()
                    }
                )
            }
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
            Task { @MainActor in
                selectEvent(id)
            }
        }
    }

    private func typeFilterButton(_ type: EventType) -> some View {
        Button(action: {
            if selectedTypeFilters.contains(type.name) {
                selectedTypeFilters.remove(type.name)
            } else {
                selectedTypeFilters.insert(type.name)
            }
        }) {
            HStack(spacing: 4) {
                Circle().fill(type.color).frame(width: 7, height: 7)
                Text(type.name).font(.caption)
                if selectedTypeFilters.contains(type.name) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTypeFilters.contains(type.name) ? type.color.opacity(0.2) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedTypeFilters.contains(type.name) ? type.color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func eventGroupSection(_ group: (key: String, events: [Event])) -> some View {
        Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
            ForEach(group.events) { event in
                EventRow(event: event)
                    .tag(event.persistentModelID)
                    .id(event.persistentModelID)
            }
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
