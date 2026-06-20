import Foundation
import SwiftData

@Model
package final class DataVersion {
    package var id: String
    package var name: String
    package var branch: String
    package var timestamp: Date
    package var filename: String
    package var parentId: String?

    package init(
        id: String = UUID().uuidString,
        name: String = "",
        branch: String = "main",
        timestamp: Date = Date(),
        filename: String = "",
        parentId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.branch = branch
        self.timestamp = timestamp
        self.filename = filename
        self.parentId = parentId
    }
}
