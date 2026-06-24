import Foundation
import SwiftData

extension ModelContext {
    package func fetchAll<T: PersistentModel>() -> [T] {
        (try? fetch(FetchDescriptor<T>())) ?? []
    }
}
