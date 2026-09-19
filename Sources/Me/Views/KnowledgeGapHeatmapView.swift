import SwiftUI
import SwiftData

struct KnowledgeGapHeatmapView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Figure.orderIndex) private var figures: [Figure]
    @Query(sort: \Place.name) private var places: [Place]
    @Query(sort: \Event.name) private var events: [Event]
    @Query(sort: \Source.name) private var sources: [Source]
    @Query private var relationships: [Relationship]

    @State private var rawSections: [KGRawSection] = []
    @State private var loaded = false
    @State private var includeExempt = false
    @State private var hiddenKinds: Set<KGEntityKind> = []
    @State private var searchText = ""
    @State private var sortBy: [KGEntityKind: String] = [:]
    @State private var sortDescending = true
    @State private var selectedDetail: KGDetailItem?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if loaded {
                matrix
            } else {
                ProgressView("Analysing knowledge gaps…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { rebuild() }
        .onChange(of: figures.map(\.persistentModelID)) { _, _ in rebuild() }
        .onChange(of: places.map(\.persistentModelID)) { _, _ in rebuild() }
        .onChange(of: events.map(\.persistentModelID)) { _, _ in rebuild() }
        .onChange(of: sources.map(\.persistentModelID)) { _, _ in rebuild() }
        .onChange(of: relationships.map(\.persistentModelID)) { _, _ in rebuild() }
        .sheet(item: $selectedDetail) { item in
            KGDetailSheet(item: item)
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Label("Knowledge Gap Heatmap", systemImage: "square.grid.3x3.fill")
                    .font(.title3.bold())
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                    Text("Filled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Circle().fill(Color.red.opacity(0.75)).frame(width: 10, height: 10)
                    Text("Gap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    TextField("Filter entities", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 240)

                ForEach(KGEntityKind.allCases, id: \.self) { kind in
                    let hidden = hiddenKinds.contains(kind)
                    Button {
                        if hidden { hiddenKinds.remove(kind) } else { hiddenKinds.insert(kind) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: kind.symbol)
                                .font(.caption)
                            Text(kind.title)
                                .font(.caption)
                            Text("\(count(for: kind))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            hidden ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(kind.tint.opacity(0.15)),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }

                Toggle("Include exempt", isOn: $includeExempt)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Spacer()

                summaryPill
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var summaryPill: some View {
        let s = aggregate
        return VStack(alignment: .trailing, spacing: 2) {
            Text("\(s.gaps) gaps / \(s.total) fields")
                .font(.caption.weight(.semibold))
            Text(String(format: "%.0f%% complete", s.filled > 0 ? (Double(s.filled) / Double(s.total)) * 100 : 0))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var matrix: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(sections) { section in
                    sectionView(section)
                }
            }
            .padding(14)
        }
    }

    private func sectionView(_ section: KGSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(section)
            columnHeader(section)
            VStack(spacing: 3) {
                ForEach(section.entries) { entry in
                    entryRow(entry, section: section)
                }
            }
        }
    }

    private func sectionHeader(_ section: KGSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.kind.symbol)
                .foregroundStyle(section.kind.tint)
            Text(section.kind.title)
                .font(.headline)
            Text("\(section.entries.count) shown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func columnHeader(_ section: KGSection) -> some View {
        HStack(spacing: 8) {
            Text("Name")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: Self.nameWidth, alignment: .leading)
            ForEach(section.columns, id: \.key) { column in
                Button {
                    toggleSort(section.kind, column: column.key)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Text(column.label)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            if sortBy[section.kind] == column.key {
                                Image(systemName: sortDescending ? "chevron.down" : "chevron.up")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.primary.opacity(0.08))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(columnCoverageColor(column))
                                    .frame(width: geo.size.width * CGFloat(column.covered) / CGFloat(max(1, column.total)))
                            }
                        }
                        .frame(height: 4)
                        Text("\(column.covered)/\(column.total)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: Self.cellWidth, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("\(column.label) set on \(column.covered)/\(column.total)")
            }
        }
    }

    private func columnCoverageColor(_ column: KGColumnMeta) -> Color {
        let fraction = column.total == 0 ? 0 : Double(column.covered) / Double(column.total)
        if fraction < 0.25 { return .red.opacity(0.8) }
        if fraction < 0.6 { return .orange.opacity(0.85) }
        return .green.opacity(0.8)
    }

    private func entryRow(_ entry: KGEntry, section: KGSection) -> some View {
        Button {
            selectedDetail = KGDetailItem(id: entry.id, kind: entry.kind, name: entry.name)
        } label: {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Text(entry.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(entry.exempt ? Color.secondary : Color.primary)
                    if entry.exempt {
                        Text("exempt")
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                    }
                }
                .frame(width: Self.nameWidth, alignment: .leading)
                ForEach(section.columns, id: \.key) { column in
                    cellView(entry, column: column, section: section)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func cellView(_ entry: KGEntry, column: KGColumnMeta, section: KGSection) -> some View {
        let covered = entry.fields[column.key] ?? false
        return RoundedRectangle(cornerRadius: 3)
            .fill(covered ? Color.green.opacity(0.8) : Color.red.opacity(0.7))
            .frame(width: Self.cellWidth, height: 14)
            .opacity(entry.exempt && !includeExempt ? 0.4 : 1)
            .help(covered
                ? "\(entry.name): \(column.label) filled"
                : "\(entry.name): missing \(column.label)")
    }

    // MARK: - Sort

    private func toggleSort(_ kind: KGEntityKind, column: String) {
        if sortBy[kind] == column {
            sortDescending.toggle()
        } else {
            sortBy[kind] = column
            sortDescending = true
        }
    }

    private func sortEntries(_ entries: [KGEntry], kind: KGEntityKind) -> [KGEntry] {
        let key = sortBy[kind]
        return entries.sorted { a, b in
            if let key {
                let aMissing = (a.fields[key] ?? false) ? 0 : 1
                let bMissing = (b.fields[key] ?? false) ? 0 : 1
                if sortDescending, aMissing != bMissing { return aMissing > bMissing }
                if !sortDescending, aMissing != bMissing { return aMissing < bMissing }
            }
            if a.missingCount != b.missingCount { return a.missingCount > b.missingCount }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    // MARK: - Derived

    private var sections: [KGSection] {
        rawSections.compactMap { raw in
            guard !hiddenKinds.contains(raw.kind) else { return nil }
            let visible = raw.entries.filter { entry in
                (includeExempt || !entry.exempt)
                    && (searchText.isEmpty || entry.name.localizedCaseInsensitiveContains(searchText))
            }
            let entries = sortEntries(visible, kind: raw.kind)
            let columns = raw.columns.map { column in
                let covered = visible.filter { ($0.fields[column.key] ?? false) }.count
                return KGColumnMeta(key: column.key, label: column.label, covered: covered, total: visible.count)
            }
            return KGSection(kind: raw.kind, columns: columns, entries: entries)
        }
    }

    private var aggregate: (filled: Int, gaps: Int, total: Int) {
        var filled = 0, gaps = 0, total = 0
        for section in sections {
            for entry in section.entries {
                for field in entry.fields.values {
                    total += 1
                    if field { filled += 1 } else { gaps += 1 }
                }
            }
        }
        return (filled, gaps, total)
    }

    private func count(for kind: KGEntityKind) -> Int {
        if includeExempt { return rawSections.first { $0.kind == kind }?.entries.count ?? 0 }
        return rawSections.first { $0.kind == kind }?.entries.filter { !$0.exempt }.count ?? 0
    }

    // MARK: - Rebuild (off render path)

    private func rebuild() {
        var raw: [KGRawSection] = []
        raw.append(buildFigureSection())
        raw.append(buildPlaceSection())
        raw.append(buildEventSection())
        raw.append(buildSourceSection())
        rawSections = raw
        loaded = true
    }

    private func buildFigureSection() -> KGRawSection {
        var hasParent = Set<PersistentIdentifier>()
        var hasChild = Set<PersistentIdentifier>()
        for relationship in relationships {
            if let to = relationship.toFigure {
                hasParent.insert(to.persistentModelID)
            }
            if let from = relationship.fromFigure {
                hasChild.insert(from.persistentModelID)
            }
        }

        var entries: [KGEntry] = []
        for figure in figures {
            let id = figure.persistentModelID
            let fields: [String: Bool] = [
                "description": !figure.figureDescription.isEmpty,
                "domain": !figure.domain.isEmpty,
                "type": figure.figureType != nil,
                "birth": figure.birthDate.startYear != nil || figure.birthDate.endYear != nil,
                "death": figure.deathDate.startYear != nil || figure.deathDate.endYear != nil,
                "parents": hasParent.contains(id),
                "children": hasChild.contains(id),
                "events": !figure.events.isEmpty,
                "places": !figure.placeAssociations.isEmpty,
                "images": !figure.images.isEmpty,
                "altNames": !figure.alternateNames.isEmpty,
                "pantheon": !figure.pantheons.isEmpty,
                "attributions": !(figure.contentAttributions ?? []).isEmpty
            ]
            entries.append(KGEntry(
                id: id,
                name: figure.name,
                kind: .figure,
                fields: fields,
                exempt: figure.coverageExempt == true
            ))
        }
        return KGRawSection(kind: .figure, columns: Self.figureColumns, entries: entries)
    }

    private func buildPlaceSection() -> KGRawSection {
        var entries: [KGEntry] = []
        for place in places {
            let hasCoordinates = (place.latitude != nil && place.longitude != nil) || place.coordinatesUnknown == true
            entries.append(KGEntry(
                id: place.persistentModelID,
                name: place.name,
                kind: .place,
                fields: [
                    "description": !place.placeDescription.isEmpty,
                    "type": place.placeType != nil,
                    "modernLocation": !place.modernLocation.isEmpty,
                    "coordinates": hasCoordinates,
                    "figures": !place.figureAssociations.isEmpty,
                    "events": !place.eventAssociations.isEmpty,
                    "altNames": !place.alternateNames.isEmpty,
                    "images": !place.images.isEmpty,
                    "attributions": !(place.contentAttributions ?? []).isEmpty
                ],
                exempt: place.coverageExempt == true
            ))
        }
        return KGRawSection(kind: .place, columns: Self.placeColumns, entries: entries)
    }

    private func buildEventSection() -> KGRawSection {
        var entries: [KGEntry] = []
        for event in events {
            entries.append(KGEntry(
                id: event.persistentModelID,
                name: event.name,
                kind: .event,
                fields: [
                    "description": !event.eventDescription.isEmpty,
                    "type": event.eventType != nil,
                    "date": event.date.startYear != nil || event.date.endYear != nil,
                    "figures": !event.involvedFigures.isEmpty || !(event.figureAssociations ?? []).isEmpty,
                    "places": !event.placeAssociations.isEmpty,
                    "images": !event.images.isEmpty,
                    "attributions": !(event.contentAttributions ?? []).isEmpty
                ],
                exempt: event.coverageExempt == true
            ))
        }
        return KGRawSection(kind: .event, columns: Self.eventColumns, entries: entries)
    }

    private func buildSourceSection() -> KGRawSection {
        var entries: [KGEntry] = []
        for source in sources {
            entries.append(KGEntry(
                id: source.persistentModelID,
                name: source.name,
                kind: .source,
                fields: [
                    "description": !source.sourceDescription.isEmpty,
                    "author": !source.author.isEmpty,
                    "language": !source.language.isEmpty,
                    "period": !source.period.isEmpty,
                    "publication": !source.publicationInfo.isEmpty,
                    "url": !source.url.isEmpty,
                    "attachments": !source.attachments.isEmpty,
                    "citations": !source.citations.isEmpty
                ],
                exempt: false
            ))
        }
        return KGRawSection(kind: .source, columns: Self.sourceColumns, entries: entries)
    }

    // MARK: - Column definitions

    private static let nameWidth: CGFloat = 200
    private static let cellWidth: CGFloat = 30

    private static let figureColumns: [(key: String, label: String)] = [
        ("description", "Description"),
        ("domain", "Domain"),
        ("type", "Type"),
        ("birth", "Birth"),
        ("death", "Death"),
        ("parents", "Parents"),
        ("children", "Children"),
        ("events", "Events"),
        ("places", "Places"),
        ("images", "Images"),
        ("altNames", "Alt names"),
        ("pantheon", "Pantheon"),
        ("attributions", "Attributions")
    ]

    private static let placeColumns: [(key: String, label: String)] = [
        ("description", "Description"),
        ("type", "Type"),
        ("modernLocation", "Modern loc."),
        ("coordinates", "Coords"),
        ("figures", "Figures"),
        ("events", "Events"),
        ("altNames", "Alt names"),
        ("images", "Images"),
        ("attributions", "Attributions")
    ]

    private static let eventColumns: [(key: String, label: String)] = [
        ("description", "Description"),
        ("type", "Type"),
        ("date", "Date"),
        ("figures", "Figures"),
        ("places", "Places"),
        ("images", "Images"),
        ("attributions", "Attributions")
    ]

    private static let sourceColumns: [(key: String, label: String)] = [
        ("description", "Description"),
        ("author", "Author"),
        ("language", "Language"),
        ("period", "Period"),
        ("publication", "Publication"),
        ("url", "URL"),
        ("attachments", "Attachment"),
        ("citations", "Citations")
    ]
}

// MARK: - Value types

private enum KGEntityKind: String, Hashable, CaseIterable {
    case figure
    case place
    case event
    case source

    var title: String {
        switch self {
        case .figure: return "Figures"
        case .place: return "Places"
        case .event: return "Events"
        case .source: return "Sources"
        }
    }

    var symbol: String {
        switch self {
        case .figure: return "person.3"
        case .place: return "building.columns"
        case .event: return "bolt.fill"
        case .source: return "books.vertical"
        }
    }

    var tint: Color {
        switch self {
        case .figure: return .blue
        case .place: return .green
        case .event: return .orange
        case .source: return .red
        }
    }
}

private struct KGRawSection {
    let kind: KGEntityKind
    let columns: [(key: String, label: String)]
    let entries: [KGEntry]
}

private struct KGEntry: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let kind: KGEntityKind
    let fields: [String: Bool]
    let exempt: Bool

    var missingCount: Int { fields.values.filter { !$0 }.count }
}

private struct KGColumnMeta {
    let key: String
    let label: String
    let covered: Int
    let total: Int
}

private struct KGSection: Identifiable {
    let kind: KGEntityKind
    let columns: [KGColumnMeta]
    let entries: [KGEntry]

    var id: KGEntityKind { kind }
}

private struct KGDetailItem: Identifiable {
    let id: PersistentIdentifier
    let kind: KGEntityKind
    let name: String
}

// MARK: - Detail sheet

private struct KGDetailSheet: View {
    let item: KGDetailItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch item.kind {
                case .figure: KGFigureSheet(entityID: item.id)
                case .place: KGPlaceSheet(entityID: item.id)
                case .event: KGEventSheet(entityID: item.id)
                case .source: KGSourceSheet(entityID: item.id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(width: 960, height: 700)
    }
}

private struct KGFigureSheet: View {
    let entityID: PersistentIdentifier
    @State private var figure: Figure?
    @Environment(\.modelContext) private var modelContext

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
}

private struct KGPlaceSheet: View {
    let entityID: PersistentIdentifier
    @State private var place: Place?
    @Environment(\.modelContext) private var modelContext

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
}

private struct KGEventSheet: View {
    let entityID: PersistentIdentifier
    @State private var event: Event?
    @Environment(\.modelContext) private var modelContext

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
}

private struct KGSourceSheet: View {
    let entityID: PersistentIdentifier
    @State private var source: Source?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let source {
                SourceDetailView(source: source)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task {
            let fetch = FetchDescriptor<Source>(predicate: #Predicate { $0.persistentModelID == entityID })
            source = try? modelContext.fetch(fetch).first
        }
    }
}