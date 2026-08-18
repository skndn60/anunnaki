import SwiftUI
import SwiftData

// MARK: - Tree Model Types

private struct TreeEntry: Identifiable {
    let primary: Figure
    let partner: Figure?
    let altPartnerCount: Int
    let generation: Int

    var id: String { "\(primary.name)@\(generation)" }
}

private struct TreeData {
    let rootID: PersistentIdentifier
    let entries: [String: TreeEntry]
    let levels: [[TreeEntry]]
    let parentToChild: [String: [String]]
}

private struct LayoutResult {
    let nodeLayouts: [PersistentIdentifier: CGRect]
    let figureAltCounts: [PersistentIdentifier: Int]
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
}

// MARK: - Lineage Tree View

struct LineageTreeView: View {
    var coordinator: NavigationCoordinator?

    @Query private var figures: [Figure]
    @Query private var figureTypes: [FigureType]
    @Query private var relationships: [Relationship]

    @State private var centerFigure: Figure?
    @State private var generationsAbove = 1
    @State private var generationsBelow = 1
    @State private var collapsedIDs: Set<String> = []
    @State private var detailFigure: Figure?
    @State private var altForFigure: Figure?
    @State private var rightClickFigureID: PersistentIdentifier?
    @State private var centerHistory: [Figure] = []
    @State private var sourceFilter = ""

    private var availableSources: [String] {
        let sources = relationships.map(\.sourceDisplayName).filter { !$0.isEmpty }
        return Array(Set(sources)).sorted()
    }

    private var filteredRelationships: [Relationship] {
        guard !sourceFilter.isEmpty else { return relationships }
        return relationships.filter { $0.sourceDisplayName == sourceFilter }
    }

