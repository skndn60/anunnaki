import SwiftUI

enum ListSortSlot: String {
    case figure
    case place
    case event

    var storageKey: String {
        "\(rawValue)SortOrder"
    }

    var defaultRawValue: String {
        switch self {
        case .figure, .place: "Name"
        case .event: "Date"
        }
    }
}

@propertyWrapper
struct DefaultSortOrder<Value: RawRepresentable & CaseIterable>: DynamicProperty where Value.RawValue == String {
    @AppStorage private var storedValue: String
    private let defaultValue: Value

    init(_ slot: ListSortSlot) {
        let fallback = Value(rawValue: slot.defaultRawValue) ?? Value.allCases.first!
        self.defaultValue = fallback
        _storedValue = AppStorage(wrappedValue: fallback.rawValue, slot.storageKey)
    }

    var wrappedValue: Value {
        get { Value(rawValue: storedValue) ?? defaultValue }
        nonmutating set { storedValue = newValue.rawValue }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
