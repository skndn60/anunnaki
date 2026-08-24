import Foundation
import SwiftData

package enum ActivityAction: String, CaseIterable, Codable {
    case created
    case updated
    case deleted

    package var displayLabel: String {
        switch self {
        case .created: return "Created"
        case .updated: return "Updated"
        case .deleted: return "Deleted"
        }
    }
}

@Model
package final class ActivityLogEntry {
    package var userName: String
    package var action: String
    package var entityType: String
    package var linkedEntityName: String
    package var details: String
    package var timestamp: Date

    package var user: User?

    package init(userName: String, action: ActivityAction, entityType: String, entityName: String, details: String = "", timestamp: Date = .now) {
        self.userName = userName
        self.action = action.rawValue
        self.entityType = entityType
        self.linkedEntityName = entityName
        self.details = details
        self.timestamp = timestamp
    }

    package var actionType: ActivityAction? {
        ActivityAction(rawValue: action)
    }

    package var displayUserName: String {
        user?.name ?? (userName.isEmpty ? ActivityLogger.unknownUserName : userName)
    }
}