    private let cardWidth: CGFloat = 120
    private let cardHeight: CGFloat = 52
    private let coupleSpacing: CGFloat = 36
    private let partnerSpacing: CGFloat = 14
    private let verticalSpacing: CGFloat = 130
    private let canvasPadding: CGFloat = 60
    private let branchBarOffset: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if figures.isEmpty {
                emptyState
            } else if let center = centerFigure {
                treeCanvas(center)
            } else {
                emptyState
            }
        }
        .sheet(item: $altForFigure) { fig in
            AlternativePartnersSheet(
                figure: fig,
                partners: alternativePartners(of: fig),
                onClose: { altForFigure = nil },
                onRecenter: { altForFigure = nil; recenterTree(to: $0) }
            )
        }
        .sheet(item: $detailFigure) { fig in
            FigureDetailSheet(
                figure: fig,
                onClose: { detailFigure = nil },
                onRecenter: { detailFigure = nil; recenterTree(to: $0) }
            )
        }
        .onAppear {
            if let pendingID = coordinator?.consumePendingLineageFigureID(),
               let fig = figures.first(where: { $0.persistentModelID == pendingID }) {
                centerFigure = fig
            } else if centerFigure == nil {
                centerFigure = figures.first(where: { $0.name == "Anu" }) ?? figures.first
            }
        }
        .onChange(of: coordinator?.pendingLineageFigureID) { _, _ in
            if let pendingID = coordinator?.consumePendingLineageFigureID(),
               let fig = figures.first(where: { $0.persistentModelID == pendingID }) {
                centerFigure = fig
                collapsedIDs.removeAll()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Text("Lineage Tree")
                .font(.title2.bold())
            if !centerHistory.isEmpty {
                Button(action: goBack) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Go back to previous figure")
            }
            Spacer()
            FigureTypeLegend(types: figureTypes)

            if availableSources.count > 1 {
                sourceFilterMenu
            }

            stepperButton(direction: .up, value: $generationsAbove, maximum: 4)
            stepperButton(direction: .down, value: $generationsBelow, maximum: 4)
        }
        .padding()
    }

    // MARK: - Stepper

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

    private enum StepperDirection {
        case up, down
        var label: String { self == .up ? "↑" : "↓" }
    }

    private func stepperButton(direction: StepperDirection, value: Binding<Int>, maximum: Int) -> some View {
        HStack(spacing: 4) {
            Button(action: { value.wrappedValue = max(0, value.wrappedValue - 1) }) {
                Image(systemName: "minus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Text("\(direction.label) \(value.wrappedValue)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 32)

            Button(action: { value.wrappedValue = min(maximum, value.wrappedValue + 1) }) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .help(direction == .up ? "Generations above" : "Generations below")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tree").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("No figures yet").font(.title3).foregroundStyle(.secondary)
            Text("Add figures and relationships using the input screens to build the lineage tree.")
                .font(.body).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
    }

    // MARK: - Tree Canvas

    private var treeData: TreeData? {
        guard let center = centerFigure else { return nil }
        return buildTreeData(center: center)
    }

    private func treeCanvas(_ center: Figure) -> some View {
        let data = buildTreeData(center: center)
        let layout = computeLayout(data: data)

        return ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    drawGenerationBackground(context: &context, data: data, layout: layout)
                }
                .allowsHitTesting(false)
                .frame(width: layout.canvasWidth, height: layout.canvasHeight)

                Canvas { context, _ in
                    drawBrackets(context: &context, data: data, layout: layout)
                }
                .allowsHitTesting(false)
                .frame(width: layout.canvasWidth, height: layout.canvasHeight)

                Canvas { context, _ in
                    drawNodes(context: &context, data: data, layout: layout, centerID: center.persistentModelID)
                }
                .frame(width: layout.canvasWidth, height: layout.canvasHeight)
                .onTapGesture { location in
                    handleTap(at: location, layout: layout)
                }
                .contextMenu {
                    if let figID = rightClickFigureID,
                       let fig = figures.first(where: { $0.persistentModelID == figID }) {
                        Button("Show Details") { detailFigure = fig }
                        Divider()
                        Button("Recenter") { recenterTree(to: figID) }
                        if collapsedIDs.contains(fig.name) {
                            Button("Expand Branch") { collapsedIDs.remove(fig.name) }
                        } else {
                            Button("Collapse Branch") { collapsedIDs.insert(fig.name) }
                        }
                    }
                }
                .onContinuousHover { phase in
                    if case .active(let location) = phase {
                        rightClickFigureID = figureAt(location: location, in: layout)
                    } else {
                        rightClickFigureID = nil
                    }
                }

                if let figID = rightClickFigureID,
                   let frame = layout.nodeLayouts[figID],
                   let figure = figures.first(where: { $0.persistentModelID == figID }),
                   figure.mugshotImage != nil {
                    let size: CGFloat = 140
                    let below = frame.maxY + size < layout.canvasHeight
                    MugshotView(
                        image: figure.mugshotImage,
                        cropRect: ImageCropRect(encoded: figure.mugshotCropRect),
                        size: size,
                        figureType: figure.figureType,
                        identification: figure.mugshotIdentification
                    )
                    .allowsHitTesting(false)
                    .position(
                        x: frame.midX,
                        y: below ? frame.maxY + 28 + size / 2 : frame.minY - 28 - size / 2
                    )
                }
            }
            .padding(40)
        }
        .id("tree-\(center.persistentModelID)-\(generationsAbove)-\(generationsBelow)")
    }

    // MARK: - Tree Building

    private func buildTreeData(center: Figure) -> TreeData {
        var entries: [String: TreeEntry] = [:]
        var levelsMap: [Int: [TreeEntry]] = [:]
        var parentToChild: [String: [String]] = [:]
        var seenFigures: Set<PersistentIdentifier> = []

        let centerPartner = preferredPartner(of: center)
        let centerAlt = partnerCount(of: center)
        let centerAltCount = max(0, centerAlt - (centerPartner != nil ? 1 : 0))
        let centerEntry = TreeEntry(primary: center, partner: centerPartner, altPartnerCount: centerAltCount, generation: 0)
        entries[centerEntry.id] = centerEntry
        levelsMap[0] = [centerEntry]
        seenFigures.insert(center.persistentModelID)
        if let partner = centerPartner {
            seenFigures.insert(partner.persistentModelID)
        }

        if generationsAbove > 0 {
            collectAncestors(of: center, currentGen: 0, maxGen: -generationsAbove, entries: &entries, levelsMap: &levelsMap, parentToChild: &parentToChild, seenFigures: &seenFigures)
        }

        if generationsBelow > 0 {
            var slotOwner: [PersistentIdentifier: String] = [center.persistentModelID: centerEntry.id]
            collectDescendants(of: center, currentGen: 0, maxGen: generationsBelow, entries: &entries, levelsMap: &levelsMap, parentToChild: &parentToChild, seenFigures: &seenFigures, slotOwner: &slotOwner)
        }

        let levels = levelsMap.sorted(by: { $0.key < $1.key }).map(\.value)
        return TreeData(rootID: center.persistentModelID, entries: entries, levels: levels, parentToChild: parentToChild)
    }

    private func isUnknownParent(_ figure: Figure) -> Bool {
        figure.name == "Unknown Father" || figure.name == "Unknown Mother"
    }

    private func collectAncestors(of figure: Figure, currentGen: Int, maxGen: Int, entries: inout [String: TreeEntry], levelsMap: inout [Int: [TreeEntry]], parentToChild: inout [String: [String]], seenFigures: inout Set<PersistentIdentifier>) {
        let nextGen = currentGen - 1
        guard nextGen >= maxGen else { return }
        guard !collapsedIDs.contains(figure.name) else { return }

        let rels = filteredRelationships.filter { $0.relationshipType?.category == "parent" && $0.toFigure?.persistentModelID == figure.persistentModelID }
        let childID = idFor(figure, gen: currentGen)

        if rels.isEmpty {
            // No parents defined at all: render a single Unknown couple so the
            // child centers under the midpoint between them (not per-card).
            let parentID = "Unknown Father@\(nextGen)"
            if entries[parentID] == nil {
                let fatherFig = Figure(name: "Unknown Father", gender: .male)
                let motherFig = Figure(name: "Unknown Mother", gender: .female)
                let entry = TreeEntry(primary: fatherFig, partner: motherFig, altPartnerCount: 0, generation: nextGen)
                entries[parentID] = entry
                levelsMap[nextGen, default: []].append(entry)
            }
            parentToChild[parentID, default: []].append(childID)
            return
        }

        let grouped = Dictionary(grouping: rels) { $0.relationshipType?.name ?? "" }
        var placedFigureIDs: Set<PersistentIdentifier> = []
        var knownRelationTypes: Set<String> = []
        var parentedChildIDs: Set<String> = []

        for (typeName, group) in grouped.sorted(by: { $0.key < $1.key }) {
            knownRelationTypes.insert(typeName)
            guard let chosen = group.first(where: { $0.isPreferred == true }) ?? group.first,
                  let parentFig = chosen.fromFigure,
                  !placedFigureIDs.contains(parentFig.persistentModelID),
                  seenFigures.insert(parentFig.persistentModelID).inserted,
                  !parentedChildIDs.contains(childID) else { continue }

            let partner = preferredPartner(of: parentFig)

            if let partner {
                let partnerWasNew = seenFigures.insert(partner.persistentModelID).inserted
                placedFigureIDs.insert(partner.persistentModelID)
                // Partner already existed as a figure elsewhere in the tree;
                // skip this entry to avoid sharing one figure across two entries
                if !partnerWasNew { continue }
            }

            placedFigureIDs.insert(parentFig.persistentModelID)

            let parentID = idFor(parentFig, gen: nextGen)
            if entries[parentID] != nil {
                parentToChild[parentID, default: []].append(childID)
                parentedChildIDs.insert(childID)
                continue
            }

            let alt = max(0, partnerCount(of: parentFig) - (partner != nil ? 1 : 0))
            let entry = TreeEntry(primary: parentFig, partner: partner, altPartnerCount: alt, generation: nextGen)
            entries[entry.id] = entry
            levelsMap[nextGen, default: []].append(entry)
            parentToChild[entry.id, default: []].append(childID)
            parentedChildIDs.insert(childID)

            collectAncestors(of: parentFig, currentGen: nextGen, maxGen: maxGen, entries: &entries, levelsMap: &levelsMap, parentToChild: &parentToChild, seenFigures: &seenFigures)
        }

        let missingPlaceholder: (name: String, gender: Figure.Gender)?
        if let fatherFig = grouped["Father"]?.first?.fromFigure, !knownRelationTypes.contains("Mother") {
            missingPlaceholder = ("Unknown Mother", .female)
        } else if let motherFig = grouped["Mother"]?.first?.fromFigure, !knownRelationTypes.contains("Father") {
            missingPlaceholder = ("Unknown Father", .male)
        } else {
            missingPlaceholder = nil
        }

        if let placeholder = missingPlaceholder {
            // Attach the missing parent as a partner of the known parent, mirroring
            // the descendant-side behavior so the parents render as a single couple.
            if let knownFig = placeholder.gender == .female ? grouped["Father"]?.first?.fromFigure : grouped["Mother"]?.first?.fromFigure {
                let knownID = idFor(knownFig, gen: nextGen)
                if var existing = entries[knownID], existing.partner == nil {
                    let placeholderFig = Figure(name: placeholder.name, gender: placeholder.gender)
                    existing = TreeEntry(primary: existing.primary, partner: placeholderFig, altPartnerCount: existing.altPartnerCount, generation: existing.generation)
                    entries[knownID] = existing
                    if let idx = levelsMap[nextGen]?.firstIndex(where: { $0.id == knownID }) {
                        levelsMap[nextGen]?[idx] = existing
                    }
                }
            }
        } else {
            // Neither Father nor Mother known: render both as a single unknown couple
            // so the child centers under the midpoint between them.
            let parentID = "Unknown Father@\(nextGen)"
            if entries[parentID] == nil {
                let fatherFig = Figure(name: "Unknown Father", gender: .male)
                let motherFig = Figure(name: "Unknown Mother", gender: .female)
                let entry = TreeEntry(primary: fatherFig, partner: motherFig, altPartnerCount: 0, generation: nextGen)
                entries[parentID] = entry
                levelsMap[nextGen, default: []].append(entry)
            }
            parentToChild[parentID, default: []].append(childID)
        }
    }

    private func collectDescendants(of figure: Figure, currentGen: Int, maxGen: Int, entries: inout [String: TreeEntry], levelsMap: inout [Int: [TreeEntry]], parentToChild: inout [String: [String]], seenFigures: inout Set<PersistentIdentifier>, slotOwner: inout [PersistentIdentifier: String]) {
        let nextGen = currentGen + 1
        guard nextGen <= maxGen else { return }
        guard !collapsedIDs.contains(figure.name) else { return }

        let rels = filteredRelationships.filter { $0.relationshipType?.category == "parent" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
        let parentID = slotOwner[figure.persistentModelID] ?? idFor(figure, gen: currentGen)
        var seen: Set<PersistentIdentifier> = []

        // Pass 1: collect all children — register in seenFigures breadth-first
        // so that gen+N entries always win over gen+(N+1) duplicates
        var children: [Figure] = []
        for rel in rels {
            guard let childFig = rel.toFigure,
                  seen.insert(childFig.persistentModelID).inserted,
                  seenFigures.insert(childFig.persistentModelID).inserted else { continue }
            children.append(childFig)
        }

        // Pass 2: add each child as a couple. `placedChildren` prevents a figure
        // from appearing twice at this level: if the child (or its preferred
        // partner) was already claimed, the child is not given its own entry —
        // it's already represented as the partner of the earlier couple.
        // `slotOwner` maps every placed figure to the entry that represents it,
        // so a skipped child's own descendants still hang off the right couple.
        var placedChildren: Set<PersistentIdentifier> = []
        var nextOwner: [PersistentIdentifier: String] = [:]
        for childFig in children {
            let childID = idFor(childFig, gen: nextGen)
            if placedChildren.contains(childFig.persistentModelID) {
                continue
            }
            let partner = preferredPartner(of: childFig)
            if let partnerPID = partner?.persistentModelID, placedChildren.contains(partnerPID) {
                continue
            }
            if let partner {
                placedChildren.insert(partner.persistentModelID)
                nextOwner[partner.persistentModelID] = childID
            }
            placedChildren.insert(childFig.persistentModelID)
            nextOwner[childFig.persistentModelID] = childID
            let alt = max(0, partnerCount(of: childFig) - (partner != nil ? 1 : 0))
            let entry = TreeEntry(primary: childFig, partner: partner, altPartnerCount: alt, generation: nextGen)
            entries[entry.id] = entry
            levelsMap[nextGen, default: []].append(entry)
            parentToChild[parentID, default: []].append(childID)
        }

        // Pass 3: recurse into each child
        for childFig in children {
            collectDescendants(of: childFig, currentGen: nextGen, maxGen: maxGen, entries: &entries, levelsMap: &levelsMap, parentToChild: &parentToChild, seenFigures: &seenFigures, slotOwner: &nextOwner)
        }

        if !rels.isEmpty,
           let currentEntry = entries[parentID],
           currentEntry.partner == nil {
            let parentTypeNames = Set(rels.compactMap { $0.relationshipType?.name })
            let unknownParent: (name: String, gender: Figure.Gender)?
            if parentTypeNames.contains("Father") && !parentTypeNames.contains("Mother") {
                unknownParent = ("Unknown Mother", .female)
            } else if parentTypeNames.contains("Mother") && !parentTypeNames.contains("Father") {
                unknownParent = ("Unknown Father", .male)
            } else {
                unknownParent = nil
            }
            if let (name, gender) = unknownParent {
                let placeholder = Figure(name: name, gender: gender)
                let updatedEntry = TreeEntry(primary: currentEntry.primary, partner: placeholder, altPartnerCount: currentEntry.altPartnerCount, generation: currentEntry.generation)
                entries[parentID] = updatedEntry
                if let idx = levelsMap[currentGen]?.firstIndex(where: { $0.id == parentID }) {
                    levelsMap[currentGen]?[idx] = updatedEntry
                }
            }
        }
    }

    private func idFor(_ figure: Figure, gen: Int) -> String {
        "\(figure.name)@\(gen)"
    }

    // MARK: - Generation Colors

    private func generationColor(for gen: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.75, green: 0.35, blue: 0.20),
            Color(red: 0.20, green: 0.50, blue: 0.70),
            Color(red: 0.45, green: 0.45, blue: 0.45),
            Color(red: 0.25, green: 0.60, blue: 0.40),
            Color(red: 0.60, green: 0.28, blue: 0.52),
        ]
        let idx = gen + 2
        return palette[max(0, min(idx, palette.count - 1))]
    }

    private func generationTint(for gen: Int) -> Color {
        let base = generationColor(for: gen)
        return base.opacity(0.04)
    }

    // MARK: - Partner Helpers

    private func preferredPartner(of figure: Figure) -> Figure? {
        let rels = filteredRelationships.filter {
            ($0.relationshipType?.name == "Spouse" || $0.relationshipType?.name == "Consort") &&
            ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID)
        }
        guard let chosen = rels.first(where: { $0.isPreferred == true }) ?? rels.first else { return nil }
        return chosen.fromFigure?.persistentModelID == figure.persistentModelID ? chosen.toFigure : chosen.fromFigure
    }

    private func partnerCount(of figure: Figure) -> Int {
        let rels = filteredRelationships.filter {
            ($0.relationshipType?.name == "Spouse" || $0.relationshipType?.name == "Consort") &&
            ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID)
        }
        var seen: Set<PersistentIdentifier> = []
        for rel in rels {
            let p = rel.fromFigure?.persistentModelID == figure.persistentModelID ? rel.toFigure : rel.fromFigure
            if let pid = p?.persistentModelID { seen.insert(pid) }
        }
        return seen.count
    }

    // MARK: - Layout

    private func computeLayout(data: TreeData) -> LayoutResult {
        var nodeLayouts: [PersistentIdentifier: CGRect] = [:]
        var figureAltCounts: [PersistentIdentifier: Int] = [:]
        var genWidths: [(Int, CGFloat)] = []
        let genKeys = data.levels.compactMap(\.first?.generation).sorted()

        for gen in genKeys {
            let entriesAtGen = data.levels.first(where: { $0.first?.generation == gen }) ?? []
            var w: CGFloat = 0
            for e in entriesAtGen {
                w += cardWidth
                if e.partner != nil { w += partnerSpacing + cardWidth }
            }
            w += CGFloat(max(0, entriesAtGen.count - 1)) * coupleSpacing
            genWidths.append((gen, w))
        }

        guard !genWidths.isEmpty else {
            return LayoutResult(nodeLayouts: [:], figureAltCounts: [:], canvasWidth: 600, canvasHeight: 400)
        }

        let maxW = (genWidths.map(\.1).max() ?? 0) + canvasPadding * 2
        let minGen = genKeys.min() ?? 0
        let maxGen = genKeys.max() ?? 0
        let topNeeded = 2 * (canvasPadding + cardHeight / 2 - CGFloat(minGen) * verticalSpacing)
        let bottomNeeded = 2 * (canvasPadding + cardHeight / 2 + CGFloat(maxGen) * verticalSpacing)
        let totalH = max(topNeeded, bottomNeeded)

        for gen in genKeys {
            let entriesAtGen = data.levels.first(where: { $0.first?.generation == gen }) ?? []
            let genW = genWidths.first(where: { $0.0 == gen })?.1 ?? 0
            let startX = (maxW - genW) / 2
            let y = totalH / 2 + CGFloat(gen) * verticalSpacing - cardHeight / 2
            var cx = startX

            for entry in entriesAtGen {
                nodeLayouts[entry.primary.persistentModelID] = CGRect(x: cx, y: y, width: cardWidth, height: cardHeight)
                figureAltCounts[entry.primary.persistentModelID] = entry.altPartnerCount
                cx += cardWidth

                if let partner = entry.partner {
                    cx += partnerSpacing
                    nodeLayouts[partner.persistentModelID] = CGRect(x: cx, y: y, width: cardWidth, height: cardHeight)
                    figureAltCounts[partner.persistentModelID] = 0
                    cx += cardWidth
                }
                cx += coupleSpacing
            }
        }

        // Align each generation under its parents (top generation to bottom):
        // shift the child generation so its PRIMARY (male) cards sit under the
        // parent couple's trunk. Runs across all generations, ancestors included.
        let descendantGens = genKeys.sorted()
        for parentGen in descendantGens {
            let childGen = parentGen + 1
            guard childGen <= (genKeys.max() ?? 0) else { continue }

            for (parentID, childIDs) in data.parentToChild {
                guard let parentEntry = data.entries[parentID],
                      parentEntry.generation == parentGen,
                      !childIDs.isEmpty else { continue }

                let parentFigIDs = [parentEntry.primary.persistentModelID] + (parentEntry.partner.map { [$0.persistentModelID] } ?? [])
                let parentFrames = parentFigIDs.compactMap { nodeLayouts[$0] }
                guard !parentFrames.isEmpty else { continue }
                let trunkX = parentFrames.map(\.midX).reduce(0, +) / CGFloat(parentFrames.count)

                let childFrames = childIDs.compactMap { cid -> CGRect? in
                    guard let ce = data.entries[cid] else { return nil }
                    return nodeLayouts[ce.primary.persistentModelID]
                }
                guard !childFrames.isEmpty else { continue }
                let childGroupMidX = childFrames.map(\.midX).reduce(0, +) / CGFloat(childFrames.count)

                let shift = trunkX - childGroupMidX
                guard abs(shift) > 2 else { continue }

                for childID in childIDs {
                    shiftSubtree(from: childID, dx: shift, data: data, nodeLayouts: &nodeLayouts)
                }
            }
        }

        // Recalculate canvas width after shifts
        let allFrames = Array(nodeLayouts.values)
        let contentMinX = allFrames.map(\.minX).min() ?? 0
        let contentMaxX = allFrames.map(\.maxX).max() ?? 0
        let contentWidth = contentMaxX - contentMinX
        let adjustedWidth = max(600, contentWidth + canvasPadding * 2)
        let recenterShift = (adjustedWidth - contentWidth) / 2 - contentMinX
        if abs(recenterShift) > 2 {
            for (id, frame) in nodeLayouts {
                nodeLayouts[id] = frame.offsetBy(dx: recenterShift, dy: 0)
            }
        }

        return LayoutResult(nodeLayouts: nodeLayouts, figureAltCounts: figureAltCounts, canvasWidth: adjustedWidth, canvasHeight: max(400, totalH))
    }

    private func shiftSubtree(from entryID: String, dx: CGFloat, data: TreeData, nodeLayouts: inout [PersistentIdentifier: CGRect]) {
        guard let entry = data.entries[entryID] else { return }
        let ids = [entry.primary.persistentModelID] + (entry.partner.map { [$0.persistentModelID] } ?? [])
        for id in ids {
            if let frame = nodeLayouts[id] {
                nodeLayouts[id] = frame.offsetBy(dx: dx, dy: 0)
            }
        }
        for childID in data.parentToChild[entryID] ?? [] {
            shiftSubtree(from: childID, dx: dx, data: data, nodeLayouts: &nodeLayouts)
        }
    }

    // MARK: - Generation Background

    private func drawGenerationBackground(context: inout GraphicsContext, data: TreeData, layout: LayoutResult) {
        let levels = data.levels.sorted(by: { $0.first?.generation ?? 0 < $1.first?.generation ?? 0 })
        for level in levels {
            guard let gen = level.first?.generation,
                  let firstEntry = level.first,
                  let firstFrame = layout.nodeLayouts[firstEntry.primary.persistentModelID] else { continue }
            let rowY = firstFrame.minY - 6
            let rowH = cardHeight + 12
            let genRect = CGRect(x: 0, y: rowY, width: layout.canvasWidth, height: rowH)
            context.fill(Path(genRect), with: .color(generationTint(for: gen)))
        }
    }

    // MARK: - Bracket Drawing

    private func drawBrackets(context: inout GraphicsContext, data: TreeData, layout: LayoutResult) {
        for (parentID, childIDs) in data.parentToChild {
            guard let parentEntry = data.entries[parentID], !childIDs.isEmpty else { continue }

            let parentFigIDs = [parentEntry.primary.persistentModelID] + (parentEntry.partner.map { [$0.persistentModelID] } ?? [])
            let parentFrames = parentFigIDs.compactMap { layout.nodeLayouts[$0] }
            guard !parentFrames.isEmpty else { continue }

            let childFrames = childIDs.compactMap { cid -> CGRect? in
                guard let ce = data.entries[cid] else { return nil }
                return layout.nodeLayouts[ce.primary.persistentModelID]
            }
            guard !childFrames.isEmpty else { continue }

            drawSingleBracket(context: &context, parentFrames: parentFrames, childFrames: childFrames)
        }
    }

    private func drawSingleBracket(context: inout GraphicsContext, parentFrames: [CGRect], childFrames: [CGRect]) {
        let lineColor = Color.secondary.opacity(0.45)
        let lineWidth: CGFloat = 2.0
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

        let marriageY = (parentFrames.map(\.maxY).max() ?? 0) + 14
        if parentFrames.count > 1 {
            let lx = parentFrames.map(\.midX).min()!
            let rx = parentFrames.map(\.midX).max()!
            for pf in parentFrames {
                var stub = Path()
                stub.move(to: CGPoint(x: pf.midX, y: pf.maxY))
                stub.addLine(to: CGPoint(x: pf.midX, y: marriageY))
                context.stroke(stub, with: .color(lineColor), style: style)
            }
            var p = Path()
            p.move(to: CGPoint(x: lx, y: marriageY))
            p.addLine(to: CGPoint(x: rx, y: marriageY))
            context.stroke(p, with: .color(lineColor), style: style)
        }

        let trunkX = parentFrames.map(\.midX).reduce(0, +) / CGFloat(parentFrames.count)
        let childTopY = childFrames.map(\.minY).min() ?? 0
        let branchBarY = childTopY - branchBarOffset
        guard branchBarY > marriageY + 4 else { return }

        var t = Path()
        t.move(to: CGPoint(x: trunkX, y: marriageY))
        t.addLine(to: CGPoint(x: trunkX, y: branchBarY))
        context.stroke(t, with: .color(lineColor), style: style)

        let allX = childFrames.map(\.midX) + [trunkX]
        let minX = allX.min()!
        let maxX = allX.max()!
        if maxX - minX > 2 {
            var b = Path()
            b.move(to: CGPoint(x: minX, y: branchBarY))
            b.addLine(to: CGPoint(x: maxX, y: branchBarY))
            context.stroke(b, with: .color(lineColor), style: style)
        }

        for cf in childFrames {
            var d = Path()
            d.move(to: CGPoint(x: cf.midX, y: branchBarY))
            d.addLine(to: CGPoint(x: cf.midX, y: cf.minY))
            context.stroke(d, with: .color(lineColor), style: style)
        }
    }

    // MARK: - Node Drawing

    private func drawNodes(context: inout GraphicsContext, data: TreeData, layout: LayoutResult, centerID: PersistentIdentifier) {
        for (figID, frame) in layout.nodeLayouts {
            let figure: Figure?
            let generation: Int
            if let dbFig = figures.first(where: { $0.persistentModelID == figID }) {
                figure = dbFig
                generation = data.entries.values.first(where: { $0.primary.persistentModelID == figID })?.generation ?? 0
            } else if let placeholder = data.entries.values.first(where: { $0.primary.persistentModelID == figID })?.primary {
                figure = placeholder
                generation = data.entries.values.first(where: { $0.primary.persistentModelID == figID })?.generation ?? 0
            } else if let partnerFig = data.entries.values.compactMap({ $0.partner }).first(where: { $0.persistentModelID == figID }) {
                figure = partnerFig
                generation = data.entries.values.first(where: { $0.partner?.persistentModelID == figID })?.generation ?? 0
            } else {
                continue
            }
            guard let figure else { continue }
            let isCenter = figID == centerID
            let alt = layout.figureAltCounts[figID] ?? 0
            drawCard(context: &context, figure: figure, frame: frame, generation: generation, isCenter: isCenter, altCount: alt)
        }
    }

    private func drawCard(context: inout GraphicsContext, figure: Figure, frame: CGRect, generation: Int, isCenter: Bool, altCount: Int) {
        let isUnknown = isUnknownParent(figure)
        let color = isUnknown ? Color.gray : (figure.figureType?.color ?? .gray)
        let radius: CGFloat = 7
        let bgPath = Path(roundedRect: frame, cornerRadius: radius)
        context.fill(bgPath, with: .color(isUnknown ? Color.gray.opacity(0.06) : color.opacity(0.10)))

        if isCenter {
            context.fill(bgPath, with: .color(Color.accentColor.opacity(0.06)))
        }

        let borderColor = isCenter ? Color.accentColor : (isUnknown ? Color.secondary.opacity(0.35) : color.opacity(0.3))
        let borderWidth: CGFloat = isCenter ? 2 : (isUnknown ? 1 : 0.5)
        let borderDash: [CGFloat] = isUnknown ? [4, 3] : []
        context.stroke(bgPath, with: .color(borderColor), style: StrokeStyle(lineWidth: borderWidth, lineCap: .round, dash: borderDash))

        if isUnknown {
            let ghostPath = Path(ellipseIn: CGRect(x: frame.minX + 24, y: frame.minY + 10, width: 12, height: 12))
            context.stroke(ghostPath, with: .color(.secondary.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            context.draw(
                Text("?").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary.opacity(0.5)),
                at: CGPoint(x: frame.minX + 30, y: frame.minY + 16),
                anchor: .center
            )
            let shortName = figure.name.replacingOccurrences(of: "Unknown ", with: "")
            context.draw(
                Text(shortName.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6)),
                at: CGPoint(x: frame.midX + 8, y: frame.midY - 1),
                anchor: .leading
            )
            return
        }

        let dotRect = CGRect(x: frame.minX + 12, y: frame.minY + 12, width: 7, height: 7)
        context.fill(Path(ellipseIn: dotRect), with: .color(color))

        let maxNameLen: Int = 14
        let displayName = figure.name.count > maxNameLen ? String(figure.name.prefix(maxNameLen - 1)) + "…" : figure.name
        let nameText = Text(displayName).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
        context.draw(nameText, at: CGPoint(x: frame.minX + 26, y: frame.minY + 11), anchor: .topLeading)

        let typeText = figure.gender != .unknown
            ? Text(figure.gender.symbol + " ").font(.system(size: 9)) + Text(figure.figureType?.name ?? "").font(.system(size: 9)).foregroundColor(.secondary)
            : Text(figure.figureType?.name ?? "").font(.system(size: 9)).foregroundColor(.secondary)
        context.draw(
            typeText,
            at: CGPoint(x: frame.minX + 26, y: frame.minY + 32),
            anchor: .topLeading
        )

        if altCount > 0 {
            let badge = Text("+\(altCount)").font(.system(size: 8, weight: .bold)).foregroundColor(.white)
            let bw: CGFloat = altCount > 9 ? 24 : 18
            let badgeRect = CGRect(x: frame.maxX - bw - 2, y: frame.minY - 5, width: bw, height: 14)
            context.fill(Path(roundedRect: badgeRect, cornerRadius: 7), with: .color(Color.accentColor))
            context.draw(badge, at: CGPoint(x: badgeRect.midX, y: badgeRect.midY), anchor: .center)
        }
    }

    // MARK: - Interaction

    private func recenterTree(to figID: PersistentIdentifier) {
        guard figID != centerFigure?.persistentModelID,
              let fig = figures.first(where: { $0.persistentModelID == figID }) else { return }
        if let current = centerFigure {
            centerHistory.append(current)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            centerFigure = fig
            collapsedIDs.removeAll()
        }
    }

    private func goBack() {
        guard let previous = centerHistory.popLast() else { return }
        centerFigure = previous
        collapsedIDs.removeAll()
    }

    private func handleTap(at location: CGPoint, layout: LayoutResult) {
        let badgeW: CGFloat = 18
        let badgeH: CGFloat = 14
        for (figID, frame) in layout.nodeLayouts {
            let alt = layout.figureAltCounts[figID] ?? 0
            if alt > 0 {
                let bw: CGFloat = alt > 9 ? 24 : badgeW
                let badgeRect = CGRect(x: frame.maxX - bw - 2, y: frame.minY - 5, width: bw, height: badgeH)
                if badgeRect.contains(location) {
                    altForFigure = figures.first(where: { $0.persistentModelID == figID })
                    return
                }
            }
        }
        for (figID, frame) in layout.nodeLayouts {
            if frame.contains(location) {
                recenterTree(to: figID)
                return
            }
        }
    }

    private func figureAt(location: CGPoint, in layout: LayoutResult) -> PersistentIdentifier? {
        for (figID, frame) in layout.nodeLayouts where frame.contains(location) {
            return figID
        }
        return nil
    }

