import SwiftUI
import SwiftData

/// Shared "Sources & Citations" section for an entity's citation list.
/// Place and Event detail views previously rendered byte-identical inline
/// copies of this block (with their own delete state + alert); the section
/// owns the delete/edit flows itself so callers stay thin.
struct CitationListSection: View {
    let citations: [Citation]

    @Environment(\.modelContext) private var modelContext
    @State private var citationToDelete: Citation?
    @State private var showDeleteConfirm = false
    @State private var editingCitation: Citation?

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources & Citations")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(citations) { citation in
                CitationListRow(citation: citation, onEdit: {
                    editingCitation = citation
                }, onDelete: {
                    citationToDelete = citation
                    showDeleteConfirm = true
                })
            }
        }
        .alert("Delete Citation?", isPresented: $showDeleteConfirm, presenting: citationToDelete) { citation in
            Button("Delete", role: .destructive) {
                modelContext.delete(citation)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { citation in
            Text("Delete the citation from \(citation.source?.name ?? "Unknown")?")
        }
        .sheet(item: $editingCitation) { citation in
            CitationFormSheet(citation: citation)
        }
    }
}

/// One citation row: source on the first line with edit/delete actions,
/// location + note on the second and third so narrow widths stay readable.
struct CitationListRow: View {
    let citation: Citation
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(.brown)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(citation.source?.name ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !citation.safeLocation.isEmpty {
                    Text(citation.safeLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if !citation.safeNote.isEmpty {
                    Text(citation.safeNote)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit citation")
            }
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete citation")
            }
        }
        .padding(.vertical, 1)
    }
}

/// Add/edit sheet for a citation. Pass `citation` to edit an existing one;
/// pass `entityType` + `linkedEntityName` to create one against an entity.
struct CitationFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var sources: [Source]

    var citation: Citation?
    var entityType: Citation.EntityType?
    var linkedEntityName: String?

    @State private var selectedSource: Source?
    @State private var location = ""
    @State private var note = ""

    private var isEditing: Bool { citation != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Citation" : "Add Citation")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Source") {
                    Picker("Source", selection: $selectedSource) {
                        Text("Select a source").tag(nil as Source?)
                        ForEach(sources, id: \.persistentModelID) { source in
                            Text(source.pickerLabel).tag(source as Source?)
                        }
                    }
                }

                TextField("Location", text: $location, prompt: Text("Tablet I, line 15"))

                TextField("Note", text: $note, prompt: Text("Optional note"))
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedSource == nil)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
        .onAppear(perform: loadIfEditing)
    }

    private func loadIfEditing() {
        guard let citation else { return }
        selectedSource = citation.source
        location = citation.location
        note = citation.note
    }

    private func save() {
        if let citation {
            citation.source = selectedSource
            citation.location = location
            citation.note = note
            try? modelContext.save()
        } else {
            if let source = selectedSource {
                RelationshipManager(context: modelContext).addCitation(
                    to: source,
                    location: location,
                    note: note,
                    entityType: entityType ?? .figure,
                    linkedEntityName: linkedEntityName ?? "",
                    dedupe: false
                )
                try? modelContext.save()
            }
        }
        dismiss()
    }
}