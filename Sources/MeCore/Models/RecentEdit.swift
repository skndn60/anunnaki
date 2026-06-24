import Foundation

package struct RecentEdit: Codable, Hashable {
    package var entityType: String
    package var entityName: String
    package var timestamp: Date
    package var id: UUID

    package init(entityType: String, entityName: String, timestamp: Date) {
        self.entityType = entityType
        self.entityName = entityName
        self.timestamp = timestamp
        self.id = UUID()
    }
}
