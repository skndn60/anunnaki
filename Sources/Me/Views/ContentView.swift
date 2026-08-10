import SwiftUI
import SwiftData

enum SidebarSection: String, CaseIterable {
    case overview = "Overview"
    case tools = "Tools"
    case visualizations = "Visualizations"
    case history = "History"
    case data = "Data"
}

enum NavigationItem: String, CaseIterable, Hashable {
    case dashboard = "Dashboard"
    case missionControl = "Mission Control"
    case importWiki = "Import from Wikipedia"
    case query = "Query"
    case tagCloud = "Tag Cloud"
    case networkGraph = "Object Graph"
    case lineage = "Lineage Tree"
    case timeline = "Timeline"
    case figures = "Figures"
    case places = "Places"
    case events = "Events"
    case things = "Things"
    case figureGroups = "Groups"
    case dictionary = "Dictionary"
    case relationships = "Relationships"
    case associations = "Associations"
    case typeSettings = "Type Settings"
    case alternateNames = "Alternate Names"
    case eras = "Eras"
    case stickies = "Stickies"
    case images = "Gallery"
    case sources = "Sources"
    case versions = "Versions"
    case sklMap = "Dynasty Map"
    case theMes = "The Me’s"

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .missionControl: return "antenna.radiowaves.left.and.right"
        case .importWiki: return "globe"
        case .query: return "text.magnifyingglass"
        case .tagCloud: return "cloud"
        case .networkGraph: return "arrow.triangle.branch"
        case .lineage: return "tree"
        case .timeline: return "calendar.day.timeline.left"
        case .figures: return "person.3"
        case .places: return "building.columns"
        case .events: return "bolt.fill"
        case .relationships: return "link"
        case .associations: return "point.3.connected.trianglepath.dotted"
        case .typeSettings: return "gearshape.2"
        case .alternateNames: return "textformat.abc"
        case .eras: return "clock.arrow.circlepath"
        case .stickies: return "square.and.pencil"
        case .images: return "photo.on.rectangle.angled"
        case .sources: return "books.vertical"
        case .versions: return "clock.arrow.circlepath"
        case .sklMap: return "map"
        case .theMes: return "rectangle.3.group"
        case .things: return "cube.box"
        case .figureGroups: return "folder"
        case .dictionary: return "book"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard: return .overview
        case .missionControl, .importWiki, .versions: return .tools
        case .query, .tagCloud, .networkGraph, .lineage, .timeline: return .visualizations
        case .figures, .places, .events, .relationships, .associations, .typeSettings, .alternateNames, .eras, .stickies, .images, .sources, .things, .figureGroups, .dictionary: return .data
        case .sklMap, .theMes: return .history
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .dashboard: DashboardView()
        case .missionControl: MissionControlView()
        case .importWiki: ImportView()
        case .query: QueryView()
        case .tagCloud: TagCloudView()
        case .networkGraph: NetworkGraphView()
        case .lineage: LineageTreeView()
        case .timeline: TimelineContainerView()
        case .figures: FigureListView()
        case .places: PlaceListView()
        case .events: EventListView()
        case .things: ThingListView()
        case .figureGroups: FigureGroupListView()
        case .dictionary: DictionaryListView()
        case .relationships: RelationshipListView()
        case .associations: AssociationsView()
        case .typeSettings: TypeSettingsView()
        case .alternateNames: AlternateNameListView()
        case .eras: EraListView()
        case .stickies: StickyNoteListView()
        case .images: ImageLibraryView()
        case .sources: SourceListView()
        case .versions: VersionListView()
        case .sklMap: SumerianDynastyMapView()
        case .theMes: ComingSoonView(title: "The Me’s")
        }
    }
}

