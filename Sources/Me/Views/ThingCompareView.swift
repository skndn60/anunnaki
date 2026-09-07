import SwiftUI
import SwiftData

/// Split-screen compare of two things. All structure lives in
/// `EntityCompareView`; this type only supplies thing data + closures.
struct ThingCompareView: View {
    @Query(sort: \Thing.name) private var allThings: [Thing]
    private let thing: Thing

    init(thing: Thing) {
        self.thing = thing
    }

    var body: some View {
        EntityCompareView(
            allItems: allThings,
            initialItem: thing,
            title: "Compare Things",
            promptNoun: "thing",
            searchPlaceholder: "Search things\u{2026}",
            name: { $0.name },
            filter: searchThings,
            detail: { ThingDetailView(thing: $0) },
            row: { thing, _ in
                HStack(spacing: 10) {
                    Image(systemName: "cube.box")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(thing.name)
                            .font(.body)
                        if !thing.thingDescription.isEmpty {
                            Text(thing.thingDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }
        )
    }
}
