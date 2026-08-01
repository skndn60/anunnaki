import SwiftUI
import SwiftData

struct EntityGroupsSection: View {
    let entityType: GroupEntityType
    let associations: [FigureGroupAssociation]
    var onCreateAssociation: ((FigureGroup) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedGroup: FigureGroup?
    @State private var showPopover = false

    private var allGroups: [FigureGroup] {
        let all: [FigureGroup] = (try? modelContext.fetch(FetchDescriptor<FigureGroup>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? []
        return all.filter { $0.entityType == entityType }
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
                            Text(group.name)
                                .font(.callout)
                        }
                        if !assoc.note.isEmpty {
                            Text(assoc.note)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button {
                            modelContext.delete(assoc)
                            try? modelContext.save()
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
                        onCreateAssociation?(group)
                    }
                    selectedGroup = nil
                    showPopover = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedGroup == nil)
            }
        }
        .padding()
        .frame(width: 340, height: 400)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0.5; g = 0.5; b = 0.5
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
