import SwiftUI
import SwiftData

struct SumerianKingEventListView: View {
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query private var events: [Event]
    @Query(sort: \Era.orderIndex) private var eras: [Era]

    @AppStorage("sklEventDetailWidth") private var detailWidth: Double = 320
    @State private var selectedEventID: PersistentIdentifier?
    @State private var imageDetailImage: ImageAsset?
    @State private var showDeleteConfirm = false
    @State private var editingEvent: Event?

    private var sklEvents: [Event] {
        events.filter { $0.source.contains("Sumerian King List") }
            .sorted { $0.date.sortValue < $1.date.sortValue }
    }

    private var selectedEvent: Event? {
        guard let id = selectedEventID else { return nil }
        return sklEvents.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Divider()
                if sklEvents.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            Group {
                if let event = selectedEvent {
                    ResizableDivider(width: $detailWidth, range: 200...800)
                    detailPanel(event: event)
                    .frame(width: detailWidth)
                    .background(.thinMaterial)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.25), value: selectedEventID)
        .onChange(of: selectedEventID) { _, newValue in
            if newValue == nil { selectedEventID = nil }
        }
        .alert("Delete Event?", isPresented: $showDeleteConfirm, presenting: selectedEvent) { event in
            Button("Delete", role: .destructive) { deleteEvent(event) }
            Button("Cancel", role: .cancel) {}
        } message: { event in
            Text("Delete \"\(event.name)\"? This cannot be undone.")
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
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("SKL Events")
                .font(.title2.bold())
            Spacer()
            Text("\(sklEvents.count) events")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No SKL event data")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Seed the database with --reseed to load the Sumerian King List events.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Event List

    private var eventList: some View {
        List(selection: $selectedEventID) {
            ForEach(sklEvents, id: \.persistentModelID) { event in
                EventRow(event: event)
                    .tag(event.persistentModelID)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Detail Panel

    private func detailPanel(event: Event) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") {
                    editingEvent = event
                }
                IconActionButton(icon: "trash", color: .red, help: "Delete") {
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
                .help("Close")
            }
            .padding(.vertical, 8)
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
                backLabel: nil,
                onBack: nil
            )
        }
    }

    private func deleteEvent(_ event: Event) {
        if selectedEventID == event.persistentModelID {
            selectedEventID = nil
        }
        withAnimation { modelContext.delete(event) }
    }
}
