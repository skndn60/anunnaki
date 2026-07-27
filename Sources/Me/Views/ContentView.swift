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
    case enoch = "Book of Enoch"
    case sumerianKingList = "Sumerian King List"
    case sklMap = "Dynasty Map"
    case flood = "The Flood"
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
        case .enoch: return "book.fill"
        case .sumerianKingList: return "list.star"
        case .sklMap: return "map"
        case .flood: return "drop"
        case .theMes: return "rectangle.3.group"
        case .things: return "cube.box"
        case .dictionary: return "book"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard: return .overview
        case .missionControl, .importWiki, .versions: return .tools
        case .query, .tagCloud, .networkGraph, .lineage, .timeline: return .visualizations
        case .figures, .places, .events, .relationships, .associations, .typeSettings, .alternateNames, .eras, .stickies, .images, .sources, .things, .dictionary: return .data
        case .enoch, .sumerianKingList, .sklMap, .flood, .theMes: return .history
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
        case .enoch: EnochView()
        case .sumerianKingList: SumerianKingListView()
        case .sklMap: SumerianDynastyMapView()
        case .flood: ComingSoonView(title: "The Flood")
        case .theMes: ComingSoonView(title: "The Me’s")
        }
    }
}

struct ContentView: View {
    @State private var coordinator = NavigationCoordinator()
    @State private var isSeeding = true
    @State private var globalSearchText = ""
    @State private var showRecoveryAlert = MeApp.recoveryError != nil
    @FocusState private var searchFocused: Bool
    @Environment(\.modelContext) private var modelContext

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
                    try? modelContext.save()
                }
                isSeeding = false
            }
        } else {
            NavigationSplitView {
                List(selection: $coordinator.selectedItem) {
                    Section("Overview") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .overview }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                    Section("Tools") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .tools }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                    Section("Visualizations") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .visualizations }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                    Section("History") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .history }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                    Section("Data") {
                        ForEach(NavigationItem.allCases.filter { $0.section == .data }, id: \.self) { item in
                            Label(item.rawValue, systemImage: item.icon)
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
                        coordinator.selectedItem = item
                    })
                } else if coordinator.selectedItem == .dashboard {
                    DashboardView(onNavigateTo: { coordinator.selectedItem = $0 })
                } else if coordinator.selectedItem == .networkGraph {
                    NetworkGraphView(coordinator: coordinator)
                } else if let selectedItem = coordinator.selectedItem {
                    if selectedItem == .figures {
                        FigureListView(coordinator: coordinator)
                    } else if selectedItem == .places {
                        PlaceListView(coordinator: coordinator)
                    } else if selectedItem == .events {
                        EventListView(coordinator: coordinator)
                    } else if selectedItem == .things {
                        ThingListView(coordinator: coordinator)
                    } else if selectedItem == .dictionary {
                        DictionaryListView(coordinator: coordinator)
                    } else if selectedItem == .enoch {
                        EnochView(coordinator: coordinator)
                    } else if selectedItem == .sumerianKingList {
                        SumerianKingListView(coordinator: coordinator)
                    } else if selectedItem == .sklMap {
                        SumerianDynastyMapView(coordinator: coordinator)
                    } else if selectedItem == .lineage {
                        LineageTreeView(coordinator: coordinator)
                    } else if selectedItem == .query {
                        QueryView(coordinator: coordinator)
                    } else {
                        selectedItem.destination
                    }
                } else {
                    Text("Select a view from the sidebar")
                        .font(.title2)
                        .foregroundStyle(.secondary)
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
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        TextField("Search all entities\u{2026}", text: $globalSearchText)
                            .textFieldStyle(.plain)
                            .focused($searchFocused)
                            .frame(width: 180)
                            .onSubmit { searchFocused = true }
                    }
                    .padding(.leading, 4)
                    .padding(.trailing, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 0.5)
                    )
                }
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
