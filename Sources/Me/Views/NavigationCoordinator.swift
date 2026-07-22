import SwiftUI
import SwiftData

struct NavigationBreadcrumb: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let item: NavigationItem
}

@Observable
final class NavigationCoordinator {
    var selectedItem: NavigationItem? = .dashboard
    var pendingFigureID: PersistentIdentifier?
    var pendingPlaceID: PersistentIdentifier?
    var pendingEventID: PersistentIdentifier?
    var pendingThingID: PersistentIdentifier?
    var pendingLineageFigureID: PersistentIdentifier?
    var history: [NavigationBreadcrumb] = []

    func navigateToFigure(_ id: PersistentIdentifier, name: String = "", recordHistory: Bool = true) {
        if recordHistory { pushHistory(id: id, name: name, item: .figures) }
        pendingFigureID = id
        selectedItem = .figures
    }

    func navigateToPlace(_ id: PersistentIdentifier, name: String = "", recordHistory: Bool = true) {
        if recordHistory { pushHistory(id: id, name: name, item: .places) }
        pendingPlaceID = id
        selectedItem = .places
    }

    func navigateToEvent(_ id: PersistentIdentifier, name: String = "", recordHistory: Bool = true) {
        if recordHistory { pushHistory(id: id, name: name, item: .events) }
        pendingEventID = id
        selectedItem = .events
    }

    func navigateToThing(_ id: PersistentIdentifier, name: String = "", recordHistory: Bool = true) {
        if recordHistory { pushHistory(id: id, name: name, item: .things) }
        pendingThingID = id
        selectedItem = .things
    }

    func navigateToLineageFigure(_ id: PersistentIdentifier) {
        pendingLineageFigureID = id
        selectedItem = .lineage
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
        case .figures: navigateToFigure(entry.id, recordHistory: false)
        case .places: navigateToPlace(entry.id, recordHistory: false)
        case .events: navigateToEvent(entry.id, recordHistory: false)
        case .things: navigateToThing(entry.id, recordHistory: false)
        case .lineage: navigateToLineageFigure(entry.id)
        default: break
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
        if history.last?.id != id {
            history.append(NavigationBreadcrumb(id: id, name: name, item: item))
            if history.count > 24 { history.removeFirst() }
        }
    }
}
