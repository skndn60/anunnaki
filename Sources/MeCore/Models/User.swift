import Foundation
import SwiftData

@Model
package final class User {
    package var name: String
    package var passwordHash: String
    package var passwordSalt: String
    package var createdAt: Date
    package var lastLoginAt: Date?
    package var isActive: Bool?
    package var isAdmin: Bool?

    @Relationship(deleteRule: .nullify, inverse: \ActivityLogEntry.user)
    package var activityLogEntries: [ActivityLogEntry]?

    package init(name: String, passwordHash: String = "", passwordSalt: String = "", createdAt: Date = .now) {
        self.name = name
        self.passwordHash = passwordHash
        self.passwordSalt = passwordSalt
        self.createdAt = createdAt
    }

    package var isAccountActive: Bool {
        isActive ?? true
    }

    package var isAdministrator: Bool {
        isAdmin ?? false
    }
}
