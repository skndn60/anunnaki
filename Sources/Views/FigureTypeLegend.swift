import SwiftUI

/// A compact legend showing what the colored dots mean for figure types.
struct FigureTypeLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(Figure.FigureType.allCases, id: \.self) { type in
                HStack(spacing: 4) {
                    Circle()
                        .fill(type.color)
                        .frame(width: 7, height: 7)
                    Text(type.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
