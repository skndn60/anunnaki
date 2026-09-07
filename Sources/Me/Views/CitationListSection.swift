import SwiftUI
import SwiftData

/// Shared "Sources & Citations" section for an entity's citation list.
/// Place and Event detail views previously rendered byte-identical inline
/// copies of this block (with their own delete state + alert); the section
/// owns the delete-confirm flow itself so callers stay thin.
struct CitationListSection: View {
    let citations: [Citation]

    @Environment(\.modelContext) private var modelContext
    @State private var citationToDelete: Citation?
    @State private var showDeleteConfirm = false

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources & Citations")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(citations) { citation in
                CitationListRow(citation: citation, onDelete: {
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
    }
}

/// One citation row: source + location on the first line, note below.
struct CitationListRow: View {
    let citation: Citation
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(.brown)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(citation.source?.name ?? "Unknown"), \(citation.safeLocation)")
                    .font(.caption)
                    .fontWeight(.medium)
                Text(citation.safeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer()
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
    }
}
