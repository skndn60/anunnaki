import Foundation
import SwiftData

/// A relationship between two events.
/// E.g. Death of Enkidu motivated Gilgamesh Seeks Immortality.
@Model
final class EventEventAssociation {
    var fromEvent: Event?
    var toEvent: Event?
    var role: Role
    var source: String

    enum Role: String, Codable, CaseIterable, Hashable {
        case caused = "Caused"
        case motivated = "Motivated"
        case precedes = "Precedes"
        case follows = "Follows"
        case relatedTo = "Related To"
        case contradicts = "Contradicts"
        case parallels = "Parallels"
    }

    init(
        fromEvent: Event? = nil,
        toEvent: Event? = nil,
        role: Role = .caused,
        source: String = ""
    ) {
        self.fromEvent = fromEvent
        self.toEvent = toEvent
        self.role = role
        self.source = source
    }
}
