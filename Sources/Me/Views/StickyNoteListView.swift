import SwiftUI
import SwiftData

// MARK: - StickyNoteCard

struct StickyNoteCard: View {
    @Bindable var note: StickyNote

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(.yellow)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .font(.body)
                    .strikethrough(note.isResolved)
                Text(note.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if note.isResolved {
                Button {
                    withAnimation { note.modelContext?.delete(note) }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.7))
                .help("Clear sticky")
            } else {
                Button {
                    withAnimation { note.isResolved = true }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)
                .help("Mark as resolved")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(note.isResolved ? 0.06 : 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(note.isResolved ? 0.15 : 0.35), lineWidth: 1)
        )
        .opacity(note.isResolved ? 0.5 : 1)
    }
}

// MARK: - StickyNoteSection (embedded in detail views)

struct StickyNoteSection: View {
    let stickies: [StickyNote]
    let onCreate: (String) -> Void

    @State private var newStickyText = ""

    private var sortedStickies: [StickyNote] {
        stickies.sorted { a, b in
            if a.isResolved != b.isResolved {
                return !a.isResolved && b.isResolved
            }
            return a.createdAt > b.createdAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stickies")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                TextField("Add sticky note\u{2026}", text: $newStickyText)
                    .textFieldStyle(.plain)
                    .onSubmit(submitSticky)
                Button(action: submitSticky) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
                .disabled(newStickyText.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("Add sticky note")
            }
            .padding(8)
            .background(Color.yellow.opacity(0.08))
            .cornerRadius(8)

            ForEach(sortedStickies) { note in
                StickyNoteCard(note: note)
            }
        }
    }

    private func submitSticky() {
        let text = newStickyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        onCreate(text)
        newStickyText = ""
    }
}

// MARK: - StickyNoteListView (global)

struct StickyNoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allStickies: [StickyNote]

    @State private var sortBy: StickySort = .newestFirst
    @State private var showResolved = false

    enum StickySort: String, CaseIterable {
        case newestFirst = "Newest"
        case oldestFirst = "Oldest"
        case byEntity = "By Entity"
    }

    private var filteredStickies: [StickyNote] {
        var result = allStickies
        if !showResolved {
            result = result.filter { !$0.isResolved }
        }
        switch sortBy {
        case .newestFirst:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            result.sort { $0.createdAt < $1.createdAt }
        case .byEntity:
            result.sort { a, b in
                let aLabel = entityLabel(a)
                let bLabel = entityLabel(b)
                if aLabel != bLabel { return aLabel < bLabel }
                return a.createdAt > b.createdAt
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Stickies")
                    .font(.title2.bold())
                Spacer()
                Picker("Sort", selection: $sortBy) {
                    ForEach(StickySort.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .frame(width: 130)
                Toggle("Show Resolved", isOn: $showResolved)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            .padding()

            Divider()

            if filteredStickies.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(allStickies.isEmpty ? "No stickies yet" : "No unresolved stickies")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(allStickies.isEmpty
                        ? "Add sticky notes to figures, places, events, and things from their detail panels."
                        : "Toggle \"Show Resolved\" to see completed stickies.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(filteredStickies) { note in
                    HStack(spacing: 10) {
                        entityIconView(note)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entityLabel(note))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(note.text)
                                .font(.callout)
                                .strikethrough(note.isResolved)
                                .lineLimit(2)
                        }

                        Spacer()

                        Text(note.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        if note.isResolved {
                            Button {
                                modelContext.delete(note)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red.opacity(0.7))
                        } else {
                            Button {
                                note.isResolved = true
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private func entityLabel(_ note: StickyNote) -> String {
        if let fig = note.figure { return "\(fig.gender.symbol) \(fig.name)" }
        if let place = note.place { return place.name }
        if let event = note.event { return event.name }
        if let thing = note.thing { return thing.name }
        return "?"
    }

    @ViewBuilder
    private func entityIconView(_ note: StickyNote) -> some View {
        if note.figure != nil {
            Image(systemName: "person.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        } else if note.place != nil {
            Image(systemName: "mappin")
                .font(.caption)
                .foregroundStyle(.teal)
        } else if note.event != nil {
            Image(systemName: "bolt.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if note.thing != nil {
            Image(systemName: "cube.box")
                .font(.caption)
                .foregroundStyle(.purple)
        }
    }
}
