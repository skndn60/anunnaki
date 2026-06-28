import SwiftUI
import SwiftData

/// Displays the family lineage radiating from a configurable center figure.
/// Default center is Anu. Right-click any figure card to recenter the tree.
struct LineageTreeView: View {
    @Query private var figures: [Figure]
    @Query private var figureTypes: [FigureType]
    @Query private var relationships: [Relationship]
    @State private var centerFigure: Figure?
    @State private var showGrandparents = false
    @State private var showGrandchildren = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if figures.isEmpty {
                emptyState
            } else if let center = centerFigure {
                ScrollView([.horizontal, .vertical]) {
                    lineageContent(for: center)
                        .padding(40)
                }
            } else {
                emptyState
            }
        }
        .onAppear {
            if centerFigure == nil {
                centerFigure = figures.first(where: { $0.name == "Anu" }) ?? figures.first
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("Lineage Tree")
                .font(.title2.bold())
            Spacer()
            FigureTypeLegend(types: figureTypes)
            if let center = centerFigure {
                Text(center.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Empty State

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

    // MARK: - Lineage Content

    private func lineageContent(for center: Figure) -> some View {
        VStack(spacing: 0) {
            if showGrandparents {
                generationRow(grandparents(of: center), label: "Grandparents", alts: grandparentAlts(of: center), onSelectAlt: { recenter(on: $0) })
                connector()
            }

            if !parents(of: center).isEmpty {
                generationRow(parents(of: center), label: "Parents", alts: parentAlts(of: center), onSelectAlt: { recenter(on: $0) })
                if !grandparents(of: center).isEmpty && !showGrandparents {
                    expandButton("Show Grandparents") { showGrandparents = true }
                }
                connector()
            } else if !grandparents(of: center).isEmpty && !showGrandparents {
                expandButton("Show Grandparents") { showGrandparents = true }
            }

            centerRow(center, siblings: siblingsExcludingCoParents(of: center), coParents: coParents(of: center))

            if !children(of: center).isEmpty {
                connector()
                generationRow(children(of: center), label: "Children", alts: childAlts(of: center), onSelectAlt: { recenter(on: $0) })
                if !grandchildren(of: center).isEmpty && !showGrandchildren {
                    expandButton("Show Grandchildren") { showGrandchildren = true }
                }
            } else if !grandchildren(of: center).isEmpty && !showGrandchildren {
                expandButton("Show Grandchildren") { showGrandchildren = true }
            }

            if showGrandchildren {
                connector()
                generationRow(grandchildren(of: center), label: "Grandchildren", alts: grandchildAlts(of: center), onSelectAlt: { recenter(on: $0) })
            }

            // Non-family relationships
            let nonFamily = nonFamilyRelationships(for: center)
            if !nonFamily.isEmpty {
                Divider()
                    .padding(.vertical, 16)
                VStack(spacing: 8) {
                    Text("Service & Alliances")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(nonFamily, id: \.label) { group in
                        if !group.figures.isEmpty {
                            serviceRow(label: group.label, figures: group.figures, color: group.color)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Non-Family Section

    private func serviceRow(label: String, figures: [Figure], color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 100, alignment: .trailing)
            ForEach(figures) { fig in
                MiniChip(name: fig.name, symbol: fig.gender.symbol, color: fig.figureType?.color ?? .gray, isClickable: true) {
                    recenter(on: fig)
                }
                .contextMenu {
                    Button("Make \(fig.name) center figure") {
                        recenter(on: fig)
                    }
                }
            }
        }
    }

    private struct ServiceGroup {
        let label: String
        let figures: [Figure]
        let color: Color
    }

    private func nonFamilyRelationships(for center: Figure) -> [ServiceGroup] {
        var groups: [ServiceGroup] = []

        let commanders = commanders(of: center)
        if !commanders.isEmpty {
            groups.append(ServiceGroup(label: "Commands", figures: commanders, color: .yellow))
        }
        let commandedBy = commandedBy(center)
        if !commandedBy.isEmpty {
            groups.append(ServiceGroup(label: "Commanded by", figures: commandedBy, color: .yellow))
        }
        let servants = servants(of: center)
        if !servants.isEmpty {
            groups.append(ServiceGroup(label: "Served by", figures: servants, color: .brown))
        }
        let masters = masters(of: center)
        if !masters.isEmpty {
            groups.append(ServiceGroup(label: "Serves", figures: masters, color: .brown))
        }
        let worshippers = worshippers(of: center)
        if !worshippers.isEmpty {
            groups.append(ServiceGroup(label: "Worshipped by", figures: worshippers, color: .indigo))
        }
        let worshipped = worshippedBy(center)
        if !worshipped.isEmpty {
            groups.append(ServiceGroup(label: "Worships", figures: worshipped, color: .indigo))
        }
        let allies = allies(of: center)
        if !allies.isEmpty {
            groups.append(ServiceGroup(label: "Allies", figures: allies, color: .green))
        }
        let enemies = enemies(of: center)
        if !enemies.isEmpty {
            groups.append(ServiceGroup(label: "Enemies", figures: enemies, color: .red))
        }

        return groups
    }

    // MARK: - Center Row

    private func centerRow(_ center: Figure, siblings: [Figure] = [], coParents: [Figure] = []) -> some View {
        HStack(spacing: 8) {
            let leftSpouses = spousesLeft(of: center)
            let leftConsorts = consortsLeft(of: center)
            let rightSpouses = spousesRight(of: center)
            let rightConsorts = consortsRight(of: center)

            if !leftSpouses.isEmpty {
                ForEach(leftSpouses) { spouse in
                    figureChip(spouse)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.pink.opacity(0.4))
                }
            }
            if !leftConsorts.isEmpty {
                ForEach(leftConsorts) { consort in
                    consortChip(consort)
                    Image(systemName: "heart.circle")
                        .font(.system(size: 7))
                        .foregroundStyle(.purple.opacity(0.5))
                }
            }

            if !siblings.isEmpty {
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("Siblings")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                        HStack(spacing: 6) {
                            ForEach(siblings) { sibling in
                                FigureCardView(figure: sibling)
                                    .contextMenu {
                                        Button("Make \(sibling.name) center figure") {
                                            recenter(on: sibling)
                                        }
                                    }
                                    .onTapGesture { recenter(on: sibling) }
                            }
                        }
                    }

                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 1, height: 50)
                        .padding(.horizontal, 12)
                }
            }

            if !coParents.isEmpty {
                VStack(spacing: 2) {
                    Text("Parent")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    HStack(spacing: 6) {
                        ForEach(coParents) { parent in
                            FigureCardView(figure: parent)
                                .contextMenu {
                                    Button("Make \(parent.name) center figure") {
                                        recenter(on: parent)
                                    }
                                }
                                .onTapGesture { recenter(on: parent) }
                        }
                    }
                }
            }

            FigureCardView(figure: center, isSelected: true)

            if !rightConsorts.isEmpty {
                ForEach(rightConsorts) { consort in
                    Image(systemName: "heart.circle")
                        .font(.system(size: 7))
                        .foregroundStyle(.purple.opacity(0.5))
                    consortChip(consort)
                }
            }
            if !rightSpouses.isEmpty {
                ForEach(rightSpouses) { spouse in
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
                .fill(center.figureType?.color.opacity(0.06) ?? .gray.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(center.figureType?.color.opacity(0.15) ?? .gray.opacity(0.15), lineWidth: 1)
                )
        )
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
        .contextMenu {
            Button("Make \(figure.name) center figure") {
                recenter(on: figure)
            }
        }
        .onTapGesture { recenter(on: figure) }
        .help("\(figure.name) — consort of \(centerFigure?.name ?? "")")
    }

    private func figureChip(_ figure: Figure) -> some View {
        MiniChip(name: figure.name, symbol: figure.gender.symbol, color: figure.figureType?.color ?? .gray, isClickable: true) {
            recenter(on: figure)
        }
        .contextMenu {
            Button("Make \(figure.name) center figure") {
                recenter(on: figure)
            }
        }
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
                    FigureCardView(figure: fig, alternatives: alts[fig.persistentModelID] ?? [], onSelectAlt: onSelectAlt)
                        .contextMenu {
                            Button("Make \(fig.name) center figure") {
                                recenter(on: fig)
                            }
                        }
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
            centerFigure = figure
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

    private func parentsAndAlts(of figure: Figure) -> (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        resolveGeneration(relationships.filter {
            $0.relationshipType?.category == "parent" && $0.toFigure?.persistentModelID == figure.persistentModelID
        })
    }

    private func parents(of figure: Figure) -> [Figure] { parentsAndAlts(of: figure).figures }
    private func parentAlts(of figure: Figure) -> [PersistentIdentifier: [Figure]] { parentsAndAlts(of: figure).alts }

    private func childrenAndAlts(of figure: Figure) -> (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        resolveGeneration(relationships.filter {
            $0.relationshipType?.category == "parent" && $0.fromFigure?.persistentModelID == figure.persistentModelID
        })
    }

    private func children(of figure: Figure) -> [Figure] { childrenAndAlts(of: figure).figures }
    private func childAlts(of figure: Figure) -> [PersistentIdentifier: [Figure]] { childrenAndAlts(of: figure).alts }

    private func spousesLeft(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Spouse" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func spousesRight(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Spouse" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func consortsLeft(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Consort" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func consortsRight(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Consort" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func grandparentsAndAlts(of figure: Figure) -> (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        let parentIDs = Set(parents(of: figure).map(\.persistentModelID))
        return resolveGeneration(relationships.filter {
            guard let toID = $0.toFigure?.persistentModelID else { return false }
            return $0.relationshipType?.category == "parent" && parentIDs.contains(toID)
        })
    }

    private func grandparents(of figure: Figure) -> [Figure] { grandparentsAndAlts(of: figure).figures }
    private func grandparentAlts(of figure: Figure) -> [PersistentIdentifier: [Figure]] { grandparentsAndAlts(of: figure).alts }

    private func grandchildrenAndAlts(of figure: Figure) -> (figures: [Figure], alts: [PersistentIdentifier: [Figure]]) {
        let childIDs = Set(children(of: figure).map(\.persistentModelID))
        return resolveGeneration(relationships.filter {
            guard let fromID = $0.fromFigure?.persistentModelID else { return false }
            return $0.relationshipType?.category == "parent" && childIDs.contains(fromID)
        })
    }

    private func grandchildren(of figure: Figure) -> [Figure] { grandchildrenAndAlts(of: figure).figures }
    private func grandchildAlts(of figure: Figure) -> [PersistentIdentifier: [Figure]] { grandchildrenAndAlts(of: figure).alts }

    private func siblings(of figure: Figure) -> [Figure] {
        let parentIDs = Set(parents(of: figure).map(\.persistentModelID))
        guard !parentIDs.isEmpty else { return [] }
        return relationships
            .filter {
                guard let fromID = $0.fromFigure?.persistentModelID,
                      let toID = $0.toFigure?.persistentModelID,
                      $0.relationshipType?.category == "parent",
                      parentIDs.contains(fromID),
                      toID != figure.persistentModelID else { return false }
                return true
            }
            .compactMap { $0.toFigure }
    }

    private func coParents(of figure: Figure) -> [Figure] {
        let childIDs = Set(children(of: figure).map(\.persistentModelID))
        guard !childIDs.isEmpty else { return [] }
        let otherParentIDs = Set(relationships
            .filter {
                guard let toID = $0.toFigure?.persistentModelID,
                      let fromID = $0.fromFigure?.persistentModelID,
                      $0.relationshipType?.category == "parent",
                      childIDs.contains(toID),
                      fromID != figure.persistentModelID else { return false }
                return true
            }
            .compactMap { $0.fromFigure?.persistentModelID })
        return self.figures.filter { otherParentIDs.contains($0.persistentModelID) }
    }

    private func siblingsExcludingCoParents(of figure: Figure) -> [Figure] {
        let coParentIDs = Set(coParents(of: figure).map(\.persistentModelID))
        return siblings(of: figure).filter { !coParentIDs.contains($0.persistentModelID) }
    }

    private func commanders(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Commander" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func commandedBy(_ figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Commander" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func servants(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Servant" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func masters(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Servant" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func worshippers(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Worshipper" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func worshippedBy(_ figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Worshipper" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func allies(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Ally" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func enemies(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType?.name == "Enemy" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }
}

// MARK: - Figure Card

struct FigureCardView: View {
    let figure: Figure
    var isSelected: Bool = false
    var alternatives: [Figure] = []
    var onSelectAlt: ((Figure) -> Void)?

    @State private var showingAlts = false

    var body: some View {
        VStack(spacing: 4) {
            Text(figure.name)
                .font(.headline)
                .lineLimit(1)
            Text(figure.figureType?.name ?? "Unknown")
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
                .fill(figure.figureType?.color.opacity(0.15) ?? .gray.opacity(0.15))
                .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : figure.figureType?.color.opacity(0.4) ?? .gray.opacity(0.4), lineWidth: isSelected ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if !alternatives.isEmpty {
                Button(action: { showingAlts = true }) {
                    Text("+\(alternatives.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
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
            }
        }
    }
}
