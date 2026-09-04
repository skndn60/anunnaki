import SwiftUI
import SwiftData

struct ParentCouple: Identifiable {
    let id: String
    let father: Figure?
    let mother: Figure?
    let fatherRel: Relationship?
    let motherRel: Relationship?
    var isPreferred: Bool { fatherRel?.isPreferred == true || motherRel?.isPreferred == true }
    var sourceLabel: String? { fatherRel?.sourceDisplayName ?? motherRel?.sourceDisplayName }
}

private struct ParentPairDashCenterKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct LineageColumnCenterKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

func buildCouples(for figure: Figure, from relationships: [Relationship]) -> [ParentCouple] {
    let parentRels = relationships.filter {
        ($0.relationshipType?.name == "Father" || $0.relationshipType?.name == "Mother") &&
        $0.toFigure?.persistentModelID == figure.persistentModelID
    }

    let groupIDs = parentRels.filter { !$0.groupID.isEmpty }
    let legacy = parentRels.filter { $0.groupID.isEmpty }

    var couples: [ParentCouple] = []

    let grouped = Dictionary(grouping: groupIDs) { $0.groupID }
    for (gid, rels) in grouped {
        couples.append(makeCouple(id: gid, rels: rels))
    }

    let legacyFathers = legacy.filter { $0.relationshipType?.name == "Father" }
    let legacyMothers = legacy.filter { $0.relationshipType?.name == "Mother" }
    let pairCount = max(legacyFathers.count, legacyMothers.count)
    for i in 0..<pairCount {
        var pairRels: [Relationship] = []
        if i < legacyFathers.count {
            pairRels.append(legacyFathers[i])
        } else if !legacyFathers.isEmpty {
            pairRels.append(legacyFathers[0])
        }
        if i < legacyMothers.count {
            pairRels.append(legacyMothers[i])
        } else if !legacyMothers.isEmpty {
            pairRels.append(legacyMothers[0])
        }
        couples.append(makeCouple(id: "legacy_\(i)", rels: pairRels))
    }

    // Fill missing parents from other couples (e.g., a Mother-only group gets the Father from another group)
    for i in couples.indices {
        if couples[i].father == nil, let fatherFig = couples.lazy.filter({ $0.id != couples[i].id }).compactMap(\.father).first {
            couples[i] = ParentCouple(id: couples[i].id, father: fatherFig, mother: couples[i].mother, fatherRel: nil, motherRel: couples[i].motherRel)
        }
        if couples[i].mother == nil, let motherFig = couples.lazy.filter({ $0.id != couples[i].id }).compactMap(\.mother).first {
            couples[i] = ParentCouple(id: couples[i].id, father: couples[i].father, mother: motherFig, fatherRel: couples[i].fatherRel, motherRel: nil)
        }
    }

    // Deduplicate: after fill-in, two couples may end up with identical (father, mother) pairs.
    // Keep the one with isPreferred set; if neither is preferred, keep the first occurrence.
    var seen: Set<String> = []
    couples = couples.filter { couple in
        let fID = couple.father?.persistentModelID.hashValue ?? Int.min
        let mID = couple.mother?.persistentModelID.hashValue ?? Int.min
        let key = "\(fID)-\(mID)"
        return seen.insert(key).inserted
    }

    return couples.sorted { $0.isPreferred && !$1.isPreferred }
}

private func makeCouple(id: String, rels: [Relationship]) -> ParentCouple {
    let fatherRel = rels.first(where: { $0.relationshipType?.name == "Father" })
    let motherRel = rels.first(where: { $0.relationshipType?.name == "Mother" })
    return ParentCouple(
        id: id,
        father: fatherRel?.fromFigure,
        mother: motherRel?.fromFigure,
        fatherRel: fatherRel,
        motherRel: motherRel
    )
}

struct MiniLineageView: View {
    static let spaceName = "miniLineageColumnSpace"

    let figure: Figure
    let relationships: [Relationship]
    var isParentGap: ((String) -> Bool)? = nil
    var onSelectFigure: ((Figure) -> Void)?
    var onTapUnknownParent: ((String) -> Void)?
    var onMarkKnownUnavailable: ((String) -> Void)?
    var onRevertKnownUnavailable: ((String) -> Void)?
    var showGrandparents: Bool = true

