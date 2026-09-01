import SwiftUI
import SwiftData

struct EntityGroupsSection: View {
    let associations: [FigureGroupAssociation]
    var onCreateAssociation: ((FigureGroup) -> Void)?
    var event: Event?
    var onJoinWithPropagation: ((FigureGroup) -> Void)?
    var onRemoveWithDepropagation: ((FigureGroupAssociation) -> Void)?
    var onRemove: ((FigureGroupAssociation) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedGroup: FigureGroup?
    @State private var showPopover = false
    @State private var showPropagationConfirm = false
    @State private var propagationPreview: FigureGroup.EventPropagationSummary?
    @State private var pendingJoinGroup: FigureGroup?

    private var allGroups: [FigureGroup] {
        (try? modelContext.fetch(FetchDescriptor<FigureGroup>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? []
    }

    private var linkedIDs: Set<PersistentIdentifier> {
        Set(associations.compactMap { $0.group?.persistentModelID })
    }

    private var filteredGroups: [FigureGroup] {
        let available = allGroups.filter { !linkedIDs.contains($0.persistentModelID) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Groups")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { showPopover = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Add to group")
                .popover(isPresented: $showPopover) {
                    linkPopover
                }
            }

            let sorted = associations.sorted { ($0.group?.name ?? "") < ($1.group?.name ?? "") }
            if sorted.isEmpty {
                Text("Not in any group")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(sorted) { assoc in
                    HStack(spacing: 8) {
                        if let group = assoc.group {
                            Image(systemName: group.icon)
                                .font(.caption)
                                .foregroundStyle(Color(hex: group.colorHex))
                                .frame(width: 16)
                            Text(group.fullDisplayName)
                                .font(.callout)
                        }
                        if !assoc.note.isEmpty {
                            Text(assoc.note)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button {
                            if let onRemoveWithDepropagation {
                                onRemoveWithDepropagation(assoc)
                            } else if let onRemove {
                                onRemove(assoc)
                            } else {
                                modelContext.delete(assoc)
                                try? modelContext.save()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove from group")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .alert("Add to Group?", isPresented: $showPropagationConfirm) {
            Button("Add") {
                if let group = pendingJoinGroup {
                    onJoinWithPropagation?(group)
                }
                pendingJoinGroup = nil
                selectedGroup = nil
                showPopover = false
            }
            Button("Cancel", role: .cancel) {
                pendingJoinGroup = nil
            }
        } message: {
            if let preview = propagationPreview {
                Text("This event will also add: \(preview.description).")
            }
        }
    }

    private var linkPopover: some View {
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

            HStack {
                Spacer()
                Button("Cancel") { showPopover = false }
                    .buttonStyle(.bordered)
                Button("Join") {
                    if let group = selectedGroup {
                        if let event, let onJoinWithPropagation {
                            let preview = group.propagationPreview(for: event)
                            if let preview {
                                propagationPreview = preview
                                pendingJoinGroup = group
                                showPropagationConfirm = true
                            } else {
                                onJoinWithPropagation(group)
                                selectedGroup = nil
                                showPopover = false
                            }
                        } else {
                            onCreateAssociation?(group)
                            selectedGroup = nil
                            showPopover = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedGroup == nil)
            }
        }
        .padding()
        .frame(width: 340, height: 400)
    }
}

