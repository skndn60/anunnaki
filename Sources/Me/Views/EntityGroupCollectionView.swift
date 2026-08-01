import SwiftUI
import SwiftData

private enum MixedItem: Identifiable {
    case figure(Figure, String?)
    case place(Place, String?)
    case event(Event, String?)
    case thing(Thing, String?)
    case group(FigureGroup)

    var id: PersistentIdentifier {
        switch self {
        case .figure(let entity, _): return entity.persistentModelID
        case .place(let entity, _): return entity.persistentModelID
        case .event(let entity, _): return entity.persistentModelID
        case .thing(let entity, _): return entity.persistentModelID
        case .group(let entity): return entity.persistentModelID
        }
    }

    var name: String {
        switch self {
        case .figure(let entity, _): return entity.name
        case .place(let entity, _): return entity.name
        case .event(let entity, _): return entity.name
        case .thing(let entity, _): return entity.name
        case .group(let entity): return entity.name
        }
    }

    var alias: String? {
        switch self {
        case .figure(_, let alias): return alias
        case .place(_, let alias): return alias
        case .event(_, let alias): return alias
        case .thing(_, let alias): return alias
        case .group: return nil
        }
    }

    var displayName: String {
        if let alias, !alias.isEmpty {
            return "\(name) as \(alias)"
        }
        return name
    }

    var canOpenInWindow: Bool {
        switch self {
        case .figure, .place, .event: return true
        case .thing, .group: return false
        }
    }
}

struct EntityGroupCollectionView: View {
    let group: FigureGroup
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var expandedGroups: Set<PersistentIdentifier> = []
    @State private var selectedMemberID: PersistentIdentifier?
    @State private var editingFigure: Figure?
    @State private var editingPlace: Place?
    @State private var editingEvent: Event?
    @State private var editingThing: Thing?
    @State private var showDeleteConfirm = false
    @State private var imageDetailImage: ImageAsset?

    private var entityType: GroupEntityType { group.entityType }

    private var subgroups: [FigureGroup] {
        (group.subgroups ?? []).sorted { ($0.orderIndex, $0.name) < ($1.orderIndex, $1.name) }
    }

    private var directMembers: [MixedItem] {
        switch entityType {
        case .figure: return group.directFigures.map { MixedItem.figure($0, group.displayName(for: $0.persistentModelID)) }
        case .place: return group.directPlaces.map { MixedItem.place($0, group.displayName(for: $0.persistentModelID)) }
        case .event: return group.directEvents.map { MixedItem.event($0, group.displayName(for: $0.persistentModelID)) }
        case .thing: return group.directThings.map { MixedItem.thing($0, group.displayName(for: $0.persistentModelID)) }
        }
    }

