import SwiftUI
import SwiftData

/// Split-screen compare of two places. All structure lives in
/// `EntityCompareView`; this type only supplies place data + closures.
struct PlaceCompareView: View {
    @Query(sort: \Place.name) private var allPlaces: [Place]
    private let place: Place

    init(place: Place) {
        self.place = place
    }

    var body: some View {
        EntityCompareView(
            allItems: allPlaces,
            initialItem: place,
            title: "Compare Places",
            promptNoun: "place",
            searchPlaceholder: "Search places\u{2026}",
            name: { $0.name },
            filter: { items, query in
                searchPlaces(items, query: query).map(\.place)
            },
            detail: { PlaceDetailView(place: $0) },
            row: { place, query in
                HStack(spacing: 10) {
                    Image(systemName: place.placeType?.icon ?? "mappin")
                        .font(.caption)
                        .foregroundStyle(.teal)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayName(for: place, query: query))
                            .font(.body)
                        if !place.modernLocation.isEmpty {
                            Text(place.modernLocation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        )
    }

    private func displayName(for place: Place, query: String) -> String {
        if let alt = place.matchedAlternateName(for: query) {
            return "\(place.name) as \(alt)"
        }
        return place.name
    }
}
