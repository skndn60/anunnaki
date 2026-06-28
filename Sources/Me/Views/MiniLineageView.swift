import SwiftUI
import SwiftData

/// A compact lineage clip showing paternal grandparents → father/mother → figure,
/// with red "unknown" chips for missing parents.
struct MiniLineageView: View {
    let figure: Figure
    let relationships: [Relationship]
    var onSelectFigure: ((Figure) -> Void)?
    var onTapUnknownParent: ((String) -> Void)?
    var showGrandparents: Bool = true

    @Query private var allRelationships: [Relationship]
    @Environment(\.modelContext) private var modelContext

    private func parents(typeName: String, of figure: Figure, from pool: [Relationship]) -> (preferred: Figure?, alternatives: [Figure]) {
        let matching = pool.filter {
            $0.relationshipType?.name == typeName &&
            $0.toFigure?.persistentModelID == figure.persistentModelID
        }
        guard !matching.isEmpty else { return (nil, []) }
        let preferredRel = matching.first(where: { $0.isPreferred == true }) ?? matching.first!
        let alts = matching.filter { $0.isPreferred != true && $0.fromFigure?.persistentModelID != preferredRel.fromFigure?.persistentModelID }
        return (preferredRel.fromFigure, alts.compactMap { $0.fromFigure })
    }

    private var father: Figure? {
        parents(typeName: "Father", of: figure, from: relationships).preferred
    }

    private var fatherAlternatives: [Figure] {
        parents(typeName: "Father", of: figure, from: relationships).alternatives
    }

    private var mother: Figure? {
        parents(typeName: "Mother", of: figure, from: relationships).preferred
    }

    private var motherAlternatives: [Figure] {
        parents(typeName: "Mother", of: figure, from: relationships).alternatives
    }

    private var paternalGrandfather: Figure? {
        guard let father else { return nil }
        return parents(typeName: "Father", of: father, from: allRelationships).preferred
    }

    private var paternalGrandmother: Figure? {
        guard let father else { return nil }
        return parents(typeName: "Mother", of: father, from: allRelationships).preferred
    }

    private var hasGrandparents: Bool {
        paternalGrandfather != nil || paternalGrandmother != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 12)

            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 6) {
                        if showGrandparents, hasGrandparents {
                            HStack(spacing: 6) {
                                if let pgf = paternalGrandfather {
                                    MiniChip(name: pgf.name, symbol: pgf.gender.symbol, color: chipColor(pgf), isClickable: true) {
                                        onSelectFigure?(pgf)
                                    }
                                }
                                if let pgm = paternalGrandmother {
                                    MiniChip(name: pgm.name, symbol: pgm.gender.symbol, color: chipColor(pgm), isClickable: true) {
                                        onSelectFigure?(pgm)
                                    }
                                }
                            }
                            connectorPiece
                        }
                        if let father {
                            parentChip(name: father.name, symbol: father.gender.symbol, color: chipColor(father), alternatives: fatherAlternatives) {
                                onSelectFigure?(father)
                            }
                        } else {
                            unknownChip(typeName: "Father")
                        }
                    }

                    VStack(spacing: 6) {
                        if showGrandparents, hasGrandparents {
                            Color.clear.frame(height: chipRowHeight + connectorHeight)
                        }
                        if let mother {
                            parentChip(name: mother.name, symbol: mother.gender.symbol, color: chipColor(mother), alternatives: motherAlternatives) {
                                onSelectFigure?(mother)
                            }
                        } else {
                            unknownChip(typeName: "Mother")
                        }
                    }
                }

                connectorPiece

                MiniChip(name: figure.name, symbol: figure.gender.symbol, color: chipColor(figure), isHighlighted: true)
            }
            .padding(.vertical, 8)
        }
    }

    private func unknownChip(typeName: String) -> some View {
        Button(action: {
            onTapUnknownParent?(typeName)
        }) {
            MiniChip(name: "unknown \(typeName.lowercased())", symbol: "?", color: .red)
        }
        .buttonStyle(.plain)
    }

    private func parentChip(name: String, symbol: String, color: Color, alternatives: [Figure], onSelect: @escaping () -> Void) -> some View {
        ParentChipView(name: name, symbol: symbol, color: color, alternatives: alternatives, figureTypeColor: figure.figureType?.color ?? .gray, onSelect: onSelect, onSelectAlt: onSelectFigure)
    }

    private var chipRowHeight: CGFloat { 24 }
    private var connectorHeight: CGFloat { 18 }

    private var connectorPiece: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: 12)
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }

    private func chipColor(_ fig: Figure) -> Color { fig.figureType?.color ?? .gray }
}

// MARK: - Parent Chip (with alternative popover)

private struct ParentChipView: View {
    let name: String
    let symbol: String
    let color: Color
    let alternatives: [Figure]
    let figureTypeColor: Color
    let onSelect: () -> Void
    let onSelectAlt: ((Figure) -> Void)?

    @State private var showingPopover = false

    var body: some View {
        HStack(spacing: 2) {
            MiniChip(name: name, symbol: symbol, color: color, isClickable: true, onTap: onSelect)
            if !alternatives.isEmpty {
                Button(action: { showingPopover = true }) {
                    Text("+\(alternatives.count)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .help("\(alternatives.count) alternative\(alternatives.count == 1 ? "" : "s")")
                .popover(isPresented: $showingPopover) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alternatives")
                            .font(.caption.bold())
                            .padding(.bottom, 2)
                        ForEach(alternatives) { fig in
                            Button(action: {
                                showingPopover = false
                                onSelectAlt?(fig)
                            }) {
                                HStack(spacing: 4) {
                                    Text(fig.gender.symbol)
                                        .font(.caption)
                                    Text(fig.name)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(figureTypeColor.opacity(0.08))
                            .cornerRadius(4)
                        }
                    }
                    .padding(10)
                    .frame(minWidth: 120, minHeight: 40)
                }
            }
        }
    }
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

    private var chipContent: some View {
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
    }

    var body: some View {
        if isClickable {
            chipContent
                .onTapGesture {
                    print("[MiniChip] tap on \(name)")
                    onTap?()
                }
                .help("View \(name)")
        } else {
            chipContent
        }
    }
}
