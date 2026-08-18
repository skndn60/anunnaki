import SwiftUI
import SwiftData

struct FigureCardView: View {
    let figure: Figure
    var isSelected: Bool = false
    var alternatives: [Figure] = []
    var onSelectAlt: ((Figure) -> Void)?
    var coordinateSpace: String = "tree"
    var onPositionChange: ((PersistentIdentifier, CGRect) -> Void)?

    @State private var showingAlts = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named(coordinateSpace))
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
                        Button(action: { showingAlts = true }) {
                            Text("+\(alternatives.count)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.accentColor))
                        }
                        .buttonStyle(.plain)
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
            .onAppear { onPositionChange?(figure.persistentModelID, frame) }
            .onChange(of: frame) { _, newFrame in
                onPositionChange?(figure.persistentModelID, newFrame)
            }
        }
        .frame(width: 100, height: 44)
        .popover(isPresented: $showingAlts) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Alternatives")
                    .font(.caption.bold())
                ForEach(alternatives) { alt in
                    Button(action: {
                        showingAlts = false
                        onSelectAlt?(alt)
                    }) {
                        HStack(spacing: 6) {
                            Circle().fill(alt.figureType?.color ?? .gray).frame(width: 6, height: 6)
                            Text(alt.name)
                                .font(.caption)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(alt.figureType?.color.opacity(0.08) ?? .gray.opacity(0.08))
                    .cornerRadius(4)
                }
            }
            .padding(8)
            .frame(width: 180)
        }
        .mugshotHover(figure, size: 140, arrowEdge: .bottom)
    }
}
