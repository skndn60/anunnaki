import SwiftUI
import SwiftData

struct TagCloudView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Figure.name) private var allFigures: [Figure]
    @Query(sort: \FigureType.name) private var figureTypes: [FigureType]
    @Query(sort: \EventType.name) private var eventTypes: [EventType]
    @Query(sort: \PlaceType.name) private var placeTypes: [PlaceType]

    @State private var segment: CloudSegment = .tags
    @State private var detailItem: DetailItem?
    @State private var detailEntity: DetailEntity?
    @State private var sheetTag: Tag?
    @State private var tagRenameText = ""
    @State private var tagPendingDelete: Tag?
    @State private var showDeleteConfirm = false
    @State private var filterText = ""
    @State private var sortAlphabetical = false

    enum CloudSegment: String, CaseIterable {
        case tags = "Tags"
        case domains = "Domains"
        case types = "Types"
    }

    enum EntityKind {
        case figure, place, event
    }

    struct DetailEntity: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let kind: EntityKind
    }

    struct DetailItem: Identifiable {
        let id: String
        let label: String
        let sections: [(type: String, entities: [DetailEntity])]
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $segment) {
                ForEach(CloudSegment.allCases, id: \.self) { seg in
                    Text(seg.rawValue).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter tags, domains, types\u{2026}", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                Toggle(isOn: $sortAlphabetical) {
                    Text("A–Z")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Sort alphabetically instead of by occurrence count")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            ScrollView {
                switch segment {
                case .tags: cloudContent(items: displayed(tagItems), emptyTitle: "No matching tags")
                case .domains: cloudContent(items: displayed(domainItems), emptyTitle: "No matching domains")
                case .types: cloudContent(items: displayed(typeItems), emptyTitle: "No matching types")
                }
            }
            .padding()
        }
        .sheet(item: $detailItem) { item in
            detailSheet(item)
        }
        .alert("Delete Tag?", isPresented: $showDeleteConfirm, presenting: tagPendingDelete) { tag in
            Button("Delete", role: .destructive) { deleteTag(tag) }
            Button("Cancel", role: .cancel) {}
        } message: { tag in
            Text("Delete the tag \"\(tag.name)\"? It will be removed from every figure, place, event, thing, and image that carries it.")
        }
    }

    private var tagItems: [CloudItem] {
        allTags
            .filter { $0.figureCount + $0.eventCount + $0.placeCount > 0 }
            .map { tag in
                CloudItem(
                    id: tag.persistentModelID.hashValue.description,
                    label: tag.name,
                    count: tag.figureCount + tag.eventCount + tag.placeCount,
                    color: tag.displayColor,
                    icon: nil,
                    detail: tagDetailItem(tag),
                    tag: tag
                )
            }
            .sorted { $0.count > $1.count }
    }

    private func tagDetailItem(_ tag: Tag) -> DetailItem {
        var sections: [(String, [DetailEntity])] = []
        if !tag.figures.isEmpty {
            sections.append(("Figures", tag.figures.map { f in
                DetailEntity(id: f.persistentModelID, name: f.name, kind: .figure)
            }))
        }
        if !tag.events.isEmpty {
            sections.append(("Events", tag.events.map { e in
                DetailEntity(id: e.persistentModelID, name: e.name, kind: .event)
            }))
        }
        if !tag.places.isEmpty {
            sections.append(("Places", tag.places.map { p in
                DetailEntity(id: p.persistentModelID, name: p.name, kind: .place)
            }))
        }
        return DetailItem(
            id: tag.persistentModelID.hashValue.description,
            label: tag.name,
            sections: sections
        )
    }

    private var domainItems: [CloudItem] {
        var counts: [String: Int] = [:]
        var figureMap: [String: [DetailEntity]] = [:]
        for figure in allFigures {
            let domains = figure.domain.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            for domain in domains {
                counts[domain, default: 0] += 1
                figureMap[domain, default: []].append(
                    DetailEntity(id: figure.persistentModelID, name: figure.name, kind: .figure)
                )
            }
        }
        return counts.map { name, count in
            CloudItem(
                id: "domain-\(name)",
                label: name,
                count: count,
                color: .orange,
                icon: "star",
                detail: DetailItem(id: "domain-\(name)", label: name, sections: [("Figures", figureMap[name] ?? [])])
            )
        }
        .sorted { $0.count > $1.count }
    }

    private var typeItems: [CloudItem] {
        var items: [CloudItem] = []
        for ft in figureTypes {
            guard ft.figures.count > 0 else { continue }
            items.append(CloudItem(
                id: "ft-\(ft.name)",
                label: ft.name,
                count: ft.figures.count,
                color: ft.color,
                icon: ft.icon,
                detail: DetailItem(id: "ft-\(ft.name)", label: ft.name, sections: [("Figures", ft.figures.map { f in
                    DetailEntity(id: f.persistentModelID, name: f.name, kind: .figure)
                })])
            ))
        }
        for et in eventTypes {
            guard et.events.count > 0 else { continue }
            items.append(CloudItem(
                id: "et-\(et.name)",
                label: et.name,
                count: et.events.count,
                color: et.color,
                icon: et.icon,
                detail: DetailItem(id: "et-\(et.name)", label: et.name, sections: [("Events", et.events.map { e in
                    DetailEntity(id: e.persistentModelID, name: e.name, kind: .event)
                })])
            ))
        }
        for pt in placeTypes {
            guard pt.places.count > 0 else { continue }
            items.append(CloudItem(
                id: "pt-\(pt.name)",
                label: pt.name,
                count: pt.places.count,
                color: pt.color,
                icon: pt.icon,
                detail: DetailItem(id: "pt-\(pt.name)", label: pt.name, sections: [("Places", pt.places.map { p in
                    DetailEntity(id: p.persistentModelID, name: p.name, kind: .place)
                })])
            ))
        }
        return items.sorted { $0.count > $1.count }
    }

    private func displayed(_ items: [CloudItem]) -> [CloudItem] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = query.isEmpty ? items : items.filter { $0.label.localizedCaseInsensitiveContains(query) }
        if sortAlphabetical {
            result.sort { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        }
        return result
    }

    private func cloudContent(items: [CloudItem], emptyTitle: String) -> some View {
        guard !items.isEmpty else {
            return AnyView(Text(emptyTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 40))
        }
        let counts = items.map(\.count)
        let minCount = counts.min() ?? 0
        let maxCount = counts.max() ?? 0

        return AnyView(
            FlowLayout(spacing: 8) {
                ForEach(items) { item in
                    Button {
                        detailItem = item.detail
                        sheetTag = item.tag
                        tagRenameText = item.tag?.name ?? ""
                    } label: {
                        HStack(spacing: 4) {
                            if let icon = item.icon {
                                Image(systemName: icon)
                                    .font(.system(size: itemFontSize(item.count, minVal: minCount, maxVal: maxCount) * 0.7))
                            }
                            Text(item.label)
                                .font(.system(size: itemFontSize(item.count, minVal: minCount, maxVal: maxCount)))
                                .lineLimit(1)
                            Text("\(item.count)")
                                .font(.system(size: itemFontSize(item.count, minVal: minCount, maxVal: maxCount) * 0.65))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(item.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(item.color.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        )
    }

    private func itemFontSize(_ count: Int, minVal: Int, maxVal: Int) -> CGFloat {
        if sortAlphabetical { return 14 }
        return fontSize(for: count, minVal: minVal, maxVal: maxVal)
    }

    private func fontSize(for count: Int, minVal: Int, maxVal: Int) -> CGFloat {
        guard maxVal > minVal else { return 16 }
        let minSize: CGFloat = 10
        let maxSize: CGFloat = 34
        let logMin = log(CGFloat(Swift.max(minVal, 1)))
        let logMax = log(CGFloat(Swift.max(maxVal, 1)))
        let logCount = log(CGFloat(Swift.max(count, 1)))
        guard logMax > logMin else { return (minSize + maxSize) / 2 }
        let fraction = (logCount - logMin) / (logMax - logMin)
        return minSize + fraction * (maxSize - minSize)
    }

    private func detailSheet(_ item: DetailItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if detailEntity != nil {
                    Button {
                        detailEntity = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(detailEntity == nil ? item.label : (detailEntity?.name ?? ""))
                    .font(.title2.bold())
                    .lineLimit(1)
                Spacer()
                Button("Close") {
                    detailItem = nil
                }
                .font(.subheadline)
            }
            .padding()

            if let tag = sheetTag {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                    TextField("Tag name", text: $tagRenameText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitRename() }
                    Button("Rename") { commitRename() }
                        .disabled(renameDisabled(tag))
                    Button {
                        tagPendingDelete = tag
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .help("Delete Tag")
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            if let entity = detailEntity {
                entityDetailView(entity)
            } else {
                entityListView(item)
            }
        }
        .frame(width: 440, height: 520)
    }

    private func renameDisabled(_ tag: Tag) -> Bool {
        let trimmed = tagRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.compare(tag.name, options: [.caseInsensitive]) == .orderedSame
    }

    private func commitRename() {
        guard let tag = sheetTag else { return }
        let newName = tagRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        if newName.compare(tag.name, options: [.caseInsensitive]) == .orderedSame { return }
        let target: Tag
        if let other = allTags.first(where: {
            $0.persistentModelID != tag.persistentModelID &&
            $0.name.compare(newName, options: [.caseInsensitive]) == .orderedSame
        }) {
            repoint(from: tag, to: other)
            modelContext.delete(tag)
            target = other
        } else {
            tag.name = newName
            target = tag
        }
        try? modelContext.save()
        sheetTag = target
        tagRenameText = target.name
        detailItem = tagDetailItem(target)
    }

    private func repoint(from old: Tag, to new: Tag) {
        for figure in Array(old.figures) {
            figure.tags.removeAll { $0.persistentModelID == old.persistentModelID }
            if !figure.tags.contains(where: { $0.persistentModelID == new.persistentModelID }) {
                figure.tags.append(new)
            }
        }
        for event in Array(old.events) {
            event.tags.removeAll { $0.persistentModelID == old.persistentModelID }
            if !event.tags.contains(where: { $0.persistentModelID == new.persistentModelID }) {
                event.tags.append(new)
            }
        }
        for place in Array(old.places) {
            place.tags.removeAll { $0.persistentModelID == old.persistentModelID }
            if !place.tags.contains(where: { $0.persistentModelID == new.persistentModelID }) {
                place.tags.append(new)
            }
        }
        for thing in Array(old.things) {
            thing.tags.removeAll { $0.persistentModelID == old.persistentModelID }
            if !thing.tags.contains(where: { $0.persistentModelID == new.persistentModelID }) {
                thing.tags.append(new)
            }
        }
        for image in Array(old.images) {
            image.tags.removeAll { $0.persistentModelID == old.persistentModelID }
            if !image.tags.contains(where: { $0.persistentModelID == new.persistentModelID }) {
                image.tags.append(new)
            }
        }
    }

    private func deleteTag(_ tag: Tag) {
        modelContext.delete(tag)
        try? modelContext.save()
        if sheetTag?.persistentModelID == tag.persistentModelID {
            sheetTag = nil
            detailItem = nil
            detailEntity = nil
        }
    }

    @ViewBuilder
    private func entityDetailView(_ entity: DetailEntity) -> some View {
        switch entity.kind {
        case .figure:
            FigureSheetDetail(entityID: entity.id)
        case .place:
            PlaceSheetDetail(entityID: entity.id)
        case .event:
            EventSheetDetail(entityID: entity.id)
        }
    }

    private func entityListView(_ item: DetailItem) -> some View {
        List {
            ForEach(item.sections, id: \.type) { section in
                Section(section.type) {
                    ForEach(section.entities) { entity in
                        Button {
                            detailEntity = entity
                        } label: {
                            Text(entity.name)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Sheet Detail Views (wraps the real detail views for in-sheet display)

private struct FigureSheetDetail: View {
    let entityID: PersistentIdentifier
    @State private var figure: Figure?

    var body: some View {
        Group {
            if let figure {
                FigureDetailView(figure: figure)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task {
            let fetch = FetchDescriptor<Figure>(predicate: #Predicate { $0.persistentModelID == entityID })
            figure = try? modelContext.fetch(fetch).first
        }
    }
    @Environment(\.modelContext) private var modelContext
}

private struct PlaceSheetDetail: View {
    let entityID: PersistentIdentifier
    @State private var place: Place?

    var body: some View {
        Group {
            if let place {
                PlaceDetailView(place: place)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task {
            let fetch = FetchDescriptor<Place>(predicate: #Predicate { $0.persistentModelID == entityID })
            place = try? modelContext.fetch(fetch).first
        }
    }
    @Environment(\.modelContext) private var modelContext
}

private struct EventSheetDetail: View {
    let entityID: PersistentIdentifier
    @State private var event: Event?

    var body: some View {
        Group {
            if let event {
                EventDetailView(event: event)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task {
            let fetch = FetchDescriptor<Event>(predicate: #Predicate { $0.persistentModelID == entityID })
            event = try? modelContext.fetch(fetch).first
        }
    }
    @Environment(\.modelContext) private var modelContext
}

// MARK: - CloudItem

struct CloudItem: Identifiable {
    let id: String
    let label: String
    let count: Int
    let color: Color
    let icon: String?
    let detail: TagCloudView.DetailItem
    var tag: Tag? = nil
}

extension Tag {
    var figureCount: Int { figures.count }
    var eventCount: Int { events.count }
    var placeCount: Int { places.count }
    var displayColor: Color {
        if let hex = colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return .accentColor
    }
}
