import SwiftUI
import SwiftData

private enum MixedItem: Identifiable {
    case figure(Figure, String?)
    case place(Place, String?)
    case event(Event, String?)
    case thing(Thing, String?)
    case group(FigureGroup)
    case text(GroupTextBlock)

    var id: PersistentIdentifier {
        switch self {
        case .figure(let entity, _): return entity.persistentModelID
        case .place(let entity, _): return entity.persistentModelID
        case .event(let entity, _): return entity.persistentModelID
        case .thing(let entity, _): return entity.persistentModelID
        case .group(let entity): return entity.persistentModelID
        case .text(let entity): return entity.persistentModelID
        }
    }

    var name: String {
        switch self {
        case .figure(let entity, _): return entity.name
        case .place(let entity, _): return entity.name
        case .event(let entity, _): return entity.name
        case .thing(let entity, _): return entity.name
        case .group(let entity): return entity.name
        case .text(let entity): return entity.title
        }
    }

    var isProse: Bool {
        if case .text = self { return true }
        return false
    }

    var alias: String? {
        switch self {
        case .figure(_, let alias): return alias
        case .place(_, let alias): return alias
        case .event(_, let alias): return alias
        case .thing(_, let alias): return alias
        case .group, .text: return nil
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
        case .thing, .group, .text: return false
        }
    }
}

private func memberItems(for group: FigureGroup, in context: ModelContext) -> [MixedItem] {
    group.effectiveMemberItems(in: context).map { item in
        switch item {
        case .figure(let figure, let alias): return MixedItem.figure(figure, alias)
        case .place(let place, let alias): return MixedItem.place(place, alias)
        case .event(let event, let alias): return MixedItem.event(event, alias)
        case .thing(let thing, let alias): return MixedItem.thing(thing, alias)
        }
    }
}

/// The group's members + text blocks as a unified spine (shared orderIndex), used
/// when the group is in manual order so prose interleaves with the member list.
private func spineItems(for group: FigureGroup) -> [MixedItem] {
    var result: [MixedItem] = []
    for item in group.memberTextSpine {
        switch item {
        case .member(let assoc):
            if let f = assoc.figure { result.append(.figure(f, assoc.displayName)) }
            else if let p = assoc.place { result.append(.place(p, assoc.displayName)) }
            else if let e = assoc.event { result.append(.event(e, assoc.displayName)) }
            else if let t = assoc.thing { result.append(.thing(t, assoc.displayName)) }
        case .text(let block):
            result.append(.text(block))
        }
    }
    return result
}

