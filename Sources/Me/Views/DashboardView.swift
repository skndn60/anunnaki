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
    @Query private var figureTypes: [FigureType]
    @Query private var citations: [Citation]
    @Query private var things: [Thing]
    private var recentEdits: [RecentEdit] { RecentEditStore.items }

    @State private var showingAddFigure = false
    @State private var showingAddPlace = false
    @State private var showingAddEvent = false
    @State private var showingAddThing = false
    @State private var showingReseedAlert = false
    @State private var isReseeding = false
    private var mostConnectedFigure: (name: String, count: Int)? {
        let counts = figures.map { figure -> (String, Int) in
            let count = relationships.filter {
                $0.fromFigure?.name == figure.name || $0.toFigure?.name == figure.name
            }.count
            return (figure.name, count)
        }
        return counts.max { $0.1 < $1.1 }
    }

    private var femaleCount: Int { figures.filter { $0.gender == .female }.count }
    private var maleCount: Int { figures.filter { $0.gender == .male }.count }
    private var nonBinaryCount: Int { figures.filter { $0.gender == .nonBinary }.count }

    private var typeDistribution: [(name: String, count: Int, color: Color)] {
        figureTypes.map { type in
            let count = figures.filter { $0.figureType?.persistentModelID == type.persistentModelID }.count
            return (type.name, count, type.color)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsGrid
                quickActions
                insights
                typeDistributionSection
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
                QuickActionButton(title: "Go to Query", icon: "text.magnifyingglass", color: .indigo) { onNavigateTo?(.query) }
                QuickActionButton(title: "Reseed Database", icon: "arrow.counterclockwise", color: .red) { showingReseedAlert = true }
                    .disabled(isReseeding)
                QuickActionButton(title: "Versions", icon: "clock.arrow.circlepath", color: .teal) { onNavigateTo?(.versions) }
            }
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

    private var insights: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Data Insights")
            VStack(spacing: 6) {
                if let (name, count) = mostConnectedFigure {
                    InsightRow(label: "Most connected figure", value: "\(name) (\(count) relationships)")
                }
                InsightRow(label: "Female figures", value: "\(femaleCount)")
                InsightRow(label: "Male figures", value: "\(maleCount)")
                InsightRow(label: "Non-binary figures", value: "\(nonBinaryCount)")
                InsightRow(label: "Total citations", value: "\(citations.count)")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.textBackgroundColor))
            )
        }
    }

    private var typeDistributionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Figure Types")
            let maxCount = typeDistribution.map(\.count).max() ?? 1
            VStack(spacing: 8) {
                ForEach(typeDistribution, id: \.name) { type in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(type.color)
                            .frame(width: 10, height: 10)
                        Text(type.name)
                            .font(.callout)
                            .frame(width: 80, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(type.color.opacity(0.3))
                                .frame(width: max(20, geo.size.width * CGFloat(type.count) / CGFloat(maxCount)), height: 16)
                                .overlay(alignment: .trailing) {
                                    Text("\(type.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.trailing, 4)
                                }
                        }
                        .frame(height: 16)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.textBackgroundColor))
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
                            default: break
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: edit.entityType == "Figure" ? "person.fill" : edit.entityType == "Place" ? "building.columns" : edit.entityType == "Event" ? "bolt.fill" : "cube.box")
                                    .font(.caption)
                                    .foregroundStyle(edit.entityType == "Figure" ? .blue : edit.entityType == "Place" ? .green : edit.entityType == "Event" ? .orange : .cyan)
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

private struct InsightRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }
}
