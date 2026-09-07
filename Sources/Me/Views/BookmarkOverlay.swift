import SwiftUI
import SwiftData

private struct BookmarkStoreKey: EnvironmentKey {
    static let defaultValue: BookmarkStore? = nil
}

extension EnvironmentValues {
    var bookmarkStore: BookmarkStore? {
        get { self[BookmarkStoreKey.self] }
        set { self[BookmarkStoreKey.self] = newValue }
    }
}

struct Bookmark: Identifiable, Equatable {
    let id: UUID
    let kind: NavigationItem
    let entityID: PersistentIdentifier
    let name: String

    var buttonIcon: String {
        switch kind {
        case .figures: return "person"
        default: return kind.icon
        }
    }
}

@Observable
final class BookmarkStore {
    private(set) var bookmarks: [Bookmark] = []
    let maxCount = 5

    var isFull: Bool { bookmarks.count >= maxCount }

    func bookmark(for entityID: PersistentIdentifier) -> Bookmark? {
        bookmarks.first { $0.entityID == entityID }
    }

    func isBookmarked(entityID: PersistentIdentifier) -> Bool {
        bookmark(for: entityID) != nil
    }

    @discardableResult
    func add(kind: NavigationItem, entityID: PersistentIdentifier, name: String) -> Bool {
        guard !isBookmarked(entityID: entityID), !isFull else { return false }
        bookmarks.append(Bookmark(id: UUID(), kind: kind, entityID: entityID, name: name))
        return true
    }

    func remove(id: UUID) {
        bookmarks.removeAll { $0.id == id }
    }

    func remove(entityID: PersistentIdentifier) {
        bookmarks.removeAll { $0.entityID == entityID }
    }
}
