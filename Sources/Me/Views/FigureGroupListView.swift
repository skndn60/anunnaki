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
                    Text("Groups")
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
                        Text("No groups yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Create groups to organize figures, places, events, or things into categories like divine councils, dynasties, or pantheons.")
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
                            onOpenMember: { item in
                                coordinator?.pushHistory(id: group.persistentModelID, name: group.name, item: .figureGroups)
                                switch item.entityType {
                                case .figure:
                                    if let figure = item.figure {
                                        coordinator?.navigateToFigure(figure.persistentModelID, name: figure.name, recordHistory: false)
                                    }
                                case .place:
                                    if let place = item.place {
                                        coordinator?.navigateToPlace(place.persistentModelID, name: place.name, recordHistory: false)
                                    }
                                case .event:
                                    if let event = item.event {
                                        coordinator?.navigateToEvent(event.persistentModelID, name: event.name, recordHistory: false)
                                    }
                                case .thing:
                                    if let thing = item.thing {
                                        coordinator?.navigateToThing(thing.persistentModelID, name: thing.name, recordHistory: false)
                                    }
                                }
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
            Task { @MainActor in
                selectedGroupID = id
            }
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
            if group.parentGroup != nil {
                Image(systemName: "arrow.turn.up.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Image(systemName: group.icon)
                .font(.caption)
                .foregroundStyle(Color(hex: group.colorHex))
                .frame(width: 16)
            Text(group.name)
                .fontWeight(.medium)
            Spacer()
            if !(group.subgroups ?? []).isEmpty {
                Image(systemName: "folder.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
    var onOpenMember: ((GroupMemberItem) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var showBulkAdd = false
    @State private var showSyncConfirm = false

    private var members: [GroupMemberItem] {
        group.figureAssociations
            .compactMap(GroupMemberItem.init(association:))
            .sorted { $0.name < $1.name }
    }

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var allPlaces: [Place] {
        (try? modelContext.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var allEvents: [Event] {
        (try? modelContext.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var allThings: [Thing] {
        (try? modelContext.fetch(FetchDescriptor<Thing>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: group.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: group.colorHex))
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.title2.bold())
                        if !group.groupDescription.isEmpty || group.richDescription != nil {
                            RichTextDisplay(richData: group.richDescription, fallback: group.groupDescription)
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

                    Toggle(isOn: Binding(
                        get: { group.isPublished },
                        set: { group.isPublished = $0; try? modelContext.save() }
                    )) {
                        Label("Show in sidebar", systemImage: "sidebar.left")
                    }
                    .toggleStyle(.checkbox)
                    .help("Hide this group from the sidebar while keeping its data")
                }

                // Members
                VStack(alignment: .leading, spacing: 8) {
                    Text("Members (\(members.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    if members.isEmpty {
                        Text("No \(group.entityType.pluralName.lowercased()) in this group")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(members) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.icon)
                                    .font(.caption)
                                    .foregroundStyle(item.color)
                                    .frame(width: 16)
                                Button(action: { onOpenMember?(item) }) {
                                    Text(item.displayName)
                                        .font(.callout)
                                        .foregroundStyle(Color.accentColor)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                                .pointingHand()
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
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
            Text("Add all \(group.entityType.pluralName.lowercased()) matching the member filter rule to this group? Existing members will be kept.")
        }
    }

    private func syncMembers() {
        guard let filter = group.decodedFilter else { return }
        let existingIDs = Set(members.map(\.id))
        let items: [GroupMemberItem]
        switch group.entityType {
        case .figure:
            items = allFigures.filter { filter.matches($0) && !existingIDs.contains($0.persistentModelID) }.map { GroupMemberItem.figure($0, nil) }
        case .place:
            items = allPlaces.filter { filter.matchesPlace($0) && !existingIDs.contains($0.persistentModelID) }.map { GroupMemberItem.place($0, nil) }
        case .event:
            items = allEvents.filter { filter.matchesEvent($0) && !existingIDs.contains($0.persistentModelID) }.map { GroupMemberItem.event($0, nil) }
        case .thing:
            items = allThings.filter { filter.matchesThing($0) && !existingIDs.contains($0.persistentModelID) }.map { GroupMemberItem.thing($0, nil) }
        }
        for item in items {
            let assoc = item.makeAssociation()
            modelContext.insert(assoc)
            group.figureAssociations.append(assoc)
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
    @Query(sort: \PlaceType.name) private var placeTypes: [PlaceType]
    @Query(sort: \EventType.name) private var eventTypes: [EventType]
    @Query(sort: \ThingType.name) private var thingTypes: [ThingType]

    private var entityType: GroupEntityType { group.entityType }

    private var typePills: [TypePill] {
        switch entityType {
        case .figure: return figureTypes.map { TypePill(name: $0.name, icon: $0.icon, color: $0.color) }
        case .place: return placeTypes.map { TypePill(name: $0.name, icon: $0.icon, color: $0.color) }
        case .event: return eventTypes.map { TypePill(name: $0.name, icon: $0.icon, color: $0.color) }
        case .thing: return thingTypes.map { TypePill(name: $0.name, icon: $0.icon, color: $0.color) }
        }
    }

    private var allCandidates: [GroupMemberItem] {
        switch entityType {
        case .figure:
            return ((try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []).map { GroupMemberItem.figure($0, nil) }
        case .place:
            return ((try? modelContext.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []).map { GroupMemberItem.place($0, nil) }
        case .event:
            return ((try? modelContext.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.name)]))) ?? []).map { GroupMemberItem.event($0, nil) }
        case .thing:
            return ((try? modelContext.fetch(FetchDescriptor<Thing>(sortBy: [SortDescriptor(\.name)]))) ?? []).map { GroupMemberItem.thing($0, nil) }
        }
    }

    private var existingIDs: Set<PersistentIdentifier> {
        Set(group.figureAssociations.compactMap { assoc in
            switch entityType {
            case .figure: return assoc.figure?.persistentModelID
            case .place: return assoc.place?.persistentModelID
            case .event: return assoc.event?.persistentModelID
            case .thing: return assoc.thing?.persistentModelID
            }
        })
    }

    private var domainKeywords: [String] {
        domainText.split(separator: ",").map(String.init).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var matchingItems: [GroupMemberItem] {
        let criteriaMet = allCandidates.filter { item in
            if selectedTypeNames.isEmpty && domainKeywords.isEmpty && nameSearch.isEmpty { return false }
            var matched = false
            if selectedTypeNames.contains(where: { $0.localizedCaseInsensitiveCompare(item.subtitle) == .orderedSame }) {
                matched = true
            }
            if !domainKeywords.isEmpty,
               case .figure(let figure, _) = item,
               domainKeywords.contains(where: { figure.domain.localizedCaseInsensitiveContains($0) }) {
                matched = true
            }
            if !nameSearch.isEmpty,
               item.matches(nameSearch) {
                matched = true
            }
            return matched
        }
        return criteriaMet.filter { !existingIDs.contains($0.id) }
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
                        Text("By \(entityType.displayName) Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let columns = [GridItem(.adaptive(minimum: 140))]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                            ForEach(typePills) { pill in
                                typeFilterButton(pill)
                            }
                        }
                    }

                    // Filter by domain (figures only)
                    if entityType == .figure {
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
                            Text("\(matchingItems.count) \(entityType.pluralName.lowercased()) match and can be added")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !matchingItems.isEmpty {
                                Button("Add All") {
                                    addAllMatching()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(matchingItems.isEmpty)
                            }
                        }

                        if !matchingItems.isEmpty {
                            List(matchingItems.prefix(20)) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.icon)
                                        .font(.caption)
                                        .foregroundStyle(item.color)
                                        .frame(width: 16)
                                    Text(item.name)
                                        .font(.callout)
                                }
                            }
                            .listStyle(.plain)
                            .frame(height: min(CGFloat(matchingItems.count) * 28, 200))
                            if matchingItems.count > 20 {
                                Text("... and \(matchingItems.count - 20) more")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Save as rule toggle
                        Toggle(isOn: $saveAsRule) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save as membership rule")
                                    .font(.callout)
                                Text("Future \(entityType.pluralName.lowercased()) matching these criteria will be auto-added when you Sync.")
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
                            Text("Select filter criteria above to find \(entityType.pluralName.lowercased()) to add.")
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
                    Text("Added \(addedCount) \(entityType.pluralName.lowercased())")
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
            Text("\(addedCount) \(entityType.pluralName.lowercased()) were added to \"\(group.name)\".")
        }
    }

    private func typeFilterButton(_ pill: TypePill) -> some View {
        let isSelected = selectedTypeNames.contains(pill.name)
        return Button(action: {
            if isSelected { selectedTypeNames.remove(pill.name) }
            else { selectedTypeNames.insert(pill.name) }
        }) {
            HStack(spacing: 6) {
                Image(systemName: pill.icon)
                    .font(.caption)
                    .foregroundStyle(pill.color)
                Text(pill.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? pill.color.opacity(0.15) : Color(.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? pill.color : Color.gray.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func addAllMatching() {
        for item in matchingItems {
            let assoc = item.makeAssociation()
            modelContext.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        if saveAsRule && hasActiveFilter {
            let filter: GroupMemberFilter
            switch entityType {
            case .figure:
                filter = GroupMemberFilter(
                    figureTypeNames: selectedTypeNames.isEmpty ? nil : Array(selectedTypeNames),
                    domainKeywords: domainKeywords.isEmpty ? nil : domainKeywords,
                    nameMatch: nameSearch.isEmpty ? nil : nameSearch
                )
            case .place:
                filter = GroupMemberFilter(
                    placeTypeNames: selectedTypeNames.isEmpty ? nil : Array(selectedTypeNames),
                    nameMatch: nameSearch.isEmpty ? nil : nameSearch
                )
            case .event:
                filter = GroupMemberFilter(
                    eventTypeNames: selectedTypeNames.isEmpty ? nil : Array(selectedTypeNames),
                    nameMatch: nameSearch.isEmpty ? nil : nameSearch
                )
            case .thing:
                filter = GroupMemberFilter(
                    thingTypeNames: selectedTypeNames.isEmpty ? nil : Array(selectedTypeNames),
                    nameMatch: nameSearch.isEmpty ? nil : nameSearch
                )
            }
            group.decodedFilter = filter
        }
        addedCount = matchingItems.count
        try? modelContext.save()
        showSuccess = true
    }
}

private struct TypePill: Identifiable {
    let name: String
    let icon: String
    let color: Color

    var id: String { name }
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
