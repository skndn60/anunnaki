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
                generationRow(grandparents(of: center), label: "Grandparents")
                connectorDown()
            }

            if !parents(of: center).isEmpty {
                generationRow(parents(of: center), label: "Parents")
                if !grandparents(of: center).isEmpty && !showGrandparents {
                    expandButton("Show Grandparents") { showGrandparents = true }
                }
                connectorDown()
            } else if !grandparents(of: center).isEmpty && !showGrandparents {
                expandButton("Show Grandparents") { showGrandparents = true }
            }

            if !siblings(of: center).isEmpty {
                generationRow(siblings(of: center), label: "Siblings")
                connectorDown()
            }

            centerRow(center)

            if !children(of: center).isEmpty {
                connectorUp()
                generationRow(children(of: center), label: "Children")
                if !grandchildren(of: center).isEmpty && !showGrandchildren {
                    expandButton("Show Grandchildren") { showGrandchildren = true }
                }
            } else if !grandchildren(of: center).isEmpty && !showGrandchildren {
                expandButton("Show Grandchildren") { showGrandchildren = true }
            }

            if showGrandchildren {
                connectorUp()
                generationRow(grandchildren(of: center), label: "Grandchildren")
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

    private func centerRow(_ center: Figure) -> some View {
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

    private func generationRow(_ list: [Figure], label: String? = nil) -> some View {
        VStack(spacing: 6) {
            if let label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
            }
            HStack(spacing: 10) {
                ForEach(list) { fig in
                    FigureCardView(figure: fig)
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

    private func connectorDown() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 1, height: 14)
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
        }
    }

    private func connectorUp() -> some View {
        VStack(spacing: 0) {
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 1, height: 14)
        }
    }

    // MARK: - Expand Button

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

    // MARK: - Actions

    private func recenter(on figure: Figure) {
        withAnimation(.easeInOut(duration: 0.2)) {
            centerFigure = figure
            showGrandparents = false
            showGrandchildren = false
        }
    }

    // MARK: - Relationship Queries

    private func parents(of figure: Figure) -> [Figure] {
        relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func children(of figure: Figure) -> [Figure] {
        relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func spousesLeft(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .spouse && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func spousesRight(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .spouse && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func consortsLeft(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .consort && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func consortsRight(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .consort && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func grandparents(of figure: Figure) -> [Figure] {
        let parentIDs = Set(parents(of: figure).map(\.persistentModelID))
        return relationships
            .filter {
                guard let toID = $0.toFigure?.persistentModelID else { return false }
                return ($0.relationshipType == .father || $0.relationshipType == .mother) && parentIDs.contains(toID)
            }
            .compactMap { $0.fromFigure }
    }

    private func grandchildren(of figure: Figure) -> [Figure] {
        let childIDs = Set(children(of: figure).map(\.persistentModelID))
        return relationships
            .filter {
                guard let fromID = $0.fromFigure?.persistentModelID else { return false }
                return ($0.relationshipType == .father || $0.relationshipType == .mother) && childIDs.contains(fromID)
            }
            .compactMap { $0.toFigure }
    }

    private func siblings(of figure: Figure) -> [Figure] {
        let parentIDs = Set(parents(of: figure).map(\.persistentModelID))
        guard !parentIDs.isEmpty else { return [] }
        return relationships
            .filter {
                guard let fromID = $0.fromFigure?.persistentModelID,
                      let toID = $0.toFigure?.persistentModelID,
                      ($0.relationshipType == .father || $0.relationshipType == .mother),
                      parentIDs.contains(fromID),
                      toID != figure.persistentModelID else { return false }
                return true
            }
            .compactMap { $0.toFigure }
    }

    private func commanders(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .commander && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func commandedBy(_ figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .commander && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func servants(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .servant && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func masters(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .servant && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func worshippers(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .worshipper && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func worshippedBy(_ figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .worshipper && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func allies(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .ally && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func enemies(of figure: Figure) -> [Figure] {
        relationships
            .filter { $0.relationshipType == .enemy && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
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
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : figure.figureType?.color.opacity(0.4) ?? .gray.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
}
