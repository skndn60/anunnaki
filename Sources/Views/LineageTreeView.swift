import SwiftUI
import SwiftData

/// Displays the family lineage as a visual tree.
struct LineageTreeView: View {
    @Query private var figures: [Figure]
    @Query private var relationships: [Relationship]
    @State private var selectedFigure: Figure?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Lineage Tree")
                    .font(.title2.bold())
                Spacer()
                FigureTypeLegend()
                if let figure = selectedFigure {
                    Text(figure.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            if figures.isEmpty {
                emptyState
            } else {
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 50) {
                        ForEach(rootFigures) { root in
                            TreeBranch(
                                figure: root,
                                allRelationships: relationships,
                                selectedFigure: $selectedFigure,
                                visited: []
                            )
                        }
                    }
                    .padding(40)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tree")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No figures yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add figures and relationships using the input screens to build the lineage tree.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
    }

    private var rootFigures: [Figure] {
        let childIds = Set(
            relationships
                .filter { $0.relationshipType == .father || $0.relationshipType == .mother }
                .compactMap { $0.toFigure?.persistentModelID }
        )
        let roots = figures.filter { !childIds.contains($0.persistentModelID) }
        return roots.isEmpty ? figures : roots
    }
}

// MARK: - Tree Branch

struct TreeBranch: View {
    let figure: Figure
    let allRelationships: [Relationship]
    @Binding var selectedFigure: Figure?
    var visited: Set<PersistentIdentifier>

    private var kids: [Figure] {
        allRelationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
            .filter { !visited.contains($0.persistentModelID) }
    }

    var body: some View {
        let children = kids
        let nextVisited = visited.union([figure.persistentModelID])

        VStack(spacing: 0) {
            // The parent card
            FigureCardView(figure: figure, isSelected: selectedFigure?.persistentModelID == figure.persistentModelID)
                .onTapGesture { selectedFigure = figure }

            if !children.isEmpty {
                // Vertical line down from parent card
                ConnectorLine()
                    .frame(width: 1.5, height: 20)

                // The children row with built-in horizontal connector
                TreeChildrenRow(children: children, allRelationships: allRelationships, selectedFigure: $selectedFigure, visited: nextVisited)
            }
        }
    }
}

// MARK: - Children Row with Connectors

struct TreeChildrenRow: View {
    let children: [Figure]
    let allRelationships: [Relationship]
    @Binding var selectedFigure: Figure?
    var visited: Set<PersistentIdentifier>

    var body: some View {
        if children.count == 1 {
            // Single child — just a vertical line and the child
            VStack(spacing: 0) {
                TreeBranch(
                    figure: children[0],
                    allRelationships: allRelationships,
                    selectedFigure: $selectedFigure,
                    visited: visited
                )
            }
        } else {
            // Multiple children — horizontal bar connecting them
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    VStack(spacing: 0) {
                        // Each child's connector piece:
                        // First child: right half of horizontal + vertical drop
                        // Last child: left half of horizontal + vertical drop
                        // Middle children: full horizontal + vertical drop
                        HStack(spacing: 0) {
                            // Left half of horizontal line
                            Rectangle()
                                .fill(index == 0 ? Color.clear : Color.secondary.opacity(0.45))
                                .frame(height: 1.5)
                            // Right half of horizontal line
                            Rectangle()
                                .fill(index == children.count - 1 ? Color.clear : Color.secondary.opacity(0.45))
                                .frame(height: 1.5)
                        }
                        .frame(height: 1.5)

                        // Vertical drop from horizontal line to child
                        ConnectorLine()
                            .frame(width: 1.5, height: 18)

                        // The child branch
                        TreeBranch(
                            figure: child,
                            allRelationships: allRelationships,
                            selectedFigure: $selectedFigure,
                            visited: visited
                        )
                    }
                    .frame(minWidth: 80)
                }
            }
        }
    }
}

// MARK: - Connector Line

struct ConnectorLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.45))
    }
}

// MARK: - Figure Card

struct FigureCardView: View {
    let figure: Figure
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(figure.name)
                .font(.headline)
                .lineLimit(1)
            Text(figure.figureType.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !figure.domain.isEmpty {
                Text(figure.domain)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(figure.figureType.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : figure.figureType.color.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
}
