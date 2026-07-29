import SwiftUI
import SwiftData

struct FigureGroupListView: View {
    var coordinator: NavigationCoordinator?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FigureGroup.orderIndex) private var groups: [FigureGroup]
    @State private var showingAddSheet = false
    @State private var editingGroup: FigureGroup?
    @State private var selectedGroupID: PersistentIdentifier?
    @State private var showDeleteConfirm = false
    @AppStorage("figureGroupDetailWidth") private var detailWidth: Double = 320

    private var selectedGroup: FigureGroup? {
        guard let id = selectedGroupID else { return nil }
        return groups.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Figure Groups")
                        .font(.title2.bold())
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Group", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                Divider()

                if groups.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No figure groups yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Create groups to organize figures into categories like divine councils, dynasties, or pantheons.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $selectedGroupID) {
                        ForEach(groups) { group in
                            FigureGroupRow(group: group)
                                .tag(group.persistentModelID)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .frame(minWidth: 350, maxWidth: .infinity)

            Group {
                if let group = selectedGroup {
                    VStack(spacing: 0) {
                        DetailToolbar(
                            onEdit: { editingGroup = group },
                            onDelete: { showDeleteConfirm = true },
                            onClose: { selectedGroupID = nil }
                        )
                        FigureGroupDetailView(
                            group: group,
                            onSelectFigure: { figure in
                                    coordinator?.pushHistory(id: group.persistentModelID, name: group.name, item: .figureGroups)
                                    coordinator?.navigateToFigure(figure.persistentModelID, name: figure.name, recordHistory: false)
                            }
                        )
                    }
                    .frame(width: detailWidth)
                    .frame(maxHeight: .infinity)
                    .background(.thinMaterial)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.25), value: selectedGroupID)
        .sheet(isPresented: $showingAddSheet) {
            FigureGroupFormView(group: nil)
        }
        .sheet(item: $editingGroup) { group in
            FigureGroupFormView(group: group)
        }
        .alert("Delete Group?", isPresented: $showDeleteConfirm, presenting: selectedGroup) { group in
            Button("Delete", role: .destructive) { deleteGroup(group) }
            Button("Cancel", role: .cancel) {}
        } message: { group in
            Text("Delete \"\(group.name)\"? This cannot be undone.")
        }
        .onAppear {
            consumePendingNavigation()
        }
        .onChange(of: coordinator?.pendingGroupID) { _, _ in
            consumePendingNavigation()
        }
    }

    private func consumePendingNavigation() {
        guard let id = coordinator?.consumePendingGroupID() else { return }
        if groups.contains(where: { $0.persistentModelID == id }) {
            selectedGroupID = id
        }
    }

    private func deleteGroup(_ group: FigureGroup) {
        if selectedGroupID == group.persistentModelID { selectedGroupID = nil }
        withAnimation { modelContext.delete(group) }
    }
}

struct FigureGroupRow: View {
    let group: FigureGroup

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: group.icon)
                .font(.caption)
                .foregroundStyle(Color(hex: group.colorHex))
                .frame(width: 16)
            Text(group.name)
                .fontWeight(.medium)
            Spacer()
            Text("\(group.figureAssociations.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.1)))
        }
    }
}

