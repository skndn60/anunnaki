import SwiftUI
import SwiftData

/// Section showing alternate names for a figure.
struct AlternateNamesSection: View {
    let figure: Figure
    let filterText: String
    @Environment(\.modelContext) private var modelContext

    private var filteredAlternateNames: [AlternateName] {
        (filterText.isEmpty ? figure.alternateNames : figure.alternateNames.filter {
            matchesFilter($0.name) || matchesFilter($0.tradition.rawValue) || matchesFilter($0.nameType.rawValue) || matchesFilter($0.note)
        }).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func matchesFilter(_ text: String) -> Bool {
        guard !filterText.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(filterText)
    }

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Also Known As")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    showAddAltSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Add alternate name")
            }

            if figure.alternateNames.isEmpty {
                Text("No alternate names")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(filteredAlternateNames) { altName in
                    AlternateNameCardRow(
                        altName: altName,
                        onEdit: { editingAltName = altName },
                        onDelete: {
                            altToDelete = altName
                            showDeleteAltConfirm = true
                        }
                    )
                }
            }
        }
        .alert("Delete Alternate Name?", isPresented: $showDeleteAltConfirm, presenting: altToDelete) { altName in
            Button("Delete", role: .destructive) {
                modelContext.delete(altName)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { altName in
            Text("Delete \"\(altName.name)\" (\(altName.tradition.rawValue)) from \(altName.figure?.name ?? "?")?")
        }
        .sheet(isPresented: $showAddAltSheet) {
            AlternateNameFormView(alternateName: nil, preSelectedFigure: figure)
        }
        .sheet(item: $editingAltName) { altName in
            AlternateNameFormView(alternateName: altName)
        }
    }

    @State private var showDeleteAltConfirm = false
    @State private var altToDelete: AlternateName?
    @State private var showAddAltSheet = false
    @State private var editingAltName: AlternateName?
}

/// Shared two-line row for an alternate name: identity + actions on the first
/// line, secondary info (type, note) on the second so narrow widths never
/// overflow horizontally.
struct AlternateNameCardRow: View {
    let altName: AlternateName
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(altName.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(altName.tradition.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(altName.tradition.color.opacity(0.12))
                    )
                Spacer(minLength: 8)
                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit alternate name")
                }
                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Delete alternate name")
                }
            }
            HStack(spacing: 6) {
                Text(altName.nameType.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !altName.note.isEmpty {
                    Text(altName.note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.leading, 4)
        }
    }
}