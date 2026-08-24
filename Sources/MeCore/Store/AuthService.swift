import Foundation
import CryptoKit
import SwiftData

package enum AuthServiceError: Error, Equatable {
    case nameTaken
    case nameTooShort
    case passwordTooShort
    case invalidCredentials
    case accountDeactivated
    case lastActiveAdmin
    case cannotDeactivateSelf
    case notAuthorized
}

package struct AuthService {
    package static let minNameLength = 2
    package static let minPasswordLength = 4

    package static func register(name: String, password: String, context: ModelContext, isAdmin: Bool = false) throws -> User {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard trimmedName.count >= minNameLength else { throw AuthServiceError.nameTooShort }
        guard password.count >= minPasswordLength else { throw AuthServiceError.passwordTooShort }

        if findUser(named: trimmedName, context: context) != nil {
            throw AuthServiceError.nameTaken
        }

        let salt = Self.generateSalt()
        let hash = Self.hash(password, salt: salt)
        let user = User(name: trimmedName, passwordHash: hash, passwordSalt: salt)
        user.isAdmin = isAdmin
        context.insert(user)
        try? context.save()
        return user
    }

    package static func createUser(name: String, password: String, isAdmin: Bool, actor: User?, context: ModelContext) throws -> User {
        if hasAnyUser(context: context) {
            guard actor?.isAdministrator ?? false else { throw AuthServiceError.notAuthorized }
        }
        return try register(name: name, password: password, context: context, isAdmin: isAdmin)
    }

    package static func login(name: String, password: String, context: ModelContext) throws -> User {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard let user = findUser(named: trimmedName, context: context) else {
            throw AuthServiceError.invalidCredentials
        }
        guard user.passwordHash == Self.hash(password, salt: user.passwordSalt) else {
            throw AuthServiceError.invalidCredentials
        }
        guard user.isAccountActive else {
            throw AuthServiceError.accountDeactivated
        }
        user.lastLoginAt = .now
        try? context.save()
        return user
    }

    package static func hasAnyUser(context: ModelContext) -> Bool {
        ((try? context.fetchCount(FetchDescriptor<User>())) ?? 0) > 0
    }

    package static func deactivate(_ user: User, actor: User?, context: ModelContext) throws {
        guard actor?.isAdministrator ?? false else { throw AuthServiceError.notAuthorized }
        if let actor, actor.persistentModelID == user.persistentModelID {
            throw AuthServiceError.cannotDeactivateSelf
        }
        if user.isAccountActive && activeUsers(context: context).count <= 1 {
            throw AuthServiceError.lastActiveAdmin
        }
        user.isActive = false
        try? context.save()
    }

    package static func reactivate(_ user: User, actor: User?, context: ModelContext) throws {
        guard actor?.isAdministrator ?? false else { throw AuthServiceError.notAuthorized }
        user.isActive = true
        try? context.save()
    }

    package static func allUsers(context: ModelContext) -> [User] {
        ((try? context.fetch(FetchDescriptor<User>(sortBy: [SortDescriptor(\.name)]))) ?? [])
    }

    package static func activeUsers(context: ModelContext) -> [User] {
        allUsers(context: context).filter(\.isAccountActive)
    }

    private static func findUser(named name: String, context: ModelContext) -> User? {
        let all = (try? context.fetch(FetchDescriptor<User>())) ?? []
        return all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private static func generateSalt() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max) }
        return Data(bytes).base64EncodedString()
    }

    private static func hash(_ password: String, salt: String) -> String {
        let input = Data("\(salt):\(password)".utf8)
        return SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    }
}
