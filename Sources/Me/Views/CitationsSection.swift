import SwiftUI
import SwiftData

/// Section showing citations for a figure.
struct CitationsSection: View {
    let figure: Figure
    let filterText: String
    @Binding var showAddCitation: Bool

    private var figureCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == figure.name && $0.safeEntityType == .figure }
    }

    private var filteredCitations: [Citation] {
        filterText.isEmpty ? figureCitations : figureCitations.filter {
            matchesFilter($0.source?.name ?? "") || matchesFilter($0.safeLocation) || matchesFilter($0.safeNote)
        }
    }

    private func matchesFilter(_ text: String) -> Bool {
        guard !filterText.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(filterText)
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

            if filteredCitations.isEmpty {
                    Text("No matching citations found")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(filteredCitations) { citation in
                        HStack(alignment: .center, spacing: 4) {
                            FigureCitationsRow(citation: citation)
                            Button(action: {
                                citationToDelete = citation
                                showDeleteConfirm = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Delete citation")
                        }
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
    }

    @Environment(\.modelContext) private var modelContext
    @State private var citationToDelete: Citation?
    @State private var showDeleteConfirm = false
}