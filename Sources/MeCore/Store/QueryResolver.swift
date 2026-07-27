import Foundation
import SwiftData

package protocol QueryResolver {
    func resolve(query: String, modelContext: ModelContext) -> QueryResult?
}
