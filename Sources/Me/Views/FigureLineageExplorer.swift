import SwiftUI
import SwiftData

/// Explorer that shows the lineage tree centered on a single figure.
/// Click any figure to re-center the tree on that figure.
/// Parents/children are always shown; grandparents/grandchildren are one click away.
struct FigureLineageExplorer: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var relationships: [Relationship]

    let initialFigure: Figure
    @State private var focusFigure: Figure
    @State private var showGrandparents = false
    @State private var showGrandchildren = false
    @State private var sourceFilter = ""

    init(initialFigure: Figure) {
        self.initialFigure = initialFigure
        self._focusFigure = State(initialValue: initialFigure)
    }

    private var availableSources: [String] {
        let sources = relationships.map(\.sourceDisplayName).filter { !$0.isEmpty }
        return Array(Set(sources)).sorted()
    }

    private var filteredRelationships: [Relationship] {
        guard !sourceFilter.isEmpty else { return relationships }
        return relationships.filter { $0.sourceDisplayName == sourceFilter }
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
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Header

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
            if availableSources.count > 1 {
                sourceFilterMenu
            }
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.1))
                )
        }
        .padding()
    }

    // MARK: - Tree Content

    private var sourceFilterMenu: some View {
        Menu {
            Button("All sources") { sourceFilter = "" }
            Divider()
            ForEach(availableSources, id: \.self) { source in
                Button(source) { sourceFilter = source }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "book.closed")
                    .font(.system(size: 9))
                Text(sourceFilter.isEmpty ? "All sources" : sourceFilter)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.1)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Filter lineage by source")
    }

    private var treeContent: some View {
        VStack(spacing: 0) {
            // ── Ancestors ──
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

            // ── Focus + Spouses + Siblings ──
            focusRow

            // ── Descendants ──

            // ── Descendants ──
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

    // MARK: - Focus Row

    private var focusRow: some View {
        let fig = focusFigure
        let siblings = siblingsExcludingCoParents
        let otherParents = coParents
        return HStack(spacing: 8) {
            if !spousesLeft.isEmpty {
                ForEach(spousesLeft) { spouse in
                    lineageChip(spouse)
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
                                .help("View \(sibling.name)")
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
                                .help("View \(parent.name)")
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
                    lineageChip(spouse)
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

    private var computeSiblings: [Figure] {
        let parentIDs = Set(parents.map(\.persistentModelID))
        guard !parentIDs.isEmpty else { return [] }
        return filteredRelationships
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
        let otherParentIDs = Set(filteredRelationships
            .filter {
                guard let toID = $0.toFigure?.persistentModelID,
                      let fromID = $0.fromFigure?.persistentModelID,
                      $0.relationshipType?.category == "parent",
                      childIDs.contains(toID),
                      fromID != focusFigure.persistentModelID else { return false }
                return true
            }
            .compactMap { $0.fromFigure?.persistentModelID })
        return filteredRelationships.compactMap(\.fromFigure).filter { otherParentIDs.contains($0.persistentModelID) }
    }

    private var siblingsExcludingCoParents: [Figure] {
        let coParentIDs = Set(coParents.map(\.persistentModelID))
        return computeSiblings.filter { !coParentIDs.contains($0.persistentModelID) }
    }

    private func lineageChip(_ figure: Figure) -> some View {
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
        .help("\(figure.name) — consort of \(focusFigure.name)")
    }

    // MARK: - Generation Row

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
                        .help("View \(fig.name)")
                }
            }
        }
    }

    // MARK: - Connectors

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

    // MARK: - Expand Button

    private func expandButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
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

    // MARK: - Actions

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
        resolveGeneration(filteredRelationships.filter {
            $0.relationshipType?.category == "parent" &&
            $0.toFigure?.persistentModelID == focusFigure.persistentModelID
        })
    }

    private var parents: [Figure] { resolvedParents.figures }
    private var parentAlts: [PersistentIdentifier: [Figure]] { resolvedParents.alts }

    private var resolvedChildren: (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        resolveGeneration(filteredRelationships.filter {
            $0.relationshipType?.category == "parent" &&
            $0.fromFigure?.persistentModelID == focusFigure.persistentModelID
        })
    }

    private var children: [Figure] { resolvedChildren.figures }
    private var childAlts: [PersistentIdentifier: [Figure]] { resolvedChildren.alts }

    private var spousesLeft: [Figure] {
        filteredRelationships
            .filter { $0.relationshipType?.name == "Spouse" && $0.toFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private var spousesRight: [Figure] {
        filteredRelationships
            .filter { $0.relationshipType?.name == "Spouse" && $0.fromFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private var consortsLeft: [Figure] {
        filteredRelationships
            .filter { $0.relationshipType?.name == "Consort" && $0.toFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private var consortsRight: [Figure] {
        filteredRelationships
            .filter { $0.relationshipType?.name == "Consort" && $0.fromFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private var resolvedGrandparents: (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        let parentIDs = Set(parents.map(\.persistentModelID))
        return resolveGeneration(filteredRelationships.filter {
            guard let toID = $0.toFigure?.persistentModelID else { return false }
            return $0.relationshipType?.category == "parent" && parentIDs.contains(toID)
        })
    }

    private var grandparents: [Figure] { resolvedGrandparents.figures }
    private var grandparentAlts: [PersistentIdentifier: [Figure]] { resolvedGrandparents.alts }

    private var resolvedGrandchildren: (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        let childIDs = Set(children.map(\.persistentModelID))
        return resolveGeneration(filteredRelationships.filter {
            guard let fromID = $0.fromFigure?.persistentModelID else { return false }
            return $0.relationshipType?.category == "parent" && childIDs.contains(fromID)
        })
    }

    private var grandchildren: [Figure] { resolvedGrandchildren.figures }
    private var grandchildAlts: [PersistentIdentifier: [Figure]] { resolvedGrandchildren.alts }
}
