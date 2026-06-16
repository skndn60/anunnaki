import SwiftUI

struct EventTypeLegend: View {
    let types: [EventType]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(types) { type in
                HStack(spacing: 4) {
                    Circle()
                        .fill(type.color)
                        .frame(width: 7, height: 7)
                    Text(type.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