struct EntityGroupCollectionView: View {
    let group: FigureGroup
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.userSession) private var userSession
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var expandedGroups: Set<PersistentIdentifier> = []
    @State private var hoveredFigureID: PersistentIdentifier?
    @State private var detailItem: GroupMemberItem?
    @State private var revealedBars: Set<Int> = []
    @State private var editingFigure: Figure?
    @State private var editingPlace: Place?
    @State private var editingEvent: Event?
    @State private var editingThing: Thing?
    @State private var editingTextBlock: GroupTextBlock?
    @State private var deletingTextBlock: GroupTextBlock?
    @State private var textBlockRevision = 0
    @State private var showDeleteConfirm = false
    @State private var showDeleteTextBlockConfirm = false
    @State private var deleteWarningMessage: String?
    @State private var showTextBlockControls = false
    @State private var imageDetailImage: ImageAsset?

    private var entityType: GroupEntityType { group.entityType }

    private var subgroups: [FigureGroup] {
        (group.subgroups ?? []).sorted { ($0.orderIndex, $0.name) < ($1.orderIndex, $1.name) }
    }

    private var mixedItems: [MixedItem] {
        if group.sortMode == .ordered && !group.isSmart {
            let spine = spineItems(for: group) + subgroups.map(MixedItem.group)
            if searchText.isEmpty { return spine }
            return spine.filter { item in
                if item.isProse { return true }
                return item.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        // Alphabetical mode: members + subgroups sorted by name, prose pinned below.
        // Smart groups always land here (their membership is evaluated live by name).
        let membersAndSubs = memberItems(for: group, in: modelContext) + subgroups.map(MixedItem.group)
        let sortedBase = searchText.isEmpty
            ? membersAndSubs.sorted { $0.name < $1.name }
            : membersAndSubs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }.sorted { $0.name < $1.name }
        let prose = group.sortedTextBlocks.map(MixedItem.text)
        return sortedBase + prose
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

    private var selectedItemName: String? {
        detailItem?.name
    }

    private func openLinkedEntity(kind: EntityKind, id: PersistentIdentifier) {
        switch kind {
        case .figure:
            if let figure = try? modelContext.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.persistentModelID == id })).first {
                detailItem = .figure(figure, nil)
            }
        case .place:
            if let place = try? modelContext.fetch(FetchDescriptor<Place>(predicate: #Predicate { $0.persistentModelID == id })).first {
                detailItem = .place(place, nil)
            }
        case .event:
            if let event = try? modelContext.fetch(FetchDescriptor<Event>(predicate: #Predicate { $0.persistentModelID == id })).first {
                detailItem = .event(event, nil)
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Breadcrumbs
                let coordinatorHistory = coordinator?.history ?? []
                if !coordinatorHistory.isEmpty {
                    BreadcrumbBar(
                        breadcrumbs: coordinatorHistory.map { Breadcrumb(id: $0.id, name: $0.name, icon: $0.item.icon) },
                        onNavigate: { index in coordinator?.navigateToHistory(at: index) },
                        onClear: { coordinator?.history.removeAll() }
                    )
                }
                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ancestorTrail
                    header
                    if group.era != nil {
                        GroupEraMapView(group: group)
                    }
                    heroStats
                    reignTower
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
                                        showTextBlockControls: showTextBlockControls,
                                        attributionRevision: textBlockRevision,
                                        onSelectMember: { detailItem = memberItem(from: $0) },
                                        onOpenInSidebar: { openInSidebar($0) },
                                        onOpenInWindow: { openInWindow($0) },
                                        onEditMember: { beginEdit($0) },
                                        onDeleteMember: { beginDelete($0) },
                                        onOpenGroup: { sub in
                                            coordinator?.navigateToGroup(sub.persistentModelID, name: sub.name, recordHistory: false)
                                        }
                                    )
                                case .text(let block):
                                    TextBlockRow(
                                        block: block,
                                        showEditControls: showTextBlockControls,
                                        attributionRevision: textBlockRevision,
                                        onEdit: { editingTextBlock = block },
                                        onDelete: { deletingTextBlock = block }
                                    )
                                default:
                                    MemberRow(
                                        item: item,
                                        isSelected: detailItem?.id == item.id,
                                        isHoverLinked: hoveredFigureID == item.id,
                                        onHoverLink: { hovering in
                                            if case .figure = item {
                                                hoveredFigureID = hovering ? item.id : nil
                                            } else if !hovering {
                                                hoveredFigureID = nil
                                            }
                                        },
                                        onSelect: { detailItem = memberItem(from: item) },
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
            }

            Group {
                if detailItem != nil {
                    Divider()
                    detailPanel
                        .id(detailItem?.id)
                        .frame(width: 320)
                        .frame(maxHeight: .infinity)
                        .background(.thinMaterial)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(.easeInOut(duration: 0.3), value: detailItem?.id)
        .environment(\.inlineLinkGroupContext, InlineLinkGroupContext(
            groupID: group.persistentModelID,
            groupName: group.name,
            onOpenEntity: { kind, id in
                openLinkedEntity(kind: kind, id: id)
            }
        ))
        .sheet(item: $editingFigure) { FigureFormView(figure: $0) }
        .sheet(item: $editingPlace) { PlaceFormView(place: $0) }
        .sheet(item: $editingEvent) { EventFormView(event: $0) }
        .sheet(item: $editingThing) { ThingFormView(thing: $0) }
        .sheet(item: $editingTextBlock) { block in
            GroupTextBlockSheet(group: group, block: block)
        }
        .alert("Delete Text Block?", isPresented: $showDeleteTextBlockConfirm) {
            Button("Delete", role: .destructive) { deleteTextBlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deletingTextBlock.map { "Delete \"\($0.title.isEmpty ? "Untitled" : $0.title)\"? This cannot be undone." } ?? "Delete this text block?")
        }
        .alert("Delete Member?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            let name = selectedItemName ?? "this member"
            if let warning = deleteWarningMessage {
                Text("Delete \"\(name)\"? \(warning)\nThis cannot be undone.")
            } else {
                Text("Delete \"\(name)\"? This cannot be undone.")
            }
        }
        .onChange(of: imageDetailImage) { _, newValue in
            if let image = newValue {
                openWindow(id: "image-detail", value: image.persistentModelID)
                imageDetailImage = nil
            }
        }
        .onChange(of: editingTextBlock) { _, newValue in
            if newValue == nil {
                textBlockRevision += 1
            }
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let item = detailItem {
                    switch item {
                    case .figure(let figure, _):
                        IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") { editingFigure = figure }
                        if isMember(item) {
                            IconActionButton(icon: "trash", color: .red, help: "Delete") { showDeleteConfirm = true }
                        }
                    case .place(let place, _):
                        IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") { editingPlace = place }
                        if isMember(item) {
                            IconActionButton(icon: "trash", color: .red, help: "Delete") { showDeleteConfirm = true }
                        }
                    case .event(let event, _):
                        IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") { editingEvent = event }
                        if isMember(item) {
                            IconActionButton(icon: "trash", color: .red, help: "Delete") { showDeleteConfirm = true }
                        }
                    case .thing(let thing, _):
                        IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") { editingThing = thing }
                        if isMember(item) {
                            IconActionButton(icon: "trash", color: .red, help: "Delete") { showDeleteConfirm = true }
                        }
                    }
                }
                Spacer()
                Button(action: { detailItem = nil }) {
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

            if let item = detailItem {
                switch item {
                case .figure(let figure, _):
                    FigureDetailView(
                        figure: figure,
                        onSelectFigure: { selected in deferSelect(selected.persistentModelID) },
                        onSelectPlace: { place in deferSelect(place.persistentModelID) },
                        onSelectEvent: { event in deferSelect(event.persistentModelID) },
                        onSelectImage: { imageDetailImage = $0 }
                    )
                case .place(let place, _):
                    PlaceDetailView(
                        place: place,
                        onSelectFigure: { figure in deferSelect(figure.persistentModelID) },
                        onSelectEvent: { event in deferSelect(event.persistentModelID) },
                        onSelectImage: { imageDetailImage = $0 }
                    )
                case .event(let event, _):
                    EventDetailView(
                        event: event,
                        onSelectFigure: { figure in deferSelect(figure.persistentModelID) },
                        onSelectPlace: { place in deferSelect(place.persistentModelID) },
                        onSelectImage: { imageDetailImage = $0 }
                    )
                case .thing(let thing, _):
                    ThingDetailView(
                        thing: thing,
                        onSelectImage: { imageDetailImage = $0 }
                    )
                }
            }
        }
    }

    private func isMember(_ item: GroupMemberItem) -> Bool {
        group.effectiveMemberItems(in: modelContext).contains { $0.id == item.id }
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
        let effectiveItems = group.effectiveMemberItems(in: modelContext)
        return HStack(alignment: .top, spacing: 16) {
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
                    Text(group.memberCountText(count: effectiveItems.count))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if group.isSmart {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("Smart — live rule")
                                .font(.caption2)
                        }
                        .foregroundStyle(.teal)
                    }
                    if !subgroups.isEmpty {
                        Text("\(subgroups.count) subgroup\(subgroups.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                if let aggregation = group.decodedAggregation, let result = aggregation.compute(items: effectiveItems) {
                    HStack(spacing: 6) {
                        Image(systemName: "sum")
                            .font(.caption)
                            .foregroundStyle(Color(hex: group.colorHex))
                        Text("\(aggregation.title): \(aggregation.formattedValue(for: result))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if result.count < effectiveItems.count {
                            Text("(\(result.count) of \(effectiveItems.count) \(group.memberPluralLabel) have data)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: addTextBlock) {
                        Label("Add Text Block", systemImage: "plus")
                    }
                    .font(.caption)
                    .help("Insert a prose block into this page")
                    Button(action: { showTextBlockControls.toggle() }) {
                        Label(showTextBlockControls ? "Hide Edit Controls" : "Show Edit Controls", systemImage: showTextBlockControls ? "pencil.slash" : "pencil")
                    }
                    .font(.caption)
                    .help("Toggle edit/delete controls on all text blocks")
                }
                if group.sortMode != .ordered {
                    Text("Switch to Manual Order to interleave text")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// Figure members in display order with their reign value (stored `reignYears`
    /// field, falling back to the description parser). Members without a reign value
    /// are excluded. Empty for non-figure groups.
    private var reignEntries: [(name: String, years: Int, id: PersistentIdentifier)] {
        guard entityType == .figure else { return [] }
        return group.effectiveMemberItems(in: modelContext).compactMap { item in
            guard let figure = item.figure else { return nil }
            let years = figure.reignYears ?? ReignLength.parse(from: figure.figureDescription)?.years
            guard let years else { return nil }
            return (figure.name, years, figure.persistentModelID)
        }
    }

    fileprivate static func formattedNumber(_ value: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Compact headline statistics row shown above the member list (figure groups only).
    @ViewBuilder
    private var heroStats: some View {
        let entries = reignEntries
        if entries.count >= 2 {
            let total = entries.reduce(0) { $0 + $1.years }
            let longest = entries.max { $0.years < $1.years }!
            let color: Color = Color(hex: group.colorHex)
            HStack(spacing: 12) {
                statTile(icon: "hourglass.circle.fill", value: Self.formattedNumber(total), note: "years", color: color)
                statTile(icon: "arrow.up.circle.fill", value: longest.name, note: Self.formattedNumber(longest.years) + " years", color: color)
                statTile(icon: "person.3.fill", value: "\(entries.count)", note: "", color: color)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: group.colorHex).opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: group.colorHex).opacity(0.12), lineWidth: 1)
            )
        }
    }

    private func statTile(icon: String, value: String, note: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
            if !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Relative bar plot of reign lengths (figure groups only). Long reigns dwarf
    /// shorter ones, which is exactly the mythology — Alulim's 28,800 years next to
    /// his successor's much shorter stint reads as a wall of lead.
    @ViewBuilder
    private var reignTower: some View {
        let entries = reignEntries
        if entries.count >= 2 {
            let maxYears = entries.map(\.years).max() ?? 1
            let color: Color = Color(hex: group.colorHex)
            VStack(alignment: .leading, spacing: 8) {
                Text("Reign lengths")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(spacing: 6) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        ReignBarRow(
                            entry: entry,
                            index: index,
                            color: color,
                            maxYears: maxYears,
                            isLinked: hoveredFigureID == entry.id,
                            isRevealed: revealedBars.contains(index),
                            onHover: { hovering in
                                hoveredFigureID = hovering ? entry.id : nil
                            }
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .onAppear {
                revealedBars = []
                Task { @MainActor in
                    for index in entries.indices {
                        revealedBars.insert(index)
                        try? await Task.sleep(nanoseconds: 80_000_000)
                    }
                }
            }
        }
    }

    private func addTextBlock() {
        let block = GroupTextBlock(title: "", text: "")
        modelContext.insert(block)
        group.appendTextBlock(block)
        editingTextBlock = block
        try? modelContext.save()
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Search \(group.memberPluralLabel) and subgroups\u{2026}", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: 320)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: entityType.icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No \(group.memberPluralLabel) in this group" : "No matches")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func deferSelect(_ id: PersistentIdentifier) {
        Task { @MainActor in
            if let figure = try? modelContext.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.persistentModelID == id })).first {
                detailItem = .figure(figure, nil)
            } else if let place = try? modelContext.fetch(FetchDescriptor<Place>(predicate: #Predicate { $0.persistentModelID == id })).first {
                detailItem = .place(place, nil)
            } else if let event = try? modelContext.fetch(FetchDescriptor<Event>(predicate: #Predicate { $0.persistentModelID == id })).first {
                detailItem = .event(event, nil)
            } else if let thing = try? modelContext.fetch(FetchDescriptor<Thing>(predicate: #Predicate { $0.persistentModelID == id })).first {
                detailItem = .thing(thing, nil)
            }
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
        case .group, .text:
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
        case .thing, .group, .text:
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
        case .text(let block): editingTextBlock = block
        }
    }

    private func beginDelete(_ item: MixedItem) {
        if case .text(let block) = item {
            deletingTextBlock = block
            showDeleteTextBlockConfirm = true
            return
        }
        if let member = memberItem(from: item) {
            detailItem = member
        }
        deleteWarningMessage = computeDeleteWarning(for: item)
        showDeleteConfirm = true
    }

    private func computeDeleteWarning(for item: MixedItem) -> String? {
        let entityID: PersistentIdentifier?
        switch item {
        case .figure(let fig, _): entityID = fig.persistentModelID
        case .place(let p, _): entityID = p.persistentModelID
        case .event(let e, _): entityID = e.persistentModelID
        case .thing(let t, _): entityID = t.persistentModelID
        case .group, .text: return nil
        }
        guard let entityID else { return nil }
        let involvingEvents = group.eventsInvolving(entityID: entityID, in: modelContext)
        guard !involvingEvents.isEmpty else { return nil }
        let eventNames = involvingEvents.map(\.name).prefix(3).joined(separator: ", ")
        let suffix = involvingEvents.count > 3 ? " and \(involvingEvents.count - 3) more" : ""
        return "This entity is involved in events: \(eventNames)\(suffix)."
    }

    private func deleteTextBlock() {
        if let block = deletingTextBlock {
            modelContext.delete(block)
        }
        deletingTextBlock = nil
        try? modelContext.save()
    }

    private func deleteSelected() {
        if let figure = detailItem?.figure {
            ActivityLogger.record(action: .deleted, entityType: "Figure", entityName: figure.name, context: modelContext, session: userSession)
            modelContext.delete(figure)
        } else if let place = detailItem?.place {
            ActivityLogger.record(action: .deleted, entityType: "Place", entityName: place.name, context: modelContext, session: userSession)
            modelContext.delete(place)
        } else if let event = detailItem?.event {
            ActivityLogger.record(action: .deleted, entityType: "Event", entityName: event.name, context: modelContext, session: userSession)
            modelContext.delete(event)
        } else if let thing = detailItem?.thing {
            ActivityLogger.record(action: .deleted, entityType: "Thing", entityName: thing.name, context: modelContext, session: userSession)
            modelContext.delete(thing)
        }
        detailItem = nil
        try? modelContext.save()
    }
}

private struct ReignBarRow: View {
    let entry: (name: String, years: Int, id: PersistentIdentifier)
    let index: Int
    let color: Color
    let maxYears: Int
    let isLinked: Bool
    let isRevealed: Bool
    let onHover: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(entry.name)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 170, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(entry.years) / CGFloat(maxYears) * (isRevealed ? 1 : 0.001)))
                        .shadow(color: color.opacity(isLinked ? 0.5 : 0), radius: isLinked ? 4 : 0)
                        .animation(.easeInOut(duration: 0.6).delay(Double(index) * 0.08), value: isRevealed)
                }
            }
            .frame(height: 10)
            Text(EntityGroupCollectionView.formattedNumber(entry.years) + " yrs")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isLinked ? color.opacity(0.10) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover(hovering)
        }
        .animation(.easeInOut(duration: 0.15), value: isLinked)
    }
}

private func memberItem(from item: MixedItem) -> GroupMemberItem? {
    switch item {
    case .figure(let entity, let alias): return .figure(entity, alias)
    case .place(let entity, let alias): return .place(entity, alias)
    case .event(let entity, let alias): return .event(entity, alias)
    case .thing(let entity, let alias): return .thing(entity, alias)
    case .group, .text: return nil
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
    var isHoverLinked: Bool = false
    var onHoverLink: ((Bool) -> Void)? = nil
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
        case .text: return "text.quote"
        }
    }

    private var iconColor: Color {
        switch item {
        case .figure(let figure, _): return figure.figureType?.color ?? .gray
        case .place(let place, _): return place.placeType?.color ?? .teal
        case .event(let event, _): return event.eventType?.color ?? .orange
        case .thing(let thing, _): return thing.thingType?.color ?? .purple
        case .group(let group): return Color(hex: group.colorHex)
        case .text: return .secondary
        }
    }

    private var subtitle: String {
        switch item {
        case .figure(let figure, _): return figure.figureType?.name ?? ""
        case .place(let place, _): return place.placeType?.name ?? ""
        case .event(let event, _): return event.eventType?.name ?? ""
        case .thing(let thing, _): return thing.thingType?.name ?? ""
        case .group: return ""
        case .text: return ""
        }
    }

    private var genderSymbol: String? {
        if case .figure(let figure, _) = item { return figure.gender.symbol }
        return nil
    }

    private var reignDisplay: String? {
        guard case .figure(let figure, _) = item else { return nil }
        if let years = figure.reignYears {
            return "Reigned \(Self.yearString(years)) years"
        }
        if let reign = ReignLength.parse(from: figure.figureDescription) {
            return reign.display
        }
        return nil
    }

    private static func yearString(_ years: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: NSNumber(value: years)) ?? "\(years)"
    }

    var body: some View {
        let row = Button(action: onSelect) {
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
                if let reignDisplay {
                    Text(reignDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : isHoverLinked ? Color.accentColor.opacity(0.08) : Color(.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.15), value: isHoverLinked)
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

        if case .figure(let figure, _) = item, figure.mugshotImage != nil {
            row.mugshotHover(figure, size: 120, arrowEdge: .leading, onHover: onHoverLink)
        } else {
            row.onHover { onHoverLink?($0) }
        }
    }
}

private struct EntityGroupTreeNode: View {
    let group: FigureGroup
    @Environment(\.modelContext) private var modelContext
    @Binding var expanded: Set<PersistentIdentifier>
    var showTextBlockControls: Bool = false
    var attributionRevision: Int = 0
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
        memberItems(for: group, in: modelContext)
    }

    private var aggregatedReign: String? {
        guard group.entityType == .figure else { return nil }
        let agg = GroupAggregation(operation: .sum, target: .reignYears)
        let items = group.effectiveMemberItems(in: modelContext)
        guard let result = agg.compute(items: items), result.count > 0 else { return nil }
        return "\(agg.title): \(agg.formattedValue(for: result))"
    }

    private var children: [MixedItem] {
        let groupItems = (group.subgroups ?? [])
            .sorted { ($0.orderIndex, $0.name) < ($1.orderIndex, $1.name) }
            .map(MixedItem.group)
        if group.sortMode == .ordered && !group.isSmart {
            return spineItems(for: group) + groupItems
        }
        let sortedMembers = (directMembers + groupItems).sorted { $0.name < $1.name }
        return sortedMembers + group.sortedTextBlocks.map(MixedItem.text)
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
                    Text(group.memberCountText(count: group.effectiveMemberCount(in: modelContext)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let aggregatedReign {
                        Text(aggregatedReign)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
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
                                showTextBlockControls: showTextBlockControls,
                                attributionRevision: attributionRevision,
                                onSelectMember: onSelectMember,
                                onOpenInSidebar: onOpenInSidebar,
                                onOpenInWindow: onOpenInWindow,
                                onEditMember: onEditMember,
                                onDeleteMember: onDeleteMember,
                                onOpenGroup: onOpenGroup
                            )
                        case .text(let block):
                            TextBlockRow(
                                block: block,
                                showEditControls: showTextBlockControls,
                                attributionRevision: attributionRevision,
                                onEdit: { onEditMember(item) },
                                onDelete: { onDeleteMember(item) }
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

private struct TextBlockAttributionFootnote: Identifiable {
    let id = UUID()
    let sourceName: String
    let url: URL?
}

private struct TextBlockRow: View {
    let block: GroupTextBlock
    var showEditControls: Bool = false
    var attributionRevision: Int = 0
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    @State private var showFullText = false
    @State private var attributionFootnotes: [TextBlockAttributionFootnote] = []

    private var hasSummary: Bool {
        !(block.summary?.isEmpty ?? true)
    }

    private var controlsVisible: Bool { showEditControls || isHovered }

    private var textAlignment: TextAlignment {
        block.alignment == .center ? .center : (block.alignment == .right ? .trailing : .leading)
    }

    private var frameAlignment: Alignment {
        block.alignment == .center ? .center : (block.alignment == .right ? .trailing : .leading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleBar
            contentBlock
            footnotesBlock
        }
        .padding(10)
        .frame(minHeight: 32)
        .frame(maxWidth: block.maxWidth.map { CGFloat($0) } ?? .infinity, alignment: frameAlignment)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.textBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
        )
        .frame(maxWidth: .infinity, alignment: block.maxWidth == nil ? .leading : frameAlignment)
        .onHover { hovering in
            isHovered = hovering
        }
        .task(id: "\(block.persistentModelID)-\(attributionRevision)") {
            let targetID = block.persistentModelID
            let all: [ContentAttribution] = modelContext.fetchAll()
            attributionFootnotes = all.filter { $0.groupTextBlock?.persistentModelID == targetID }
                .map { attribution in
                    let sourceName = attribution.source?.name ?? "Unknown source"
                    var url: URL?
                    if let urlString = attribution.url, !urlString.isEmpty {
                        url = URL(string: urlString)
                    }
                    if url == nil, let sourceURL = attribution.source?.url, !sourceURL.isEmpty {
                        url = URL(string: sourceURL)
                    }
                    return TextBlockAttributionFootnote(sourceName: sourceName, url: url)
                }
        }
        .animation(.easeInOut(duration: 0.15), value: controlsVisible)
        .contextMenu {
            Button("Edit Text Block") { onEdit() }
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.quote")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if !block.title.isEmpty {
                Text(block.title)
                    .font(block.titleSize.font)
                    .foregroundStyle(.primary)
            } else {
                Text("Untitled text block")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if controlsVisible {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Edit text block")
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete text block")
            }
        }
    }

    @ViewBuilder
    private var contentBlock: some View {
        if hasSummary {
            RichTextDisplay(richData: block.summaryRichText, fallback: block.summary ?? "", stripForegroundColor: true)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            if showFullText {
                RichTextDisplay(richData: block.richText, fallback: block.text, stripForegroundColor: true)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFullText.toggle()
                }
            } label: {
                Text(showFullText ? "Hide full text" : "Show full text\u{2026}")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .pointingHand()
            .frame(maxWidth: .infinity, alignment: frameAlignment)
        } else {
            RichTextDisplay(richData: block.richText, fallback: block.text, stripForegroundColor: true)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
    }

    @ViewBuilder
    private var footnotesBlock: some View {
        if !attributionFootnotes.isEmpty {
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(attributionFootnotes) { footnote in
                    HStack(spacing: 4) {
                        Image(systemName: "book.and.wrench")
                            .font(.caption2)
                            .foregroundStyle(.teal)
                        Text("Source: \(footnote.sourceName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let url = footnote.url {
                            Link("(click to see, note: may open browser window)", destination: url)
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 6)
        }
    }
}

struct GroupTextBlockSheet: View {
    let group: FigureGroup
    let block: GroupTextBlock

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var text: String
    @State private var richText: Data?
    @State private var summary: String
    @State private var summaryRichText: Data?
    @State private var maxWidth: Double?
    @State private var alignment: GroupTextBlock.TextBlockAlignment
    @State private var titleSize: GroupTextBlock.TextBlockTitleSize
    @State private var showingAttributionForm = false
    @State private var editingAttribution: ContentAttribution?

    init(group: FigureGroup, block: GroupTextBlock) {
        self.group = group
        self.block = block
        _title = State(initialValue: block.title)
        _text = State(initialValue: block.text)
        _richText = State(initialValue: block.richText)
        _summary = State(initialValue: block.summary ?? "")
        _summaryRichText = State(initialValue: block.summaryRichText)
        _maxWidth = State(initialValue: block.maxWidth)
        _alignment = State(initialValue: block.alignment)
        _titleSize = State(initialValue: block.titleSize)
    }

    private var blockAttributions: [ContentAttribution] {
        let all: [ContentAttribution] = modelContext.fetchAll()
        return all.filter { $0.groupTextBlock == block }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text Block")
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Title (optional)", text: $title)
                        .textFieldStyle(.roundedBorder)
                    Text("Summary")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    RichTextEditorSection(richData: $summaryRichText, plainText: $summary)
                        .frame(minHeight: 90)
                    Text("Full text")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    RichTextEditorSection(richData: $richText, plainText: $text)
                        .frame(minHeight: 140)
                    HStack(spacing: 8) {
                        Text("Title size:")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Picker("Title size", selection: $titleSize) {
                            ForEach(GroupTextBlock.TextBlockTitleSize.allCases, id: \.self) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    HStack(spacing: 8) {
                        Text("Max width:")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Picker("Max width", selection: $maxWidth) {
                            Text("Full").tag(Double?.none)
                            Text("420").tag(Double?.some(420))
                            Text("560").tag(Double?.some(560))
                            Text("700").tag(Double?.some(700))
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    HStack(spacing: 8) {
                        Text("Align:")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Picker("Align", selection: $alignment) {
                            Text("Left").tag(GroupTextBlock.TextBlockAlignment.left)
                            Text("Center").tag(GroupTextBlock.TextBlockAlignment.center)
                            Text("Right").tag(GroupTextBlock.TextBlockAlignment.right)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    ContentAttributionSection(
                        attributions: blockAttributions,
                        onAdd: {
                            editingAttribution = nil
                            showingAttributionForm = true
                        },
                        onEdit: { attribution in
                            editingAttribution = attribution
                            showingAttributionForm = true
                        },
                        onDelete: { attribution in
                            modelContext.delete(attribution)
                            try? modelContext.save()
                        }
                    )
                }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    block.title = title
                    block.text = text
                    block.richText = richText
                    block.summary = summary
                    block.summaryRichText = summaryRichText
                    block.maxWidth = maxWidth
                    block.alignmentRawValue = alignment.rawValue
                    block.titleSizeRawValue = titleSize.rawValue
                    if group.sortMode == .ordered, block.orderIndex == nil {
                        block.orderIndex = (group.textBlocks ?? []).count
                    }
                    try? modelContext.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 760)
        .sheet(isPresented: $showingAttributionForm) {
            ContentAttributionFormView(attribution: editingAttribution, groupTextBlock: block)
        }
    }
}

private extension GroupTextBlock.TextBlockTitleSize {
    var font: Font {
        switch self {
        case .small: return .callout.weight(.semibold)
        case .medium: return .title3.weight(.semibold)
        case .large: return .title2.weight(.bold)
        case .xlarge: return .largeTitle.weight(.bold)
        }
    }
}