    private var mixedItems: [MixedItem] {
        let all = directMembers + subgroups.map(MixedItem.group)
        if searchText.isEmpty { return all.sorted { $0.name < $1.name } }
        return all
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name < $1.name }
    }

    private var ancestors: [FigureGroup] {
        var chain: [FigureGroup] = []
        var current: FigureGroup? = group.parentGroup
        while let parent = current {
            chain.append(parent)
            current = parent.parentGroup
        }
        return chain.reversed()
    }

    private var selectedFigure: Figure? {
        guard entityType == .figure, let id = selectedMemberID else { return nil }
        let fetch = FetchDescriptor<Figure>(predicate: #Predicate { $0.persistentModelID == id })
        return try? modelContext.fetch(fetch).first
    }

    private var selectedPlace: Place? {
        guard entityType == .place, let id = selectedMemberID else { return nil }
        let fetch = FetchDescriptor<Place>(predicate: #Predicate { $0.persistentModelID == id })
        return try? modelContext.fetch(fetch).first
    }

    private var selectedEvent: Event? {
        guard entityType == .event, let id = selectedMemberID else { return nil }
        let fetch = FetchDescriptor<Event>(predicate: #Predicate { $0.persistentModelID == id })
        return try? modelContext.fetch(fetch).first
    }

    private var selectedThing: Thing? {
        guard entityType == .thing, let id = selectedMemberID else { return nil }
        let fetch = FetchDescriptor<Thing>(predicate: #Predicate { $0.persistentModelID == id })
        return try? modelContext.fetch(fetch).first
    }

    private var selectedItemName: String? {
        switch entityType {
        case .figure: return selectedFigure?.name
        case .place: return selectedPlace?.name
        case .event: return selectedEvent?.name
        case .thing: return selectedThing?.name
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ancestorTrail
                    header
                    searchBar
                    if mixedItems.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 2) {
                            ForEach(mixedItems) { item in
                                switch item {
                                case .group(let subgroup):
                                    EntityGroupTreeNode(
                                        group: subgroup,
                                        expanded: $expandedGroups,
                                        onSelectMember: { selectedMemberID = $0.id },
                                        onOpenInSidebar: { openInSidebar($0) },
                                        onOpenInWindow: { openInWindow($0) },
                                        onEditMember: { beginEdit($0) },
                                        onDeleteMember: { beginDelete($0) },
                                        onOpenGroup: { sub in
                                            coordinator?.navigateToGroup(sub.persistentModelID, name: sub.name, recordHistory: false)
                                        }
                                    )
                                default:
                                    MemberRow(
                                        item: item,
                                        isSelected: selectedMemberID == item.id,
                                        onSelect: { selectedMemberID = item.id },
                                        onOpenInSidebar: { openInSidebar(item) },
                                        onOpenInWindow: { openInWindow(item) },
                                        onEdit: { beginEdit(item) },
                                        onDelete: { beginDelete(item) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if selectedMemberID != nil {
                Divider()
                detailPanel
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)
                    .background(.thinMaterial)
            }
        }
        .sheet(item: $editingFigure) { FigureFormView(figure: $0) }
        .sheet(item: $editingPlace) { PlaceFormView(place: $0) }
        .sheet(item: $editingEvent) { EventFormView(event: $0) }
        .sheet(item: $editingThing) { ThingFormView(thing: $0) }
        .alert("Delete Member?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(selectedItemName.map { "Delete \"\($0)\"? This cannot be undone." } ?? "Delete this member?")
        }
        .onChange(of: imageDetailImage) { _, newValue in
            if let image = newValue {
                openWindow(id: "image-detail", value: image.persistentModelID)
                imageDetailImage = nil
            }
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                switch entityType {
                case .figure:
                    if let figure = selectedFigure {
                        IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") { editingFigure = figure }
                        IconActionButton(icon: "trash", color: .red, help: "Delete") { showDeleteConfirm = true }
                    }
                case .place:
                    if let place = selectedPlace {
                        IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") { editingPlace = place }
                        IconActionButton(icon: "trash", color: .red, help: "Delete") { showDeleteConfirm = true }
                    }
                case .event:
                    if let event = selectedEvent {
                        IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") { editingEvent = event }
                        IconActionButton(icon: "trash", color: .red, help: "Delete") { showDeleteConfirm = true }
                    }
                case .thing:
                    if let thing = selectedThing {
                        IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") { editingThing = thing }
                        IconActionButton(icon: "trash", color: .red, help: "Delete") { showDeleteConfirm = true }
                    }
                }
                Spacer()
                Button(action: { selectedMemberID = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(8)

            switch entityType {
            case .figure:
                if let figure = selectedFigure {
                    FigureDetailView(
                        figure: figure,
                        onSelectFigure: { selected in deferSelect(selected.persistentModelID) },
                        onSelectPlace: { place in deferSelect(place.persistentModelID) },
                        onSelectEvent: { event in deferSelect(event.persistentModelID) },
                        onSelectImage: { imageDetailImage = $0 }
                    )
                } else {
                    Text("Select a figure")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .place:
                if let place = selectedPlace {
                    PlaceDetailView(
                        place: place,
                        onSelectFigure: { figure in deferSelect(figure.persistentModelID) },
                        onSelectEvent: { event in deferSelect(event.persistentModelID) },
                        onSelectImage: { imageDetailImage = $0 }
                    )
                } else {
                    Text("Select a place")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .event:
                if let event = selectedEvent {
                    EventDetailView(
                        event: event,
                        onSelectFigure: { figure in deferSelect(figure.persistentModelID) },
                        onSelectPlace: { place in deferSelect(place.persistentModelID) },
                        onSelectImage: { imageDetailImage = $0 }
                    )
                } else {
                    Text("Select an event")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .thing:
                if let thing = selectedThing {
                    ThingDetailView(
                        thing: thing,
                        onSelectImage: { imageDetailImage = $0 }
                    )
                } else {
                    Text("Select a thing")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var ancestorTrail: some View {
        Group {
            if !ancestors.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(ancestors.enumerated()), id: \.offset) { index, ancestor in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            coordinator?.navigateToGroup(ancestor.persistentModelID, name: ancestor.name, recordHistory: false)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: ancestor.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(ancestor.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: group.icon)
                .font(.system(size: 28))
                .foregroundStyle(Color(hex: group.colorHex))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(hex: group.colorHex).opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.largeTitle.bold())
                if !group.groupDescription.isEmpty || group.richDescription != nil {
                    GroupDescriptionDisplay(group: group)
                }
                HStack(spacing: 8) {
                    Text("\(group.figureAssociations.count) member\(group.figureAssociations.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if !subgroups.isEmpty {
                        Text("\(subgroups.count) subgroup\(subgroups.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Search \(entityType.pluralName.lowercased()) and subgroups\u{2026}", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: 320)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: entityType.icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No \(entityType.pluralName.lowercased()) in this group" : "No matches")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func deferSelect(_ id: PersistentIdentifier) {
        Task { @MainActor in
            selectedMemberID = id
        }
    }

    private func openInSidebar(_ item: MixedItem) {        switch item {
        case .figure(let figure, _):
            coordinator?.pushHistory(id: group.persistentModelID, name: group.name, item: .figureGroups)
            coordinator?.navigateToFigure(figure.persistentModelID, name: figure.name, recordHistory: false)
        case .place(let place, _):
            coordinator?.pushHistory(id: group.persistentModelID, name: group.name, item: .figureGroups)
            coordinator?.navigateToPlace(place.persistentModelID, name: place.name, recordHistory: false)
        case .event(let event, _):
            coordinator?.pushHistory(id: group.persistentModelID, name: group.name, item: .figureGroups)
            coordinator?.navigateToEvent(event.persistentModelID, name: event.name, recordHistory: false)
        case .thing(let thing, _):
            coordinator?.pushHistory(id: group.persistentModelID, name: group.name, item: .figureGroups)
            coordinator?.navigateToThing(thing.persistentModelID, name: thing.name, recordHistory: false)
        case .group:
            break
        }
    }

    private func openInWindow(_ item: MixedItem) {
        switch item {
        case .figure(let figure, _):
            openWindow(id: "figure-detail", value: figure.persistentModelID)
        case .place(let place, _):
            openWindow(id: "place-quickview", value: place.persistentModelID)
        case .event(let event, _):
            openWindow(id: "event-quickview", value: event.persistentModelID)
        default:
            break
        }
    }

    private func beginEdit(_ item: MixedItem) {
        switch item {
        case .figure(let figure, _): editingFigure = figure
        case .place(let place, _): editingPlace = place
        case .event(let event, _): editingEvent = event
        case .thing(let thing, _): editingThing = thing
        case .group: break
        }
    }

    private func beginDelete(_ item: MixedItem) {
        selectedMemberID = item.id
        showDeleteConfirm = true
    }

    private func deleteSelected() {
        switch entityType {
        case .figure:
            if let figure = selectedFigure {
                modelContext.delete(figure)
            }
        case .place:
            if let place = selectedPlace {
                modelContext.delete(place)
            }
        case .event:
            if let event = selectedEvent {
                modelContext.delete(event)
            }
        case .thing:
            if let thing = selectedThing {
                modelContext.delete(thing)
            }
        }
        selectedMemberID = nil
        try? modelContext.save()
    }
}

private struct GroupDescriptionDisplay: View {
    let group: FigureGroup

    var body: some View {
        RichTextDisplay(richData: group.richDescription, fallback: group.groupDescription, stripForegroundColor: true)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 560, alignment: .leading)
    }
}

private struct MemberRow: View {
    let item: MixedItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpenInSidebar: () -> Void
    let onOpenInWindow: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var icon: String {
        switch item {
        case .figure(let figure, _): return figure.figureType?.icon ?? "person.fill"
        case .place(let place, _): return place.placeType?.icon ?? "mappin.and.ellipse"
        case .event(let event, _): return event.eventType?.icon ?? "bolt.fill"
        case .thing(let thing, _): return thing.thingType?.icon ?? "cube.box"
        case .group(let group): return group.icon
        }
    }

    private var iconColor: Color {
        switch item {
        case .figure(let figure, _): return figure.figureType?.color ?? .gray
        case .place(let place, _): return place.placeType?.color ?? .teal
        case .event(let event, _): return event.eventType?.color ?? .orange
        case .thing(let thing, _): return thing.thingType?.color ?? .purple
        case .group(let group): return Color(hex: group.colorHex)
        }
    }

    private var subtitle: String {
        switch item {
        case .figure(let figure, _): return figure.figureType?.name ?? ""
        case .place(let place, _): return place.placeType?.name ?? ""
        case .event(let event, _): return event.eventType?.name ?? ""
        case .thing(let thing, _): return thing.thingType?.name ?? ""
        case .group: return ""
        }
    }

    private var genderSymbol: String? {
        if case .figure(let figure, _) = item { return figure.gender.symbol }
        return nil
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                    .frame(width: 16)
                Text(item.displayName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let genderSymbol {
                    Text(genderSymbol)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHand()
        .contextMenu {
            Button("Open in Sidebar") {
                onOpenInSidebar()
            }
            if item.canOpenInWindow {
                Button("Open in Window") {
                    onOpenInWindow()
                }
            }
            Divider()
            Button("Edit") {
                onEdit()
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

private struct EntityGroupTreeNode: View {
    let group: FigureGroup
    @Binding var expanded: Set<PersistentIdentifier>
    var onSelectMember: (MixedItem) -> Void
    var onOpenInSidebar: (MixedItem) -> Void
    var onOpenInWindow: (MixedItem) -> Void
    var onEditMember: (MixedItem) -> Void
    var onDeleteMember: (MixedItem) -> Void
    var onOpenGroup: (FigureGroup) -> Void

    private var isExpanded: Bool { expanded.contains(group.persistentModelID) }

    private var childCount: Int {
        (group.subgroups ?? []).count
    }

    private var directMembers: [MixedItem] {
        switch group.entityType {
        case .figure: return group.directFigures.map { MixedItem.figure($0, group.displayName(for: $0.persistentModelID)) }
        case .place: return group.directPlaces.map { MixedItem.place($0, group.displayName(for: $0.persistentModelID)) }
        case .event: return group.directEvents.map { MixedItem.event($0, group.displayName(for: $0.persistentModelID)) }
        case .thing: return group.directThings.map { MixedItem.thing($0, group.displayName(for: $0.persistentModelID)) }
        }
    }

    private var children: [MixedItem] {
        let groupItems = (group.subgroups ?? []).map(MixedItem.group)
        return (directMembers + groupItems).sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 2) {
            Button {
                if isExpanded {
                    expanded.remove(group.persistentModelID)
                } else {
                    expanded.insert(group.persistentModelID)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Image(systemName: group.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: group.colorHex))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: group.colorHex).opacity(0.12))
                        )
                    Text(group.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if childCount > 0 {
                        Text("\(childCount) subgroup\(childCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(group.figureAssociations.count) member\(group.figureAssociations.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 8)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHand()
            .help(isExpanded ? "Collapse subgroup" : "Expand subgroup")
            .contextMenu {
                Button("Open as Page") {
                    onOpenGroup(group)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    if !group.groupDescription.isEmpty || group.richDescription != nil {
                        GroupDescriptionDisplay(group: group)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 6)
                    }
                    ForEach(children) { item in
                        switch item {
                        case .group(let child):
                            EntityGroupTreeNode(
                                group: child,
                                expanded: $expanded,
                                onSelectMember: onSelectMember,
                                onOpenInSidebar: onOpenInSidebar,
                                onOpenInWindow: onOpenInWindow,
                                onEditMember: onEditMember,
                                onDeleteMember: onDeleteMember,
                                onOpenGroup: onOpenGroup
                            )
                        default:
                            MemberRow(
                                item: item,
                                isSelected: false,
                                onSelect: { onSelectMember(item) },
                                onOpenInSidebar: { onOpenInSidebar(item) },
                                onOpenInWindow: { onOpenInWindow(item) },
                                onEdit: { onEditMember(item) },
                                onDelete: { onDeleteMember(item) }
                            )
                        }
                    }
                }
                .padding(.leading, 28)
            }
        }
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
