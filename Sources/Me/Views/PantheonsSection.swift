import SwiftUI
import SwiftData

/// Section showing pantheons a figure belongs to with alias editing.
struct PantheonsSection: View {
    let figure: Figure
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pantheon.name) private var allPantheons: [Pantheon]

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pantheons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Menu {
                    ForEach(allPantheons) { pantheon in
                        let isMember = figure.pantheons.contains { $0.persistentModelID == pantheon.persistentModelID }
                        Button {
                            if isMember {
                                pantheonToRemove = pantheon
                                showRemoveConfirm = true
                            } else {
                                figure.pantheons.append(pantheon)
                                try? modelContext.save()
                            }
                        } label: {
                            Label(pantheon.name, systemImage: isMember ? "checkmark" : "")
                        }
                    }
                    if allPantheons.isEmpty {
                        Text("No pantheons — add them in Type Settings")
                    }
                } label: {
                    Label("\(figure.pantheons.count)", systemImage: "building.columns")
                        .labelStyle(.titleAndIcon)
                }
                .menuStyle(.borderlessButton)
                .help("Assign pantheons to this figure")
                .fixedSize()
            }

            if figure.pantheons.isEmpty {
                Text("Not assigned to any pantheon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(figure.pantheons.sorted { $0.name < $1.name }) { pantheon in
                    HStack(spacing: 8) {
                        Image(systemName: pantheon.icon)
                            .font(.caption)
                            .foregroundStyle(pantheon.color)
                            .frame(width: 16)
                        Text(pantheon.name)
                            .font(.callout)
                        Text("as")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        TextField("\(figure.name)", text: pantheonAliasBinding(for: pantheon))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 160)
                        Button(action: {
                            pantheonToRemove = pantheon
                            showRemoveConfirm = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Remove from pantheon")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .alert("Remove from Pantheon?", isPresented: $showRemoveConfirm, presenting: pantheonToRemove) { pantheon in
            Button("Remove", role: .destructive) {
                removePantheonMembership(pantheon)
            }
            Button("Cancel", role: .cancel) {}
        } message: { pantheon in
            Text("Remove \(figure.name) from the pantheon \(pantheon.name)?")
        }
    }

    @State private var pantheonToRemove: Pantheon?
    @State private var showRemoveConfirm = false

    private func removePantheonMembership(_ pantheon: Pantheon) {
        figure.pantheons.removeAll { $0.persistentModelID == pantheon.persistentModelID }
        if let assoc = figure.pantheonAssociations?.first(where: { $0.pantheon?.persistentModelID == pantheon.persistentModelID }) {
            figure.pantheonAssociations?.removeAll { $0.persistentModelID == assoc.persistentModelID }
            modelContext.delete(assoc)
        }
        try? modelContext.save()
    }

    private func pantheonAliasBinding(for pantheon: Pantheon) -> Binding<String> {
        Binding(
            get: {
                if let assoc = figure.pantheonAssociations?.first(where: { $0.pantheon?.persistentModelID == pantheon.persistentModelID }),
                   let name = assoc.displayName, !name.isEmpty {
                    return name
                }
                return figure.name
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != figure.name else {
                    if let assoc = figure.pantheonAssociations?.first(where: { $0.pantheon?.persistentModelID == pantheon.persistentModelID }) {
                        assoc.displayName = nil
                        try? modelContext.save()
                    }
                    return
                }
                if let assoc = figure.pantheonAssociations?.first(where: { $0.pantheon?.persistentModelID == pantheon.persistentModelID }) {
                    assoc.displayName = trimmed
                } else {
                    let assoc = FigurePantheonAssociation(figure: figure, pantheon: pantheon, displayName: trimmed)
                    modelContext.insert(assoc)
                    if figure.pantheonAssociations == nil {
                        figure.pantheonAssociations = []
                    }
                    figure.pantheonAssociations?.append(assoc)
                }
                try? modelContext.save()
            }
        )
    }
}