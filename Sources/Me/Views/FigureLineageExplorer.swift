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

    init(initialFigure: Figure) {
        self.initialFigure = initialFigure
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
        .frame(minWidth: 520, minHeight: 420)
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

    private var treeContent: some View {
        VStack(spacing: 0) {
            // ── Ancestors ──
            if showGrandparents {
                generationRow(grandparents, label: "Grandparents")
                connectorDown()
            }

            if !parents.isEmpty {
                generationRow(parents, label: "Parents")
                if !grandparents.isEmpty && !showGrandparents {
                    expandButton("Show Grandparents") { showGrandparents = true }
                }
                connectorDown()
            } else if !grandparents.isEmpty && !showGrandparents {
                expandButton("Show Grandparents") { showGrandparents = true }
            }

            // ── Focus + Spouses ──
            focusRow

            // ── Descendants ──
            if !children.isEmpty {
                connectorUp()
                generationRow(children, label: "Children")
                if !grandchildren.isEmpty && !showGrandchildren {
                    expandButton("Show Grandchildren") { showGrandchildren = true }
                }
            } else if !grandchildren.isEmpty && !showGrandchildren {
                expandButton("Show Grandchildren") { showGrandchildren = true }
            }

            if showGrandchildren {
                connectorUp()
                generationRow(grandchildren, label: "Grandchildren")
            }
        }
    }

    // MARK: - Focus Row

    private var focusRow: some View {
        let fig = focusFigure
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
                    FigureCardView(figure: fig, isSelected: false)
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
            focusFigure = figure
            showGrandparents = false
            showGrandchildren = false
        }
    }

    // MARK: - Relationship Queries

    private var parents: [Figure] {
        relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.toFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private var children: [Figure] {
        relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.fromFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private var spousesLeft: [Figure] {
        relationships
            .filter { $0.relationshipType == .spouse && $0.toFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private var spousesRight: [Figure] {
        relationships
            .filter { $0.relationshipType == .spouse && $0.fromFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private var consortsLeft: [Figure] {
        relationships
            .filter { $0.relationshipType == .consort && $0.toFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private var consortsRight: [Figure] {
        relationships
            .filter { $0.relationshipType == .consort && $0.fromFigure?.persistentModelID == focusFigure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private var grandparents: [Figure] {
        let parentIDs = Set(parents.map(\.persistentModelID))
        return relationships
            .filter {
                guard let toID = $0.toFigure?.persistentModelID else { return false }
                return ($0.relationshipType == .father || $0.relationshipType == .mother) && parentIDs.contains(toID)
            }
            .compactMap { $0.fromFigure }
    }

    private var grandchildren: [Figure] {
        let childIDs = Set(children.map(\.persistentModelID))
        return relationships
            .filter {
                guard let fromID = $0.fromFigure?.persistentModelID else { return false }
                return ($0.relationshipType == .father || $0.relationshipType == .mother) && childIDs.contains(fromID)
            }
            .compactMap { $0.toFigure }
    }
}
