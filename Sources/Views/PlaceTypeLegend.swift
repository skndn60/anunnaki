import SwiftUI

/// A compact legend showing what the icons mean for place types.
struct PlaceTypeLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Place.PlaceType.allCases, id: \.self) { type in
                HStack(spacing: 4) {
                    Image(systemName: type.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(.teal)
                    Text(type.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
