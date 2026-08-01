import Foundation
import SwiftUI
import SwiftData

enum SidebarSelection: Hashable {
    case item(NavigationItem)
    case group(PersistentIdentifier)

    var item: NavigationItem? {
        if case .item(let item) = self { return item }
        return nil
    }
}

struct NavigationBreadcrumb: Identifiable {
    let id: UUID
    let name: String
    let item: NavigationItem
    let entityID: PersistentIdentifier?

    init(id: PersistentIdentifier, name: String, item: NavigationItem) {
        self.id = UUID()
        self.name = name
        self.item = item
        self.entityID = id
    }

    init?(queryText: String) {
        guard !queryText.isEmpty else { return nil }
        self.id = UUID()
        self.name = "Query: \"\(queryText)\""
        self.item = .query
        self.entityID = nil
    }
}

@Observable
final class NavigationCoordinator {
    var selection: SidebarSelection? = .item(.dashboard)
    var pendingFigureID: PersistentIdentifier?
    var pendingPlaceID: PersistentIdentifier?
    var pendingEventID: PersistentIdentifier?
    var pendingThingID: PersistentIdentifier?
    var pendingGroupID: PersistentIdentifier?
    var pendingLineageFigureID: PersistentIdentifier?
    var history: [NavigationBreadcrumb] = []
    var recentQueryText = ""
    var recentQueryResult: QueryResult?

    func navigateToFigure(_ id: PersistentIdentifier, name: String = "", recordHistory: Bool = true) {
        if recordHistory { pushHistory(id: id, name: name, item: .figures) }
        pendingFigureID = id
        selection = .item(.figures)
    }

    func navigateToPlace(_ id: PersistentIdentifier, name: String = "", recordHistory: Bool = true) {
        if recordHistory { pushHistory(id: id, name: name, item: .places) }
        pendingPlaceID = id
        selection = .item(.places)
    }

    func navigateToEvent(_ id: PersistentIdentifier, name: String = "", recordHistory: Bool = true) {
        if recordHistory { pushHistory(id: id, name: name, item: .events) }
        pendingEventID = id
        selection = .item(.events)
    }

    func navigateToThing(_ id: PersistentIdentifier, name: String = "", recordHistory: Bool = true) {
        if recordHistory { pushHistory(id: id, name: name, item: .things) }
        pendingThingID = id
        selection = .item(.things)
    }

    func navigateToGroup(_ id: PersistentIdentifier, name: String = "", recordHistory: Bool = true) {
        if recordHistory { pushHistory(id: id, name: name, item: .figureGroups) }
        pendingGroupID = id
        selection = .group(id)
    }

    func navigateToLineageFigure(_ id: PersistentIdentifier) {
        pendingLineageFigureID = id
        selection = .item(.lineage)
    }

    func pushQueryBreadcrumb(queryText: String) {
        guard let crumb = NavigationBreadcrumb(queryText: queryText) else { return }
        if history.last?.id != crumb.id {
            history.append(crumb)
            if history.count > 24 { history.removeFirst() }
        }
    }

    func consumePendingGroupID() -> PersistentIdentifier? {
        let id = pendingGroupID
        pendingGroupID = nil
        return id
    }

    func consumePendingLineageFigureID() -> PersistentIdentifier? {
        let id = pendingLineageFigureID
        pendingLineageFigureID = nil
        return id
    }

    func navigateToHistory(at index: Int) {
        guard index < history.count else { return }
        let entry = history[index]
        history = Array(history.prefix(index + 1))
        switch entry.item {
        case .figures:
            if let id = entry.entityID { navigateToFigure(id, recordHistory: false) }
        case .places:
            if let id = entry.entityID { navigateToPlace(id, recordHistory: false) }
        case .events:
            if let id = entry.entityID { navigateToEvent(id, recordHistory: false) }
        case .things:
            if let id = entry.entityID { navigateToThing(id, recordHistory: false) }
        case .figureGroups:
            if let id = entry.entityID { navigateToGroup(id, recordHistory: false) }
            else { selection = .item(.figureGroups) }
        case .lineage: selection = .item(.lineage)
        case .query: selection = .item(.query)
        default: selection = .item(entry.item)
        }
    }

    func consumePendingFigureID() -> PersistentIdentifier? {
        let id = pendingFigureID
        pendingFigureID = nil
        return id
    }

    func consumePendingPlaceID() -> PersistentIdentifier? {
        let id = pendingPlaceID
        pendingPlaceID = nil
        return id
    }

    func consumePendingEventID() -> PersistentIdentifier? {
        let id = pendingEventID
        pendingEventID = nil
        return id
    }

    func consumePendingThingID() -> PersistentIdentifier? {
        let id = pendingThingID
        pendingThingID = nil
        return id
    }

    func pushHistory(id: PersistentIdentifier, name: String, item: NavigationItem) {
        if history.last?.name != name || history.last?.entityID != id {
            history.append(NavigationBreadcrumb(id: id, name: name, item: item))
            if history.count > 24 { history.removeFirst() }
        }
    }
}
