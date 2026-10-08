import Foundation
import SwiftData

extension Migration {
    package static func fixFoundingOfEriduEra(context: ModelContext) {
        let targetKey = NameDuplicateCheck.normalizedKey("Founding of Eridu")
        let staleEraKey = NameDuplicateCheck.normalizedKey("Anunnaki on Earth")

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        guard let event = events.first(where: { NameDuplicateCheck.normalizedKey($0.name) == targetKey }) else { return }

        let carriesStaleEra = NameDuplicateCheck.normalizedKey(event.date.era) == staleEraKey
            || NameDuplicateCheck.normalizedKey(event.era) == staleEraKey
        guard carriesStaleEra else { return }

        guard let year = event.date.startYear ?? event.date.endYear else { return }

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        guard let staleEra = eras.first(where: { NameDuplicateCheck.normalizedKey($0.name) == staleEraKey }),
              let staleBand = EventChronology.eraRange(of: staleEra),
              !staleBand.contains(year) else { return }

        let corrected = EventChronology.derivedEra(of: event, from: eras)
        guard !corrected.isEmpty,
              NameDuplicateCheck.normalizedKey(corrected) != staleEraKey else { return }

        var changed = false
        if NameDuplicateCheck.normalizedKey(event.date.era) == staleEraKey {
            event.date.era = corrected
            changed = true
        }
        if NameDuplicateCheck.normalizedKey(event.era) == staleEraKey {
            event.era = corrected
            changed = true
        }
        if changed { Commit.save(context, "fixFoundingOfEriduEra") }
    }
}
