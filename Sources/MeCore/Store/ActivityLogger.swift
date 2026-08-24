import Foundation
import SwiftData

package struct ActivityLogger {
    package static let unknownUserName = "(unknown)"

    package static func record(action: ActivityAction, entityType: String, entityName: String, details: String = "", context: ModelContext, session: UserSession?) {
        let user = session?.currentUser
        let entry = ActivityLogEntry(
            userName: user?.name ?? unknownUserName,
            action: action,
            entityType: entityType,
            entityName: entityName,
            details: details
        )
        context.insert(entry)
        if let user {
            user.activityLogEntries?.append(entry)
        }
        try? context.save()
    }
}
