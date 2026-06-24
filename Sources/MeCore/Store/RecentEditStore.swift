import Foundation

package enum RecentEditStore {
    private static let key = "RecentEditStore_items"
    private static let maxCount = 10

    package static var items: [RecentEdit] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([RecentEdit].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    package static func trackEdit(entityType: String, entityName: String) {
        var all = items
        let edit = RecentEdit(entityType: entityType, entityName: entityName, timestamp: Date())
        all.insert(edit, at: 0)
        if all.count > maxCount {
            all = Array(all.prefix(maxCount))
        }
        items = all
    }
}
