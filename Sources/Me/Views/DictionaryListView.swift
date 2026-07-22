import SwiftUI
import SwiftData

struct DictionaryListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DictionaryEntry.english) private var entries: [DictionaryEntry]
    @State private var showingAddSheet = false
    @State private var editingEntry: DictionaryEntry?
    @State private var selectedEntryID: PersistentIdentifier?
    @AppStorage("dictionaryDetailWidth") private var detailWidth: Double = 380
    @State private var showDeleteConfirm = false
    @State private var searchText = ""
    enum DictionarySortOrder: String, CaseIterable {
        case english = "English"
        case sumerian = "Sumerian"
    }

    @State private var sortOrder: DictionarySortOrder = .english

    private var filteredEntries: [DictionaryEntry] {
        var result = entries
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.english.lowercased().contains(query) ||
                $0.sumerian.lowercased().contains(query) ||
                $0.entryDescription.lowercased().contains(query)
            }
        }
        if sortOrder == .sumerian {
            result.sort { sortName(for: $0.sumerian) < sortName(for: $1.sumerian) }
        } else {
            result.sort { sortName(for: $0.english) < sortName(for: $1.english) }
        }
        return result
    }

    private var groupedEntries: [(key: String, entries: [DictionaryEntry])] {
        Dictionary(grouping: filteredEntries) { entry in
            let sortField = sortOrder == .sumerian ? entry.sumerian : entry.english
            return String(sortName(for: sortField).uppercased().prefix(1))
        }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, entries: $0.value) }
    }

    private var selectedEntry: DictionaryEntry? {
        guard let id = selectedEntryID else { return nil }
        return filteredEntries.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Dictionary")
                        .font(.title2.bold())
                    Spacer()
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(DictionarySortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .frame(width: 130)
                    TextField("🔍 Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .overlay(alignment: .trailing) {
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 6)
                                .help("Clear search")
                            }
                        }
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Entry", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                Divider()

                if filteredEntries.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No entries yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Add a Sumerian\u{2013}English dictionary entry")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $selectedEntryID) {
                        ForEach(groupedEntries, id: \.key) { group in
                            Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
                                ForEach(group.entries) { entry in
                                    DictionaryRow(entry: entry, showSumerian: sortOrder == .sumerian, searchText: searchText, onDoubleClick: { editingEntry = entry })
                                        .tag(entry.persistentModelID)
                                }
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            if let entry = selectedEntry {
                ResizableDivider(width: $detailWidth, range: 200...600)
                detailPanel(entry: entry, showSumerian: sortOrder == .sumerian)
                    .frame(width: detailWidth)
                    .background(.thinMaterial)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedEntryID)
        .sheet(isPresented: $showingAddSheet) {
            DictionaryFormView(entry: nil) { newEntry in
                modelContext.insert(newEntry)
                try? modelContext.save()
            }
        }
        .sheet(item: $editingEntry) { entry in
            DictionaryFormView(entry: entry) { _ in
                try? modelContext.save()
            }
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirm, presenting: selectedEntry) { entry in
            Button("Delete", role: .destructive) { deleteEntry(entry) }
            Button("Cancel", role: .cancel) {}
        } message: { entry in
            Text("Delete \"\(entry.english)\" (\u{201C}\(entry.sumerian)\u{201D})?")
        }
    }

    private func detailPanel(entry: DictionaryEntry, showSumerian: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") {
                    editingEntry = entry
                }
                IconActionButton(icon: "trash", color: .red, help: "Delete") {
                    showDeleteConfirm = true
                }
                Spacer()
                Button(action: { selectedEntryID = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)

            DictionaryDetailView(entry: entry, showSumerian: showSumerian)
        }
    }

    private func deleteEntry(_ entry: DictionaryEntry) {
        if selectedEntryID == entry.persistentModelID {
            selectedEntryID = nil
        }
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private func sortName(for string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let articles = ["the ", "a ", "an "]
        for article in articles {
            if trimmed.lowercased().hasPrefix(article) {
                return String(trimmed.dropFirst(article.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return trimmed
    }
}

// MARK: - Row

private struct DictionaryRow: View {
    let entry: DictionaryEntry
    let showSumerian: Bool
    let searchText: String
    var onDoubleClick: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(showSumerian ? entry.sumerian : entry.english)
                        .fontWeight(.medium)
                    if let part = entry.partOfSpeech, !part.isEmpty {
                        Text(part)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(showSumerian ? entry.english : entry.sumerian)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let cuneiform = entry.cuneiform, !cuneiform.isEmpty {
                Text(cuneiform)
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .onTapGesture(count: 2) { onDoubleClick?() }
    }
}

// MARK: - Detail

struct DictionaryDetailView: View {
    let entry: DictionaryEntry
    let showSumerian: Bool

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "character.book.closed")
                                .foregroundStyle(.purple)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(showSumerian ? entry.sumerian : entry.english)
                            .font(.title2.bold())
                        Text(showSumerian ? entry.english : entry.sumerian)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let part = entry.partOfSpeech, !part.isEmpty {
                        Text(part)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.purple.opacity(0.12))
                            )
                    }
                }

                if let cuneiform = entry.cuneiform, !cuneiform.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cuneiform")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(cuneiform)
                            .font(.system(size: 28, design: .serif))
                    }
                }

                if let pronunciation = entry.pronunciation, !pronunciation.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pronunciation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("pronounced as \"\(pronunciation)\"")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                if !entry.entryDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.entryDescription)
                            .font(.body)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .textSelection(.enabled)
        }
    }
}

