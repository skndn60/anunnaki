import SwiftUI
import SwiftData

/// Section showing figure groups a figure belongs to.
struct GroupsSection: View {
    let figure: Figure
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Groups")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { showGroupLinkPopover = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Add to group")
                .popover(isPresented: $showGroupLinkPopover) {
                    GroupLinkPopover(
                        figure: figure,
                        searchText: $groupSearchText,
                        selectedGroup: $selectedGroupForLink,
                        isPresented: $showGroupLinkPopover
                    )
                    .frame(width: 340, height: 400)
                }
            }

            let groups = figure.groupAssociations
                .sorted { ($0.group?.fullDisplayName ?? "") < ($1.group?.fullDisplayName ?? "") }

            if groups.isEmpty {
                Text("Not in any group")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(groups) { assoc in
                    HStack(spacing: 8) {
                        Image(systemName: assoc.group?.icon ?? "folder")
                            .font(.caption)
                            .foregroundStyle(assoc.group.map { Color(hex: $0.colorHex) } ?? .gray)
                            .frame(width: 16)
                        Text(assoc.group?.fullDisplayName ?? "?")
                            .font(.callout)
                        if !assoc.note.isEmpty {
                            Text(assoc.note)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button(action: {
                            assocToDelete = assoc
                            showDeleteConfirm = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Remove from group")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .alert("Remove from Group?", isPresented: $showDeleteConfirm, presenting: assocToDelete) { assoc in
            Button("Remove", role: .destructive) {
                modelContext.delete(assoc)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { assoc in
            Text("Remove \(figure.name) from group \(assoc.group?.name ?? "?")?")
        }
    }

    @State private var showGroupLinkPopover = false
    @State private var groupSearchText = ""
    @State private var selectedGroupForLink: FigureGroup?
    @State private var assocToDelete: FigureGroupAssociation?
    @State private var showDeleteConfirm = false
}

private struct GroupLinkPopover: View {
    let figure: Figure
    @Binding var searchText: String
    @Binding var selectedGroup: FigureGroup?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var note: String = ""

    private var allGroups: [FigureGroup] {
        (try? modelContext.fetch(FetchDescriptor<FigureGroup>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? []
    }

    private var filteredGroups: [FigureGroup] {
        let linked = Set(figure.groupAssociations.compactMap { $0.group?.persistentModelID })
        let available = allGroups.filter { !linked.contains($0.persistentModelID) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search groups...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            if filteredGroups.isEmpty {
                Text("No matching groups")
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(filteredGroups, id: \.persistentModelID) { group in
                    Button(action: { selectedGroup = group }) {
                        HStack(spacing: 10) {
                            Image(systemName: group.icon)
                                .font(.caption)
                                .foregroundStyle(Color(hex: group.colorHex))
                                .frame(width: 16)
                            Text(group.name)
                                .font(.body)
                            Spacer()
                            if selectedGroup?.persistentModelID == group.persistentModelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Note (optional):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. chief deity of this council", text: $note)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
                }

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.bordered)
                    Button("Join") {
                        createAssociation()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedGroup == nil)
                }
            }
        }
        .padding()
    }

    private func createAssociation() {
        guard let group = selectedGroup else { return }
        let assoc = FigureGroupAssociation(figure: figure, group: group, note: note)
        modelContext.insert(assoc)
        figure.groupAssociations.append(assoc)
        group.figureAssociations.append(assoc)
        try? modelContext.save()
    }
}