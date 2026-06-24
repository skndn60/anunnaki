import SwiftUI
import SwiftData

/// Content view for the lineage explorer secondary window.
/// Receives a figure's PersistentIdentifier via openWindow(value:).
struct LineageExplorerWindow: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var relationships: [Relationship]
    let figureID: PersistentIdentifier?

    @State private var figure: Figure?

    var body: some View {
        Group {
            if let figure {
                FigureLineageExplorerContent(
                    initialFigure: figure,
                    relationships: relationships
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tree")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Figure not found")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let figureID else { return }
            let fetch = FetchDescriptor<Figure>(
                predicate: #Predicate { $0.persistentModelID == figureID }
            )
            figure = try? modelContext.fetch(fetch).first
        }
    }
}

/// Standalone lineage tree content, extracted from FigureLineageExplorer
/// for use in a secondary window.
private struct FigureLineageExplorerContent: View {
    let initialFigure: Figure
    let relationships: [Relationship]

    @State private var focusFigure: Figure
    @State private var showGrandparents = false
    @State private var showGrandchildren = false

    init(initialFigure: Figure, relationships: [Relationship]) {
        self.initialFigure = initialFigure
        self.relationships = relationships
        self._focusFigure = State(initialValue: initialFigure)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView([.horizontal, .vertical]) {
                treeContent
                    .padding(40)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var header: some View {
        let fig = focusFigure
        return HStack(spacing: 8) {
            Circle()
                .fill(fig.figureType?.color.opacity(0.15) ?? .gray.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: fig.figureType?.icon ?? "questionmark")
                        .font(.system(size: 11))
                        .foregroundStyle(fig.figureType?.color ?? .gray)
                )
            Text("Lineage: ")
                .font(.headline)
                .foregroundStyle(.secondary)
                + Text(fig.name)
                .font(.headline.bold())
            Spacer()
            Text(fig.title)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding()
    }

    private var treeContent: some View {
        VStack(spacing: 0) {
            if showGrandparents {
                generationRow(grandparents, label: "Grandparents", alts: grandparentAlts, onSelectAlt: { recenter(on: $0) })
                connector()
            }

            if !parents.isEmpty {
                generationRow(parents, label: "Parents", alts: parentAlts, onSelectAlt: { recenter(on: $0) })
                if !grandparents.isEmpty && !showGrandparents {
                    expandButton("Show Grandparents") { showGrandparents = true }
                }
                connector()
            } else if !grandparents.isEmpty && !showGrandparents {
                expandButton("Show Grandparents") { showGrandparents = true }
            }

            focusRow

            if !children.isEmpty {
                connector()
                generationRow(children, label: "Children", alts: childAlts, onSelectAlt: { recenter(on: $0) })
                if !grandchildren.isEmpty && !showGrandchildren {
                    expandButton("Show Grandchildren") { showGrandchildren = true }
                }
            } else if !grandchildren.isEmpty && !showGrandchildren {
                expandButton("Show Grandchildren") { showGrandchildren = true }
            }

            if showGrandchildren {
                connector()
                generationRow(grandchildren, label: "Grandchildren", alts: grandchildAlts, onSelectAlt: { recenter(on: $0) })
            }
        }
    }

    private var focusRow: some View {
        let fig = focusFigure
        let siblings = siblingsExcludingCoParents
        let otherParents = coParents
        return HStack(spacing: 8) {
            if !spousesLeft.isEmpty {
                ForEach(spousesLeft) { spouse in
                    figureChip(spouse)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.pink.opacity(0.4))
                }
            }
            if !consortsLeft.isEmpty {
                ForEach(consortsLeft) { consort in
                    consortChip(consort)
                    Image(systemName: "heart.circle")
                        .font(.system(size: 7))
                        .foregroundStyle(.purple.opacity(0.5))
                }
            }

            if !siblings.isEmpty {
                VStack(spacing: 2) {
                    Text("Siblings")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    HStack(spacing: 6) {
                        ForEach(siblings) { sibling in
                            FigureCardView(figure: sibling)
                                .onTapGesture { recenter(on: sibling) }
                        }
                    }
                }
            }

            if !otherParents.isEmpty {
                VStack(spacing: 2) {
                    Text("Parent")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    HStack(spacing: 6) {
                        ForEach(otherParents) { parent in
                            FigureCardView(figure: parent)
                                .onTapGesture { recenter(on: parent) }
                        }
                    }
                }
            }

            FigureCardView(figure: fig, isSelected: true)

            if !consortsRight.isEmpty {
                ForEach(consortsRight) { consort in
                    Image(systemName: "heart.circle")
                        .font(.system(size: 7))
                        .foregroundStyle(.purple.opacity(0.5))
                    consortChip(consort)
                }
            }
            if !spousesRight.isEmpty {
                ForEach(spousesRight) { spouse in
                    Image(systemName: "heart.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.pink.opacity(0.4))
                    figureChip(spouse)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(fig.figureType?.color.opacity(0.06) ?? .gray.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(fig.figureType?.color.opacity(0.15) ?? .gray.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func generationRow(_ list: [Figure], label: String? = nil, alts: [PersistentIdentifier: [Figure]] = [:], onSelectAlt: ((Figure) -> Void)? = nil) -> some View {
        VStack(spacing: 6) {
            if let label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
            }
            HStack(spacing: 10) {
                ForEach(list) { fig in
                    FigureCardView(figure: fig, isSelected: false, alternatives: alts[fig.persistentModelID] ?? [], onSelectAlt: onSelectAlt)
                        .onTapGesture { recenter(on: fig) }
                }
            }
        }
    }

    private func connector() -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 1.5, height: 18)
            Circle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 5, height: 5)
        }
    }

    private func expandButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 9))
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func figureChip(_ figure: Figure) -> some View {
        MiniChip(name: figure.name, symbol: figure.gender.symbol, color: figure.figureType?.color ?? .gray, isClickable: true) {
            recenter(on: figure)
        }
    }

    private func consortChip(_ figure: Figure) -> some View {
        HStack(spacing: 3) {
            Text(figure.gender.symbol)
                .font(.system(size: 8))
            Text(figure.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
            Text("consort")
                .font(.system(size: 7))
                .foregroundStyle(.purple)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.purple.opacity(0.12))
                )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(figure.figureType?.color.opacity(0.08) ?? .gray.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(figure.figureType?.color.opacity(0.2) ?? .gray.opacity(0.2), lineWidth: 0.5)
                )
        )
        .onTapGesture { recenter(on: figure) }
    }

