import SwiftUI

enum SidebarSection: String, CaseIterable {
    case tools = "Tools"
    case visualizations = "Visualizations"
    case data = "Data"
}

enum NavigationItem: String, CaseIterable, Hashable {
    case importWiki = "Import from Wikipedia"
    case query = "Query"
    case lineage = "Lineage Tree"
    case timeline = "Timeline"
    case figures = "Figures"
    case places = "Places"
    case events = "Events"
    case relationships = "Relationships"
    case associations = "Associations"
    case alternateNames = "Alternate Names"
    case eras = "Eras"
    case sources = "Sources"

    var icon: String {
        switch self {
        case .importWiki: return "globe.badge.plus"
        case .query: return "text.magnifyingglass"
        case .lineage: return "tree"
        case .timeline: return "calendar.day.timeline.left"
        case .figures: return "person.3"
        case .places: return "building.columns"
        case .events: return "bolt.fill"
        case .relationships: return "link"
        case .associations: return "point.3.connected.trianglepath.dotted"
        case .alternateNames: return "textformat.abc"
        case .eras: return "clock.arrow.circlepath"
        case .sources: return "books.vertical"
        }
    }

    var section: SidebarSection {
        switch self {
        case .importWiki: return .tools
        case .query, .lineage, .timeline: return .visualizations
        case .figures, .places, .events, .relationships, .associations, .alternateNames, .eras, .sources: return .data
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .importWiki: ImportView()
        case .query: QueryView()
        case .lineage: LineageTreeView()
        case .timeline: TimelineView()
        case .figures: FigureListView()
        case .places: PlaceListView()
        case .events: EventListView()
        case .relationships: RelationshipListView()
        case .associations: AssociationsView()
        case .alternateNames: AlternateNameListView()
        case .eras: EraListView()
        case .sources: SourceListView()
        }
    }
}

struct ContentView: View {
    @State private var selection: NavigationItem? = .query

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
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
            if let selection {
                selection.destination
            } else {
                Text("Select a view from the sidebar")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
