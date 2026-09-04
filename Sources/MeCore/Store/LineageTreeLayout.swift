import Foundation
import SwiftData

/// An entry in the lineage tree — a primary figure plus its (optional) preferred
/// partner rendered as a couple card.
package struct LineageEntry {
    package let primary: Figure
    package let partner: Figure?
    package let altPartnerCount: Int
    package let generation: Int

    package var id: String { "\(primary.name)@\(generation)" }

    package init(primary: Figure, partner: Figure?, altPartnerCount: Int, generation: Int) {
        self.primary = primary
        self.partner = partner
        self.altPartnerCount = altPartnerCount
        self.generation = generation
    }
}

/// The constructed tree: every entry, the entries grouped by generation, and the
/// parent-entry-ID → child-entry-ID edges used to draw connectors.
package struct LineageTreeData {
    package let rootID: PersistentIdentifier
    package let entries: [String: LineageEntry]
    package let levels: [[LineageEntry]]
    package let parentToChild: [String: [String]]

    package init(rootID: PersistentIdentifier, entries: [String: LineageEntry], levels: [[LineageEntry]], parentToChild: [String: [String]]) {
        self.rootID = rootID
        self.entries = entries
        self.levels = levels
        self.parentToChild = parentToChild
    }
}

/// The resolved geometry for a tree: every displayed figure's card frame, the
/// alternative-partner badge counts, and the canvas dimensions.
package struct LineageLayout {
    package let nodeLayouts: [PersistentIdentifier: CGRect]
    package let figureAltCounts: [PersistentIdentifier: Int]
    package let canvasWidth: CGFloat
    package let canvasHeight: CGFloat

    package init(nodeLayouts: [PersistentIdentifier: CGRect], figureAltCounts: [PersistentIdentifier: Int], canvasWidth: CGFloat, canvasHeight: CGFloat) {
        self.nodeLayouts = nodeLayouts
        self.figureAltCounts = figureAltCounts
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }
}

/// A single connector line segment to be stroked by the view.
package struct LineageSegment: Equatable {
    package let start: CGPoint
    package let end: CGPoint

    package init(start: CGPoint, end: CGPoint) {
        self.start = start
        self.end = end
    }
}

