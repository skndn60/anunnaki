import SwiftUI
import SwiftData

/// Split-screen compare of two events. All structure lives in
/// `EntityCompareView`; this type only supplies event data + closures.
struct EventCompareView: View {
    @Query(sort: \Event.name) private var allEvents: [Event]
    private let event: Event

    init(event: Event) {
        self.event = event
    }

    var body: some View {
        EntityCompareView(
            allItems: allEvents,
            initialItem: event,
            title: "Compare Events",
            promptNoun: "event",
            searchPlaceholder: "Search events\u{2026}",
            name: { $0.name },
            filter: searchEvents,
            detail: { EventDetailView(event: $0) },
            row: { event, _ in
                HStack(spacing: 10) {
                    Image(systemName: event.eventType?.icon ?? "bolt")
                        .font(.caption)
                        .foregroundStyle(event.eventType?.color ?? .gray)
                        .frame(width: 16)
                    Text(event.name)
                        .font(.body)
                    Spacer()
                    Text(event.date.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        )
    }
}