    @State private var showUnknownDialog: String? = nil
    @State private var showRevertDialog: String? = nil
    @State private var immediateGaps: [String: Bool] = [:]
    @State private var pairDashCenterX: CGFloat = 0
    @State private var lineageColumnCenterX: CGFloat = 0

    private var parentTrunkOffset: CGFloat {
        pairDashCenterX - lineageColumnCenterX
    }

    private func effectiveIsGap(typeName: String) -> Bool {
        (isParentGap?(typeName) ?? false) || (immediateGaps[typeName] ?? false)
    }

    @Query private var allRelationships: [Relationship]
    @Environment(\.modelContext) private var modelContext
    @State private var sourceFilter = ""

    private var availableSources: [String] {
        let sources = relationships.map(\.sourceDisplayName).filter { !$0.isEmpty }
        return Array(Set(sources)).sorted()
    }

    private var filteredRelationships: [Relationship] {
        guard !sourceFilter.isEmpty else { return relationships }
        return relationships.filter { $0.sourceDisplayName == sourceFilter }
    }

    private var filteredAllRelationships: [Relationship] {
        guard !sourceFilter.isEmpty else { return allRelationships }
        return allRelationships.filter { $0.sourceDisplayName == sourceFilter }
    }

    private var couples: [ParentCouple] {
        buildCouples(for: figure, from: filteredRelationships)
    }

    private var preferredCouple: ParentCouple? {
        couples.first(where: { $0.isPreferred }) ?? couples.first
    }

    private var altCouples: [ParentCouple] {
        couples.filter { $0.id != preferredCouple?.id }
    }

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

    private var paternalGrandfather: Figure? {
        guard let father = preferredCouple?.father else { return nil }
        return parents(typeName: "Father", of: father, from: filteredAllRelationships).preferred
    }

    private var paternalGrandmother: Figure? {
        guard let father = preferredCouple?.father else { return nil }
        return parents(typeName: "Mother", of: father, from: filteredAllRelationships).preferred
    }

    private var hasGrandparents: Bool {
        paternalGrandfather != nil || paternalGrandmother != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 12)

