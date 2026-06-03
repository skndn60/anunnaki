import SwiftUI
import SwiftData

/// A compact lineage clip showing parents → figure → children.
/// Chips are clickable to navigate to other figures.
struct MiniLineageView: View {
    let figure: Figure
    let relationships: [Relationship]
    var onSelectFigure: ((Figure) -> Void)?

    private var parents: [Figure] {
        relationships
            .filter {
                ($0.relationshipType == .father || $0.relationshipType == .mother) &&
                $0.toFigure?.persistentModelID == figure.persistentModelID
            }
            .compactMap { $0.fromFigure }
    }

    private var children: [Figure] {
        relationships
            .filter {
                ($0.relationshipType == .father || $0.relationshipType == .mother) &&
                $0.fromFigure?.persistentModelID == figure.persistentModelID
            }
            .compactMap { $0.toFigure }
    }

    private var spouses: [Figure] {
        relationships
            .filter {
                ($0.relationshipType == .spouse || $0.relationshipType == .consort) &&
                ($0.fromFigure?.persistentModelID == figure.persistentModelID ||
                 $0.toFigure?.persistentModelID == figure.persistentModelID)
            }
            .compactMap {
                $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure
            }
    }

    var body: some View {
        if parents.isEmpty && children.isEmpty && spouses.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                Divider()
                    .padding(.bottom, 12)

                VStack(spacing: 12) {
                    // Parents row
                    if !parents.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(parents) { parent in
                                MiniChip(name: parent.name, symbol: parent.gender.symbol, color: chipColor(parent), isClickable: true) {
                                    onSelectFigure?(parent)
                                }
                            }
                        }

                        // Connector down
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 1, height: 12)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                    }

                    // Center: figure + spouse
                    HStack(spacing: 8) {
                        MiniChip(name: figure.name, symbol: figure.gender.symbol, color: chipColor(figure), isHighlighted: true)

                        if !spouses.isEmpty {
                            ForEach(spouses) { spouse in
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 7))
                                        .foregroundStyle(.pink.opacity(0.6))
                                    MiniChip(name: spouse.name, symbol: spouse.gender.symbol, color: chipColor(spouse), isClickable: true) {
                                        onSelectFigure?(spouse)
                                    }
                                }
                            }
                        }
                    }

                    // Connector down to children
                    if !children.isEmpty {
                        VStack(spacing: 0) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary.opacity(0.5))
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 1, height: 12)
                        }

                        // Children row
                        HStack(spacing: 8) {
                            ForEach(children) { child in
                                MiniChip(name: child.name, symbol: child.gender.symbol, color: chipColor(child), isClickable: true) {
                                    onSelectFigure?(child)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func chipColor(_ fig: Figure) -> Color { fig.figureType.color }
}

/// A tiny chip for the mini lineage view.
struct MiniChip: View {
    let name: String
    let symbol: String
    let color: Color
    var isHighlighted: Bool = false
    var isClickable: Bool = false
    var onTap: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 3) {
            Text(symbol)
                .font(.system(size: 9))
            Text(name)
                .font(.system(size: 10, weight: isHighlighted ? .bold : .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(isHighlighted ? 0.2 : isHovered ? 0.25 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isHighlighted ? color.opacity(0.6) : isHovered ? color.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
        .scaleEffect(isHovered && isClickable ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            if isClickable { isHovered = hovering }
        }
        .onTapGesture {
            if isClickable { onTap?() }
        }
        .help(isClickable ? "View \(name)" : "")
    }
}