struct FigureGroupDetailView: View {
    let group: FigureGroup
    var onSelectFigure: ((Figure) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var showBulkAdd = false
    @State private var showSyncConfirm = false

    private var members: [FigureGroupAssociation] {
        group.figureAssociations
            .sorted { ($0.figure?.name ?? "") < ($1.figure?.name ?? "") }
    }

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: group.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: group.colorHex))
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.title2.bold())
                        if !group.groupDescription.isEmpty {
                            Text(group.groupDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let filter = group.decodedFilter {
                            HStack(spacing: 4) {
                                Image(systemName: "repeat")
                                    .font(.caption2)
                                Text(filter.summary)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.teal)
                            .padding(.top, 2)
                        }
                    }
                    Spacer()
                }

                Divider()

                // Actions
                HStack(spacing: 8) {
                    Button(action: { showBulkAdd = true }) {
                        Label("Bulk Add", systemImage: "plus.rectangle.on.rectangle")
                    }
                    .buttonStyle(.bordered)

                    if group.memberFilter != nil {
                        Button(action: { showSyncConfirm = true }) {
                            Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()
                }

                // Members
                VStack(alignment: .leading, spacing: 8) {
                    Text("Members (\(members.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    if members.isEmpty {
                        Text("No figures in this group")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(members) { assoc in
                            HStack(spacing: 10) {
                                Image(systemName: assoc.figure?.figureType?.icon ?? "person.fill")
                                    .font(.caption)
                                    .foregroundStyle(assoc.figure?.figureType?.color ?? .gray)
                                    .frame(width: 16)
                                if let figure = assoc.figure {
                                    Button(action: { onSelectFigure?(figure) }) {
                                        Text(figure.name)
                                            .font(.callout)
                                            .foregroundStyle(Color.accentColor)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                    .pointingHand()
                                } else {
                                    Text("(removed)")
                                        .font(.callout)
                                        .foregroundStyle(.tertiary)
                                }
                                if !assoc.note.isEmpty {
                                    Text(assoc.note)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .sheet(isPresented: $showBulkAdd) {
            BulkAddMembersSheet(group: group)
        }
        .alert("Sync Group Members?", isPresented: $showSyncConfirm) {
            Button("Sync") { syncMembers() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add all figures matching the member filter rule to this group? Existing members will be kept.")
        }
    }

    private func syncMembers() {
        guard let filter = group.decodedFilter else { return }
        let existingIDs = Set(members.compactMap { $0.figure?.persistentModelID })
        let toAdd = allFigures.filter { filter.matches($0) && !existingIDs.contains($0.persistentModelID) }
        for figure in toAdd {
            let assoc = FigureGroupAssociation(figure: figure, group: group)
            modelContext.insert(assoc)
        }
        try? modelContext.save()
    }
}

private struct BulkAddMembersSheet: View {
    let group: FigureGroup
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTypeNames: Set<String> = []
    @State private var domainText = ""
    @State private var nameSearch = ""
    @State private var saveAsRule = false
    @State private var addedCount = 0
    @State private var showSuccess = false

    @Query(sort: \FigureType.name) private var figureTypes: [FigureType]

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var existingFigureIDs: Set<PersistentIdentifier> {
        Set(group.figureAssociations.compactMap { $0.figure?.persistentModelID })
    }

    private var matchingFigures: [Figure] {
        let domainKeywords = domainText.split(separator: ",").map(String.init).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let criteriaMet = allFigures.filter { figure in
            if selectedTypeNames.isEmpty && domainKeywords.isEmpty && nameSearch.isEmpty { return false }
            var matched = false
            if let typeName = figure.figureType?.name,
               selectedTypeNames.contains(where: { $0.localizedCaseInsensitiveCompare(typeName) == .orderedSame }) {
                matched = true
            }
            if !domainKeywords.isEmpty,
               domainKeywords.contains(where: { figure.domain.localizedCaseInsensitiveContains($0) }) {
                matched = true
            }
            if !nameSearch.isEmpty,
               figure.name.localizedCaseInsensitiveContains(nameSearch) {
                matched = true
            }
            return matched
        }
        return criteriaMet.filter { !existingFigureIDs.contains($0.persistentModelID) }
    }

    private var hasActiveFilter: Bool {
        !selectedTypeNames.isEmpty || !domainText.trimmingCharacters(in: .whitespaces).isEmpty || !nameSearch.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Bulk Add Members")
                .font(.title3.bold())
                .padding()

            ScrollView {
                VStack(spacing: 14) {
                    // Filter by type
                    VStack(alignment: .leading, spacing: 6) {
                        Text("By Figure Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let columns = [GridItem(.adaptive(minimum: 140))]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                            ForEach(figureTypes) { type in
                                typeFilterButton(type)
                            }
                        }
                    }

                    // Filter by domain
                    VStack(alignment: .leading, spacing: 6) {
                        Text("By Domain Keyword")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Sumerian, Akkadian, Kingship", text: $domainText)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                    }

                    // Filter by name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("By Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Enki, Gilgamesh", text: $nameSearch)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                    }

                    // Results
                    if hasActiveFilter {
                        Divider()
                        HStack {
                            Text("\(matchingFigures.count) figure(s) match and can be added")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !matchingFigures.isEmpty {
                                Button("Add All") {
                                    addAllMatching()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(matchingFigures.isEmpty)
                            }
                        }

                        if !matchingFigures.isEmpty {
                            List(matchingFigures.prefix(20), id: \.persistentModelID) { figure in
                                HStack(spacing: 10) {
                                    Image(systemName: figure.figureType?.icon ?? "person.fill")
                                        .font(.caption)
                                        .foregroundStyle(figure.figureType?.color ?? .gray)
                                        .frame(width: 16)
                                    Text(figure.name)
                                        .font(.callout)
                                }
                            }
                            .listStyle(.plain)
                            .frame(height: min(CGFloat(matchingFigures.count) * 28, 200))
                            if matchingFigures.count > 20 {
                                Text("... and \(matchingFigures.count - 20) more")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Save as rule toggle
                        Toggle(isOn: $saveAsRule) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save as membership rule")
                                    .font(.callout)
                                Text("Future figures matching these criteria will be auto-added when you Sync.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("Select filter criteria above to find figures to add.")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }

            Divider()
            HStack {
                if addedCount > 0 {
                    Text("Added \(addedCount) figure(s)")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 520, height: 620)
        .alert("Members Added", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("\(addedCount) figure(s) were added to \"\(group.name)\".")
        }
    }

    private func typeFilterButton(_ type: FigureType) -> some View {
        let isSelected = selectedTypeNames.contains(type.name)
        return Button(action: {
            if isSelected { selectedTypeNames.remove(type.name) }
            else { selectedTypeNames.insert(type.name) }
        }) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                    .foregroundStyle(type.color)
                Text(type.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? type.color.opacity(0.15) : Color(.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? type.color : Color.gray.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func addAllMatching() {
        for figure in matchingFigures {
            let assoc = FigureGroupAssociation(figure: figure, group: group)
            modelContext.insert(assoc)
        }
        if saveAsRule && hasActiveFilter {
            let domainKeywords = domainText.split(separator: ",").map(String.init).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let filter = GroupMemberFilter(
                figureTypeNames: selectedTypeNames.isEmpty ? nil : Array(selectedTypeNames),
                domainKeywords: domainKeywords.isEmpty ? nil : domainKeywords,
                nameMatch: nameSearch.isEmpty ? nil : nameSearch
            )
            group.decodedFilter = filter
        }
        addedCount = matchingFigures.count
        try? modelContext.save()
        showSuccess = true
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