            VStack(spacing: 10) {

                if availableSources.count > 1 {
                    sourceFilterMenu
                        .padding(.bottom, 2)
                }

                // Grandparents (from preferred couple's father)
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

                // Parent row
                if let couple = preferredCouple {
                    HStack(spacing: 8) {
                        coupleChip(figure: couple.father, typeName: "Father")
                        pairDash
                        coupleChip(figure: couple.mother, typeName: "Mother")

                        if !altCouples.isEmpty {
                            AltCouplesButton(couples: altCouples, figureTypeColor: figure.figureType?.color ?? .gray) { altCouple in
                                setPreferredCouple(altCouple)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        parentSlotChip(typeName: "Father")
                        pairDash
                        parentSlotChip(typeName: "Mother")
                    }
                }

                parentTrunk

                MiniChip(name: figure.name, symbol: figure.gender.symbol, color: chipColor(figure), isHighlighted: true)
            }
            .coordinateSpace(name: MiniLineageView.spaceName)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: LineageColumnCenterKey.self,
                        value: geo.frame(in: .named(MiniLineageView.spaceName)).midX
                    )
                }
            }
            .onPreferenceChange(LineageColumnCenterKey.self) { lineageColumnCenterX = $0 }
            .onPreferenceChange(ParentPairDashCenterKey.self) { pairDashCenterX = $0 }
            .padding(.vertical, 8)
        }
    }

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
                    .font(.caption2)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.1)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Filter lineage by source")
    }

    @ViewBuilder
    private func parentSlotChip(typeName: String) -> some View {
        if effectiveIsGap(typeName: typeName) {
            permanentUnknownChip(typeName: typeName)
        } else {
            unknownChip(typeName: typeName)
        }
    }

    @ViewBuilder
    private func coupleChip(figure: Figure?, typeName: String) -> some View {
        if let fig = figure {
            ParentChipView(name: fig.name, symbol: fig.gender.symbol, color: chipColor(fig), alternatives: [], figureTypeColor: fig.figureType?.color ?? .gray, onSelect: { onSelectFigure?(fig) }, onSelectAlt: nil)
        } else if effectiveIsGap(typeName: typeName) {
            permanentUnknownChip(typeName: typeName)
        } else {
            unknownChip(typeName: typeName)
        }
    }

    private func unknownChip(typeName: String) -> some View {
        Button(action: { showUnknownDialog = typeName }) {
            HStack(spacing: 4) {
                Text("?")
                    .font(.caption)
                Text("unknown \(typeName.lowercased())")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundColor(.red.opacity(0.4))
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .confirmationDialog(
            "Unknown \(typeName)",
            isPresented: .init(
                get: { showUnknownDialog == typeName },
                set: { if !$0 { showUnknownDialog = nil } }
            )
        ) {
            Button("Add \(typeName.lowercased())") {
                showUnknownDialog = nil
                onTapUnknownParent?(typeName)
            }
                Button("Mark as known-unavailable", role: .destructive) {
                    showUnknownDialog = nil
                    onMarkKnownUnavailable?(typeName)
                    immediateGaps[typeName] = true
                }
            Button("Cancel", role: .cancel) { showUnknownDialog = nil }
        }
    }

    private func permanentUnknownChip(typeName: String) -> some View {
        Button(action: { showRevertDialog = typeName }) {
            MiniChip(name: "\(typeName.lowercased()) — no record", symbol: "—", color: .secondary, isClickable: false)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .confirmationDialog(
            "Known-unavailable \(typeName.lowercased())",
            isPresented: .init(
                get: { showRevertDialog == typeName },
                set: { if !$0 { showRevertDialog = nil } }
            )
        ) {
            Button("Revert to unresearched", role: .destructive) {
                showRevertDialog = nil
                onRevertKnownUnavailable?(typeName)
                immediateGaps[typeName] = false
            }
            Button("Cancel", role: .cancel) { showRevertDialog = nil }
        }
    }

    private func setPreferredCouple(_ couple: ParentCouple) {
        for rel in relationships where rel.persistentModelID == couple.fatherRel?.persistentModelID || rel.persistentModelID == couple.motherRel?.persistentModelID {
            rel.isPreferred = true
        }
        for rel in relationships where (rel.relationshipType?.name == "Father" || rel.relationshipType?.name == "Mother") && rel.toFigure?.persistentModelID == figure.persistentModelID {
            if rel.persistentModelID != couple.fatherRel?.persistentModelID && rel.persistentModelID != couple.motherRel?.persistentModelID {
                rel.isPreferred = false
            }
        }
        try? modelContext.save()
    }

    private var chipRowHeight: CGFloat { 24 }
    private var connectorHeight: CGFloat { 18 }

    private var pairDash: some View {
        Text("—")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ParentPairDashCenterKey.self,
                        value: geo.frame(in: .named(MiniLineageView.spaceName)).midX
                    )
                }
            }
    }

    private var parentTrunk: some View {
        connectorPiece
            .offset(x: parentTrunkOffset)
    }

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

// MARK: - Alternative Couples Button

private struct AltCouplesButton: View {
    let couples: [ParentCouple]
    let figureTypeColor: Color
    let onSelect: (ParentCouple) -> Void

    @State private var showingPopover = false

    var body: some View {
        Button(action: { showingPopover = true }) {
            Text("+\(couples.count)")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .help("\(couples.count) alternative couple\(couples.count == 1 ? "" : "s")")
        .popover(isPresented: $showingPopover) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Alternative Couples")
                    .font(.caption.bold())
                    .padding(.bottom, 2)
                ForEach(couples) { couple in
                    Button(action: {
                        showingPopover = false
                        onSelect(couple)
                    }) {
                        HStack(spacing: 6) {
                            if let father = couple.father {
                                Text(father.gender.symbol)
                                    .font(.caption)
                                Text(father.name)
                                    .font(.caption)
                            } else {
                                Text("?")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Text("—")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            if let mother = couple.mother {
                                Text(mother.gender.symbol)
                                    .font(.caption)
                                Text(mother.name)
                                    .font(.caption)
                            } else {
                                Text("?")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            if let source = couple.sourceLabel, !source.isEmpty {
                                Spacer()
                                SourceBadgeView(name: source)
                            }
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
            .frame(minWidth: 160, minHeight: 40)
        }
    }
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
                    onTap?()
                }
                .help("View \(name)")
        } else {
            chipContent
        }
    }
}
