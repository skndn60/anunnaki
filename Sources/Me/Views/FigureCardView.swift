import SwiftUI
import SwiftData

struct FigureCardView: View {
    let figure: Figure
    var isSelected: Bool = false
    var alternatives: [Figure] = []
    var onSelectAlt: ((Figure) -> Void)?

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(figure.figureType?.color ?? .gray)
                    .frame(width: 6, height: 6)
                Text(figure.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            Text(figure.figureType?.name ?? "Unknown")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 100, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(figure.figureType?.color.opacity(0.12) ?? .gray.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : figure.figureType?.color.opacity(0.3) ?? .gray.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 2) {
                if !alternatives.isEmpty {
                    AltSelector(
                        title: "Alternatives",
                        items: alternatives,
                        minWidth: 180,
                        helpText: "\(alternatives.count) alternative\(alternatives.count == 1 ? "" : "s")",
                        onSelect: { alt in onSelectAlt?(alt) }
                    ) { alt in
                        HStack(spacing: 6) {
                            Circle().fill(alt.figureType?.color ?? .gray).frame(width: 6, height: 6)
                            Text(alt.name)
                                .font(.caption)
                        }
                        .background(alt.figureType?.color.opacity(0.08) ?? .gray.opacity(0.08))
                        .cornerRadius(4)
                    }
                }
                Button(action: { openWindow(id: "figure-detail", value: figure.persistentModelID) }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .offset(x: 3, y: -3)
        }
        .mugshotHover(figure, size: 140, arrowEdge: .bottom)
    }
}