// MARK: - Form

private struct DictionaryFormView: View {
    @Environment(\.dismiss) var dismiss
    let entry: DictionaryEntry?
    let onSave: (DictionaryEntry) -> Void

    @State private var english = ""
    @State private var sumerian = ""
    @State private var entryDescription = ""
    @State private var cuneiform = ""
    @State private var partOfSpeech = ""
    @State private var pronunciation = ""

    private var isEditing: Bool { entry != nil }

    init(entry: DictionaryEntry?, onSave: @escaping (DictionaryEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        if let entry {
            _english = State(initialValue: entry.english)
            _sumerian = State(initialValue: entry.sumerian)
            _entryDescription = State(initialValue: entry.entryDescription)
            _cuneiform = State(initialValue: entry.cuneiform ?? "")
            _partOfSpeech = State(initialValue: entry.partOfSpeech ?? "")
            _pronunciation = State(initialValue: entry.pronunciation ?? "")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Entry" : "Add Entry")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Translation") {
                    TextField("English", text: $english, prompt: Text("e.g. God, Heaven"))
                    TextField("Sumerian", text: $sumerian, prompt: Text("e.g. dingir, an"))
                    TextField("Part of Speech", text: $partOfSpeech, prompt: Text("e.g. noun, verb"))
                    TextField("Pronunciation", text: $pronunciation, prompt: Text("e.g. shoe"))
                }
                Section("Cuneiform") {
                    TextField("Cuneiform", text: $cuneiform, prompt: Text("e.g. \u{12000}\u{1229A}"))
                }
                Section("Description") {
                    TextEditor(text: $entryDescription)
                        .frame(minHeight: 80)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    let target = entry ?? DictionaryEntry()
                    target.english = english
                    target.sumerian = sumerian
                    target.entryDescription = entryDescription
                    target.cuneiform = cuneiform.isEmpty ? nil : cuneiform
                    target.partOfSpeech = partOfSpeech.isEmpty ? nil : partOfSpeech
                    target.pronunciation = pronunciation.isEmpty ? nil : pronunciation
                    onSave(target)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(english.trimmingCharacters(in: .whitespaces).isEmpty || sumerian.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 500)
    }
}
