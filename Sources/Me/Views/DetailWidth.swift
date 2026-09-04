import SwiftUI

enum DetailWidthSlot: String, CaseIterable {
    case dictionary
    case era
    case event
    case figure
    case figureGroup
    case missionControl
    case place
    case skl
    case source
    case thing

    var key: String {
        switch self {
        case .dictionary: "dictionaryDetailWidth"
        case .era: "eraDetailWidth"
        case .event: "eventDetailWidth"
        case .figure: "figureDetailWidth"
        case .figureGroup: "figureGroupDetailWidth"
        case .missionControl: "missionControlDetailWidth"
        case .place: "placeDetailWidth"
        case .skl: "sklDetailWidth"
        case .source: "sourceDetailWidth"
        case .thing: "thingDetailWidth"
        }
    }

    var defaultValue: Double {
        switch self {
        case .dictionary: 380
        case .figure: 390
        case .missionControl: 480
        default: 320
        }
    }

    var defaultRange: ClosedRange<Double> {
        200...800
    }
}

/// Backs the detail-panel width for a list view with a single persisted
/// `@AppStorage` key + default originating from `DetailWidthSlot`, so every
/// `<entity>DetailWidth` declaration and its default live in one place.
/// Exposes a read/write `wrappedValue` and a `projectedValue` Binding for
/// `ResizableDivider(width:)`.
@propertyWrapper
struct DetailWidth {
    private let slot: DetailWidthSlot
    @AppStorage private var storedValue: Double

    init(_ slot: DetailWidthSlot) {
        self.slot = slot
        _storedValue = AppStorage(wrappedValue: slot.defaultValue, slot.key)
    }

    var wrappedValue: Double {
        get { storedValue }
        nonmutating set { storedValue = newValue }
    }

    var projectedValue: Binding<Double> {
        Binding(
            get: { storedValue },
            set: { storedValue = $0 }
        )
    }
}
