import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
    // MARK: - LineageTreeLayout

    func makeLineageFixture(_ context: ModelContext) -> (father: RelationshipType, mother: RelationshipType, spouse: RelationshipType) {
        let father = RelationshipType(name: "Father", icon: "", colorHex: "#4A90D9", category: "parent")
        let mother = RelationshipType(name: "Mother", icon: "", colorHex: "#D94A64", category: "parent")
        let spouse = RelationshipType(name: "Spouse", icon: "", colorHex: "#888888", category: "partner")
        context.insert(father)
        context.insert(mother)
        context.insert(spouse)
        try? context.save()
        return (father, mother, spouse)
    }

    @discardableResult
    func makeTreeFigure(_ context: ModelContext, _ name: String, _ gender: Figure.Gender = .male) -> Figure {
        let f = Figure(name: name, gender: gender)
        context.insert(f)
        return f
    }

    @discardableResult
    func makeParentRel(_ context: ModelContext, parent: Figure, child: Figure, type: RelationshipType, preferred: Bool = false) -> Relationship {
        let rel = Relationship(fromFigure: parent, toFigure: child, relationshipType: type, source: "test", isPreferred: preferred)
        context.insert(rel)
        return rel
    }

    @discardableResult
    func makeSpouseRel(_ context: ModelContext, _ a: Figure, _ b: Figure, type: RelationshipType, preferred: Bool = false) -> Relationship {
        let rel = Relationship(fromFigure: a, toFigure: b, relationshipType: type, source: "test", isPreferred: preferred)
        context.insert(rel)
        return rel
    }

    func framesForGeneration(_ gen: Int, data: LineageTreeData, layout: LineageLayout) -> [CGRect] {
        var frames: [CGRect] = []
        for entry in data.entries.values where entry.generation == gen {
            if let f = layout.nodeLayouts[entry.primary.persistentModelID] { frames.append(f) }
            if let partner = entry.partner, let f = layout.nodeLayouts[partner.persistentModelID] { frames.append(f) }
        }
        return frames
    }

    func makeThreeGenerationFamily(_ context: ModelContext) -> (father: RelationshipType, mother: RelationshipType, spouse: RelationshipType, anu: Figure) {
        let types = makeLineageFixture(context)
        let an = makeTreeFigure(context, "An")
        let nammu = makeTreeFigure(context, "Nammu", .female)
        let anu = makeTreeFigure(context, "Anu")
        let antu = makeTreeFigure(context, "Antu", .female)
        let enlil = makeTreeFigure(context, "Enlil")
        let ninlil = makeTreeFigure(context, "Ninlil", .female)
        let enki = makeTreeFigure(context, "Enki")
        let damkina = makeTreeFigure(context, "Damkina", .female)
        let sin = makeTreeFigure(context, "Sin")
        let shala = makeTreeFigure(context, "Shala", .female)

        makeParentRel(context, parent: an, child: anu, type: types.father)
        makeParentRel(context, parent: nammu, child: anu, type: types.mother)
        makeSpouseRel(context, anu, antu, type: types.spouse, preferred: true)
        makeParentRel(context, parent: anu, child: enlil, type: types.father)
        makeParentRel(context, parent: antu, child: enlil, type: types.mother)
        makeParentRel(context, parent: anu, child: enki, type: types.father)
        makeParentRel(context, parent: antu, child: enki, type: types.mother)
        makeParentRel(context, parent: enlil, child: sin, type: types.father)
        makeParentRel(context, parent: ninlil, child: sin, type: types.mother)
        makeSpouseRel(context, enlil, ninlil, type: types.spouse)
        makeSpouseRel(context, enki, damkina, type: types.spouse)
        makeSpouseRel(context, sin, shala, type: types.spouse)
        try? context.save()

        return (types.father, types.mother, types.spouse, anu)
    }

    func testLineageTreeLayoutBuildsThreeGenerations() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixtures = makeThreeGenerationFamily(context)
        let anu = fixtures.anu
        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []

        let data = LineageTreeLayout.buildTreeData(center: anu, relationships: allRels, generationsAbove: 1, generationsBelow: 1, collapsedNames: [])

        XCTAssertEqual(data.rootID, anu.persistentModelID)
        XCTAssertEqual(data.levels.count, 3)
        XCTAssertEqual(Set(data.levels.map { $0.first?.generation ?? 99 }), Set([-1, 0, 1]))

        let center = data.entries["Anu@0"]
        XCTAssertNotNil(center)
        XCTAssertEqual(center?.generation, 0)
        XCTAssertEqual(center?.partner?.name, "Antu")

        XCTAssertTrue(data.entries.keys.contains("An@-1"))
        XCTAssertTrue(data.entries.keys.contains("Enki@1"))
        XCTAssertTrue(data.entries.keys.contains("Enlil@1"))

        XCTAssertEqual(data.parentToChild["An@-1"], ["Anu@0"])
    }

    func testLineageTreeLayoutPreferredPartnerAndAltCount() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixture = makeLineageFixture(context)
        let center = makeTreeFigure(context, "Anu")
        let antu = makeTreeFigure(context, "Antu", .female)
        let tiamat = makeTreeFigure(context, "Tiamat", .female)
        makeSpouseRel(context, center, antu, type: fixture.spouse, preferred: true)
        makeSpouseRel(context, center, tiamat, type: fixture.spouse)
        try? context.save()

        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let data = LineageTreeLayout.buildTreeData(center: center, relationships: allRels, generationsAbove: 0, generationsBelow: 0, collapsedNames: [])
        let layout = LineageTreeLayout.computeLayout(data: data, metrics: .standard)

        let entry = data.entries["Anu@0"]
        XCTAssertEqual(entry?.partner?.name, "Antu", "preferred partner must win")
        XCTAssertEqual(entry?.altPartnerCount, 1, "one of two partners is the preferred one")
        XCTAssertEqual(layout.figureAltCounts[center.persistentModelID], 1)
    }

    func testLineageTreeLayoutChildGroupAlignsUnderParentTrunk() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixture = makeLineageFixture(context)
        let anu = makeTreeFigure(context, "Anu")
        let antu = makeTreeFigure(context, "Antu", .female)
        let kids = (0..<4).map { makeTreeFigure(context, "Kid\($0)") }
        let spouses = (0..<4).map { makeTreeFigure(context, "Spouse\($0)", .female) }
        for i in kids.indices {
            makeParentRel(context, parent: anu, child: kids[i], type: fixture.father)
            makeParentRel(context, parent: antu, child: kids[i], type: fixture.mother)
            makeSpouseRel(context, kids[i], spouses[i], type: fixture.spouse)
        }
        try? context.save()

        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let data = LineageTreeLayout.buildTreeData(center: anu, relationships: allRels, generationsAbove: 0, generationsBelow: 2, collapsedNames: [])
        let layout = LineageTreeLayout.computeLayout(data: data, metrics: .standard)

        for (parentID, childIDs) in data.parentToChild {
            guard let parentEntry = data.entries[parentID] else { continue }
            let parentIDs = [parentEntry.primary.persistentModelID] + (parentEntry.partner.map { [$0.persistentModelID] } ?? [])
            let parentFrames = parentIDs.compactMap { layout.nodeLayouts[$0] }
            let childFrames = childIDs.compactMap { cid -> CGRect? in
                guard let ce = data.entries[cid] else { return nil }
                return layout.nodeLayouts[ce.primary.persistentModelID]
            }
            guard !parentFrames.isEmpty, !childFrames.isEmpty else { continue }
            let trunkX = parentFrames.map(\.midX).reduce(0, +) / CGFloat(parentFrames.count)
            let childGroupMidX = childFrames.map(\.midX).reduce(0, +) / CGFloat(childFrames.count)
            XCTAssertEqual(childGroupMidX, trunkX, accuracy: 2.01, "children of \(parentID) must sit under the parent trunk")
        }
    }

    func testLineageTreeLayoutCardsDoNotOverlapWithinGeneration() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixture = makeLineageFixture(context)
        let anu = makeTreeFigure(context, "Anu")
        let antu = makeTreeFigure(context, "Antu", .female)
        let kids = (0..<4).map { makeTreeFigure(context, "Kid\($0)") }
        let spouses = (0..<4).map { makeTreeFigure(context, "Spouse\($0)", .female) }
        for i in kids.indices {
            makeParentRel(context, parent: anu, child: kids[i], type: fixture.father)
            makeParentRel(context, parent: antu, child: kids[i], type: fixture.mother)
            makeSpouseRel(context, kids[i], spouses[i], type: fixture.spouse)
        }
        try? context.save()

        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let data = LineageTreeLayout.buildTreeData(center: anu, relationships: allRels, generationsAbove: 0, generationsBelow: 1, collapsedNames: [])
        let layout = LineageTreeLayout.computeLayout(data: data, metrics: .standard)

        for level in data.levels {
            let gen = level.first?.generation ?? 0
            let frames = framesForGeneration(gen, data: data, layout: layout)
            for i in 0..<frames.count {
                for j in (i + 1)..<frames.count {
                    XCTAssertFalse(frames[i].intersects(frames[j]), "generation \(gen) cards overlap: \(frames[i]) vs \(frames[j])")
                }
            }
        }
    }

    func testLineageTreeLayoutCoupleCardsAreAdjacent() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixture = makeLineageFixture(context)
        let anu = makeTreeFigure(context, "Anu")
        let antu = makeTreeFigure(context, "Antu", .female)
        makeSpouseRel(context, anu, antu, type: fixture.spouse)
        try? context.save()

        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let data = LineageTreeLayout.buildTreeData(center: anu, relationships: allRels, generationsAbove: 0, generationsBelow: 0, collapsedNames: [])
        let layout = LineageTreeLayout.computeLayout(data: data, metrics: .standard)

        guard let anuFrame = layout.nodeLayouts[anu.persistentModelID],
              let antuFrame = layout.nodeLayouts[antu.persistentModelID] else {
            XCTFail("missing couple frames")
            return
        }
        XCTAssertEqual(anuFrame.minY, antuFrame.minY)
        XCTAssertEqual(antuFrame.minX - anuFrame.maxX, MetricsTestConstants.partnerGap, accuracy: 0.001)
        XCTAssertEqual(antuFrame.width, anuFrame.width)
        XCTAssertEqual(antuFrame.height, anuFrame.height)
    }

    func testLineageTreeLayoutGenerationsVerticallySpaced() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixture = makeLineageFixture(context)
        let anu = makeTreeFigure(context, "Anu")
        let antu = makeTreeFigure(context, "Antu", .female)
        let kid = makeTreeFigure(context, "Kid")
        makeSpouseRel(context, anu, antu, type: fixture.spouse)
        makeParentRel(context, parent: anu, child: kid, type: fixture.father)
        makeParentRel(context, parent: antu, child: kid, type: fixture.mother)
        try? context.save()

        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let data = LineageTreeLayout.buildTreeData(center: anu, relationships: allRels, generationsAbove: 0, generationsBelow: 1, collapsedNames: [])
        let layout = LineageTreeLayout.computeLayout(data: data, metrics: .standard)

        guard let centerFrame = layout.nodeLayouts[anu.persistentModelID],
              let childFrame = layout.nodeLayouts[kid.persistentModelID] else {
            XCTFail("missing frames")
            return
        }
        XCTAssertEqual(childFrame.minY - centerFrame.minY, MetricsTestConstants.verticalGap, accuracy: 0.001)
    }

    func testLineageTreeLayoutCanvasContainsAllContent() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixtures = makeThreeGenerationFamily(context)
        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []

        let data = LineageTreeLayout.buildTreeData(center: fixtures.anu, relationships: allRels, generationsAbove: 1, generationsBelow: 2, collapsedNames: [])
        let layout = LineageTreeLayout.computeLayout(data: data, metrics: .standard)

        XCTAssertGreaterThanOrEqual(layout.canvasWidth, 600)
        XCTAssertGreaterThanOrEqual(layout.canvasHeight, 400)
        for (_, frame) in layout.nodeLayouts {
            XCTAssertGreaterThanOrEqual(frame.minX, 0)
            XCTAssertLessThanOrEqual(frame.maxX, layout.canvasWidth)
            XCTAssertGreaterThanOrEqual(frame.minY, 0)
            XCTAssertLessThanOrEqual(frame.maxY, layout.canvasHeight)
        }
    }

    func testLineageTreeLayoutDescendantSideUnknownPlaceholder() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixture = makeLineageFixture(context)
        let adam = makeTreeFigure(context, "Adam")
        let cain = makeTreeFigure(context, "Cain")
        makeParentRel(context, parent: adam, child: cain, type: fixture.father)
        try? context.save()

        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let data = LineageTreeLayout.buildTreeData(center: adam, relationships: allRels, generationsAbove: 0, generationsBelow: 1, collapsedNames: [])

        let entry = data.entries["Adam@0"]
        XCTAssertEqual(entry?.partner?.name, "Unknown Mother", "a father with children but no mother rel gets the placeholder spouse")
        XCTAssertEqual(entry?.partner?.gender, .female)
    }

    func testLineageTreeLayoutAncestorSideUnknownCouplePlaceholder() {
        let container = makeContainer()
        let context = ModelContext(container)
        let orphan = makeTreeFigure(context, "Orphan")
        try? context.save()
        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []

        let data = LineageTreeLayout.buildTreeData(center: orphan, relationships: allRels, generationsAbove: 1, generationsBelow: 0, collapsedNames: [])

        let entry = data.entries["Unknown Father@-1"]
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.primary.name, "Unknown Father")
        XCTAssertEqual(entry?.partner?.name, "Unknown Mother")
        XCTAssertEqual(entry?.generation, -1)
        XCTAssertEqual(data.parentToChild["Unknown Father@-1"], ["Orphan@0"])
    }

    func testLineageTreeLayoutCollapseStopsExpansion() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixture = makeLineageFixture(context)
        let grandpa = makeTreeFigure(context, "Grandpa")
        let papa = makeTreeFigure(context, "Papa")
        let me = makeTreeFigure(context, "Me")
        let son = makeTreeFigure(context, "Son")
        let grandson = makeTreeFigure(context, "Grandson")
        makeParentRel(context, parent: grandpa, child: papa, type: fixture.father)
        makeParentRel(context, parent: papa, child: me, type: fixture.father)
        makeParentRel(context, parent: me, child: son, type: fixture.father)
        makeParentRel(context, parent: son, child: grandson, type: fixture.father)
        try? context.save()

        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let data = LineageTreeLayout.buildTreeData(center: me, relationships: allRels, generationsAbove: 2, generationsBelow: 2, collapsedNames: ["Papa", "Son"])

        XCTAssertTrue(data.entries.keys.contains("Papa@-1"), "collapsed node itself still appears")
        XCTAssertTrue(data.entries.keys.contains("Son@1"), "collapsed node itself still appears")
        XCTAssertFalse(data.entries.keys.contains("Grandpa@-2"), "ancestors of a collapsed node must not render")
        XCTAssertFalse(data.entries.keys.contains("Grandson@2"), "descendants of a collapsed node must not render")
        XCTAssertEqual(data.entries.keys.filter { $0.hasSuffix("@-2") }.count, 0)
        XCTAssertEqual(data.entries.keys.filter { $0.hasSuffix("@2") }.count, 0)
    }

    func testLineageTreeLayoutIsUnknownParentName() {
        XCTAssertTrue(LineageTreeLayout.isUnknownParentName("Unknown Father"))
        XCTAssertTrue(LineageTreeLayout.isUnknownParentName("Unknown Mother"))
        XCTAssertFalse(LineageTreeLayout.isUnknownParentName("Anu"))
        XCTAssertFalse(LineageTreeLayout.isUnknownParentName(""))
    }

    // MARK: - Lineage bracket segments

    func testLineageBracketSegmentsCoupleGeometry() {
        let p1 = CGRect(x: 100, y: 100, width: 120, height: 52)
        let p2 = CGRect(x: 234, y: 100, width: 120, height: 52)
        let c1 = CGRect(x: 120, y: 300, width: 120, height: 52)
        let c2 = CGRect(x: 320, y: 300, width: 120, height: 52)

        let segments = LineageTreeLayout.segmentsForBracket(parentFrames: [p1, p2], childFrames: [c1, c2], branchBarOffset: 16)

        let expected: [LineageSegment] = [
            LineageSegment(start: CGPoint(x: 160, y: 152), end: CGPoint(x: 160, y: 166)),
            LineageSegment(start: CGPoint(x: 294, y: 152), end: CGPoint(x: 294, y: 166)),
            LineageSegment(start: CGPoint(x: 160, y: 166), end: CGPoint(x: 294, y: 166)),
            LineageSegment(start: CGPoint(x: 227, y: 166), end: CGPoint(x: 227, y: 284)),
            LineageSegment(start: CGPoint(x: 180, y: 284), end: CGPoint(x: 380, y: 284)),
            LineageSegment(start: CGPoint(x: 180, y: 284), end: CGPoint(x: 180, y: 300)),
            LineageSegment(start: CGPoint(x: 380, y: 284), end: CGPoint(x: 380, y: 300)),
        ]
        XCTAssertEqual(segments, expected)
    }

    func testLineageBracketSegmentsSingleParentOmitsMarriageBar() {
        let parent = CGRect(x: 100, y: 100, width: 120, height: 52)
        let c1 = CGRect(x: 140, y: 300, width: 120, height: 52)
        let c2 = CGRect(x: 380, y: 300, width: 120, height: 52)

        let segments = LineageTreeLayout.segmentsForBracket(parentFrames: [parent], childFrames: [c1, c2], branchBarOffset: 16)

        let expected: [LineageSegment] = [
            LineageSegment(start: CGPoint(x: 160, y: 166), end: CGPoint(x: 160, y: 284)),
            LineageSegment(start: CGPoint(x: 160, y: 284), end: CGPoint(x: 440, y: 284)),
            LineageSegment(start: CGPoint(x: 200, y: 284), end: CGPoint(x: 200, y: 300)),
            LineageSegment(start: CGPoint(x: 440, y: 284), end: CGPoint(x: 440, y: 300)),
        ]
        XCTAssertEqual(segments, expected)
    }

    func testLineageBracketSegmentsCoversRealTree() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixture = makeLineageFixture(context)
        let anu = makeTreeFigure(context, "Anu")
        let antu = makeTreeFigure(context, "Antu", .female)
        let enlil = makeTreeFigure(context, "Enlil")
        let enki = makeTreeFigure(context, "Enki")
        makeSpouseRel(context, anu, antu, type: fixture.spouse)
        makeParentRel(context, parent: anu, child: enlil, type: fixture.father)
        makeParentRel(context, parent: antu, child: enlil, type: fixture.mother)
        makeParentRel(context, parent: anu, child: enki, type: fixture.father)
        makeParentRel(context, parent: antu, child: enki, type: fixture.mother)
        try? context.save()

        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let data = LineageTreeLayout.buildTreeData(center: anu, relationships: allRels, generationsAbove: 0, generationsBelow: 1, collapsedNames: [])
        let layout = LineageTreeLayout.computeLayout(data: data, metrics: .standard)
        let segments = LineageTreeLayout.bracketSegments(data: data, layout: layout, metrics: .standard)

        XCTAssertFalse(segments.isEmpty)

        for segment in segments {
            let isHorizontal = segment.start.y == segment.end.y
            let isVertical = segment.start.x == segment.end.x
            XCTAssertTrue(isHorizontal || isVertical, "bracket segments must be axis-aligned: \(segment)")
        }

        guard let anuFrame = layout.nodeLayouts[anu.persistentModelID],
              let antuFrame = layout.nodeLayouts[antu.persistentModelID] else {
            XCTFail("missing parent frames")
            return
        }
        let marriageY = max(anuFrame.maxY, antuFrame.maxY) + 14
        let hasMarriageBar = segments.contains {
            $0.start.y == marriageY && $0.end.y == marriageY
        }
        XCTAssertTrue(hasMarriageBar, "a couple link must draw a marriage bar at y=\(marriageY)")

        for child in [enlil, enki] {
            guard let childFrame = layout.nodeLayouts[child.persistentModelID] else {
                XCTFail("missing child frame for \(child.name)")
                continue
            }
            let hasDropLine = segments.contains {
                $0.end == CGPoint(x: childFrame.midX, y: childFrame.minY) && $0.start.y < childFrame.minY
            }
            XCTAssertTrue(hasDropLine, "each child \(child.name) must have a drop line onto its top edge")
        }
    }

    enum MetricsTestConstants {
        static let partnerGap: CGFloat = 14
        static let verticalGap: CGFloat = 130
    }

    func testLineageTreeLayoutTrunkOriginatesAtCoupleMidpoint() {
        let container = makeContainer()
        let context = ModelContext(container)
        let fixture = makeLineageFixture(context)
        let kid = makeTreeFigure(context, "Kid")
        let dad = makeTreeFigure(context, "Dad")
        let mom = makeTreeFigure(context, "Mom", .female)
        makeParentRel(context, parent: dad, child: kid, type: fixture.father)
        makeParentRel(context, parent: mom, child: kid, type: fixture.mother)
        try? context.save()

        let allRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        for name in ["both", "father", "mother"] {
            let rels: [Relationship]
            switch name {
            case "father": rels = allRels.filter { $0.relationshipType?.name == "Father" }
            case "mother": rels = allRels.filter { $0.relationshipType?.name == "Mother" }
            default: rels = []
            }
            let data = LineageTreeLayout.buildTreeData(center: kid, relationships: rels, generationsAbove: 1, generationsBelow: 0, collapsedNames: [])
            let layout = LineageTreeLayout.computeLayout(data: data, metrics: .standard)
            let segments = LineageTreeLayout.bracketSegments(data: data, layout: layout, metrics: .standard)
            let keys = data.entries.values.filter { $0.generation == -1 }
            let parentFrames = keys.flatMap { entry -> [CGRect] in
                [entry.primary, entry.partner].compactMap { fig in
                    guard let fig, let f = layout.nodeLayouts[fig.persistentModelID] else { return nil }
                    return f
                }
            }
            guard parentFrames.count == 2 else {
                XCTFail("\(name): expected 2 parent frames, got \(parentFrames.count)")
                continue
            }
            let marriageY = parentFrames.map(\.maxY).max()! + 14
            let trunks = segments.filter { $0.start.x == $0.end.x && abs($0.start.y - marriageY) < 0.001 && $0.end.y > $0.start.y }
            let expectedMid = (parentFrames[0].midX + parentFrames[1].midX) / 2
            XCTAssertEqual(trunks.count, 1, "\(name): exactly one trunk from marriage bar")
            if let trunk = trunks.first {
                XCTAssertEqual(trunk.start.x, expectedMid, accuracy: 0.001, "\(name): trunk must originate at couple midpoint")
            }
            if let kidFrame = layout.nodeLayouts[kid.persistentModelID] {
                XCTAssertEqual(kidFrame.midX, expectedMid, accuracy: 0.001, "\(name): child centered under couple midpoint")
            }
        }
    }

}
