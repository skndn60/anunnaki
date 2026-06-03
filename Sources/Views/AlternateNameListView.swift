import SwiftUI
import SwiftData

/// Dedicated management view for alternate names and cross-cultural equivalents.
struct AlternateNameListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var alternateNames: [AlternateName]
    @Query private var figures: [Figure]
    @State private var showingAddSheet = false
    @State private var editingAltName: AlternateName?
    @State private var hoveredID: PersistentIdentifier?
    @State private var filterTradition: AlternateName.Tradition?
    @State private var filterFigure: Figure?

    private var filteredNames: [AlternateName] {
        var result = alternateNames
        if let tradition = filterTradition {
            result = result.filter { $0.tradition == tradition }
        }
        if let figure = filterFigure {
            result = result.filter { $0.figure?.persistentModelID == figure.persistentModelID }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Alternate Names")
                    .font(.title2.bold())
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Label("Add Name", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(figures.isEmpty)
            }
            .padding()

            // Filters
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("Tradition:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $filterTradition) {
                        Text("All").tag(nil as AlternateName.Tradition?)
                        ForEach(AlternateName.Tradition.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t as AlternateName.Tradition?)
                        }
                    }
                    .frame(width: 140)
                }

                HStack(spacing: 6) {
                    Text("Figure:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $filterFigure) {
                        Text("All").tag(nil as Figure?)
                        ForEach(figures) { fig in
                            Text(fig.name).tag(fig as Figure?)
                        }
                    }
                    .frame(width: 160)
                }

                Spacer()

                Text("\(filteredNames.count) names")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            if alternateNames.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "textformat.abc")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No alternate names yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Track alternate spellings, translations, and cross-cultural identifications for figures.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    Spacer()
                }
            } else {
                Table(filteredNames) {
                    TableColumn("Figure") { altName in
                        Text(altName.figure?.name ?? "—")
                            .fontWeight(.medium)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Alternate Name") { altName in
                        Text(altName.name)
                            .fontWeight(.medium)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Tradition") { altName in
                        Text(altName.tradition.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(traditionColor(altName.tradition).opacity(0.12))
                            )
                    }
                    .width(100)

                    TableColumn("Type") { altName in
                        Text(altName.nameType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 100, ideal: 130)

                    TableColumn("Note") { altName in
                        Text(altName.note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                    .width(min: 140, ideal: 200)

                    TableColumn("") { altName in
                        HStack(spacing: 4) {
                            IconActionButton(icon: "pencil", color: .accentColor, isVisible: hoveredID == altName.persistentModelID) {
                                editingAltName = altName
                            }
                            IconActionButton(icon: "trash", color: .red, isVisible: hoveredID == altName.persistentModelID) {
                                withAnimation { modelContext.delete(altName) }
                            }
                        }
                        .onHover { hovering in
                            hoveredID = hovering ? altName.persistentModelID : nil
                        }
                    }
                    .width(60)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AlternateNameFormView(alternateName: nil)
        }
        .sheet(item: $editingAltName) { altName in
            AlternateNameFormView(alternateName: altName)
        }
    }

    private func traditionColor(_ tradition: AlternateName.Tradition) -> Color { tradition.color }
}

// MARK: - Alternate Name Form

struct AlternateNameFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]

    let alternateName: AlternateName?

    @State private var selectedFigure: Figure?
    @State private var name = ""
    @State private var tradition: AlternateName.Tradition = .akkadian
    @State private var nameType: AlternateName.NameType = .translation
    @State private var note = ""

    private var isEditing: Bool { alternateName != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Alternate Name" : "Add Alternate Name")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Link to Figure") {
                    Picker("Figure", selection: $selectedFigure) {
                        Text("Select a figure").tag(nil as Figure?)
                        ForEach(figures) { fig in
                            Text("\(fig.gender.symbol) \(fig.name)").tag(fig as Figure?)
                        }
                    }
                }

                Section("Alternate Name") {
                    TextField("Name", text: $name, prompt: Text("e.g. Ea, Ptah, Ishtar"))
                    Picker("Tradition", selection: $tradition) {
                        ForEach(AlternateName.Tradition.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    Picker("Type", selection: $nameType) {
                        ForEach(AlternateName.NameType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }

                Section("Note") {
                    TextField("Note", text: $note, prompt: Text("e.g. Identified by Herodotus"))
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || selectedFigure == nil)
            }
            .padding()
        }
        .frame(width: 480, height: 420)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let alternateName else { return }
        selectedFigure = alternateName.figure
        name = alternateName.name
        tradition = alternateName.tradition
        nameType = alternateName.nameType
        note = alternateName.note
    }

    private func save() {
        if let alternateName {
            alternateName.figure = selectedFigure
            alternateName.name = name
            alternateName.tradition = tradition
            alternateName.nameType = nameType
            alternateName.note = note
        } else {
            let newAltName = AlternateName(
                figure: selectedFigure,
                name: name, tradition: tradition,
                nameType: nameType, note: note
            )
            modelContext.insert(newAltName)
        }
        dismiss()
    }
}