// MARK: - Sheet Views

private struct AlternativePartnersSheet: View {
    let figure: Figure
    let partners: [(figure: Figure, source: String?)]
    let onClose: () -> Void
    let onRecenter: (PersistentIdentifier) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Alternative partners of \(figure.name)")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding()
            Divider()
            if partners.isEmpty {
                Text("No alternative partners found.").foregroundStyle(.secondary).padding()
                Spacer()
            } else {
                List(partners, id: \.figure.persistentModelID) { partner in
                    HStack(spacing: 8) {
                        Circle().fill(partner.figure.figureType?.color ?? .gray).frame(width: 8, height: 8)
                        Text(partner.figure.name).font(.body)
                        Text(partner.figure.figureType?.name ?? "").font(.caption).foregroundStyle(.secondary)
                        if let source = partner.source {
                            SourceBadgeView(name: source)
                        }
                        Spacer()
                        Button("Recenter") {
                            onRecenter(partner.figure.persistentModelID)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(width: 360, height: 300)
    }
}

private struct FigureDetailSheet: View {
    let figure: Figure
    let onClose: () -> Void
    let onRecenter: (PersistentIdentifier) -> Void

    var body: some View {
        NavigationStack {
            FigureQuicklookView(figure: figure)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onClose)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Recenter Tree") {
                            onRecenter(figure.persistentModelID)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

    private func alternativePartners(of figure: Figure) -> [(figure: Figure, source: String?)] {
        let preferred = preferredPartner(of: figure)
        let rels = filteredRelationships.filter {
            ($0.relationshipType?.name == "Spouse" || $0.relationshipType?.name == "Consort") &&
            ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID)
        }
        var partners: [(figure: Figure, source: String?)] = []
        var seen = Set<PersistentIdentifier>()
        for rel in rels {
            let p = rel.fromFigure?.persistentModelID == figure.persistentModelID ? rel.toFigure : rel.fromFigure
            if let fig = p, seen.insert(fig.persistentModelID).inserted {
                partners.append((fig, rel.sourceDisplayName.isEmpty ? nil : rel.sourceDisplayName))
            }
        }
        if let pref = preferred {
            partners.removeAll { $0.figure.persistentModelID == pref.persistentModelID }
        }
        return partners
    }
}
