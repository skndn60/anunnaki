import SwiftUI
import SwiftData

struct TimelineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Timeline.orderIndex) private var timelines: [Timeline]
    @State private var showingAddSheet = false
    @State private var editingTimeline: Timeline?
    @State private var selectedTimelineID: PersistentIdentifier?
    @DetailWidth(.timeline) private var detailWidth
    @State private var showDeleteConfirm = false

    private var sortedTimelines: [Timeline] {
        timelines.sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var selectedTimeline: Timeline? {
        guard let id = selectedTimelineID else { return nil }
        return sortedTimelines.first { $0.persistentModelID == id }
    }

    private func selectTimeline(_ id: PersistentIdentifier) {
        selectedTimelineID = id
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Timelines")
                        .font(.title2.bold())
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Timeline", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                Divider()

                if sortedTimelines.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No timelines yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Curate sequences of events in narrative order, with prose woven between them.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(sortedTimelines, selection: $selectedTimelineID) { timeline in
                        TimelineRow(timeline: timeline)
                            .tag(timeline.persistentModelID)
                            .contextMenu {
                                Button("Edit") { editingTimeline = timeline }
                                Divider()
                                Button("Add Entry") {
                                    editingTimeline = timeline
                                    showingAddEntrySheet = true
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    selectedTimelineID = timeline.persistentModelID
                                    showDeleteConfirm = true
                                }
                            }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            Group {
                if let timeline = selectedTimeline {
                    VStack(spacing: 0) {
                        DetailToolbar(
                            onEdit: { editingTimeline = timeline },
                            onDelete: { showDeleteConfirm = true },
                            onClose: { selectedTimelineID = nil },
                            leadingButtons: [
                                ToolbarButton(icon: "plus.square.on.square", color: .blue, help: "Add entry") {
                                    editingTimeline = timeline
                                    showingAddEntrySheet = true
                                }
                            ]
                        )
                        TimelineDetailView(
                            timeline: timeline,
                            onReorder: { entry, direction in
                                timeline.moveEntry(entry, direction: direction)
                            },
                            onDeleteEntry: { entry in
                                modelContext.delete(entry)
                            },
                            onAddEntry: {
                                editingTimeline = timeline
                                showingAddEntrySheet = true
                            }
                        )
                    }
                    .frame(width: detailWidth)
                    .frame(maxHeight: .infinity)
                    .background(.thinMaterial)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: selectedTimelineID)
        }
        .sheet(isPresented: $showingAddSheet) {
            TimelineFormView(timeline: nil)
        }
        .sheet(item: $editingTimeline) { timeline in
            TimelineFormView(timeline: timeline)
        }
        .sheet(isPresented: $showingAddEntrySheet) {
            if let timeline = editingTimeline {
                TimelineEntrySheet(timeline: timeline)
            }
        }
        .alert("Delete Timeline?", isPresented: $showDeleteConfirm, presenting: selectedTimeline) { timeline in
            Button("Delete", role: .destructive) { deleteTimeline(timeline) }
            Button("Cancel", role: .cancel) {}
        } message: { timeline in
            Text("Delete \"\(timeline.name)\"? Its entries and narrative blocks will also be removed.")
        }
    }

    @State private var showingAddEntrySheet = false

    private func deleteTimeline(_ timeline: Timeline) {
        if selectedTimelineID == timeline.persistentModelID { selectedTimelineID = nil }
        withAnimation { modelContext.delete(timeline) }
    }
}

struct TimelineRow: View {
    let timeline: Timeline

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 16)
            Text(timeline.name)
                .fontWeight(.medium)
            Text("\(timeline.entries.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !timeline.timelineDescription.isEmpty {
                Text(timeline.timelineDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

struct TimelineDetailView: View {
    let timeline: Timeline
    let onReorder: (TimelineEntry, Int) -> Void
    let onDeleteEntry: (TimelineEntry) -> Void
    let onAddEntry: () -> Void

    @State private var editingEntry: TimelineEntry?
    @State private var showingEntrySheet = false
    @State private var blockTarget: TimelineEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.blue)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeline.name)
                            .font(.title2.bold())
                        Text("Order \(timeline.orderIndex) · \(timeline.entries.count) entries")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if !timeline.timelineDescription.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(timeline.timelineDescription)
                            .font(.body)
                    }
                }

                Divider()

                HStack {
                    Text("Entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Button {
                        onAddEntry()
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if timeline.sortedEntries.isEmpty {
                    Text("No entries yet. Add events to tell this timeline's story.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(timeline.sortedEntries.enumerated()), id: \.element.persistentModelID) { index, entry in
                            TimelineEntryCard(
                                entry: entry,
                                index: index,
                                total: timeline.sortedEntries.count,
                                onMoveUp: { onReorder(entry, -1) },
                                onMoveDown: { onReorder(entry, 1) },
                                onEdit: { editingEntry = entry },
                                onDelete: { onDeleteEntry(entry) },
                                onAddBlock: { blockTarget = entry }
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .textSelection(.enabled)
        }
        .sheet(item: $editingEntry) { entry in
            TimelineEntrySheet(timeline: timeline, entry: entry)
        }
        .sheet(item: $blockTarget) { entry in
            TimelineBlockSheet(entry: entry)
        }
    }
}

struct TimelineEntryCard: View {
    let entry: TimelineEntry
    let index: Int
    let total: Int
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddBlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        if let event = entry.event {
                            Image(systemName: event.eventType?.icon ?? "bolt")
                                .font(.caption)
                                .foregroundStyle(event.eventType?.color ?? .gray)
                            Text(event.name)
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(event.date.displayLabel)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("Unlinked event")
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .disabled(index == 0)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(index == total - 1)
            }

            if !(entry.sortedBlocks.isEmpty) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.sortedBlocks) { block in
                        VStack(alignment: .leading, spacing: 2) {
                            if !block.title.isEmpty {
                                Text(block.title)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Text(block.text.isEmpty ? block.title : block.text)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(alignment: .topTrailing) {
                            Button {
                                blockContext = block
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: onAddBlock) {
                    Label("Narrative", systemImage: "text.quote")
                }
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(action: onDelete) {
                    Label("Remove", systemImage: "minus.circle")
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .alert("Delete Narrative Block?", isPresented: blockDeleteAlertBinding, presenting: blockContext) { block in
            Button("Delete", role: .destructive) {
                deleteBlock(block)
            }
            Button("Cancel", role: .cancel) {}
        } message: { block in
            Text("Remove this narrative block from \"\(entry.note.isEmpty ? (entry.event?.name ?? "") : entry.note)\"?")
        }
    }

    @State private var blockContext: GroupTextBlock?

    private var blockDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { blockContext != nil },
            set: { if !$0 { blockContext = nil } }
        )
    }

    @Environment(\.modelContext) private var modelContext

    private func deleteBlock(_ block: GroupTextBlock) {
        modelContext.delete(block)
        blockContext = nil
    }
}

struct TimelineFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let timeline: Timeline?
    @Query private var allTimelines: [Timeline]

    @State private var name = ""
    @State private var orderIndex = 0
    @State private var timelineDescription = ""

    private var isEditing: Bool { timeline != nil }

    private var duplicateNameWarning: String? {
        let others = allTimelines
            .filter { $0.persistentModelID != timeline?.persistentModelID }
            .map(\.name)
        return NameDuplicateCheck.warning(candidate: name, existingNames: others)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Timeline" : "Add Timeline")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Timeline Details") {
                    TextField("Name", text: $name, prompt: Text("The House of Uruk"))
                        .foregroundStyle(duplicateNameWarning == nil ? Color.primary : Color.orange)
                    if let duplicate = duplicateNameWarning {
                        Label("A timeline named \"\(duplicate)\" already exists — continuing will create another one.", systemImage: "exclamationmark.triangle.fill")
                            .font(.callout.bold())
                            .foregroundStyle(.orange)
                    }
                    Stepper("Order: \(orderIndex)", value: $orderIndex, in: 0...100)
                }

                Section("Description") {
                    TextEditor(text: $timelineDescription)
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
        .frame(width: 500, height: 420)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let timeline else { return }
        name = timeline.name
        orderIndex = timeline.orderIndex
        timelineDescription = timeline.timelineDescription
    }

    private func save() {
        if let timeline {
            timeline.name = name
            timeline.orderIndex = orderIndex
            timeline.timelineDescription = timelineDescription
        } else {
            let newTimeline = Timeline(
                name: name,
                timelineDescription: timelineDescription,
                orderIndex: orderIndex
            )
            modelContext.insert(newTimeline)
        }
        dismiss()
    }
}

struct TimelineEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let timeline: Timeline
    var entry: TimelineEntry?

    @Query(sort: \Event.name) private var allEvents: [Event]
    @State private var selectedEvent: Event?
    @State private var note = ""

    private var isEditing: Bool { entry != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Entry" : "Add Entry")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Event") {
                    Picker("Event", selection: $selectedEvent) {
                        Text("Select an event").tag(Event?.none)
                        ForEach(allEvents) { event in
                            Text("\(event.name) · \(event.date.displayLabel)").tag(Event?.some(event))
                        }
                    }
                    .disabled(allEvents.isEmpty)
                    if allEvents.isEmpty {
                        Text("No events exist yet. Create events before building a timeline.")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Note") {
                    TextField("Optional note for this entry", text: $note, axis: .vertical)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedEvent == nil)
            }
            .padding()
        }
        .frame(width: 480, height: 340)
        .onAppear {
            if let entry {
                selectedEvent = entry.event
                note = entry.note
            } else if allEvents.count == 1 {
                selectedEvent = allEvents.first
            }
        }
    }

    private func save() {
        if let entry {
            entry.event = selectedEvent
            entry.note = note
        } else if let event = selectedEvent {
            let newEntry = TimelineEntry(event: event, note: note)
            modelContext.insert(newEntry)
            timeline.appendEntry(newEntry)
        }
        dismiss()
    }
}

struct TimelineBlockSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let entry: TimelineEntry

    @State private var title = ""
    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Narrative Block")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Block") {
                    TextField("Title (optional)", text: $title)
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.isEmpty || title.isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 380)
    }

    private func save() {
        let block = GroupTextBlock(title: title, text: text)
        modelContext.insert(block)
        entry.appendBlock(block)
        dismiss()
    }
}