/// Pure tree-building and layout math behind the lineage tree view.
///
/// Building the entries, assigning card frames, and deriving the connector
/// segments is deterministic work over the figure/relationship models — no
/// SwiftUI involved. Keeping it here (mirroring `SKLDatePropagator`) makes the
/// whole layout unit-testable off the render path.
package enum LineageTreeLayout {

    /// Tunable geometry. Defaults match the classic lineage view; tests can
    /// shrink spacings to exercise edge cases without huge canvases.
    package struct Metrics: Equatable {
        package var cardWidth: CGFloat
        package var cardHeight: CGFloat
        package var coupleSpacing: CGFloat
        package var partnerSpacing: CGFloat
        package var verticalSpacing: CGFloat
        package var canvasPadding: CGFloat
        package var branchBarOffset: CGFloat

        package init(
            cardWidth: CGFloat = 120,
            cardHeight: CGFloat = 52,
            coupleSpacing: CGFloat = 36,
            partnerSpacing: CGFloat = 14,
            verticalSpacing: CGFloat = 130,
            canvasPadding: CGFloat = 60,
            branchBarOffset: CGFloat = 16
        ) {
            self.cardWidth = cardWidth
            self.cardHeight = cardHeight
            self.coupleSpacing = coupleSpacing
            self.partnerSpacing = partnerSpacing
            self.verticalSpacing = verticalSpacing
            self.canvasPadding = canvasPadding
            self.branchBarOffset = branchBarOffset
        }

        package static let standard = Metrics()
    }

    /// `true` for the synthetic placeholder figures the tree renders when a
    /// parent is unknown.
    package static func isUnknownParentName(_ name: String) -> Bool {
        name == "Unknown Father" || name == "Unknown Mother"
    }

    /// The figure's preferred partner (i.e. from the preferred spouse/consort
    /// relationship), or the first such partner when nothing is marked preferred.
    package static func preferredPartner(of figure: Figure, relationships: [Relationship]) -> Figure? {
        let rels = relationships.filter {
            ($0.relationshipType?.name == "Spouse" || $0.relationshipType?.name == "Consort") &&
            ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID)
        }
        guard let chosen = rels.first(where: { $0.isPreferred == true }) ?? rels.first else { return nil }
        return chosen.fromFigure?.persistentModelID == figure.persistentModelID ? chosen.toFigure : chosen.fromFigure
    }

    /// The number of distinct partners (spouse/consort) a figure has.
    package static func partnerCount(of figure: Figure, relationships: [Relationship]) -> Int {
        let rels = relationships.filter {
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

    // MARK: - Tree Building

    /// Builds the tree centered on `center`, walking `generationsAbove` ancestor
    /// levels and `generationsBelow` descendant levels. `relationships` should be
    /// pre-filtered (e.g. by source) exactly as the view wants to display them;
    /// figures whose `name` is in `collapsedNames` are not expanded.
    package static func buildTreeData(
        center: Figure,
        relationships: [Relationship],
        generationsAbove: Int,
        generationsBelow: Int,
        collapsedNames: Set<String>
    ) -> LineageTreeData {
        var entries: [String: LineageEntry] = [:]
        var levelsMap: [Int: [LineageEntry]] = [:]
        var parentToChild: [String: [String]] = [:]
        var seenFigures: Set<PersistentIdentifier> = []

        let centerPartner = preferredPartner(of: center, relationships: relationships)
        let centerAlt = partnerCount(of: center, relationships: relationships)
        let centerAltCount = max(0, centerAlt - (centerPartner != nil ? 1 : 0))
        let centerEntry = LineageEntry(primary: center, partner: centerPartner, altPartnerCount: centerAltCount, generation: 0)
        entries[centerEntry.id] = centerEntry
        levelsMap[0] = [centerEntry]
        seenFigures.insert(center.persistentModelID)
        if let partner = centerPartner {
            seenFigures.insert(partner.persistentModelID)
        }

        if generationsAbove > 0 {
            collectAncestors(of: center, currentGen: 0, maxGen: -generationsAbove, relationships: relationships, collapsedNames: collapsedNames, entries: &entries, levelsMap: &levelsMap, parentToChild: &parentToChild, seenFigures: &seenFigures)
        }

        if generationsBelow > 0 {
            var slotOwner: [PersistentIdentifier: String] = [center.persistentModelID: centerEntry.id]
            collectDescendants(of: center, currentGen: 0, maxGen: generationsBelow, relationships: relationships, collapsedNames: collapsedNames, entries: &entries, levelsMap: &levelsMap, parentToChild: &parentToChild, seenFigures: &seenFigures, slotOwner: &slotOwner)
        }

        let levels = levelsMap.sorted(by: { $0.key < $1.key }).map(\.value)
        return LineageTreeData(rootID: center.persistentModelID, entries: entries, levels: levels, parentToChild: parentToChild)
    }

    private static func collectAncestors(of figure: Figure, currentGen: Int, maxGen: Int, relationships: [Relationship], collapsedNames: Set<String>, entries: inout [String: LineageEntry], levelsMap: inout [Int: [LineageEntry]], parentToChild: inout [String: [String]], seenFigures: inout Set<PersistentIdentifier>) {
        let nextGen = currentGen - 1
        guard nextGen >= maxGen else { return }
        guard !collapsedNames.contains(figure.name) else { return }

        let rels = relationships.filter { $0.relationshipType?.category == "parent" && $0.toFigure?.persistentModelID == figure.persistentModelID }
        let childID = idFor(figure, gen: currentGen)

        if rels.isEmpty {
            // No parents defined at all: render a single Unknown couple so the
            // child centers under the midpoint between them (not per-card).
            let parentID = "Unknown Father@\(nextGen)"
            if entries[parentID] == nil {
                let fatherFig = Figure(name: "Unknown Father", gender: .male)
                let motherFig = Figure(name: "Unknown Mother", gender: .female)
                let entry = LineageEntry(primary: fatherFig, partner: motherFig, altPartnerCount: 0, generation: nextGen)
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

            let partner = preferredPartner(of: parentFig, relationships: relationships)

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

            let alt = max(0, partnerCount(of: parentFig, relationships: relationships) - (partner != nil ? 1 : 0))
            let entry = LineageEntry(primary: parentFig, partner: partner, altPartnerCount: alt, generation: nextGen)
            entries[entry.id] = entry
            levelsMap[nextGen, default: []].append(entry)
            parentToChild[entry.id, default: []].append(childID)
            parentedChildIDs.insert(childID)

            collectAncestors(of: parentFig, currentGen: nextGen, maxGen: maxGen, relationships: relationships, collapsedNames: collapsedNames, entries: &entries, levelsMap: &levelsMap, parentToChild: &parentToChild, seenFigures: &seenFigures)
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
                    existing = LineageEntry(primary: existing.primary, partner: placeholderFig, altPartnerCount: existing.altPartnerCount, generation: existing.generation)
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
                let entry = LineageEntry(primary: fatherFig, partner: motherFig, altPartnerCount: 0, generation: nextGen)
                entries[parentID] = entry
                levelsMap[nextGen, default: []].append(entry)
            }
            parentToChild[parentID, default: []].append(childID)
        }
    }

    private static func collectDescendants(of figure: Figure, currentGen: Int, maxGen: Int, relationships: [Relationship], collapsedNames: Set<String>, entries: inout [String: LineageEntry], levelsMap: inout [Int: [LineageEntry]], parentToChild: inout [String: [String]], seenFigures: inout Set<PersistentIdentifier>, slotOwner: inout [PersistentIdentifier: String]) {
        let nextGen = currentGen + 1
        guard nextGen <= maxGen else { return }
        guard !collapsedNames.contains(figure.name) else { return }

        let rels = relationships.filter { $0.relationshipType?.category == "parent" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
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
            let partner = preferredPartner(of: childFig, relationships: relationships)
            if let partnerPID = partner?.persistentModelID, placedChildren.contains(partnerPID) {
                continue
            }
            if let partner {
                placedChildren.insert(partner.persistentModelID)
                nextOwner[partner.persistentModelID] = childID
            }
            placedChildren.insert(childFig.persistentModelID)
            nextOwner[childFig.persistentModelID] = childID
            let alt = max(0, partnerCount(of: childFig, relationships: relationships) - (partner != nil ? 1 : 0))
            let entry = LineageEntry(primary: childFig, partner: partner, altPartnerCount: alt, generation: nextGen)
            entries[entry.id] = entry
            levelsMap[nextGen, default: []].append(entry)
            parentToChild[parentID, default: []].append(childID)
        }

        // Pass 3: recurse into each child
        for childFig in children {
            collectDescendants(of: childFig, currentGen: nextGen, maxGen: maxGen, relationships: relationships, collapsedNames: collapsedNames, entries: &entries, levelsMap: &levelsMap, parentToChild: &parentToChild, seenFigures: &seenFigures, slotOwner: &nextOwner)
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
                let updatedEntry = LineageEntry(primary: currentEntry.primary, partner: placeholder, altPartnerCount: currentEntry.altPartnerCount, generation: currentEntry.generation)
                entries[parentID] = updatedEntry
                if let idx = levelsMap[currentGen]?.firstIndex(where: { $0.id == parentID }) {
                    levelsMap[currentGen]?[idx] = updatedEntry
                }
            }
        }
    }

    private static func idFor(_ figure: Figure, gen: Int) -> String {
        "\(figure.name)@\(gen)"
    }

    // MARK: - Layout

    /// Computes card frames and canvas size for a built tree. The child
    /// generation of every couple is shifted so its primary cards sit under the
    /// parent couple's trunk.
    package static func computeLayout(data: LineageTreeData, metrics: Metrics) -> LineageLayout {
        var nodeLayouts: [PersistentIdentifier: CGRect] = [:]
        var figureAltCounts: [PersistentIdentifier: Int] = [:]
        var genWidths: [(Int, CGFloat)] = []
        let genKeys = data.levels.compactMap(\.first?.generation).sorted()

        for gen in genKeys {
            let entriesAtGen = data.levels.first(where: { $0.first?.generation == gen }) ?? []
            var w: CGFloat = 0
            for e in entriesAtGen {
                w += metrics.cardWidth
                if e.partner != nil { w += metrics.partnerSpacing + metrics.cardWidth }
            }
            w += CGFloat(max(0, entriesAtGen.count - 1)) * metrics.coupleSpacing
            genWidths.append((gen, w))
        }

        guard !genWidths.isEmpty else {
            return LineageLayout(nodeLayouts: [:], figureAltCounts: [:], canvasWidth: 600, canvasHeight: 400)
        }

        let maxW = (genWidths.map(\.1).max() ?? 0) + metrics.canvasPadding * 2
        let minGen = genKeys.min() ?? 0
        let maxGen = genKeys.max() ?? 0
        let topNeeded = 2 * (metrics.canvasPadding + metrics.cardHeight / 2 - CGFloat(minGen) * metrics.verticalSpacing)
        let bottomNeeded = 2 * (metrics.canvasPadding + metrics.cardHeight / 2 + CGFloat(maxGen) * metrics.verticalSpacing)
        let totalH = max(topNeeded, bottomNeeded)

        for gen in genKeys {
            let entriesAtGen = data.levels.first(where: { $0.first?.generation == gen }) ?? []
            let genW = genWidths.first(where: { $0.0 == gen })?.1 ?? 0
            let startX = (maxW - genW) / 2
            let y = totalH / 2 + CGFloat(gen) * metrics.verticalSpacing - metrics.cardHeight / 2
            var cx = startX

            for entry in entriesAtGen {
                nodeLayouts[entry.primary.persistentModelID] = CGRect(x: cx, y: y, width: metrics.cardWidth, height: metrics.cardHeight)
                figureAltCounts[entry.primary.persistentModelID] = entry.altPartnerCount
                cx += metrics.cardWidth

                if let partner = entry.partner {
                    cx += metrics.partnerSpacing
                    nodeLayouts[partner.persistentModelID] = CGRect(x: cx, y: y, width: metrics.cardWidth, height: metrics.cardHeight)
                    figureAltCounts[partner.persistentModelID] = 0
                    cx += metrics.cardWidth
                }
                cx += metrics.coupleSpacing
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
        let adjustedWidth = max(600, contentWidth + metrics.canvasPadding * 2)
        let recenterShift = (adjustedWidth - contentWidth) / 2 - contentMinX
        if abs(recenterShift) > 2 {
            for (id, frame) in nodeLayouts {
                nodeLayouts[id] = frame.offsetBy(dx: recenterShift, dy: 0)
            }
        }

        return LineageLayout(nodeLayouts: nodeLayouts, figureAltCounts: figureAltCounts, canvasWidth: adjustedWidth, canvasHeight: max(400, totalH))
    }

    private static func shiftSubtree(from entryID: String, dx: CGFloat, data: LineageTreeData, nodeLayouts: inout [PersistentIdentifier: CGRect]) {
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

    // MARK: - Connector Segments

    /// Computes every bracket connector for the tree: per parent→children link,
    /// stubs and a marriage bar down from a couple, then a trunk and branch bar
    /// leading to each child's drop line.
    package static func bracketSegments(data: LineageTreeData, layout: LineageLayout, metrics: Metrics) -> [LineageSegment] {
        var all: [LineageSegment] = []
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

            all.append(contentsOf: segmentsForBracket(parentFrames: parentFrames, childFrames: childFrames, branchBarOffset: metrics.branchBarOffset))
        }
        return all
    }

    /// Pure bracket geometry for one parent→children link.
    ///
    /// For a couple the two parents get stubs down to a shared marriage bar;
    /// a trunk drops from the parent group's midpoint, a branch bar spans the
    /// children above their tops, and every child gets a drop line from the
    /// branch bar to its own top edge.
    package static func segmentsForBracket(parentFrames: [CGRect], childFrames: [CGRect], branchBarOffset: CGFloat, marriageGap: CGFloat = 14) -> [LineageSegment] {
        guard !parentFrames.isEmpty, !childFrames.isEmpty else { return [] }

        var out: [LineageSegment] = []
        let marriageY = (parentFrames.map(\.maxY).max() ?? 0) + marriageGap
        if parentFrames.count > 1 {
            let lx = parentFrames.map(\.midX).min()!
            let rx = parentFrames.map(\.midX).max()!
            for pf in parentFrames {
                out.append(LineageSegment(start: CGPoint(x: pf.midX, y: pf.maxY), end: CGPoint(x: pf.midX, y: marriageY)))
            }
            out.append(LineageSegment(start: CGPoint(x: lx, y: marriageY), end: CGPoint(x: rx, y: marriageY)))
        }

        let trunkX = parentFrames.map(\.midX).reduce(0, +) / CGFloat(parentFrames.count)
        let childTopY = childFrames.map(\.minY).min() ?? 0
        let branchBarY = childTopY - branchBarOffset
        guard branchBarY > marriageY + 4 else { return out }

        out.append(LineageSegment(start: CGPoint(x: trunkX, y: marriageY), end: CGPoint(x: trunkX, y: branchBarY)))
        let allX = childFrames.map(\.midX) + [trunkX]
        let minX = allX.min()!
        let maxX = allX.max()!
        if maxX - minX > 2 {
            out.append(LineageSegment(start: CGPoint(x: minX, y: branchBarY), end: CGPoint(x: maxX, y: branchBarY)))
        }
        for cf in childFrames {
            out.append(LineageSegment(start: CGPoint(x: cf.midX, y: branchBarY), end: CGPoint(x: cf.midX, y: cf.minY)))
        }
        return out
    }
}