    private func recenter(on figure: Figure) {
        withAnimation(.easeInOut(duration: 0.2)) {
            focusFigure = figure
            showGrandparents = false
            showGrandchildren = false
        }
    }

    // MARK: - Relationship Queries

    /// Returns at most one figure per relationship type, plus a dictionary of alternatives.
    private func resolveGeneration(_ rels: [Relationship]) -> (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        let grouped = Dictionary(grouping: rels) { $0.relationshipType?.name ?? "" }
        var figures: [Figure] = []
        var alts: [PersistentIdentifier: [Figure]] = [:]
        for (_, group) in grouped {
            guard let chosen = group.first(where: { $0.isPreferred == true }) ?? group.first,
                  let chosenFig = chosen.fromFigure else { continue }
            figures.append(chosenFig)
            if group.count > 1 {
                alts[chosenFig.persistentModelID] = group.compactMap { $0.fromFigure }.filter { $0.persistentModelID != chosenFig.persistentModelID }
            }
        }
        return (figures, alts)
    }

    private var resolvedParents: (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        resolveGeneration(relationships.filter {
            $0.relationshipType?.category == "parent" && $0.toFigure?.persistentModelID == focusFigure.persistentModelID
        })
    }

    private var parents: [Figure] { resolvedParents.figures }
    private var parentAlts: [PersistentIdentifier: [Figure]] { resolvedParents.alts }

    private var resolvedChildren: (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        resolveGeneration(relationships.filter {
            $0.relationshipType?.category == "parent" && $0.fromFigure?.persistentModelID == focusFigure.persistentModelID
        })
    }

    private var children: [Figure] { resolvedChildren.figures }
    private var childAlts: [PersistentIdentifier: [Figure]] { resolvedChildren.alts }

    private var spousesLeft: [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Spouse" && $0.toFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private var spousesRight: [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Spouse" && $0.fromFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private var consortsLeft: [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Consort" && $0.toFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private var consortsRight: [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Consort" && $0.fromFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private var resolvedGrandparents: (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        let parentIDs = Set(parents.map(\.persistentModelID))
        return resolveGeneration(relationships.filter {
            guard let toID = $0.toFigure?.persistentModelID else { return false }
            return $0.relationshipType?.category == "parent" && parentIDs.contains(toID)
        })
    }

    private var grandparents: [Figure] { resolvedGrandparents.figures }
    private var grandparentAlts: [PersistentIdentifier: [Figure]] { resolvedGrandparents.alts }

    private var resolvedGrandchildren: (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        let childIDs = Set(children.map(\.persistentModelID))
        return resolveGeneration(relationships.filter {
            guard let fromID = $0.fromFigure?.persistentModelID else { return false }
            return $0.relationshipType?.category == "parent" && childIDs.contains(fromID)
        })
    }

    private var grandchildren: [Figure] { resolvedGrandchildren.figures }
    private var grandchildAlts: [PersistentIdentifier: [Figure]] { resolvedGrandchildren.alts }

    private var computeSiblings: [Figure] {
        let parentIDs = Set(parents.map(\.persistentModelID))
        guard !parentIDs.isEmpty else { return [] }
        return relationships
            .filter {
                guard let fromID = $0.fromFigure?.persistentModelID,
                      let toID = $0.toFigure?.persistentModelID,
                      $0.relationshipType?.category == "parent",
                      parentIDs.contains(fromID),
                      toID != focusFigure.persistentModelID else { return false }
                return true
            }
            .compactMap { $0.toFigure }
    }

    private var coParents: [Figure] {
        guard !children.isEmpty else { return [] }
        let childIDs = Set(children.map(\.persistentModelID))
        let otherParentIDs = Set(relationships
            .filter {
                guard let toID = $0.toFigure?.persistentModelID,
                      let fromID = $0.fromFigure?.persistentModelID,
                      $0.relationshipType?.category == "parent",
                      childIDs.contains(toID),
                      fromID != focusFigure.persistentModelID else { return false }
                return true
            }
            .compactMap { $0.fromFigure?.persistentModelID })
        return relationships.compactMap(\.fromFigure).filter { otherParentIDs.contains($0.persistentModelID) }
    }

    private var siblingsExcludingCoParents: [Figure] {
        let coParentIDs = Set(coParents.map(\.persistentModelID))
        return computeSiblings.filter { !coParentIDs.contains($0.persistentModelID) }
    }
}
