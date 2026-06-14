import SwiftData

extension ModelContext {
    func fetchAll<T: PersistentModel>() -> [T] {
        (try? fetch(FetchDescriptor<T>())) ?? []
    }
}
