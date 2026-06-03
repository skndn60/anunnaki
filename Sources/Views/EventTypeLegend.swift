import SwiftUI

/// A compact legend showing what the colors/icons mean for event types.
struct EventTypeLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(Event.EventType.allCases, id: \.self) { type in
                HStack(spacing: 3) {
                    Circle()
                        .fill(type.color)
                        .frame(width: 6, height: 6)
                    Text(type.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
