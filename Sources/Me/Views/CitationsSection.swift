import SwiftUI
import SwiftData

/// Section showing citations for a figure.
struct CitationsSection: View {
    let figure: Figure
    @Binding var showAddCitation: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var citationToDelete: Citation?
    @State private var showDeleteConfirm = false
    @State private var editingCitation: Citation?

    private var figureCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == figure.name && $0.safeEntityType == .figure }
    }

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sources & Citations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { showAddCitation = true }) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Add citation")
            }

            if figureCitations.isEmpty {
                Text("No citations yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(figureCitations) { citation in
                    CitationListRow(citation: citation, onEdit: {
                        editingCitation = citation
                    }, onDelete: {
                        citationToDelete = citation
                        showDeleteConfirm = true
                    })
                }
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