import SwiftUI
import SwiftData

struct DashboardView: View {
    var onNavigateTo: ((NavigationItem) -> Void)?

    @Environment(\.modelContext) private var modelContext

    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @Query private var events: [Event]
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var sources: [Source]
    @Query private var relationships: [Relationship]
    @Query private var things: [Thing]
    @Query private var entries: [DictionaryEntry]
    private var recentEdits: [RecentEdit] { RecentEditStore.items }

    @State private var showingAddFigure = false
    @State private var showingAddPlace = false
    @State private var showingAddEvent = false
    @State private var showingAddThing = false
    @State private var showingReseedAlert = false
    @State private var isReseeding = false
    @State private var showingCoverage = false

    private var coverageFigures: [Figure] {
        figures.filter { $0.coverageExempt != true }
    }

    private var coverage: FigureCoverage {
        let withFather = Set(relationships.filter { $0.relationshipType?.name == "Father" }.compactMap { $0.toFigure?.persistentModelID })
        let withMother = Set(relationships.filter { $0.relationshipType?.name == "Mother" }.compactMap { $0.toFigure?.persistentModelID })

        var c = FigureCoverage()
        for fig in coverageFigures {
            if !withFather.contains(fig.persistentModelID) { c.missingFather.append(fig) }
            if !withMother.contains(fig.persistentModelID) { c.missingMother.append(fig) }
            if fig.birthDate.startYear == nil && fig.birthDate.endYear == nil { c.missingBirth.append(fig) }
            if fig.deathDate.startYear == nil && fig.deathDate.endYear == nil { c.missingDeath.append(fig) }
            if fig.figureDescription.isEmpty { c.missingDescription.append(fig) }
            if fig.domain.isEmpty { c.missingDomain.append(fig) }
            if fig.figureType == nil { c.missingType.append(fig) }
            if fig.reignYears == nil { c.missingReignYears.append(fig) }
            if fig.epithet == nil { c.missingEpithet.append(fig) }
            if fig.mugshotImage == nil { c.missingMugshot.append(fig) }
            if fig.pantheons.isEmpty { c.missingPantheon.append(fig) }
            if fig.alternateNames.isEmpty { c.missingAlternateNames.append(fig) }
            if fig.images.isEmpty { c.missingImages.append(fig) }
            if (fig.contentAttributions ?? []).isEmpty { c.missingAttribution.append(fig) }
        }
        c.missingAncestry = c.missingFather.filter { c.missingMother.contains($0) }

        return c
    }

    private var placeCoverage: PlaceCoverage {
        let all = places.filter { $0.coverageExempt != true }
        var c = PlaceCoverage()
        for p in all {
            if p.placeDescription.isEmpty { c.missingDescription.append(p) }
            if p.modernLocation.isEmpty { c.missingModernLocation.append(p) }
            if p.latitude == nil || p.longitude == nil { c.missingCoordinates.append(p) }
            if p.placeType == nil { c.missingType.append(p) }
        }
        return c
    }

    private var eventCoverage: EventCoverage {
        let all = events.filter { $0.coverageExempt != true }
        var c = EventCoverage()
        for e in all {
            if e.eventDescription.isEmpty { c.missingDescription.append(e) }
            if e.date.startYear == nil && e.date.endYear == nil { c.missingDate.append(e) }
            if e.eventType == nil { c.missingType.append(e) }
            if e.involvedFigures.isEmpty && (e.figureAssociations ?? []).isEmpty { c.missingInvolvedFigures.append(e) }
        }
        return c
    }

