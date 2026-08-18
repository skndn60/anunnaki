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
                    HStack(spacing: 8) {
                        Text(altName.name)
                            .font(.callout)
                            .fontWeight(.medium)
                        Text(altName.tradition.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        Text(altName.nameType.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button(action: {
                            altToDelete = altName
                            showDeleteAltConfirm = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Delete alternate name")
                    }
                    if !altName.note.isEmpty {
                        Text(altName.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
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
    }

    @State private var showDeleteAltConfirm = false
    @State private var altToDelete: AlternateName?
    @State private var showAddAltSheet = false
}