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

    private var coverage: (missingAncestry: [Figure], missingFather: [Figure], missingMother: [Figure], missingBirth: [Figure], missingDeath: [Figure], missingDescription: [Figure], missingDomain: [Figure]) {
        let withFather = Set(relationships.filter { $0.relationshipType?.name == "Father" }.compactMap { $0.toFigure?.persistentModelID })
        let withMother = Set(relationships.filter { $0.relationshipType?.name == "Mother" }.compactMap { $0.toFigure?.persistentModelID })

        var mf: [Figure] = []
        var mm: [Figure] = []
        var mb: [Figure] = []
        var md: [Figure] = []
        var mdesc: [Figure] = []
        var mdom: [Figure] = []

        for fig in coverageFigures {
            if !withFather.contains(fig.persistentModelID) { mf.append(fig) }
            if !withMother.contains(fig.persistentModelID) { mm.append(fig) }
            if fig.birthDate.startYear == nil && fig.birthDate.endYear == nil { mb.append(fig) }
            if fig.deathDate.startYear == nil && fig.deathDate.endYear == nil { md.append(fig) }
            if fig.figureDescription.isEmpty { mdesc.append(fig) }
            if fig.domain.isEmpty { mdom.append(fig) }
        }

        let missingAncestry = mf.filter { mm.contains($0) }

        return (missingAncestry, mf, mm, mb, md, mdesc, mdom)
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
        let reviewed = figures.filter { $0.coverageExempt == true && $0.coverageReviewedAt != nil }.count
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
            let exemptAndReviewed: (Figure) -> Void = { fig in
                fig.coverageExempt = true
                fig.coverageReviewedAt = .now
                try? modelContext.save()
            }
            let now = Date.now

            CoverageBlock(
                title: "Missing Ancestry",
                icon: "person.fill.questionmark",
                color: .red,
                items: c.missingAncestry,
                total: coverageFigures.count,
                totalLabel: "figures",
                onMarkAll: { c.missingAncestry.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                onMarkFigure: exemptAndReviewed
            )

            CoverageBlock(
                title: "Missing Father",
                icon: "figure.stand",
                color: .orange,
                items: c.missingFather,
                total: coverageFigures.count,
                totalLabel: "figures",
                onMarkAll: { c.missingFather.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                onMarkFigure: exemptAndReviewed
            )

            CoverageBlock(
                title: "Missing Mother",
                icon: "figure.stand.dress",
                color: .orange,
                items: c.missingMother,
                total: coverageFigures.count,
                totalLabel: "figures",
                onMarkAll: { c.missingMother.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                onMarkFigure: exemptAndReviewed
            )

            CoverageBlock(
                title: "Missing Birth Date",
                icon: "calendar.badge.exclamationmark",
                color: .orange,
                items: c.missingBirth,
                total: coverageFigures.count,
                totalLabel: "figures",
                onMarkAll: { c.missingBirth.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                onMarkFigure: exemptAndReviewed
            )

            CoverageBlock(
                title: "Missing Death Date",
                icon: "calendar.badge.exclamationmark",
                color: .orange,
                items: c.missingDeath,
                total: coverageFigures.count,
                totalLabel: "figures",
                onMarkAll: { c.missingDeath.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                onMarkFigure: exemptAndReviewed
            )

            CoverageBlock(
                title: "Missing Description",
                icon: "text.alignleft",
                color: .yellow,
                items: c.missingDescription,
                total: coverageFigures.count,
                totalLabel: "figures",
                onMarkAll: { c.missingDescription.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                onMarkFigure: exemptAndReviewed
            )

            CoverageBlock(
                title: "Missing Domain",
                icon: "globe",
                color: .yellow,
                items: c.missingDomain,
                total: coverageFigures.count,
                totalLabel: "figures",
                onMarkAll: { c.missingDomain.forEach { $0.coverageExempt = true; $0.coverageReviewedAt = now }; try? modelContext.save() },
                onMarkFigure: exemptAndReviewed
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

private struct CoverageBlock: View {
    let title: String
    let icon: String
    let color: Color
    let items: [Figure]
    let total: Int
    let totalLabel: String
    let onMarkAll: (() -> Void)?
    let onMarkFigure: ((Figure) -> Void)?

    private var count: Int { items.count }
    private var fraction: Double { total > 0 ? Double(count) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            }

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

            if !items.isEmpty {
                let displayItems = items.prefix(10)
                let remainder = count - displayItems.count
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(displayItems), id: \.persistentModelID) { fig in
                        HStack(spacing: 4) {
                            Text(fig.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let onMarkFigure {
                                Button("Dismiss") {
                                    onMarkFigure(fig)
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
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.textBackgroundColor))
        )
    }
}
