import Foundation
import SwiftData

extension Migration {
    package static func ensurePunishmentEventTypeAndBindings(context: ModelContext) {
        let punishmentKey = NameDuplicateCheck.normalizedKey("Punishment")
        let eventTypes = (try? context.fetch(FetchDescriptor<EventType>())) ?? []

        let punishment: EventType
        if let existing = eventTypes.first(where: { NameDuplicateCheck.normalizedKey($0.name) == punishmentKey }) {
            punishment = existing
        } else {
            let created = EventType(name: "Punishment", icon: "lock.fill", colorHex: "8E44AD")
            context.insert(created)
            punishment = created
        }

        let bindingKeys = Set([
            NameDuplicateCheck.normalizedKey("The Binding of Azazel"),
            NameDuplicateCheck.normalizedKey("The Binding of the Watchers")
        ])
        let battleKey = NameDuplicateCheck.normalizedKey("Battle")

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        for event in events where bindingKeys.contains(NameDuplicateCheck.normalizedKey(event.name)) {
            guard let current = event.eventType,
                  NameDuplicateCheck.normalizedKey(current.name) == battleKey else { continue }
            current.events.removeAll { $0 == event }
            punishment.events.append(event)
        }

        Commit.save(context, "ensurePunishmentEventTypeAndBindings")
    }
}