    private var thingCoverage: ThingCoverage {
        let all = things.filter { $0.coverageExempt != true }
        var c = ThingCoverage()
        for t in all {
            if t.thingDescription.isEmpty { c.missingDescription.append(t) }
            if t.thingType == nil { c.missingType.append(t) }
        }
        return c
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsGrid
                quickActions
                recentEditsSection
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dashboard")
                .font(.largeTitle.bold())
            Text("An overview of your Mesopotamian mythology database")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            StatCard(title: "Figures", count: figures.count, icon: "person.3", color: .blue, action: { onNavigateTo?(.figures) })
            StatCard(title: "Places", count: places.count, icon: "building.columns", color: .green, action: { onNavigateTo?(.places) })
            StatCard(title: "Events", count: events.count, icon: "bolt.fill", color: .orange, action: { onNavigateTo?(.events) })
            StatCard(title: "Eras", count: eras.count, icon: "clock.arrow.circlepath", color: .purple, action: { onNavigateTo?(.eras) })
            StatCard(title: "Sources", count: sources.count, icon: "books.vertical", color: .red, action: { onNavigateTo?(.sources) })
            StatCard(title: "Relationships", count: relationships.count, icon: "link", color: .teal, action: { onNavigateTo?(.relationships) })
            StatCard(title: "Things", count: things.count, icon: "cube.box", color: .cyan, action: { onNavigateTo?(.things) })
            StatCard(title: "Dictionary", count: entries.count, icon: "character.book.closed", color: .purple, action: { onNavigateTo?(.dictionary) })
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Quick Actions")
            HStack(spacing: 12) {
                QuickActionButton(title: "New Figure", icon: "person.badge.plus", color: .blue) { showingAddFigure = true }
                QuickActionButton(title: "New Place", icon: "building.2", color: .green) { showingAddPlace = true }
                QuickActionButton(title: "New Event", icon: "calendar.badge.plus", color: .orange) { showingAddEvent = true }
                QuickActionButton(title: "New Thing", icon: "cube.box", color: .cyan) { showingAddThing = true }
                QuickActionButton(title: "Coverage & Exemptions", icon: "chart.bar.fill", color: .purple) { showingCoverage = true }
                QuickActionButton(title: "Go to Query", icon: "text.magnifyingglass", color: .indigo) { onNavigateTo?(.query) }
                QuickActionButton(title: "Reseed Database", icon: "arrow.counterclockwise", color: .red) { showingReseedAlert = true }
                    .disabled(isReseeding)
                QuickActionButton(title: "Versions", icon: "clock.arrow.circlepath", color: .teal) { onNavigateTo?(.versions) }
            }
        }
        .sheet(isPresented: $showingCoverage) {
            NavigationStack {
                ScrollView {
                    dataCoverageSection
                        .padding(20)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showingCoverage = false }
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showingAddFigure) { FigureFormView(figure: nil) }
        .sheet(isPresented: $showingAddPlace) { PlaceFormView(place: nil) }
        .sheet(isPresented: $showingAddEvent) { EventFormView(event: nil) }
        .sheet(isPresented: $showingAddThing) { ThingFormView(thing: nil) }
        .alert("Reseed Database?", isPresented: $showingReseedAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reseed", role: .destructive) {
                isReseeding = true
                Task {
                    await MainActor.run {
                        SeedData.reseed(context: modelContext)
                        try? modelContext.save()
                        isReseeding = false
                    }
                }
            }
        } message: {
            Text("This will delete all existing data and re-import from seed_data.json and igigi.json. This action cannot be undone.")
        }
        .overlay {
            if isReseeding {
                ZStack {
                    Color(.windowBackgroundColor).opacity(0.8)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Reseeding database\u{2026}")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var auditSummary: some View {
        let autoExempted = figures.filter { $0.coverageExempt == true && $0.coverageReviewedAt == nil }.count
            + places.filter { $0.coverageExempt == true && $0.coverageReviewedAt == nil }.count
            + events.filter { $0.coverageExempt == true && $0.coverageReviewedAt == nil }.count
            + things.filter { $0.coverageExempt == true && $0.coverageReviewedAt == nil }.count
        let reviewed = figures.filter { $0.coverageExempt == true && $0.coverageReviewedAt != nil }.count
            + places.filter { $0.coverageExempt == true && $0.coverageReviewedAt != nil }.count
            + events.filter { $0.coverageExempt == true && $0.coverageReviewedAt != nil }.count
            + things.filter { $0.coverageExempt == true && $0.coverageReviewedAt != nil }.count
        return HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("\(autoExempted) auto-exempted by type")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("·")
                .foregroundStyle(.quaternary)
            Text("\(reviewed) manually reviewed")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var dataCoverageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Data Coverage")
            auditSummary

            let c = coverage
            let pc = placeCoverage
            let ec = eventCoverage
            let tc = thingCoverage
            let now = Date.now

            coverageGroupHeader("Figures")
            coverageBlocks(
                dims: [
                    (title: "Missing Ancestry", icon: "person.fill.questionmark", color: .red, items: c.missingAncestry),
                    (title: "Missing Father", icon: "figure.stand", color: .orange, items: c.missingFather),
                    (title: "Missing Mother", icon: "figure.stand.dress", color: .orange, items: c.missingMother),
                    (title: "Missing Birth Date", icon: "calendar.badge.exclamationmark", color: .orange, items: c.missingBirth),
                    (title: "Missing Death Date", icon: "calendar.badge.exclamationmark", color: .orange, items: c.missingDeath),
                    (title: "Missing Description", icon: "text.alignleft", color: .yellow, items: c.missingDescription),
                    (title: "Missing Domain", icon: "globe", color: .yellow, items: c.missingDomain),
                    (title: "Missing Type", icon: "questionmark.circle", color: .orange, items: c.missingType),
                    (title: "Missing Reign Years", icon: "crown", color: .orange, items: c.missingReignYears),
                    (title: "Missing Epithet", icon: "quote.opening", color: .yellow, items: c.missingEpithet),
                    (title: "Missing Mugshot", icon: "person.crop.circle.badge.questionmark", color: .yellow, items: c.missingMugshot),
                    (title: "Missing Pantheon", icon: "building.columns", color: .yellow, items: c.missingPantheon),
                    (title: "Missing Alternate Names", icon: "textformat.abc", color: .yellow, items: c.missingAlternateNames),
                    (title: "No Images", icon: "photo", color: .yellow, items: c.missingImages),
                    (title: "Missing Attribution", icon: "book.closed", color: .yellow, items: c.missingAttribution),
                ],
                total: coverageFigures.count,
                totalLabel: "figures",
                name: { $0.name },
                markAll: { items in items.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                markOne: { item in item.coverageExempt = true; item.coverageReviewedAt = now; try? modelContext.save() }
            )

            coverageGroupHeader("Places")
            coverageBlocks(
                dims: [
                    (title: "Missing Description", icon: "text.alignleft", color: .yellow, items: pc.missingDescription),
                    (title: "Missing Modern Location", icon: "mappin.and.ellipse", color: .orange, items: pc.missingModernLocation),
                    (title: "Missing Coordinates", icon: "location.slash", color: .orange, items: pc.missingCoordinates),
                    (title: "Missing Type", icon: "questionmark.circle", color: .orange, items: pc.missingType),
                ],
                total: places.filter { $0.coverageExempt != true }.count,
                totalLabel: "places",
                name: { $0.name },
                markAll: { items in items.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                markOne: { item in item.coverageExempt = true; item.coverageReviewedAt = now; try? modelContext.save() }
            )

            coverageGroupHeader("Events")
            coverageBlocks(
                dims: [
                    (title: "Missing Description", icon: "text.alignleft", color: .yellow, items: ec.missingDescription),
                    (title: "Missing Date", icon: "calendar.badge.exclamationmark", color: .orange, items: ec.missingDate),
                    (title: "Missing Type", icon: "questionmark.circle", color: .orange, items: ec.missingType),
                    (title: "No Involved Figures", icon: "person.2.slash", color: .yellow, items: ec.missingInvolvedFigures),
                ],
                total: events.filter { $0.coverageExempt != true }.count,
                totalLabel: "events",
                name: { $0.name },
                markAll: { items in items.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                markOne: { item in item.coverageExempt = true; item.coverageReviewedAt = now; try? modelContext.save() }
            )

            coverageGroupHeader("Things")
            coverageBlocks(
                dims: [
                    (title: "Missing Description", icon: "text.alignleft", color: .yellow, items: tc.missingDescription),
                    (title: "Missing Type", icon: "questionmark.circle", color: .orange, items: tc.missingType),
                ],
                total: things.filter { $0.coverageExempt != true }.count,
                totalLabel: "things",
                name: { $0.name },
                markAll: { items in items.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                markOne: { item in item.coverageExempt = true; item.coverageReviewedAt = now; try? modelContext.save() }
            )
        }
    }

    private func coverageGroupHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .padding(.top, 6)
    }

    private func coverageBlocks<Entity: PersistentModel>(
        dims: [(title: String, icon: String, color: Color, items: [Entity])],
        total: Int,
        totalLabel: String,
        name: @escaping (Entity) -> String,
        markAll: @escaping ([Entity]) -> Void,
        markOne: @escaping (Entity) -> Void
    ) -> some View {
        ForEach(dims, id: \.title) { dim in
            CoverageBlock(
                title: dim.title,
                icon: dim.icon,
                color: dim.color,
                items: dim.items,
                total: total,
                totalLabel: totalLabel,
                name: name,
                onMarkAll: { markAll(dim.items) },
                onMarkFigure: markOne
            )
        }
    }

    private var recentEditsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Recent Edits")
            if recentEdits.isEmpty {
                Text("No recent edits")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    let edits = recentEdits.sorted { $0.timestamp > $1.timestamp }.prefix(10)
                    ForEach(Array(edits.enumerated()), id: \.element.id) { index, edit in
                        Button {
                            switch edit.entityType {
                            case "Figure": onNavigateTo?(.figures)
                            case "Place": onNavigateTo?(.places)
                            case "Event": onNavigateTo?(.events)
                            case "Thing": onNavigateTo?(.things)
                            case "DictionaryEntry": onNavigateTo?(.dictionary)
                            default: break
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: edit.entityType == "Figure" ? "person.fill" : edit.entityType == "Place" ? "building.columns" : edit.entityType == "Event" ? "bolt.fill" : edit.entityType == "DictionaryEntry" ? "character.book.closed" : "cube.box")
                                    .font(.caption)
                                    .foregroundStyle(edit.entityType == "Figure" ? .blue : edit.entityType == "Place" ? .green : edit.entityType == "Event" ? .orange : edit.entityType == "DictionaryEntry" ? .purple : .cyan)
                                    .frame(width: 16)
                                Text(edit.entityName)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(edit.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < edits.count - 1 {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.textBackgroundColor))
                )
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.secondary)
    }
}

private struct StatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text("\(count)")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.08))
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FigureCoverage {
    var missingAncestry: [Figure] = []
    var missingFather: [Figure] = []
    var missingMother: [Figure] = []
    var missingBirth: [Figure] = []
    var missingDeath: [Figure] = []
    var missingDescription: [Figure] = []
    var missingDomain: [Figure] = []
    var missingType: [Figure] = []
    var missingReignYears: [Figure] = []
    var missingEpithet: [Figure] = []
    var missingMugshot: [Figure] = []
    var missingPantheon: [Figure] = []
    var missingAlternateNames: [Figure] = []
    var missingImages: [Figure] = []
    var missingAttribution: [Figure] = []
}

private struct PlaceCoverage {
    var missingDescription: [Place] = []
    var missingModernLocation: [Place] = []
    var missingCoordinates: [Place] = []
    var missingType: [Place] = []
}

private struct EventCoverage {
    var missingDescription: [Event] = []
    var missingDate: [Event] = []
    var missingType: [Event] = []
    var missingInvolvedFigures: [Event] = []
}

private struct ThingCoverage {
    var missingDescription: [Thing] = []
    var missingType: [Thing] = []
}

private struct CoverageBlock<Entity: PersistentModel>: View {
    let title: String
    let icon: String
    let color: Color
    let items: [Entity]
    let total: Int
    let totalLabel: String
    let name: (Entity) -> String
    let onMarkAll: (() -> Void)?
    let onMarkFigure: ((Entity) -> Void)?

    @State private var isExpanded = false

    private var count: Int { items.count }
    private var fraction: Double { total > 0 ? Double(count) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !items.isEmpty, let onMarkAll {
                        Button("Dismiss All") {
                            onMarkAll()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.blue)
                    }
                    Text("\(count)/\(total)")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(fraction > 0.5 ? .red : fraction > 0.2 ? .orange : .secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.separatorColor).opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * fraction), height: 6)
                }
            }
            .frame(height: 6)

            if isExpanded && !items.isEmpty {
                let displayItems = items.prefix(10)
                let remainder = count - displayItems.count
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(displayItems), id: \.persistentModelID) { item in
                        HStack(spacing: 4) {
                            Text(name(item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let onMarkFigure {
                                Button("Dismiss") {
                                    onMarkFigure(item)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                                .tint(.blue)
                            }
                        }
                    }
                    if remainder > 0 {
                        Text("+ \(remainder) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.textBackgroundColor))
        )
    }
}