struct ContentView: View {
    @State private var coordinator = NavigationCoordinator()
    @State private var isSeeding = true
    @State private var globalSearchText = ""
    @State private var showRecoveryAlert = MeApp.recoveryError != nil
    @State private var showBackupSheet = false
    @State private var showFromTextSheet = false
    @State private var showFromTextHistorySheet = false
    @FocusState private var searchFocused: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FigureGroup.orderIndex) private var allFigureGroups: [FigureGroup]
    @Query(
        filter: #Predicate<FigureGroup> { $0.parentGroup == nil },
        sort: \FigureGroup.orderIndex
    ) private var topLevelFigureGroups: [FigureGroup]
    @AppStorage("sidebarExpandedGroupPaths") private var expandedGroupPathsRaw = ""

    private var expandedGroupPaths: Set<String> {
        get { Set(expandedGroupPathsRaw.split(separator: ";").map(String.init)) }
        set { expandedGroupPathsRaw = newValue.sorted().joined(separator: ";") }
    }

    private var expandedGroupPathsBinding: Binding<Set<String>> {
        Binding(
            get: { expandedGroupPaths },
            set: { newValue in
                $expandedGroupPathsRaw.wrappedValue = newValue.sorted().joined(separator: ";")
            }
        )
    }

    var body: some View {
        if isSeeding {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Seeding database\u{2026}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await MainActor.run {
                    Migration.ensureRelationTypesExist(context: modelContext)
                    SeedData.seedIfEmpty(context: modelContext)
                    Migration.removeAutoGeneratedStickies(context: modelContext)
                    Migration.ensureSKLAnchorDates(context: modelContext)
                    Migration.ensureParentRelationshipsExist(context: modelContext)
                    Migration.ensureCoverageExemptFlags(context: modelContext)
                    Migration.ensureSKLDomain(context: modelContext)
                    Migration.enrichSKLData(context: modelContext)
                    Migration.ensureSKLEventTypesExist(context: modelContext)
                    Migration.ensureMissingCitiesAndAssociations(context: modelContext)
                    Migration.ensureImportedDeityRelationships(context: modelContext)
                    Migration.ensureEventCitations(context: modelContext)
                    Migration.ensureSKLEventsAndFigures(context: modelContext)
                    Migration.ensureReignYears(context: modelContext)
                    Migration.ensureEpithets(context: modelContext)
                    Migration.ensureMesopotamianPantheons(context: modelContext)
                    Migration.ensureDefaultFigureGroups(context: modelContext)
                    Migration.ensureFigureGroupKinds(context: modelContext)
                    Migration.removeFloodPlaceholder(context: modelContext)
                    Migration.ensureSKLRegnalOrder(context: modelContext)

                    try? modelContext.save()
                }
                isSeeding = false
            }
        } else {
            NavigationSplitView {
                List(selection: $coordinator.selection) {
                    Section("Overview") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .overview }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
                                .tag(SidebarSelection.item(item))
                        }
                    }
                    Section("Tools") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .tools }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
                                .tag(SidebarSelection.item(item))
                        }
                    }
                    Section("Visualizations") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .visualizations }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
                                .tag(SidebarSelection.item(item))
                        }
                    }
                    Section("History") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .history }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
                                .tag(SidebarSelection.item(item))
                        }
                    }
                    ForEach(GroupEntityType.allCases, id: \.self) { type in
                        let typeGroups = topLevelFigureGroups.filter { $0.isPublished && $0.entityType == type }
                        if !typeGroups.isEmpty {
                            Section(type.sidebarHeader) {
                                ForEach(typeGroups) { group in
                                    SidebarGroupRow(
                                        group: group,
                                        type: type,
                                        path: "\(type.rawValue)/\(group.name)",
                                        expandedPaths: expandedGroupPathsBinding
                                    )
                                }
                            }
                        }
                    }
                    Section("Data") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .data }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
                                .tag(SidebarSelection.item(item))
                        }
                    }
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
                .listStyle(.sidebar)
                .focusable(false)
            } detail: {
                if !globalSearchText.isEmpty {
                    GlobalSearchView(searchText: globalSearchText, onNavigateTo: { item in
                        globalSearchText = ""
                        coordinator.selection = .item(item)
                    })
                } else if let selection = coordinator.selection {
                    switch selection {
                    case .group(let id):
                        if let group = allFigureGroups.first(where: { $0.persistentModelID == id }) {
                            groupDestination(group: group)
                        } else {
                            Text("Select a view from the sidebar")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    case .item(let selectedItem):
                        if selectedItem == .dashboard {
                            DashboardView(onNavigateTo: { coordinator.selection = .item($0) })
                        } else if selectedItem == .networkGraph {
                            NetworkGraphView(coordinator: coordinator)
                        } else if selectedItem == .figures {
                            FigureListView(coordinator: coordinator)
                        } else if selectedItem == .places {
                            PlaceListView(coordinator: coordinator)
                        } else if selectedItem == .events {
                            EventListView(coordinator: coordinator)
                        } else if selectedItem == .things {
                            ThingListView(coordinator: coordinator)
                        } else if selectedItem == .figureGroups {
                            FigureGroupListView(coordinator: coordinator)
                        } else if selectedItem == .dictionary {
                            DictionaryListView(coordinator: coordinator)
                        } else if selectedItem == .sklMap {
                            SumerianDynastyMapView(coordinator: coordinator)
                        } else if selectedItem == .lineage {
                            LineageTreeView(coordinator: coordinator)
                        } else if selectedItem == .query {
                            QueryView(coordinator: coordinator)
                        } else {
                            selectedItem.destination
                        }
                    }
                } else {
                    Text("Select a view from the sidebar")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if let windowUM = NSApp.keyWindow?.undoManager {
                    modelContext.undoManager = windowUM
                }
            }
            .alert("Database Issue", isPresented: $showRecoveryAlert) {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            } message: {
                Text(MeApp.recoveryError.map { "The database at:\n\(MeApp.recoveryBackupPath ?? "unknown")\n\ncould not be opened. The app is running with an empty in-memory store.\n\nOn next launch the app will try again.\n\nError: " + $0 } ?? "Unknown error")
            }
            .onExitCommand { globalSearchText = "" }
            .background {
                Button("") { searchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .hidden()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    TextField("Search all entities\u{2026}", text: $globalSearchText)
                        .textFieldStyle(.roundedBorder)
                        .focused($searchFocused)
                        .frame(width: 220)
                        .overlay(alignment: .leading) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 6)
                                .allowsHitTesting(false)
                        }
                        .onSubmit { searchFocused = true }
                        .padding(.vertical, 2)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFromTextSheet = true
                    } label: {
                        Image(systemName: "text.badge.plus")
                    }
                    .help("Add figures and connections from text")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFromTextHistorySheet = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .help("View and revert past 'Add from Text' operations")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showBackupSheet = true
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .help("Back up or restore the database")
                }
            }
            .sheet(isPresented: $showFromTextSheet) {
                FromTextSheet()
            }
            .sheet(isPresented: $showFromTextHistorySheet) {
                FromTextHistorySheet()
            }
            .sheet(isPresented: $showBackupSheet) {
                BackupSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showBackupSheet)) { _ in
                showBackupSheet = true
            }
        }
    }
}

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.secondary)
            Text("Coming soon\u{2026}")
                .font(.body)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ContentView {
    @ViewBuilder
    private func groupDestination(group: FigureGroup) -> some View {
        let isDedicatedRoot = group.parentGroup == nil
        switch group.kind {
        case .standard:
            EntityGroupCollectionView(group: group, coordinator: coordinator)
        case .enoch:
            if isDedicatedRoot && group.entityType == .figure && (group.subgroups ?? []).isEmpty {
                EnochView(coordinator: coordinator)
            } else {
                EntityGroupCollectionView(group: group, coordinator: coordinator)
            }
        case .skl:
            if isDedicatedRoot && group.entityType == .figure && (group.subgroups ?? []).isEmpty {
                SumerianKingListView(coordinator: coordinator)
            } else {
                EntityGroupCollectionView(group: group, coordinator: coordinator)
            }
        case .flood:
            if isDedicatedRoot && group.entityType == .figure && (group.subgroups ?? []).isEmpty {
                ComingSoonView(title: "The Flood")
            } else {
                EntityGroupCollectionView(group: group, coordinator: coordinator)
            }
        }
    }
}

private struct SidebarGroupRow: View {
    let group: FigureGroup
    let type: GroupEntityType
    let path: String
    @Binding var expandedPaths: Set<String>

    private var subgroups: [FigureGroup] {
        (group.subgroups ?? [])
            .filter { $0.entityType == type }
            .sorted { ($0.orderIndex, $0.name) < ($1.orderIndex, $1.name) }
    }

    var body: some View {
        if subgroups.isEmpty {
            Label(group.name, systemImage: group.icon)
                .tag(SidebarSelection.group(group.persistentModelID))
        } else {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(subgroups) { sub in
                    SidebarGroupRow(
                        group: sub,
                        type: type,
                        path: path + "/" + sub.name,
                        expandedPaths: $expandedPaths
                    )
                }
            } label: {
                Label(group.name, systemImage: group.icon)
            }
            .tag(SidebarSelection.group(group.persistentModelID))
        }
    }

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedPaths.contains(path) },
            set: { newValue in
                if newValue {
                    expandedPaths.insert(path)
                } else {
                    expandedPaths.remove(path)
                }
            }
        )
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
