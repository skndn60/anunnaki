import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
    // MARK: - Group ordering (sortMode / orderIndex)

    func testGroupSortModeDefaultsToAlphabetical() {
        let group = FigureGroup(name: "Council")
        XCTAssertEqual(group.sortMode, .alphabetical)
    }

    func testGroupSortModeBackwardsCompatibleNil() {
        let group = FigureGroup(name: "Council", sortMode: .ordered)
        group.sortModeRawValue = nil
        XCTAssertEqual(group.sortMode, .alphabetical)
    }

    func testGroupSortModeRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings", sortMode: .ordered)
        context.insert(group)
        try? context.save()
        XCTAssertEqual(group.sortMode, .ordered)
        XCTAssertEqual(group.sortModeRawValue, "ordered")
    }

    func makeFigureGroupWithMembers(context: ModelContext, names: [String]) -> FigureGroup {
        let group = FigureGroup(name: "Test")
        context.insert(group)
        for name in names {
            let f = Figure(name: name)
            context.insert(f)
            let assoc = FigureGroupAssociation(figure: f)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        return group
    }

    func addSubgroup(_ sub: FigureGroup, to group: FigureGroup) {
        if group.subgroups == nil { group.subgroups = [] }
        group.subgroups?.append(sub)
    }

    func testSortedAssociationsAlphabeticalByDefault() {
        let container = makeContainer()
        let context = container.mainContext
        let group = makeFigureGroupWithMembers(context: context, names: ["Ziusudra", "Enki", "Abzu"])
        try? context.save()

        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["Abzu", "Enki", "Ziusudra"])
    }

    func testSortedAssociationsOrderedByOrderIndex() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings", sortMode: .ordered)
        context.insert(group)
        let alulu = Figure(name: "Alulim")
        let alalgar = Figure(name: "Alalgar")
        let ziusudra = Figure(name: "Ziusudra")
        for f in [alulu, alalgar, ziusudra] { context.insert(f) }
        for (i, f) in [alalgar, ziusudra, alulu].enumerated() {
            let assoc = FigureGroupAssociation(figure: f, orderIndex: i)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["Alalgar", "Ziusudra", "Alulim"])
    }

    func testSortedAssociationsOrderIndexDefersToNameWhenNil() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings", sortMode: .ordered)
        context.insert(group)
        // C has an explicit high orderIndex; A and B are nil (tie-break by name).
        let a = Figure(name: "A")
        let b = Figure(name: "B")
        let c = Figure(name: "C")
        for f in [a, b, c] { context.insert(f) }
        for assoc in [
            FigureGroupAssociation(figure: a),
            FigureGroupAssociation(figure: b),
            FigureGroupAssociation(figure: c, orderIndex: 99)
        ] {
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["C", "A", "B"])
    }

    func testSetSortModeOrderedSeedsSequentialIndexes() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings")
        context.insert(group)
        let a = Figure(name: "Ziu")
        let b = Figure(name: "Anu")
        for f in [a, b] { context.insert(f) }
        for assoc in [FigureGroupAssociation(figure: a), FigureGroupAssociation(figure: b)] {
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        group.setSortMode(.ordered)
        let indexes = group.figureAssociations.compactMap(\.orderIndex).sorted()
        XCTAssertEqual(indexes, [0, 1])
        XCTAssertEqual(group.sortMode, .ordered)
    }

    func testMoveAssociationSwapsOrder() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "A")
        let b = Figure(name: "B")
        let c = Figure(name: "C")
        for f in [a, b, c] { context.insert(f) }
        let assocs = [FigureGroupAssociation(figure: a, orderIndex: 0),
                      FigureGroupAssociation(figure: b, orderIndex: 1),
                      FigureGroupAssociation(figure: c, orderIndex: 2)]
        for assoc in assocs { context.insert(assoc); group.figureAssociations.append(assoc) }
        try? context.save()

        // Move C (at index 2) up by one -> [A, C, B]
        group.moveAssociation(assocs[2], direction: -1)
        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["A", "C", "B"])

        // Moving top member up is a no-op.
        group.moveAssociation(assocs[0], direction: -1)
        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name }, ["A", "C", "B"])
    }

    func testSortedSubgroupsOrderedByOrderIndex() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page", sortMode: .ordered)
        context.insert(group)
        let one = FigureGroup(name: "One", orderIndex: 1)
        let zero = FigureGroup(name: "Zero", orderIndex: 0)
        let two = FigureGroup(name: "Two", orderIndex: 2)
        for sub in [two, zero, one] {
            context.insert(sub)
            addSubgroup(sub, to: group)
        }
        try? context.save()

        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["Zero", "One", "Two"])
    }

    func testSortedSubgroupsNameTieBreakWhenNil() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page", sortMode: .ordered)
        context.insert(group)
        // No explicit orderIndex: tie-break by name.
        let b = FigureGroup(name: "Beta")
        let a = FigureGroup(name: "Alpha")
        for sub in [b, a] {
            context.insert(sub)
            addSubgroup(sub, to: group)
        }
        try? context.save()

        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["Alpha", "Beta"])
    }

    func testSetSortModeOrderedSeedsSubgroupIndexes() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page")
        context.insert(group)
        let zeta = FigureGroup(name: "Zeta")
        let alpha = FigureGroup(name: "Alpha")
        for sub in [zeta, alpha] {
            context.insert(sub)
            addSubgroup(sub, to: group)
        }
        try? context.save()

        group.setSortMode(.ordered)
        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["Alpha", "Zeta"])
        XCTAssertEqual(alpha.orderIndex, 0)
        XCTAssertEqual(zeta.orderIndex, 1)
    }

    func testMoveSubgroupSwapsOrder() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page", sortMode: .ordered)
        context.insert(group)
        let a = FigureGroup(name: "A", orderIndex: 0)
        let b = FigureGroup(name: "B", orderIndex: 1)
        let c = FigureGroup(name: "C", orderIndex: 2)
        for sub in [a, b, c] {
            context.insert(sub)
            addSubgroup(sub, to: group)
        }
        try? context.save()

        // Move C (at index 2) up by one -> [A, C, B]
        group.moveSubgroup(c, direction: -1)
        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["A", "C", "B"])

        // Moving top subgroup up is a no-op.
        group.moveSubgroup(a, direction: -1)
        XCTAssertEqual(group.sortedSubgroups.map(\.name), ["A", "C", "B"])

        // Renumbering is contiguous after the swap.
        XCTAssertEqual(group.sortedSubgroups.map(\.orderIndex), [0, 1, 2])
    }

    func testApplyRegnalOrderAcrossEras() {
        let container = makeContainer()
        let context = container.mainContext
        let dynastyA = Era(name: "First dynasty of Kish", orderIndex: 1)
        let dynastyB = Era(name: "First dynasty of Uruk", orderIndex: 2)
        context.insert(dynastyA)
        context.insert(dynastyB)

        let group = FigureGroup(name: "SKL", kind: .skl)
        context.insert(group)
        // Grouped by era; within each era the in-era sequence is figure.orderIndex.
        let rulers: [(String, Int, Era)] = [
            ("Etana", 3, dynastyA),
            ("Balih", 1, dynastyA),
            ("Meskiag", 0, dynastyB),
            ("Enmerkar", 1, dynastyB),
        ]
        var assocs: [FigureGroupAssociation] = []
        for (name, seq, era) in rulers {
            let f = Figure(name: name, orderIndex: seq)
            f.era = era
            context.insert(f)
            let assoc = FigureGroupAssociation(figure: f)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
            assocs.append(assoc)
        }
        try? context.save()

        group.applyRegnalOrder()
        group.sortMode = .ordered
        XCTAssertEqual(group.sortedAssociations.compactMap { $0.figure?.name },
                       ["Balih", "Etana", "Meskiag", "Enmerkar"])
    }

    func testGroupTextBlockSpineInterleavesMembersAndText() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "Alpha")
        let b = Figure(name: "Beta")
        context.insert(a); context.insert(b)
        let ass1 = FigureGroupAssociation(figure: a, orderIndex: 0)
        let ass2 = FigureGroupAssociation(figure: b, orderIndex: 2)
        context.insert(ass1); context.insert(ass2)
        group.figureAssociations.append(ass1); group.figureAssociations.append(ass2)
        // A prose block sits between member 0 and member 2.
        let block = GroupTextBlock(title: "Aside", text: "Prose", orderIndex: 1)
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        let spine = group.memberTextSpine
        XCTAssertEqual(spine.count, 3)
        switch spine[0] { case .member(let m): XCTAssertEqual(m.figure?.name, "Alpha"); case .text: XCTFail("expected member") }
        switch spine[1] { case .text(let t): XCTAssertEqual(t.title, "Aside"); case .member: XCTFail("expected text") }
        switch spine[2] { case .member(let m): XCTAssertEqual(m.figure?.name, "Beta"); case .text: XCTFail("expected member") }
    }

    func testGroupTextBlockSummaryRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter")
        context.insert(group)
        let block = GroupTextBlock(
            title: "Atrahasis Tablet I",
            text: "Long full prose body.",
            summary: "The Anunnaki assign the Igigi their digging work.",
            summaryRichText: nil
        )
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        let fetched = try? context.fetch(FetchDescriptor<GroupTextBlock>()).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.summary, "The Anunnaki assign the Igigi their digging work.")
        XCTAssertNil(fetched?.summaryRichText)
        // Defaults for blocks without a summary: nil, and init default is nil.
        let plain = GroupTextBlock(title: "Plain", text: "No summary")
        XCTAssertNil(plain.summary)
        XCTAssertNil(plain.summaryRichText)
    }

    func testGroupTextBlockAttributionRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter")
        context.insert(group)
        let block = GroupTextBlock(title: "Atrahasis Tablet I", text: "Prose body.")
        context.insert(block)
        group.textBlocks = [block]

        let source = Source(name: "Atrahasis", sourceType: .ancientText, author: "", language: "Akkadian", period: "Old Babylonian", sourceDescription: "", publicationInfo: "", url: "")
        context.insert(source)
        let attribution = ContentAttribution(
            groupTextBlock: block,
            source: source,
            propertyName: "text",
            contentPreview: "The Anunnaki assign the Igigi their digging work.",
            note: ""
        )
        context.insert(attribution)
        block.contentAttributions = [attribution]
        try? context.save()

        let fetchedBlock = (try? context.fetch(FetchDescriptor<GroupTextBlock>()).first)
        XCTAssertNotNil(fetchedBlock)
        XCTAssertEqual(fetchedBlock?.contentAttributions?.count, 1)
        XCTAssertEqual(fetchedBlock?.contentAttributions?.first?.source?.name, "Atrahasis")
        XCTAssertEqual(fetchedBlock?.contentAttributions?.first?.groupTextBlock, fetchedBlock)
        // The attribution is attached to the text block, not to any figure/place/event/thing.
        XCTAssertNil(fetchedBlock?.contentAttributions?.first?.figure)
        XCTAssertNil(fetchedBlock?.contentAttributions?.first?.place)
        XCTAssertNil(fetchedBlock?.contentAttributions?.first?.event)
        XCTAssertNil(fetchedBlock?.contentAttributions?.first?.thing)
    }

    func testGroupTextBlockAttributionFormSavePath() {
        let container = makeDiskContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter")
        context.insert(group)
        let block = GroupTextBlock(title: "My notes", text: "My own words.")
        context.insert(block)
        group.textBlocks = [block]

        // Mirror ContentAttributionFormView.save(): insert a fresh attribution,
        // set the forward (unannotated) side, save, then reload from disk.
        let attribution = ContentAttribution(
            source: Source(name: "S", sourceType: .ancientText, author: "", language: "", period: "", sourceDescription: "", publicationInfo: "", url: ""),
            propertyName: "text",
            contentPreview: "Snippet"
        )
        context.insert(attribution)
        attribution.groupTextBlock = block
        try? context.save()

        // Fetch through a SECOND context on the same store so every instance is
        // guaranteed fresh: identity-based `==` on model objects would then fail,
        // which is why the row's task compares by persistentModelID instead.
        let otherContext = ModelContext(container)
        let fetchedBlock = (try? otherContext.fetch(FetchDescriptor<GroupTextBlock>()).first)
        XCTAssertNotNil(fetchedBlock)
        XCTAssertEqual(fetchedBlock?.persistentModelID, block.persistentModelID)
        let fetchedAttributions: [ContentAttribution] = (try? otherContext.fetch(FetchDescriptor<ContentAttribution>())) ?? []
        XCTAssertEqual(fetchedAttributions.count, 1)
        XCTAssertEqual(fetchedAttributions.first?.groupTextBlock?.persistentModelID, fetchedBlock?.persistentModelID)
        XCTAssertEqual(fetchedBlock?.contentAttributions?.count, 1)
    }

    func testGroupTextBlockAttributionIsOptional() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter")
        context.insert(group)
        // A text block with no attributions is valid — the user's own prose.
        let block = GroupTextBlock(title: "My notes", text: "My own words.")
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<GroupTextBlock>()).first)
        XCTAssertEqual(fetched?.contentAttributions?.count ?? 0, 0)
        XCTAssertNil(ContentAttribution().groupTextBlock)

        // Deleting a text block nullifies (rather than cascades) its attributions.
        let orphan = ContentAttribution(groupTextBlock: block, contentPreview: "Snippet")
        context.insert(orphan)
        block.contentAttributions = [orphan]
        try? context.save()
        context.delete(block)
        try? context.save()
        let remaining: [ContentAttribution] = context.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertNil(remaining.first?.groupTextBlock)
    }

    func testGroupMemberTextSpineMoveRenumbers() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "Alpha")
        let b = Figure(name: "Beta")
        context.insert(a); context.insert(b)
        let ass1 = FigureGroupAssociation(figure: a, orderIndex: 0)
        let ass2 = FigureGroupAssociation(figure: b, orderIndex: 2)
        context.insert(ass1); context.insert(ass2)
        group.figureAssociations.append(ass1); group.figureAssociations.append(ass2)
        let block = GroupTextBlock(title: "Aside", text: "Prose", orderIndex: 1)
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        // Move the text block up so it precedes Alpha entirely.
        let item = group.memberTextSpine[1] // text
        group.moveMemberTextItem(item, direction: -1)
        XCTAssertEqual(block.orderIndex, 0)
        XCTAssertEqual(ass1.orderIndex, 1)
        XCTAssertEqual(ass2.orderIndex, 2)
        XCTAssertEqual(group.memberTextSpine.compactMap { $0.name },
                       ["Aside", "Alpha", "Beta"])
    }

    func testGroupMemberTextSpineMoveToIndex() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "Alpha")
        let b = Figure(name: "Beta")
        let c = Figure(name: "Gamma")
        context.insert(a); context.insert(b); context.insert(c)
        let ass1 = FigureGroupAssociation(figure: a, orderIndex: 0)
        let ass2 = FigureGroupAssociation(figure: b, orderIndex: 1)
        let ass3 = FigureGroupAssociation(figure: c, orderIndex: 2)
        context.insert(ass1); context.insert(ass2); context.insert(ass3)
        group.figureAssociations.append(ass1); group.figureAssociations.append(ass2); group.figureAssociations.append(ass3)
        try? context.save()

        // Move Alpha (index 0) to the end (index 2).
        group.moveMemberTextItem(.member(ass1), toIndex: 2)
        XCTAssertEqual(group.memberTextSpine.compactMap { $0.name }, ["Beta", "Gamma", "Alpha"])
        XCTAssertEqual([ass2.orderIndex, ass3.orderIndex, ass1.orderIndex], [0, 1, 2])

        // Move Gamma (now index 1) to the front (index 0).
        group.moveMemberTextItem(.member(ass3), toIndex: 0)
        XCTAssertEqual(group.memberTextSpine.compactMap { $0.name }, ["Gamma", "Beta", "Alpha"])
        XCTAssertEqual([ass3.orderIndex, ass2.orderIndex, ass1.orderIndex], [0, 1, 2])
    }

    func testGroupMemberTextSpineCanMoveUsesSpinePosition() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Chapter", sortMode: .ordered)
        context.insert(group)
        let a = Figure(name: "Alpha")
        let b = Figure(name: "Beta")
        context.insert(a); context.insert(b)
        let ass1 = FigureGroupAssociation(figure: a, orderIndex: 0)
        let ass2 = FigureGroupAssociation(figure: b, orderIndex: 2)
        context.insert(ass1); context.insert(ass2)
        group.figureAssociations.append(ass1); group.figureAssociations.append(ass2)
        let block = GroupTextBlock(title: "Aside", text: "Prose", orderIndex: 1)
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        // The text block has spine index 1 (between Alpha and Beta). Even though it's the
        // ONLY text block (text-only arrows would be disabled), it can move up and down
        // within the unified spine.
        XCTAssertEqual(group.memberTextSpine.map { $0.name }, ["Alpha", "Aside", "Beta"])
        XCTAssertTrue(group.canMoveMemberTextItem(.text(block), direction: -1))
        XCTAssertTrue(group.canMoveMemberTextItem(.text(block), direction: 1))
        // First member can't move up (anyshift), last member can't move down.
        XCTAssertFalse(group.canMoveMemberTextItem(.member(ass1), direction: -1))
        XCTAssertTrue(group.canMoveMemberTextItem(.member(ass1), direction: 1))
        XCTAssertFalse(group.canMoveMemberTextItem(.member(ass2), direction: 1))
        // Out-of-spine items report false.
        let other = GroupTextBlock(title: "Elsewhere", text: "")
        context.insert(other)
        XCTAssertFalse(group.canMoveMemberTextItem(.text(other), direction: -1))
    }

    func testGroupMemberTextSpineNilOrderDefersByName() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Page", sortMode: .ordered)
        context.insert(group)
        let z = Figure(name: "Zed")
        context.insert(z)
        let ass = FigureGroupAssociation(figure: z, orderIndex: nil)
        context.insert(ass)
        group.figureAssociations.append(ass)
        let block = GroupTextBlock(title: "Alpha", text: "P", orderIndex: nil)
        context.insert(block)
        group.textBlocks = [block]
        try? context.save()

        // Nil orderIndex ties break by name ("Alpha" < "Zed").
        XCTAssertEqual(group.memberTextSpine.map { $0.name }, ["Alpha", "Zed"])
    }

func testRegnalKeyOrdersEventsByDate() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Events", entityType: .event)
        context.insert(group)
        let later = Event(name: "Treaty", date: MythologicalDate(year: -1200))
        let earlier = Event(name: "Foundation", date: MythologicalDate(year: -1500))
        context.insert(later)
        context.insert(earlier)
        for assoc in [FigureGroupAssociation(event: later), FigureGroupAssociation(event: earlier)] {
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        XCTAssertLessThan(FigureGroup.regnalKey(FigureGroupAssociation(event: earlier)),
                          FigureGroup.regnalKey(FigureGroupAssociation(event: later)))
    }

    func testGroupAssociationOrderIndexRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Enki")
        context.insert(figure)
        let assoc = FigureGroupAssociation(figure: figure, orderIndex: 3)
        context.insert(assoc)
        try? context.save()
        XCTAssertEqual(assoc.orderIndex, 3)
    }

    // MARK: - Group aggregation

    func testGroupAggregationCodableRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "First Dynasty of Ur")
        context.insert(group)
        group.decodedAggregation = GroupAggregation(
            operation: .sum,
            target: .reignYears,
            label: "Total listed reign"
        )
        try? context.save()

        XCTAssertEqual(group.decodedAggregation?.operation, .sum)
        XCTAssertEqual(group.decodedAggregation?.target, .reignYears)
        XCTAssertEqual(group.decodedAggregation?.label, "Total listed reign")
        XCTAssertNotNil(group.aggregationRawValue)
    }

    func testGroupAggregationBackwardsCompatibleNil() {
        let group = FigureGroup(name: "Council")
        XCTAssertNil(group.decodedAggregation)
        group.decodedAggregation = nil
        XCTAssertNil(group.aggregationRawValue)
    }

    func testGroupAggregationSumReignYears() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "First Dynasty of Ur")
        context.insert(group)
        let kings = [
            Figure(name: "Mesannepada", figureDescription: "Reigned 80 years. (Listed reign: 80 years.)"),
            Figure(name: "Meshkiang-nanna", figureDescription: "Reigned 36 years."),
            Figure(name: "Elulu", figureDescription: "Reigned 25 years."),
        ]
        for king in kings {
            context.insert(king)
            let assoc = FigureGroupAssociation(figure: king)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        let agg = GroupAggregation(operation: .sum, target: .reignYears)
        let result = agg.compute(in: group)
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?.sum, 141)
        XCTAssertNil(result?.average)
        XCTAssertEqual(agg.title, "Total listed reign")
        XCTAssertEqual(agg.formattedValue(for: result!), "141 years")
    }

    func testGroupAggregationAverageLifespan() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Long-lived Rulers")
        context.insert(group)
        let a = Figure(name: "A", birthDate: MythologicalDate(year: -2400), deathDate: MythologicalDate(year: -2300))
        let b = Figure(name: "B", birthDate: MythologicalDate(year: -2000), deathDate: MythologicalDate(year: -1960))
        context.insert(a)
        context.insert(b)
        for figure in [a, b] {
            let assoc = FigureGroupAssociation(figure: figure)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        let agg = GroupAggregation(operation: .average, target: .lifespan)
        let result = agg.compute(in: group)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?.average ?? 0, 70, accuracy: 0.001)
        XCTAssertEqual(agg.title, "Average lifespan")
        XCTAssertEqual(agg.formattedValue(for: result!), "70 years")
    }

    func testGroupAggregationEventYearSum() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Akkad Battles", entityType: .event)
        context.insert(group)
        let events = [
            Event(name: "Fall of Kish", date: MythologicalDate(year: -2300)),
            Event(name: "Fall of Uruk", date: MythologicalDate(year: -2100)),
        ]
        for event in events {
            context.insert(event)
            let assoc = FigureGroupAssociation(event: event)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        let agg = GroupAggregation(operation: .sum, target: .eventYear)
        let result = agg.compute(in: group)
        XCTAssertEqual(result?.sum, -4400)
        XCTAssertEqual(agg.formattedValue(for: result!), "4,400 BCE")
        XCTAssertEqual(agg.title, "Total event date")
    }

    func testGroupAggregationIgnoresMissingData() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Kings")
        context.insert(group)
        let withReign = Figure(name: "Meskiag", figureDescription: "Reigned 900 years.")
        let withoutReign = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.")
        context.insert(withReign)
        context.insert(withoutReign)
        for figure in [withReign, withoutReign] {
            let assoc = FigureGroupAssociation(figure: figure)
            context.insert(assoc)
            group.figureAssociations.append(assoc)
        }
        try? context.save()

        let agg = GroupAggregation(operation: .sum, target: .reignYears)
        let result = agg.compute(in: group)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.sum, 900)
        XCTAssertNil(GroupAggregation(operation: .sum, target: .reignSpan).compute(in: group))
    }

    func testGroupAggregationNoDataReturnsNil() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Empty")
        context.insert(group)
        let figure = Figure(name: "Nobody", figureDescription: "No reign recorded.")
        context.insert(figure)
        let assoc = FigureGroupAssociation(figure: figure)
        context.insert(assoc)
        group.figureAssociations.append(assoc)
        try? context.save()

        XCTAssertNil(GroupAggregation(operation: .sum, target: .reignYears).compute(in: group))
    }

    func testGroupAggregationCustomLabelWins() {
        let agg = GroupAggregation(operation: .sum, target: .reignYears, label: "Dynasty total")
        XCTAssertEqual(agg.title, "Dynasty total")
    }

    // MARK: - Figure reign duration (reignYears)

    func testReignLengthParsesListedReignSuffix() {
        XCTAssertEqual(ReignLength.parse(from: "…place him in Eridu and assign a reign to him lasting tens of thousands of years. (Listed reign: 28,800 years.)")?.years, 28800)
        XCTAssertEqual(ReignLength.parse(from: "…(Listed reign: 1,200 years.)")?.years, 1200)
    }

    func testReignLengthParsesLowercaseAndAroundVariants() {
        XCTAssertEqual(ReignLength.parse(from: "he reigned for around 670 years according to some versions")?.years, 670)
        XCTAssertEqual(ReignLength.parse(from: "he reigned for 25 years.")?.years, 25)
        XCTAssertEqual(ReignLength.parse(from: "He was said to have reigned for 18,600 years (5 sars and 1 ner).")?.years, 18600)
        XCTAssertEqual(ReignLength.parse(from: "Ruler from the First dynasty of Kish. Reigned 840 years (mythological length).")?.years, 840)
        XCTAssertEqual(ReignLength.parse(from: "possibly reigning for 6 years")?.years, 6)
        XCTAssertEqual(ReignLength.parse(from: "reigning for 7 years")?.years, 7)
    }

    func testReignLengthParsesNone() {
        XCTAssertNil(ReignLength.parse(from: "No reign recorded."))
        XCTAssertNil(ReignLength.parse(from: "Ruled c. 2255–2218 BC."))
    }

    func testEnsureReignYearsBackfillsFromDescription() {
        let container = makeContainer()
        let context = container.mainContext
        let a = Figure(name: "Kullassina-bel", figureDescription: "…(Listed reign: 960 years.)")
        let b = Figure(name: "En-men-gal-ana", figureDescription: "…ruled for 28,800 years…")
        let c = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.")
        context.insert(a)
        context.insert(b)
        context.insert(c)
        try? context.save()

        Migration.ensureReignYears(context: context)
        XCTAssertEqual(a.reignYears, 960)
        XCTAssertEqual(b.reignYears, 28800)
        XCTAssertNil(c.reignYears)
    }

    func testEnsureReignYearsDoesNotOverwrite() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Mesannepada", figureDescription: "Reigned 80 years. (Listed reign: 80 years.)")
        figure.reignYears = 9999  // user-entered value
        context.insert(figure)
        try? context.save()

        Migration.ensureReignYears(context: context)
        XCTAssertEqual(figure.reignYears, 9999)
    }

    func testGroupAggregationPrefersReignYearsField() {
        let container = makeContainer()
        let context = container.mainContext
        let group = FigureGroup(name: "Dynasty")
        context.insert(group)
        let figure = Figure(name: "Mesannepada", figureDescription: "Reigned 80 years.")
        figure.reignYears = 120  // field wins over the parseable description
        context.insert(figure)
        let assoc = FigureGroupAssociation(figure: figure)
        context.insert(assoc)
        group.figureAssociations.append(assoc)
        try? context.save()

        let result = GroupAggregation(operation: .sum, target: .reignYears).compute(in: group)
        XCTAssertEqual(result?.sum, 120)
    }

    // MARK: - Figure epithet

    func testEnsureEpithetsBackfillsFromDoubleQuotedProse() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Etana", figureDescription: "Etana was the thirteenth king of Kish. Epithet: ''\"the shepherd who ascended to heaven\"''.")
        context.insert(figure)
        try? context.save()

        Migration.ensureEpithets(context: context)
        XCTAssertEqual(figure.epithet, "the shepherd who ascended to heaven")
    }

    func testEnsureEpithetsBackfillsFromSingleQuotedProse() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Nergal", figureDescription: "Patron of Kutha. Epithet: 'the one who comes forth from Meslam'.")
        context.insert(figure)
        try? context.save()

        Migration.ensureEpithets(context: context)
        XCTAssertEqual(figure.epithet, "the one who comes forth from Meslam")
    }

    func testEnsureEpithetsDoesNotOverwrite() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Etana", figureDescription: "Epithet: ''\"the boatman\"''.")
        figure.epithet = "user entered epithet"
        context.insert(figure)
        try? context.save()

        Migration.ensureEpithets(context: context)
        XCTAssertEqual(figure.epithet, "user entered epithet")
    }

    func testEnsureEpithetsIgnoresFiguresWithoutEpithetProse() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Marduk", figureDescription: "No epithet mentioned here.")
        context.insert(figure)
        try? context.save()

        Migration.ensureEpithets(context: context)
        XCTAssertNil(figure.epithet)
    }

    // MARK: - Computed SKL dates

    func testDateSourceDefaultsToNil() {
        let figure = Figure(name: "Test")
        XCTAssertNil(figure.dateSource)
        XCTAssertEqual(figure.decodedDateSource, .historical)
    }

    func testEnsureComputedSKLDatesWritesDatesAndSetsSource() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 390, startDate: MythologicalDate(startYear: -2334, endYear: -2334, era: "Dynasty of Akkad"), endDate: MythologicalDate(startYear: -2154, endYear: -2154, era: "Dynasty of Akkad"))
        context.insert(era)
        let anchor = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.\n(Listed reign: 37 years.)")
        anchor.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Dynasty of Akkad")
        anchor.era = era
        context.insert(anchor)
        let successor = Figure(name: "Sharkalisharri")
        successor.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Dynasty of Akkad")
        successor.era = era
        successor.figureDescription = "(Listed reign: 25 years.)"
        context.insert(successor)
        try? context.save()

        Migration.ensureComputedSKLDates(context: context)
        XCTAssertNotNil(anchor.birthDate.startYear)
        XCTAssertNotNil(successor.birthDate.startYear)
        XCTAssertEqual(anchor.decodedDateSource, .computed)
        XCTAssertEqual(successor.decodedDateSource, .computed)
    }

    func testEnsureComputedSKLDatesDoesNotOverwriteExistingDates() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 390, startDate: MythologicalDate(startYear: -2334, endYear: -2334, era: "Dynasty of Akkad"), endDate: MythologicalDate(startYear: -2154, endYear: -2154, era: "Dynasty of Akkad"))
        context.insert(era)
        let figure = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.\n(Listed reign: 37 years.)")
        figure.birthDate = MythologicalDate(startYear: -2200, endYear: -2160, era: "Dynasty of Akkad")
        figure.era = era
        figure.dateSource = Figure.DateSource.historical.rawValue
        context.insert(figure)
        try? context.save()

        Migration.ensureComputedSKLDates(context: context)
        XCTAssertEqual(figure.birthDate.startYear, -2200)
        XCTAssertEqual(figure.decodedDateSource, .historical)
    }

    func testEnsureComputedSKLDatesIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 390, startDate: MythologicalDate(startYear: -2334, endYear: -2334, era: "Dynasty of Akkad"), endDate: MythologicalDate(startYear: -2154, endYear: -2154, era: "Dynasty of Akkad"))
        context.insert(era)
        let figure = Figure(name: "Naram-Sin", figureDescription: "Ruled c. 2255–2218 BC.\n(Listed reign: 37 years.)")
        figure.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Dynasty of Akkad")
        figure.era = era
        context.insert(figure)
        try? context.save()

        Migration.ensureComputedSKLDates(context: context)
        let firstStartYear = figure.birthDate.startYear
        XCTAssertNotNil(firstStartYear)

        Migration.ensureComputedSKLDates(context: context)
        XCTAssertEqual(figure.birthDate.startYear, firstStartYear)
    }

    func testFixSKLFigureOrderFixesHyphenatedName() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Apil-kin")
        figure.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Gutian rule")
        figure.orderIndex = 0
        context.insert(figure)
        try? context.save()

        Migration.fixSKLFigureOrder(context: context)

        XCTAssertEqual(figure.orderIndex, 10, "seed 'Apilkin' (index 10) must match hyphenated DB 'Apil-kin'")
    }

    func testEnsureSKLGutianReignLengthsFixesHyphenatedName() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Apil-kin")
        figure.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Gutian rule")
        figure.figureDescription = "Ruler from the Gutian rule. Reigned 3 years."
        context.insert(figure)
        try? context.save()

        Migration.ensureSKLGutianReignLengths(context: context)

        XCTAssertTrue(
            figure.figureDescription.contains("(Listed reign: 3 years.)"),
            "seed 'Apilkin' (Listed reign: 3 years.) must match hyphenated DB 'Apil-kin'"
        )
    }

    func testEnsureComputedSKLDatesPropagatesFullGutianDynastyFromAnchor() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Gutian rule", orderIndex: 700, startDate: MythologicalDate(startYear: -2200, endYear: -2200, era: "Gutian rule"), endDate: MythologicalDate(startYear: -2072, endYear: -2072, era: "Gutian rule"))
        context.insert(era)

        let namesAndReigns: [(String, Int)] = [
            ("Inkishush", 6), ("Sarlagab", 6), ("Shulme", 6), ("Elulmesh", 6),
            ("Inimabakesh", 5), ("Igeshaush", 6), ("Yarlagab", 15), ("Ibate", 3),
            ("Yarla", 3), ("Kurum", 1), ("Apilkin", 3), ("La-erabum", 2),
            ("Irarum", 2), ("Ibranum", 1), ("Hablum", 2), ("Puzur-Suen", 7),
            ("Yarlaganda", 7), ("Unknown", 7), ("Tirigan", 40),
        ]
        var figures: [Figure] = []
        for (i, (name, reign)) in namesAndReigns.enumerated() {
            let figure = Figure(name: name)
            figure.birthDate = MythologicalDate(startYear: nil, endYear: nil, era: "Gutian rule")
            figure.orderIndex = i
            figure.era = era
            if name == "Inkishush" {
                figure.figureDescription = "Ruler from the Gutian rule. Reigned \(reign) years. (Listed reign: \(reign) years.) c. 2200–2194 BC"
            } else {
                figure.figureDescription = "Ruler from the Gutian rule. Reigned \(reign) years. (Listed reign: \(reign) years.)"
            }
            context.insert(figure)
            figures.append(figure)
        }
        try? context.save()

        Migration.ensureComputedSKLDates(context: context)

        XCTAssertEqual(figures[0].birthDate.startYear, -2200)
        XCTAssertEqual(figures[0].birthDate.endYear, -2194)
        for figure in figures {
            XCTAssertNotNil(figure.birthDate.startYear, "\(figure.name) should have a computed start year")
            XCTAssertNotNil(figure.birthDate.endYear, "\(figure.name) should have a computed end year")
            XCTAssertEqual(figure.decodedDateSource, .computed, "\(figure.name) dates must be flagged computed")
        }
        for i in 1..<figures.count {
            XCTAssertEqual(figures[i].birthDate.startYear, figures[i - 1].birthDate.endYear, "contiguous reign chain breaks at \(figures[i].name)")
        }
        XCTAssertEqual(figures.last?.birthDate.endYear, -2072, "2200 minus 128 total Gutian reign-years")
    }

    // MARK: - Era date backfill from seed

    func testEnsureEraDatesFromSeedBackfillsSecondDynastyOfKish() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Second dynasty of Kish", orderIndex: 15, startDate: .unknown, endDate: .unknown))
        try? context.save()

        Migration.ensureEraDatesFromSeed(context: context)

        let era = (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == "Second dynasty of Kish" })))?.first
        XCTAssertEqual(era?.startDate.startYear, -2500, "seed anchors Second dynasty of Kish at its conventional slot after Awan")
        XCTAssertEqual(era?.startDate.endYear, -2500)
        XCTAssertEqual(era?.endDate.startYear, -2400)
        XCTAssertEqual(era?.endDate.endYear, -2400)
        XCTAssertTrue(era?.startDate.isApproximate == true)
    }

    func testEnsureEraDatesFromSeedBackfillsAllDatedDynastyEras() {
        let container = makeContainer()
        let context = container.mainContext
        let names = ["First dynasty of Kish", "Second dynasty of Kish", "Dynasty of Akkad", "Gutian rule", "Dynasty of Isin"]
        for (i, name) in names.enumerated() {
            context.insert(Era(name: name, orderIndex: 500 + i, startDate: .unknown, endDate: .unknown))
        }
        try? context.save()

        Migration.ensureEraDatesFromSeed(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        for era in eras {
            XCTAssertNotNil(era.startDate.startYear, "\(era.name) should be backfilled from seed")
            XCTAssertNotNil(era.endDate.startYear, "\(era.name) should be backfilled from seed")
        }
    }

    func testEnsureEraDatesFromSeedIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Second dynasty of Kish", orderIndex: 15, startDate: .unknown, endDate: .unknown))
        try? context.save()

        Migration.ensureEraDatesFromSeed(context: context)
        let first = (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == "Second dynasty of Kish" })))?.first
        let firstStart = first?.startDate.startYear

        Migration.ensureEraDatesFromSeed(context: context)
        let second = (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == "Second dynasty of Kish" })))?.first
        XCTAssertEqual(second?.startDate.startYear, firstStart)
    }

    func testEnsureEraDatesFromSeedNeverOverwritesExistingDates() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(
            name: "Second dynasty of Kish",
            orderIndex: 15,
            startDate: MythologicalDate(startYear: -2600, endYear: -2600, era: "Second dynasty of Kish"),
            endDate: MythologicalDate(startYear: -2550, endYear: -2550, era: "Second dynasty of Kish")
        ))
        try? context.save()

        Migration.ensureEraDatesFromSeed(context: context)

        let era = (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == "Second dynasty of Kish" })))?.first
        XCTAssertEqual(era?.startDate.startYear, -2600, "user-entered era dates must never be overwritten")
        XCTAssertEqual(era?.endDate.startYear, -2550)
    }

    // MARK: - Relationship sources

    func testEnsureRelationshipSourcesResolvesExistingSourceCaseInsensitively() {
        let container = makeContainer()
        let context = container.mainContext
        let source = Source(name: "Adapa Myth")
        context.insert(source)
        let rel = Relationship(source: "Adapa myth")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.name, "Adapa Myth")
        XCTAssertTrue(source.relationships.contains(where: { $0.persistentModelID == rel.persistentModelID }))
        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(allSources.count, 1)
    }

    func testEnsureRelationshipSourcesCreatesCoarseSourceForUnknownName() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Sumerian hymns")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.name, "Sumerian hymns")
        XCTAssertEqual(rel.sourceRef?.sourceType, .ancientText)
        XCTAssertEqual(rel.sourceRef?.relationships.count, 1)
    }

    func testEnsureRelationshipSourcesUsesFirstCommaSegment() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Enuma Elish, Babylonian texts")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.name, "Enuma Elish")
    }

    func testEnsureRelationshipSourcesKingListDetection() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Sumerian King List")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.sourceType, .kingList)
    }

    func testEnsureRelationshipSourcesIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Enuma Elish")
        context.insert(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        Migration.ensureRelationshipSources(context: context)
        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(allSources.count, 1)
        XCTAssertNotNil(rel.sourceRef)
    }

    func testEnsureRelationshipSourcesNeverRepointsExistingSourceRef() {
        let container = makeContainer()
        let context = container.mainContext
        let sumerianTexts = Source(name: "Sumerian texts")
        let enumaElish = Source(name: "Enuma Elish")
        context.insert(sumerianTexts)
        context.insert(enumaElish)
        let rel = Relationship(source: "Enuma Elish")
        context.insert(rel)
        sumerianTexts.relationships.append(rel)
        try? context.save()

        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.name, "Sumerian texts")
        XCTAssertFalse(enumaElish.relationships.contains(where: { $0.persistentModelID == rel.persistentModelID }))
    }

    func testJunkSourceCleanupBlanksShortStringAndDeletesDebrisSource() {
        let container = makeContainer()
        let context = container.mainContext
        let debris = Source(name: "d")
        let rel = Relationship(source: "d")
        context.insert(debris)
        context.insert(rel)
        debris.relationships.append(rel)
        try? context.save()

        Migration.ensureJunkSourceStringsCleaned(context: context)
        XCTAssertEqual(rel.source, "")
        XCTAssertNil(rel.sourceRef)
        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertTrue(allSources.isEmpty)

        Migration.ensureRelationshipSources(context: context)
        let afterRescan: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertTrue(afterRescan.isEmpty)
        XCTAssertNil(rel.sourceRef)
    }

    func testJunkSourceCleanupKeepsSourcesWithMetadataOrReferences() {
        let container = makeContainer()
        let context = container.mainContext
        let curatedShort = Source(name: "d", author: "Someone")
        let referenced = Source(name: "ab")
        let rel = Relationship(source: "")
        context.insert(curatedShort)
        context.insert(referenced)
        context.insert(rel)
        referenced.relationships.append(rel)
        try? context.save()

        Migration.ensureJunkSourceStringsCleaned(context: context)
        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(Set(allSources.map(\.persistentModelID)), Set([curatedShort.persistentModelID, referenced.persistentModelID]))
    }

    func testEnsureAnAnumGodListSourceCreatesOnceAndIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        Migration.ensureAnAnumGodListSourceExists(context: context)
        let afterFirst: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(afterFirst.count, 1)
        XCTAssertEqual(afterFirst.first?.name, "Lexical God List An = Anum (Tablet IV)")
        XCTAssertTrue(afterFirst.first?.url.isEmpty ?? false, "should have no URL")

        Migration.ensureAnAnumGodListSourceExists(context: context)
        let afterSecond: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(afterSecond.count, 1, "must not duplicate an existing source")
    }

    func testCellSourceMultipleAttributions() {
        let container = makeContainer()
        let context = container.mainContext
        let enuma = Source(name: "Enuma Elish")
        context.insert(enuma)
        try? context.save()

        let cell = PopupTableCell(value: "Truth")
        context.insert(cell)
        cell.addCellSource(named: "Enuma Elish", context: context)
        cell.addCellSource(named: "SKL", context: context)
        try? context.save()

        XCTAssertEqual(cell.effectiveCellSourceNames.count, 2)
        XCTAssertTrue(cell.effectiveCellSourceNames.contains { $0.name == "Enuma Elish" })
        let linked = cell.cellSources.first { $0.source == "Enuma Elish" }
        XCTAssertEqual(linked?.sourceRef?.name, "Enuma Elish")
        let unlinked = cell.cellSources.first { $0.source == "SKL" }
        XCTAssertNil(unlinked?.sourceRef, "non-matching name must not create a Source row")

        cell.removeCellSource(linked!)
        XCTAssertEqual(cell.effectiveCellSourceNames.count, 1)
        XCTAssertFalse(cell.effectiveCellSourceNames.contains { $0.name == "Enuma Elish" })
    }

    func testCellSourceNameAndLocationAreSeparate() {
        let container = makeContainer()
        let context = container.mainContext
        let enuma = Source(name: "Enuma Elish")
        context.insert(enuma)
        try? context.save()

        let cell = PopupTableCell(value: "Storm")
        context.insert(cell)
        cell.addCellSource(named: "Enuma Elish", location: "Tablet V, lines 120\u{2013}143", context: context)
        try? context.save()

        XCTAssertEqual(cell.cellSources.count, 1)
        let entry = cell.cellSources.first
        XCTAssertEqual(entry?.source, "Enuma Elish")
        XCTAssertEqual(entry?.location, "Tablet V, lines 120\u{2013}143")
        XCTAssertEqual(entry?.sourceRef?.name, "Enuma Elish", "matching should use the work name, not the combined reference")
    }


    func testJunkSourceCleanupLeavesLegitSourceStringsAlone() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "SKL")
        context.insert(rel)
        try? context.save()

        Migration.ensureJunkSourceStringsCleaned(context: context)
        XCTAssertEqual(rel.source, "SKL")
        Migration.ensureRelationshipSources(context: context)
        XCTAssertEqual(rel.sourceRef?.name, "SKL")
    }

    func testRelationshipSourceDisplayNameFallsBackToString() {
        let container = makeContainer()
        let context = container.mainContext
        let rel = Relationship(source: "Enuma Elish")
        context.insert(rel)
        try? context.save()

        XCTAssertEqual(rel.sourceDisplayName, "Enuma Elish")
        XCTAssertNil(rel.sourceURL)

        let source = Source(name: "Enuma Elish", url: "https://example.com/enuma")
        context.insert(source)
        source.relationships.append(rel)
        try? context.save()

        XCTAssertEqual(rel.sourceDisplayName, "Enuma Elish")
        XCTAssertEqual(rel.sourceURL, "https://example.com/enuma")
    }

    // MARK: - Figure era links

    func testEnsureFigureEraLinksLinksByBirthEraString() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 390)
        context.insert(era)
        let figure = Figure(name: "Sargon", birthDate: MythologicalDate(year: -2334, era: "Dynasty of Akkad"))
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
    }

    func testEnsureFigureEraLinksAliasMapsBeforeTheFlood() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Age of the Watchers", orderIndex: 1)
        context.insert(era)
        let figure = Figure(name: "Shamhazai", birthDate: MythologicalDate(year: nil, era: "Before the Flood"))
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
    }

    func testEnsureFigureEraLinksFallsBackToDescriptionPrefix() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Antediluvian Period", orderIndex: 5)
        context.insert(era)
        let figure = Figure(name: "Ubara-Tutu", figureDescription: "Ruler from the Antediluvian Period. Father of Ziusudra.")
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
    }

    func testEnsureFigureEraLinksBackfillsBirthEraStringFromDescriptionPrefix() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Antediluvian Period", orderIndex: 5)
        context.insert(era)
        let figure = Figure(name: "Alalngar", figureDescription: "Ruler from the Antediluvian Period.")
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
        XCTAssertEqual(figure.birthDate.era, "Antediluvian Period")
    }

    func testEnsureFigureEraLinksDoesNotOverwriteExistingBirthEraString() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Antediluvian", orderIndex: 6)
        context.insert(era)
        let figure = Figure(name: "Alalngar", figureDescription: "Ruler from the Antediluvian Period.", birthDate: MythologicalDate(year: nil, era: "Antediluvian"))
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.birthDate.era, "Antediluvian")
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
    }

    func testEnsureFigureEraLinksResyncsStaleLink() {
        let container = makeContainer()
        let context = container.mainContext
        let oldEra = Era(name: "Gutian rule", orderIndex: 392)
        let newEra = Era(name: "Dynasty of Isin", orderIndex: 395)
        context.insert(oldEra)
        context.insert(newEra)
        let figure = Figure(name: "Ishbi-Erra", birthDate: MythologicalDate(year: -2017, era: "Dynasty of Isin"))
        figure.era = oldEra
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.era?.persistentModelID, newEra.persistentModelID)
    }

    func testEnsureFigureEraLinksClearsLinkWhenStringEmptyAndNoPrefix() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Creation", orderIndex: 0)
        context.insert(era)
        let figure = Figure(name: "Tiamat", figureDescription: "Primordial goddess of the salt sea.")
        figure.era = era
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertNil(figure.era)
    }

    func testEnsureFigureEraLinksDoesNotWriteUnmatchedDescriptionAsEra() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Early Dynastic Period", orderIndex: 100)
        context.insert(era)
        let figure = Figure(
            name: "Enmetena",
            figureDescription: "Ruler of Lagash who defeated Umma and restored the border channel."
        )
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.birthDate.era, "", "biographical description must not become an era string")
        XCTAssertNil(figure.era)
    }

    func testEnsureFigureEraLinksClearsAutoDerivedGarbageEraString() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Early Dynastic Period", orderIndex: 100))
        let figure = Figure(
            name: "Enmetena",
            figureDescription: "Ruler of Lagash who defeated Umma and restored the border channel.",
            birthDate: MythologicalDate(era: "Lagash who defeated Umma and restored the border channel")
        )
        context.insert(figure)
        try? context.save()

        Migration.ensureFigureEraLinks(context: context)
        XCTAssertEqual(figure.birthDate.era, "", "auto-derived garbage era string should be cleared")
        XCTAssertNil(figure.era)
    }

    func testHistoricalEventsImportRepairsAutoDerivedGarbageEra() {
        let container = makeContainer()
        let context = ModelContext(container)
        let era = Era(name: "Early Dynastic Period", orderIndex: 100)
        context.insert(era)
        let figure = Figure(
            name: "Enmetena",
            figureDescription: "Ruler of Lagash who defeated Umma and restored the border channel.",
            birthDate: MythologicalDate(era: "Lagash who defeated Umma and restored the border channel")
        )
        context.insert(figure)
        try? context.save()

        Migration.ensureHistoricalEventsImportExist(context: context)
        XCTAssertEqual(figure.birthDate.era, "Early Dynastic Period", "importer must restore era from authoritative JSON")
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)

        Migration.ensureHistoricalEventsImportExist(context: context)
        XCTAssertEqual(figure.birthDate.era, "Early Dynastic Period", "repair must be idempotent")
        XCTAssertEqual(figure.era?.persistentModelID, era.persistentModelID)
    }

    func testEraNamedHelper() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Age of the Watchers", orderIndex: 1)
        context.insert(era)
        try? context.save()

        XCTAssertEqual(Migration.era(named: "Before the Flood", context: context)?.persistentModelID, era.persistentModelID)
        XCTAssertEqual(Migration.era(named: "Age of the Watchers", context: context)?.persistentModelID, era.persistentModelID)
        XCTAssertNil(Migration.era(named: "", context: context))
        XCTAssertNil(Migration.era(named: "  ", context: context))
        XCTAssertNil(Migration.era(named: "Nonexistent", context: context))
    }

    func testEraBoundaryGeoJSONRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[44.4,33.3],[45.0,33.5],[44.8,32.9],[44.4,33.3]]]}"
        context.insert(era)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<Era>()))?.first
        XCTAssertEqual(fetched?.name, "Dynasty of Akkad")
        XCTAssertEqual(fetched?.boundaryGeoJSON, era.boundaryGeoJSON, "boundary persisted on the era")
    }

    func testPolygonGeoJSONClosesRing() {
        let json = Migration.polygonGeoJSON(ring: [[44.0, 33.0], [45.0, 33.0], [45.0, 34.0]])
        XCTAssertNotNil(json)
        guard let data = json?.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let coordinates = object["coordinates"] as? [[[Double]]],
              let ring = coordinates.first else {
            XCTFail("expected a serialized Polygon")
            return
        }
        XCTAssertEqual(object["type"] as? String, "Polygon")
        XCTAssertEqual(ring.first!, ring.last!, "ring must be closed")
        XCTAssertEqual(ring.count, 4)
        XCTAssertNil(Migration.polygonGeoJSON(ring: [[44.0, 33.0], [45.0, 33.0]]))
    }

    func testEnsureDynastyBoundariesBackfillsEras() {
        let container = makeContainer()
        let context = container.mainContext
        for name in ["Dynasty of Akkad", "Dynasty of Isin", "Dynasty of Mari", "Dynasty of Awan", "Gutian rule"] {
            context.insert(Era(name: name, orderIndex: 1))
        }
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        for era in eras {
            XCTAssertNotNil(era.boundaryGeoJSON, "\(era.name) got a boundary")
            guard let data = era.boundaryGeoJSON?.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let coordinates = object["coordinates"] as? [[[Double]]],
                  let ring = coordinates.first else {
                XCTFail("\(era.name) boundary not a Polygon")
                continue
            }
            XCTAssertEqual(ring.first!, ring.last!, "\(era.name) ring closed")
        }
    }

    func testEnsureDynastyBoundariesContainsCapitals() {
        let container = makeContainer()
        let context = container.mainContext
        for name in ["Dynasty of Akkad", "Dynasty of Isin", "Dynasty of Mari", "First dynasty of Ur", "Dynasty of Awan"] {
            context.insert(Era(name: name, orderIndex: 1))
        }
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let points: [String: (Double, Double)] = [
            "Dynasty of Akkad": (44.42, 33.33),
            "Dynasty of Isin": (45.29, 31.92),
            "Dynasty of Mari": (40.89, 34.55),
            "First dynasty of Ur": (46.103, 30.963),
            "Dynasty of Awan": (46.0, 33.0),
        ]
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        for era in eras {
            guard let data = era.boundaryGeoJSON?.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let coordinates = object["coordinates"] as? [[[Double]]],
                  let ring = coordinates.first,
                  let capital = points[era.name] else { continue }
            XCTAssertTrue(pointInRing(capital, ring), "\(era.name) contains its capital")
        }
    }

    func testEnsureDynastyBoundariesBackfillsHistoricalEras() {
        let container = makeContainer()
        let context = container.mainContext
        for name in ["Old Assyrian Period", "Old Babylonian Period", "Neo-Assyrian Period", "Uruk Period", "Jemdet Nasr Period", "Mitanni", "Karduniaš (Kassite Babylonia)", "Middle Assyrian Period", "Late Bronze Age Collapse", "Neo-Babylonian Empire", "Achaemenid Empire", "Macedonian Empire", "Seleucid Empire", "Parthian Empire", "Roman and Byzantine Mesopotamia", "Sassanid Empire"] {
            context.insert(Era(name: name, orderIndex: 31))
        }
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        XCTAssertEqual(eras.count, 16)
        for era in eras {
            XCTAssertNotNil(era.boundaryGeoJSON, "\(era.name) got a boundary")
            guard let data = era.boundaryGeoJSON?.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let coordinates = object["coordinates"] as? [[[Double]]],
                  let ring = coordinates.first else {
                XCTFail("\(era.name) boundary not a Polygon")
                continue
            }
            XCTAssertEqual(ring.first!, ring.last!, "\(era.name) ring closed")
        }
    }

    func testEnsureDynastyBoundariesContainsHistoricalCapitals() {
        let container = makeContainer()
        let context = container.mainContext
        let names = ["Old Assyrian Period", "Old Babylonian Period", "Neo-Assyrian Period", "Uruk Period", "Jemdet Nasr Period", "Mitanni", "Karduniaš (Kassite Babylonia)", "Middle Assyrian Period", "Neo-Babylonian Empire", "Achaemenid Empire", "Macedonian Empire", "Seleucid Empire", "Parthian Empire", "Roman and Byzantine Mesopotamia", "Sassanid Empire"]
        for name in names {
            context.insert(Era(name: name, orderIndex: 31))
        }
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let points: [String: (Double, Double)] = [
            "Old Assyrian Period": (43.26, 35.46),
            "Old Babylonian Period": (44.42, 32.54),
            "Neo-Assyrian Period": (43.15, 36.36),
            "Uruk Period": (45.64, 31.32),
            "Jemdet Nasr Period": (44.64, 32.55),
            "Mitanni": (40.04, 36.83),
            "Karduniaš (Kassite Babylonia)": (44.42, 32.54),
            "Middle Assyrian Period": (43.26, 35.46),
            "Neo-Babylonian Empire": (44.42, 32.54),
            "Achaemenid Empire": (48.24, 32.19),
            "Macedonian Empire": (44.42, 32.54),
            "Seleucid Empire": (44.50, 33.10),
            "Parthian Empire": (44.50, 33.10),
            "Roman and Byzantine Mesopotamia": (41.20, 37.10),
            "Sassanid Empire": (44.50, 33.10),
        ]
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        for era in eras {
            guard let data = era.boundaryGeoJSON?.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let coordinates = object["coordinates"] as? [[[Double]]],
                  let ring = coordinates.first,
                  let capital = points[era.name] else { continue }
            XCTAssertTrue(pointInRing(capital, ring), "\(era.name) contains its capital")
        }
    }

    func testRemoveEraTerritoryPlacesRemovesOnlyArtifacts() {
        let container = makeContainer()
        let context = container.mainContext
        let eraNames = ["Old Assyrian Period", "Old Babylonian Period", "Neo-Assyrian Period", "Uruk Period", "Jemdet Nasr Period", "Mitanni", "Karduniaš (Kassite Babylonia)", "Middle Assyrian Period", "Late Bronze Age Collapse", "Neo-Babylonian Empire", "Achaemenid Empire", "Macedonian Empire", "Seleucid Empire", "Parthian Empire", "Roman and Byzantine Mesopotamia", "Sassanid Empire"]
        let eras = eraNames.map { Era(name: $0, orderIndex: 31) }
        eras.forEach { context.insert($0) }
        let placeType = PlaceType(name: "Region", icon: "map", colorHex: "34C759")
        context.insert(placeType)
        for (normalizedKey, seed) in Migration.eraTerritoryPlaces {
            guard let era = eras.first(where: { Migration.normalizedGroupName($0.name) == normalizedKey }) else { continue }
            context.insert(Place(name: seed.name, placeType: placeType, placeDescription: "\(era.name) territory"))
        }
        let userMitanni = Place(name: "Mitanni", placeType: placeType, modernLocation: "Khabur triangle, northern Syria", placeDescription: "Hurrian kingdom of northern Syria")
        context.insert(userMitanni)
        try? context.save()

        Migration.removeEraTerritoryPlaces(context: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.count, 1, "all 16 artifact places removed, the user-authored Mitanni survives")
        XCTAssertEqual(places.first?.name, "Mitanni")
        XCTAssertEqual(places.first?.placeDescription, "Hurrian kingdom of northern Syria", "user-authored place untouched")
    }

    func testRemoveEraTerritoryPlacesLeavesNonArtifactPlacesAlone() {
        let container = makeContainer()
        let context = container.mainContext
        for name in ["Late Bronze Age Collapse", "Mitanni"] {
            context.insert(Era(name: name, orderIndex: 31))
        }
        let placeType = PlaceType(name: "Region", icon: "map", colorHex: "34C759")
        context.insert(placeType)
        context.insert(Place(name: "Late Bronze Age Collapse", placeType: placeType, placeDescription: "Late Bronze Age Collapse territory"))
        let userPlace = Place(name: "Mitanni", placeType: placeType, modernLocation: "Khabur triangle", placeDescription: "user's own entry")
        context.insert(userPlace)
        try? context.save()

        Migration.removeEraTerritoryPlaces(context: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.map(\.name), ["Mitanni"])
        XCTAssertEqual(places.first?.placeDescription, "user's own entry")
    }

    func testEnsureDynastyBoundariesNeverOverwrites() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[1.0,1.0],[2.0,1.0],[2.0,2.0],[1.0,1.0]]]}"
        context.insert(era)
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<Era>()))?.first
        XCTAssertEqual(fetched?.boundaryGeoJSON, era.boundaryGeoJSON, "existing boundary untouched")
    }

    func testEnsureDynastyBoundariesRepairsDegenerateTestDraw() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[42.6,32.67],[42.7,32.68],[42.8,32.68],[42.9,32.68],[43.0,32.68],[43.1,32.68],[43.2,32.68],[43.3,32.68],[43.4,32.68]]]}"
        context.insert(era)
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<Era>()))?.first
        guard let data = fetched?.boundaryGeoJSON?.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let coordinates = object["coordinates"] as? [[[Double]]],
              let ring = coordinates.first else {
            XCTFail("expected a repaired Polygon")
            return
        }
        XCTAssertEqual(ring.first!, ring.last!, "repaired ring must be closed")
        XCTAssertEqual(ring.count, 15, "authored Akkad ring is 14 vertices + closing point")
        let lats = ring.map { $0[1] }
        XCTAssertGreaterThan(lats.max()! - lats.min()!, 4.0, "degenerate sliver replaced with a real territory")
    }

    func testEnsureDynastyBoundariesRepairsClosedSliver() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        var ring: [[Double]] = []
        for lon in stride(from: 42.0, through: 44.5, by: 0.08) {
            ring.append([lon, 32.94])
            ring.append([lon + 0.04, 32.95])
        }
        ring.append(ring[0])
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[\(ring.map { "[\($0[0]),\($0[1])]" }.joined(separator: ","))]}"
        context.insert(era)
        try? context.save()

        Migration.ensureDynastyBoundaries(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<Era>()))?.first
        guard let data = fetched?.boundaryGeoJSON?.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let coordinates = object["coordinates"] as? [[[Double]]],
              let repaired = coordinates.first else {
            XCTFail("expected a repaired Polygon")
            return
        }
        XCTAssertEqual(repaired.first!, repaired.last!, "repaired ring must be closed")
        XCTAssertEqual(repaired.count, 15, "authored Akkad ring is 14 vertices + closing point")
        let lats = repaired.map { $0[1] }
        XCTAssertGreaterThan(lats.max()! - lats.min()!, 4.0, "closed horizontal sliver replaced with a real territory")
    }

    func testPlaceBoundaryInheritsEraFromGroup() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[44.4,33.3],[45.0,33.5],[44.8,32.9],[44.4,33.3]]]}"
        context.insert(era)
        let group = FigureGroup(name: "Dynasty of Akkad", kind: .skl)
        group.era = era
        context.insert(group)
        let place = Place(name: "Akkad", modernLocation: "Central Iraq")
        context.insert(place)
        let assoc = FigureGroupAssociation(place: place)
        context.insert(assoc)
        group.figureAssociations.append(assoc)
        place.groupAssociations.append(assoc)
        try? context.save()

        XCTAssertEqual(place.boundaryGeoJSON, era.boundaryGeoJSON, "place inherits the dynasty boundary from its group's era")
        XCTAssertEqual(place.boundarySourceEraName, "Dynasty of Akkad")
    }

    func testPlaceBoundaryNilWithoutDynastyGroup() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "Aratta", modernLocation: "Unknown")
        context.insert(place)
        let plainGroup = FigureGroup(name: "Cities")
        context.insert(plainGroup)
        let assoc = FigureGroupAssociation(place: place)
        context.insert(assoc)
        plainGroup.figureAssociations.append(assoc)
        place.groupAssociations.append(assoc)
        try? context.save()

        XCTAssertNil(place.boundaryGeoJSON, "group without an era has no silhhouette")
        XCTAssertNil(place.boundarySourceEraName)
    }

    func testStoredPlaceBoundaryWinsOverInherited() {
        let container = makeContainer()
        let context = container.mainContext
        let era = Era(name: "Dynasty of Akkad", orderIndex: 1)
        era.boundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[44.4,33.3],[45.0,33.5],[44.8,32.9],[44.4,33.3]]]}"
        context.insert(era)
        let group = FigureGroup(name: "Dynasty of Akkad", kind: .skl)
        group.era = era
        context.insert(group)
        let place = Place(name: "Akkad", modernLocation: "Central Iraq")
        place.storedBoundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[40.0,35.0],[41.0,35.0],[41.0,34.0],[40.0,35.0]]]}"
        context.insert(place)
        let assoc = FigureGroupAssociation(place: place)
        context.insert(assoc)
        group.figureAssociations.append(assoc)
        place.groupAssociations.append(assoc)
        try? context.save()

        XCTAssertEqual(place.boundaryGeoJSON, place.storedBoundaryGeoJSON, "stored boundary wins over the inherited dynasty boundary")
    }

    func testEnsurePlaceBoundariesBackfillsRegions() {
        let container = makeContainer()
        let context = container.mainContext
        let centers: [String: (Double, Double)] = [
            "Mesopotamia": (44.42, 32.54),
            "Cedar Forest": (36.05, 34.27),
            "Dilmun": (50.5, 26.1),
            "Dudael": (35.25, 31.56),
            "Lebanon": (35.5, 33.89),
            "Upper Mesopotamia": (39.03, 36.86),
            "The Southern Mesopotamian Marshes (Hawizeh / Hammar System)": (47.0, 31.0),
            "Gutium": (45.43, 35.56),
            "Kassite homeland": (48.33, 33.5),
            "Magan": (58.41, 23.61),
            "Meluhha": (68.14, 27.33),
            "Elam": (48.26, 32.19),
            "Subartu": (40.74, 37.31),
            "Hurri": (41.0, 36.8),
            "Amurru": (38.28, 34.56),
            "Assyria": (43.26, 35.46),
            "Persian Gulf (The Lower Sea)": (50.5, 27.0),
            "The Mediterranean Sea (The Upper Sea)": (33.0, 34.5),
        ]
        for name in [
            "Mesopotamia", "Cedar Forest", "Dilmun", "Dudael", "Lebanon",
            "Upper Mesopotamia", "The Southern Mesopotamian Marshes (Hawizeh / Hammar System)",
            "Gutium", "Magan", "Meluhha", "Elam", "Subartu", "Hurri", "Amurru", "Assyria",
            "Kassite homeland",
            "Persian Gulf (The Lower Sea)", "The Mediterranean Sea (The Upper Sea)",
            "Aratta",
        ] {
            context.insert(Place(name: name, modernLocation: "test"))
        }
        try? context.save()

        Migration.ensurePlaceBoundaries(context: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        for place in places {
            guard let center = centers[place.name] else {
                XCTAssertNil(place.storedBoundaryGeoJSON, "unlisted place untouched")
                continue
            }
            XCTAssertNotNil(place.storedBoundaryGeoJSON, "\(place.name) got a boundary")
            guard let data = place.storedBoundaryGeoJSON?.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let coordinates = object["coordinates"] as? [[[Double]]],
                  let ring = coordinates.first else {
                XCTFail("\(place.name) boundary not a Polygon")
                continue
            }
            XCTAssertEqual(ring.first!, ring.last!, "\(place.name) ring closed")
            XCTAssertTrue(pointInRing(center, ring), "\(place.name) contains its landmark")
        }
    }

    func testUpgradeSeededMarshesBoundaryReplacesLegacyRing() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "The Southern Mesopotamian Marshes (Hawizeh / Hammar System)", modernLocation: "Iraq")
        place.storedBoundaryGeoJSON = Migration.polygonGeoJSON(ring: Migration.legacySeededMarshesRing)
        context.insert(place)
        try? context.save()

        Migration.upgradeSeededMarshesBoundary(context: context)

        let fetched: Place? = (try? context.fetch(FetchDescriptor<Place>()))?.first
        let authored = Migration.polygonGeoJSON(
            ring: Migration.placeBoundaryRings["southern mesopotamian marshes (hawizeh / hammar system)"]!
        )
        XCTAssertEqual(fetched?.storedBoundaryGeoJSON, authored, "legacy seeded ring upgraded to the refined ring")
        let refined = Migration.decodedRing(from: authored ?? "") ?? []
        XCTAssertTrue(pointInRing((47.0, 31.0), refined), "refined ring contains a mid-marsh landmark")
    }

    func testUpgradeSeededMarshesBoundaryLeavesUserRing() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "The Southern Mesopotamian Marshes (Hawizeh / Hammar System)", modernLocation: "Iraq")
        let userJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[46.0,30.5],[48.0,30.5],[48.4,31.5],[47.0,32.0],[46.0,30.5]]]}"
        place.storedBoundaryGeoJSON = userJSON
        context.insert(place)
        try? context.save()

        Migration.upgradeSeededMarshesBoundary(context: context)

        let fetched: Place? = (try? context.fetch(FetchDescriptor<Place>()))?.first
        XCTAssertEqual(fetched?.storedBoundaryGeoJSON, userJSON, "user-drawn boundary untouched")
    }

    func testUpgradeSeededCedarForestBoundaryReplacesLegacyRing() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "Cedar Forest", modernLocation: "Lebanon / Syria")
        place.storedBoundaryGeoJSON = Migration.polygonGeoJSON(ring: Migration.legacySeededCedarForestRing)
        context.insert(place)
        try? context.save()

        Migration.upgradeSeededCedarForestBoundary(context: context)

        let fetched: Place? = (try? context.fetch(FetchDescriptor<Place>()))?.first
        let authored = Migration.polygonGeoJSON(ring: Migration.placeBoundaryRings["cedar forest"]!)
        XCTAssertEqual(fetched?.storedBoundaryGeoJSON, authored, "legacy corridor upgraded to the Mount-Lebanon ring")
    }

    func testUpgradeSeededCedarForestBoundaryLeavesUserRing() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "Cedar Forest", modernLocation: "Lebanon / Syria")
        let userJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[35.9,34.6],[36.3,34.6],[36.3,34.2],[35.9,34.6]]]}"
        place.storedBoundaryGeoJSON = userJSON
        context.insert(place)
        try? context.save()

        Migration.upgradeSeededCedarForestBoundary(context: context)

        let fetched: Place? = (try? context.fetch(FetchDescriptor<Place>()))?.first
        XCTAssertEqual(fetched?.storedBoundaryGeoJSON, userJSON, "user-drawn boundary untouched")
    }

    func testRefinedCedarForestRingGeoreferenced() {
        let geo = Migration.polygonGeoJSON(ring: Migration.placeBoundaryRings["cedar forest"]!)
        let decoded = Migration.decodedRing(from: geo ?? "") ?? []
        XCTAssertEqual(decoded.first!, decoded.last!, "Cedar Forest ring closed")
        for grove in [(36.052, 34.243), (35.99, 34.31), (35.72, 33.70), (36.0, 34.2)] {
            XCTAssertTrue(pointInRing(grove, decoded), "grove \(grove) within Cedar Forest")
        }
        for outside in [(36.21, 34.01), (35.50, 33.89), (35.84, 34.44), (36.29, 33.51), (36.32, 36.70)] {
            XCTAssertFalse(pointInRing(outside, decoded), "\(outside) outside Cedar Forest")
        }
    }

    func testAmurruBoundaryGeoreferenced() {
        let geo = Migration.polygonGeoJSON(ring: Migration.placeBoundaryRings["amurru"]!)
        let decoded = Migration.decodedRing(from: geo ?? "") ?? []
        XCTAssertEqual(decoded.first!, decoded.last!, "Amurru ring closed")
        for inside in [(36.231944, 34.569722), (38.27, 34.56), (40.19, 35.06), (36.52, 34.55), (36.72, 34.73), (35.98, 34.71), (40.74, 34.75)] {
            XCTAssertTrue(pointInRing(inside, decoded), "\(inside) within Amurru")
        }
        for outside in [(37.16, 36.20), (36.29, 33.51), (35.50, 33.89), (35.84, 34.44), (36.21, 34.01), (44.36, 33.34), (39.02, 35.95)] {
            XCTAssertFalse(pointInRing(outside, decoded), "\(outside) outside Amurru")
        }
    }

    func testRefinedElamRingGeoreferenced() {
        let geo = Migration.polygonGeoJSON(ring: Migration.placeBoundaryRings["elam"]!)
        let decoded = Migration.decodedRing(from: geo ?? "") ?? []
        XCTAssertEqual(decoded.first!, decoded.last!, "Elam ring closed")
        for inside in [(52.4,29.9),(52.355,30.012),(52.89,29.93),(52.95,29.90),(52.53,29.60),(48.258,32.19),(48.531,32.011),(48.33,32.08),(48.40,32.38),(48.67,31.32),(48.85,32.05),(50.83,28.92),(49.87,31.83),(49.60,31.28),(51.25,31.0)] {
            XCTAssertTrue(pointInRing(inside, decoded), "\(inside) within Elam")
        }
        for outside in [(47.14,31.84),(47.79,30.51),(44.36,33.34),(51.67,32.65),(57.06,30.29),(48.35,33.49),(53.98,26.50),(56.26,27.18)] {
            XCTAssertFalse(pointInRing(outside, decoded), "\(outside) outside Elam")
        }
    }

    func testHurriBoundaryBackfilledAndGeoreferenced() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "Hurri", modernLocation: "Syria / Turkey / Iraq")
        context.insert(place)
        try? context.save()

        Migration.ensurePlaceBoundaries(context: context)

        let fetched = ((try? context.fetch(FetchDescriptor<Place>())) ?? []).first { $0.name == "Hurri" }
        XCTAssertNotNil(fetched?.storedBoundaryGeoJSON, "Hurri got a kingdom boundary")
        let decoded = Migration.decodedRing(from: fetched?.storedBoundaryGeoJSON ?? "") ?? []
        XCTAssertEqual(decoded.first!, decoded.last!, "Hurri ring closed")
        for inside in [(41.0,36.8),(40.00,36.90),(40.97,37.06),(41.06,36.67),(41.50,36.96),(41.19,36.85),(41.22,37.08),(40.74,37.31),(39.03,36.87),(40.24,37.91),(41.88,36.32)] {
            XCTAssertTrue(pointInRing(inside, decoded), "\(inside) within Hurri")
        }
        for outside in [(38.28,37.76),(42.11,38.40),(43.13,36.36),(43.26,35.46),(40.92,34.55),(40.57,34.92)] {
            XCTAssertFalse(pointInRing(outside, decoded), "\(outside) outside Hurri")
        }
    }

    func testKassiteHomelandBoundaryBackfilledAndGeoreferenced() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "Kassite homeland", modernLocation: "Iran")
        context.insert(place)
        try? context.save()

        Migration.ensurePlaceBoundaries(context: context)

        let fetched = ((try? context.fetch(FetchDescriptor<Place>())) ?? []).first { $0.name == "Kassite homeland" }
        XCTAssertNotNil(fetched?.storedBoundaryGeoJSON, "Kassite homeland got a boundary")
        let decoded = Migration.decodedRing(from: fetched?.storedBoundaryGeoJSON ?? "") ?? []
        XCTAssertEqual(decoded.first!, decoded.last!, "Kassite homeland ring closed")
        for inside in [(48.3333,33.5),(48.51,34.80),(47.08,34.32),(46.99,35.31),(48.77,33.90),(48.83,34.30),(46.43,33.64),(47.80,35.17)] {
            XCTAssertTrue(pointInRing(inside, decoded), "\(inside) within Kassite homeland")
        }
        for outside in [(44.39,35.47),(49.70,34.09),(48.48,36.67),(47.27,32.68),(46.17,33.11),(45.55,33.74),(44.36,33.34)] {
            XCTAssertFalse(pointInRing(outside, decoded), "\(outside) outside Kassite homeland")
        }
    }

    func testEnsureRiverBoundariesBackfillsRivers() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "Tigris river", modernLocation: "Iraq"))
        context.insert(Place(name: "Euphrates river", modernLocation: "Iraq"))
        context.insert(Place(name: "The Balikh River", modernLocation: "Syria"))
        context.insert(Place(name: "The Diyala River", modernLocation: "Iraq"))
        context.insert(Place(name: "The Irnina Canal", modernLocation: "Iraq"))
        context.insert(Place(name: "The Karkheh River", modernLocation: "Iran"))
        context.insert(Place(name: "The Karun River", modernLocation: "Iran"))
        context.insert(Place(name: "The Khabur River", modernLocation: "Syria"))
        context.insert(Place(name: "The Greater Zab River", modernLocation: "Iraq"))
        context.insert(Place(name: "The Lesser Zab River", modernLocation: "Iraq"))
        context.insert(Place(name: "The Shatt al-Nil (ancient Iturungal)", modernLocation: "Iraq"))
        context.insert(Place(name: "Zagros river", modernLocation: "Iran"))
        try? context.save()

        Migration.ensureRiverBoundaries(context: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let tigris = places.first { $0.name == "Tigris river" }
        let euphrates = places.first { $0.name == "Euphrates river" }
        let balikh = places.first { $0.name == "The Balikh River" }
        let diyala = places.first { $0.name == "The Diyala River" }
        let irnina = places.first { $0.name == "The Irnina Canal" }
        let karkheh = places.first { $0.name == "The Karkheh River" }
        let karun = places.first { $0.name == "The Karun River" }
        let khabur = places.first { $0.name == "The Khabur River" }
        let greaterZab = places.first { $0.name == "The Greater Zab River" }
        let lesserZab = places.first { $0.name == "The Lesser Zab River" }
        let shattNil = places.first { $0.name == "The Shatt al-Nil (ancient Iturungal)" }
        let zagros = places.first { $0.name == "Zagros river" }

        let reachChecks: [(Place?, (Double, Double))] = [
            (tigris, (44.3499559, 33.3604274)),
            (tigris, (43.8151395, 34.2265645)),
            (euphrates, (40.1527833, 35.3436015)),
            (euphrates, (43.284148, 33.438219)),
            (euphrates, (44.3915302, 32.0496843)),
            (balikh, (39.0808251, 35.9404161)),
            (balikh, (39.0173324, 36.289192)),
            (diyala, (44.6094527, 33.760634)),
            (diyala, (45.2106668, 34.3948031)),
            (diyala, (44.5066559, 33.2210595)),
            (irnina, (43.40, 33.35)),
            (irnina, (43.60, 33.30)),
            (irnina, (43.90, 33.22)),
            (irnina, (44.15, 33.28)),
            (irnina, (44.28, 33.31)),
            (karkheh, (48.2258499, 32.179036)),
            (karkheh, (47.5066637, 33.8279668)),
            (karkheh, (48.4428191, 31.5562171)),
            (karun, (49.261, 32.1786)),
            (karun, (48.9594, 32.2625)),
            (karun, (48.6705, 31.3128)),
            (karun, (48.2894, 30.4927)),
            (khabur, (39.716, 37.1181)),
            (khabur, (40.0502, 36.8296)),
            (khabur, (40.7492, 36.4979)),
            (khabur, (40.4316482, 35.1546396)),
            (greaterZab, (43.5396561, 36.1668395)),
            (greaterZab, (43.9453855, 36.9617936)),
            (greaterZab, (43.8771328, 37.6353371)),
            (lesserZab, (43.4965038, 35.2601629)),
            (lesserZab, (44.1103574, 35.6907544)),
            (lesserZab, (45.2435556, 36.0694496)),
            (shattNil, (45.231, 32.127)),
            (shattNil, (45.685, 31.951)),
            (shattNil, (44.63, 32.54)),
            (shattNil, (45.05, 32.31)),
        ]
        let rivers = [(tigris, "Tigris river"), (euphrates, "Euphrates river"), (balikh, "The Balikh River"), (diyala, "The Diyala River"), (irnina, "The Irnina Canal"), (karkheh, "The Karkheh River"), (karun, "The Karun River"), (khabur, "The Khabur River"), (greaterZab, "The Greater Zab River"), (lesserZab, "The Lesser Zab River"), (shattNil, "The Shatt al-Nil (ancient Iturungal)")]
        for (place, name) in rivers {
            XCTAssertNotNil(place?.storedBoundaryGeoJSON, "\(name) got a corridor boundary")
        }
        XCTAssertNil(zagros?.storedBoundaryGeoJSON, "unlisted river untouched")

        for (place, reach) in reachChecks {
            guard place != nil else { continue }
            let name = rivers.first(where: { $0.0 === place })?.1 ?? "river"
            guard let data = place?.storedBoundaryGeoJSON?.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let coordinates = object["coordinates"] as? [[[Double]]],
                  let ring = coordinates.first else {
                XCTFail("\(name) boundary not a Polygon")
                continue
            }
            XCTAssertEqual(object["type"] as? String, "Polygon")
            XCTAssertEqual(ring.first!, ring.last!, "\(name) ring closed")
            XCTAssertGreaterThanOrEqual(ring.count, 4, "\(name) corridor is a closed, non-degenerate ring")
            XCTAssertTrue(pointInRing(reach, ring), "\(name) corridor contains its on-river reach")
        }
    }

    func testEnsureRiverPlacesCreatesAbsentZabs() {
        let container = makeContainer()
        let context = container.mainContext
        let riverType = PlaceType(name: "River, canal", icon: "water.waves", colorHex: "2E7D9C")
        context.insert(riverType)
        context.insert(Place(name: "Tigris river", placeType: riverType, modernLocation: "Iraq"))
        try? context.save()

        Migration.ensureRiverPlaces(context: context)
        Migration.ensureRiverBoundaries(context: context)

        var places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let greaterZab = places.first { $0.name == "The Greater Zab River" }
        let lesserZab = places.first { $0.name == "The Lesser Zab River" }
        XCTAssertNotNil(greaterZab, "Greater Zab created by migration")
        XCTAssertNotNil(lesserZab, "Lesser Zab created by migration")
        XCTAssertEqual(greaterZab?.placeType?.name, "River, canal")
        XCTAssertEqual(lesserZab?.placeType?.name, "River, canal")
        XCTAssertNotNil(greaterZab?.storedBoundaryGeoJSON, "Greater Zab got its corridor")
        XCTAssertNotNil(lesserZab?.storedBoundaryGeoJSON, "Lesser Zab got its corridor")

        Migration.ensureRiverPlaces(context: context)
        places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.count, 3, "migration never duplicates places")
        XCTAssertNotNil(places.first { $0.name == "Tigris river" }, "existing places untouched")
    }

    func testEnsureRiverBoundariesNeverOverwrites() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "Tigris river", modernLocation: "Iraq")
        place.storedBoundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[43.0,33.0],[44.0,33.0],[44.0,34.0],[43.0,33.0]]]}"
        context.insert(place)
        try? context.save()

        Migration.ensureRiverBoundaries(context: context)

        let fetched: Place? = (try? context.fetch(FetchDescriptor<Place>()))?.first
        XCTAssertEqual(fetched?.storedBoundaryGeoJSON, place.storedBoundaryGeoJSON, "existing stored boundary untouched")
    }

    func testEnsureRiverBoundariesIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "Tigris river", modernLocation: "Iraq"))
        try? context.save()

        Migration.ensureRiverBoundaries(context: context)
        let first = (try? context.fetch(FetchDescriptor<Place>()))?.first?.storedBoundaryGeoJSON
        Migration.ensureRiverBoundaries(context: context)
        let second = (try? context.fetch(FetchDescriptor<Place>()))?.first?.storedBoundaryGeoJSON
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second, "second run leaves the boundary identical")
    }

    func testEnsurePlaceBoundariesNeverOverwrites() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "Mesopotamia", modernLocation: "test")
        place.storedBoundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[33.0,44.0],[34.0,44.0],[34.0,45.0],[33.0,44.0]]]}"
        context.insert(place)
        try? context.save()

        Migration.ensurePlaceBoundaries(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<Place>()))?.first
        XCTAssertEqual(fetched?.storedBoundaryGeoJSON, place.storedBoundaryGeoJSON, "existing stored boundary untouched")
    }

    func testAssyriaBoundaryBackfilledAndGeoreferenced() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "Assyria", modernLocation: "Iraq"))
        try? context.save()

        Migration.ensurePlaceBoundaries(context: context)

        let assyria = ((try? context.fetch(FetchDescriptor<Place>())) ?? []).first { $0.name == "Assyria" }
        XCTAssertNotNil(assyria?.storedBoundaryGeoJSON, "Assyria got a kingdom boundary")
        let decoded = Migration.decodedRing(from: assyria?.storedBoundaryGeoJSON ?? "") ?? []
        XCTAssertEqual(decoded.first!, decoded.last!, "Assyria ring closed")
        XCTAssertTrue(pointInRing((43.26, 35.46), decoded), "Assur within Assyria")
        XCTAssertTrue(pointInRing((43.13, 36.27), decoded), "Nineveh within Assyria")
        XCTAssertTrue(pointInRing((44.01, 36.19), decoded), "Erbil within Assyria")
        XCTAssertFalse(pointInRing((33.34, 44.36), decoded), "Baghdad outside Assyria")
        XCTAssertFalse(pointInRing((36.5, 40.7), decoded), "Hasakah outside Assyria")
    }

    func testAssyriaBoundaryNeverOverwritesUserRing() {
        let container = makeContainer()
        let context = container.mainContext
        let place = Place(name: "Assyria", modernLocation: "Iraq")
        place.storedBoundaryGeoJSON = "{\"type\":\"Polygon\",\"coordinates\":[[[39.0,34.0],[45.0,34.0],[45.0,38.0],[39.0,34.0]]]}"
        context.insert(place)
        try? context.save()

        Migration.ensurePlaceBoundaries(context: context)

        let fetched = (try? context.fetch(FetchDescriptor<Place>()))?.first
        XCTAssertEqual(fetched?.storedBoundaryGeoJSON, place.storedBoundaryGeoJSON, "user-drawn Assyria boundary untouched")
    }

    func pointInRing(_ point: (Double, Double), _ ring: [[Double]]) -> Bool {
        var inside = false
        let n = ring.count
        for i in 0..<n {
            let p1 = ring[i]
            let p2 = ring[(i + 1) % n]
            if (p1[1] > point.1) != (p2[1] > point.1)
                && point.0 < (p2[0] - p1[0]) * (point.1 - p1[1]) / (p2[1] - p1[1]) + p1[0] {
                inside.toggle()
            }
        }
        return inside
    }

    func testFromTextSubjectOnly() {
        let result = FromTextParser.parse("Marduk")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertTrue(result.otherRelationships.isEmpty)
        XCTAssertTrue(result.placeLinks.isEmpty)
    }

    func testFromTextSubjectCouldNotResolve() {
        let result = FromTextParser.parse("is a deity")
        XCTAssertEqual(result.subject, "deity")
        XCTAssertTrue(result.otherRelationships.isEmpty)
        XCTAssertTrue(result.placeLinks.isEmpty)
    }

    func testFromTextSonOfCreatesParent() {
        let result = FromTextParser.parse("Marduk the son of Enki and Damkina")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.parents.count, 2)
        XCTAssertTrue(result.parents.contains { $0.fromFigure == "Enki" && $0.toFigure == "Marduk" && $0.relationshipType == "Father" })
        XCTAssertTrue(result.parents.contains { $0.fromFigure == "Damkina" && $0.toFigure == "Marduk" && $0.relationshipType == "Mother" })
        XCTAssertEqual(result.newFigures.sorted(), ["Damkina", "Enki"])
    }

    func testFromTextDaughterOfCreatesMotherRelation() {
        let result = FromTextParser.parse("Inanna the daughter of Nanna")
        XCTAssertEqual(result.parents.count, 1)
        XCTAssertEqual(result.parents.first?.fromFigure, "Nanna")
        XCTAssertEqual(result.parents.first?.toFigure, "Inanna")
        XCTAssertEqual(result.parents.first?.relationshipType, "Mother")
    }

    func testFromTextFatherOfCreatesFatherRelation() {
        let result = FromTextParser.parse("Enki the father of Marduk")
        XCTAssertEqual(result.parents.count, 1)
        XCTAssertEqual(result.parents.first?.fromFigure, "Enki")
        XCTAssertEqual(result.parents.first?.toFigure, "Marduk")
        XCTAssertEqual(result.parents.first?.relationshipType, "Father")
    }

    func testFromTextConsortOfCreatesPreferredSpouse() {
        let result = FromTextParser.parse("Marduk the consort of Sarpanit")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.otherRelationships.count, 1)
        XCTAssertEqual(result.otherRelationships.first?.toFigure, "Sarpanit")
        XCTAssertEqual(result.otherRelationships.first?.relationshipType, "Spouse")
        XCTAssertTrue(result.otherRelationships.first?.isPreferred == true)
    }

    func testFromTextCreatorOf() {
        let result = FromTextParser.parse("Marduk the creator of humans")
        XCTAssertEqual(result.otherRelationships.count, 1)
        XCTAssertEqual(result.otherRelationships.first?.relationshipType, "Creator")
        XCTAssertEqual(result.otherRelationships.first?.fromFigure, "humans")
        XCTAssertEqual(result.otherRelationships.first?.toFigure, "Marduk")
    }

    func testFromTextPatronPlaceLink() {
        let result = FromTextParser.parse("Marduk patron of Babylon")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.placeLinks.count, 1)
        XCTAssertEqual(result.placeLinks.first?.place, "Babylon")
        XCTAssertEqual(result.placeLinks.first?.roleName, "Patron Deity")
        XCTAssertEqual(result.newPlaces, ["Babylon"])
    }

    func testFromTextRulerPlaceLink() {
        let result = FromTextParser.parse("Marduk ruler of Babylon")
        XCTAssertEqual(result.placeLinks.first?.roleName, "Ruler")
        XCTAssertEqual(result.newPlaces, ["Babylon"])
    }

    func testFromTextMultipleRelationshipsWithAnd() {
        let result = FromTextParser.parse("Marduk brother of Ishtar and Ereshkigal")
        XCTAssertEqual(result.otherRelationships.count, 2)
        XCTAssertEqual(result.newFigures, ["Ereshkigal", "Ishtar"])
        XCTAssertTrue(result.otherRelationships.contains { $0.toFigure == "Ishtar" && $0.relationshipType == "Sibling" })
    }

    func testFromTextPartnerSiblingRelationDirection() {
        let partnerResult = FromTextParser.parse("Marduk consort of Sarpanit")
        XCTAssertEqual(partnerResult.otherRelationships.first?.fromFigure, "Marduk")
        XCTAssertEqual(partnerResult.otherRelationships.first?.toFigure, "Sarpanit")

        let parentResult = FromTextParser.parse("Enki father of Marduk")
        XCTAssertEqual(parentResult.parents.first?.fromFigure, "Enki")
        XCTAssertEqual(parentResult.parents.first?.toFigure, "Marduk")
    }

    func testFromTextEmptyYieldsNothing() {
        let result = FromTextParser.parse("")
        XCTAssertEqual(result.subject, "")
        XCTAssertTrue(result.otherRelationships.isEmpty)
        XCTAssertTrue(result.placeLinks.isEmpty)
    }

    func testFromTextSiblingRelationAppearsInNewFigures() {
        let result = FromTextParser.parse("Ishtar sister of Ereshkigal")
        XCTAssertEqual(result.otherRelationships.first?.relationshipType, "Sibling")
        XCTAssertEqual(result.newFigures, ["Ereshkigal"])
    }

    func testFromTextMultipleClausesWithoutSemicolons() {
        let result = FromTextParser.parse("Marduk the son of Enki, consort of Sarpanit, patron of Babylon")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.parents.count, 1)
        XCTAssertEqual(result.parents.first?.fromFigure, "Enki")
        XCTAssertEqual(result.parents.first?.relationshipType, "Father")
        XCTAssertEqual(result.otherRelationships.count, 1)
        XCTAssertEqual(result.otherRelationships.first?.toFigure, "Sarpanit")
        XCTAssertEqual(result.otherRelationships.first?.relationshipType, "Spouse")
        XCTAssertEqual(result.placeLinks.count, 1)
        XCTAssertEqual(result.placeLinks.first?.place, "Babylon")
        XCTAssertEqual(result.placeLinks.first?.roleName, "Patron Deity")
        XCTAssertEqual(result.newFigures.sorted(), ["Enki", "Sarpanit"])
        XCTAssertEqual(result.newPlaces, ["Babylon"])
    }

    func testFromTextNewlineDelimitedClauses() {
        let result = FromTextParser.parse("Sarpanit\nsister of Ishtar\nconsort of Marduk")
        XCTAssertEqual(result.subject, "Sarpanit")
        XCTAssertEqual(result.otherRelationships.count, 2)
        XCTAssertEqual(result.newFigures.sorted(), ["Ishtar", "Marduk"])
    }

    func testFromTextAlternateNames() {
        let result = FromTextParser.parse("Marduk, also known as Bel and Merodach, the patron of Babylon")
        XCTAssertEqual(result.subject, "Marduk")
        XCTAssertEqual(result.alternateNames, ["Bel", "Merodach"])
    }

    func testFromTextHammurabiWikipediaBio() {
        let clip = "Hammurabi (also spelled Hammurapi) was the sixth Amorite king of Babylon, reigning from c. 1792 BC to c. 1750 BC. He was a son of Sin-Muballit."
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.subject, "Hammurabi")
        XCTAssertEqual(result.gender, .male)
        XCTAssertEqual(result.figureKind, .human)
        XCTAssertEqual(result.title, "King")
        XCTAssertEqual(result.alternateNames, ["Hammurapi"])
        XCTAssertEqual(result.parents.count, 1)
        XCTAssertEqual(result.parents.first?.fromFigure, "Sin-Muballit")
        XCTAssertEqual(result.parents.first?.relationshipType, "Father")
        XCTAssertTrue(result.placeLinks.contains { $0.place == "Babylon" && $0.roleName == "Ruler" })
        XCTAssertEqual(result.reignStart, -1792)
        XCTAssertEqual(result.reignEnd, -1750)
        XCTAssertFalse(result.newFigures.contains("became"))
        XCTAssertEqual(result.newFigures, ["Sin-Muballit"])
    }

    func testFromTextQueenGenderInferred() {
        let result = FromTextParser.parse("Kubaba was queen of Kish, the wife of Puzur-Suen")
        XCTAssertEqual(result.gender, .female)
        XCTAssertEqual(result.figureKind, .human)
        XCTAssertEqual(result.title, "Queen")
    }

    func testFromTextAlsoSpelledAlternate() {
        let result = FromTextParser.parse("Hammurabi, also spelled Hammurapi, king of Babylon")
        XCTAssertEqual(result.subject, "Hammurabi")
        XCTAssertEqual(result.alternateNames, ["Hammurapi"])
    }

    func testFromTextPtahWikipediaLead() {
        // Verbatim Wikipedia lead with Greek/Coptic/Phoenician scripts and a
        // descriptive word before a father's name ("father of the sage Imhotep").
        let clip = "Ptah (/tɑː/ TAH;[2] Ancient Egyptian: ptḥ, reconstructed [piˈtaħ]; Ancient Greek: Φθά, romanized: Phthá; Coptic: ⲡⲧⲁϩ, romanized: Ptah; Phoenician: 𐤐𐤕𐤇, romanized: ptḥ)[3][4][note 1] is an ancient Egyptian deity, a creator god,[5] and a patron deity of craftsmen and architects. In the triad of Memphis, he is the husband of Sekhmet and the father of Nefertem. He was also regarded as the father of the sage Imhotep."
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.subject, "Ptah")
        XCTAssertEqual(result.figureKind, .deity)
        XCTAssertEqual(result.gender, .male)
        XCTAssertEqual(result.parents.count, 2)
        XCTAssertEqual(result.parents.map { $0.toFigure }, ["Nefertem", "Imhotep"])
        XCTAssertEqual(result.parents.map { $0.relationshipType }, ["Father", "Father"])
        XCTAssertEqual(result.otherRelationships.map { "\($0.relationshipType):\($0.toFigure)" }, ["Spouse:Sekhmet"])
        XCTAssertEqual(result.newFigures.sorted(), ["Imhotep", "Nefertem", "Sekhmet"])
        XCTAssertTrue(result.placeLinks.isEmpty)
    }

    func testFromTextAkaMarkerWordBoundary() {
        // "aka " must not match inside "Shabaka" — otherwise "Stone" and
        // "Twenty-Fifth Dynasty" leak in as alternate names. Verify on the
        // full Origin-and-symbolism paragraph plus the epithet list.
        let clip = "Ptah is an Egyptian creator god who conceived the world and brought it into being through the creative power of speech. A hymn to Ptah dating to the Twenty-second Dynasty of Egypt says Ptah \"crafted the world in the design of his heart,\" and the Shabaka Stone, from the Twenty-Fifth Dynasty, says Ptah \"gave life to all the gods and their kas as well, through this heart and this tongue.\"[6] Ptah creating the world through heart and tongue, has been subject to comparative interest, in particular with the Jewish conceptions of divine word as a creative process.[7]\n\nHe bears many epithets that describe his role in ancient Egyptian religion and its importance in society at the time:\n\nPtah the begetter of the first beginning\nPtah lord of truth\nPtah lord of eternity\nPtah who listens to prayers\nPtah master of ceremonies\nPtah master of justice\nPtah the God who made himself to be God\nPtah the double being\nPtah the beautiful face"
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.alternateNames, [])
        XCTAssertEqual(result.subject, "Ptah")
    }

    func testFromTextWikipediaLeadWithCuneiform() {
        // Verbatim Wikipedia lead containing supplementary-plane cuneiform
        // (surrogate pairs) — must not corrupt UTF-16/grapheme index mapping.
        let clip = "Hammurabi (/ˌhæmʊˈrɑːbi/; Old Babylonian Akkadian: 𒄩𒄠𒈬𒊏𒁉, romanized: Ḫammu-rāpi;[2][a] Akkadian: [xammuˈraːpʰi]; c. 1810 BC – c. 1750 BC), also spelled Hammurapi,[4][5] was the sixth Amorite king of Babylon, reigning from c. 1792 BC to c. 1750 BC. He was preceded by his father, Sin-Muballit, who abdicated due to failing health. During his reign, he conquered the city-states of Larsa, Eshnunna, and Mari. He ousted Ishme-Dagan I, ruler of the Kingdom of Upper Mesopotamia, bringing almost all of Mesopotamia under Babylonian rule."
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.subject, "Hammurabi")
        XCTAssertEqual(result.alternateNames, ["Hammurapi"], "cuneiform must not corrupt the alternate-name value")
        XCTAssertTrue(result.placeLinks.contains { $0.place == "Babylon" && $0.roleName == "Ruler" })
        XCTAssertTrue(result.placeLinks.contains { $0.place == "Upper Mesopotamia" && $0.roleName == "Ruler" })
        XCTAssertFalse(result.placeLinks.contains { $0.place == "on" }, "no bogus 'on' place from UTF-16 corruption")
        XCTAssertEqual(result.reignStart, -1792)
        XCTAssertEqual(result.reignEnd, -1750)
        XCTAssertEqual(result.birthYear, -1810)
        XCTAssertEqual(result.deathYear, -1750)
        XCTAssertEqual(result.gender, .male)
        XCTAssertEqual(result.figureKind, .human)
        XCTAssertEqual(result.title, "King")
    }

    func testFromTextSubjectSkipsPrepositionalOpeners() {
        // Blurbs that open with a prepositional phrase or epithet, not the name.
        XCTAssertEqual(FromTextParser.parse("In Mesopotamian mythology, Ereshkigal was the queen of the underworld, also known as Allatu.").subject, "Ereshkigal")
        XCTAssertEqual(FromTextParser.parse("In Sumerian religion, Enki was the god of wisdom, fresh water and magic.").subject, "Enki")
        XCTAssertEqual(FromTextParser.parse("In the ancient city of Ur, Nanna was the moon god, patron of the city.").subject, "Nanna")
        XCTAssertEqual(FromTextParser.parse("According to the Sumerian King List, Etana ruled Kish.").subject, "Etana")
        XCTAssertEqual(FromTextParser.parse("God of the sun and justice, Shamash was worshipped in Sippar and Larsa.").subject, "Shamash")
        XCTAssertEqual(FromTextParser.parse("Lady of the great temple at Uruk, Inanna was the goddess of love and war.").subject, "Inanna")
        XCTAssertEqual(FromTextParser.parse("The ruler of the underworld, Nergal was a fearsome deity.").subject, "Nergal")
        XCTAssertEqual(FromTextParser.parse("A powerful storm god, Ishkur was venerated in Karkar.").subject, "Ishkur")
    }

    func testFromTextSubjectHandlesPossessiveAndPassive() {
        // Possessive subject: "Nergal's consort was Ereshkigal" — the figure is
        // the complement after the copula, not "Nergal".
        XCTAssertEqual(FromTextParser.parse("Nergal's consort was Ereshkigal, queen of the underworld.").subject, "Ereshkigal")
        // Pronoun stand-in resolved through the subordinate clause.
        XCTAssertEqual(FromTextParser.parse("It is said that Ptah created the world").subject, "Ptah")
        // Passive construction: the figure is the object of "by".
        XCTAssertEqual(FromTextParser.parse("The Akkadian Empire was founded by Sargon the Great.").subject, "Sargon")
        XCTAssertEqual(FromTextParser.parse("The city of Uruk was ruled by Gilgamesh.").subject, "Gilgamesh")
        XCTAssertEqual(FromTextParser.parse("The temple of Eanna was built by Naram-Sin.").subject, "Naram-Sin")
        XCTAssertEqual(FromTextParser.parse("The state of Lagash was conquered by Eannatum.").subject, "Eannatum")
        // A person as grammatical subject is preserved (not overridden by "by").
        XCTAssertEqual(FromTextParser.parse("Hammurabi was preceded by his father, Sin-Muballit.").subject, "Hammurabi")
        XCTAssertEqual(FromTextParser.parse("Sargon was born in Azupiranu on the banks of the Euphrates.").subject, "Sargon")
    }

    func testFromTextSubjectTitleCaseHeadingNotWholeSentence() {
        // Title-cased headings used to swallow the whole first sentence as the name.
        XCTAssertEqual(FromTextParser.parse("Ptah Lord Of Truth Lord Of Eternity Who Listens To Prayers").subject, "Ptah")
        XCTAssertEqual(FromTextParser.parse("Inanna Queen Of Heaven And Earth Goddess Of Love And War").subject, "Inanna")
        XCTAssertEqual(FromTextParser.parse("Ptah Creator God Of Memphis And Patron Of Craftsmen").subject, "Ptah")
        XCTAssertEqual(FromTextParser.parse("Ereshkigal Queen Of The Underworld Also Known As Allatu").subject, "Ereshkigal")
        XCTAssertEqual(FromTextParser.parse("Ptah Who Listens to Prayers").subject, "Ptah")
        XCTAssertEqual(FromTextParser.parse("The Sumerian goddess Inanna was known as Ishtar to the Akkadians.").subject, "Inanna")
    }

    func testFromTextGenderDeityDetected() {
        let male = FromTextParser.parse("Marduk is a god of Babylon, the son of Enki")
        XCTAssertEqual(male.gender, .male)
        XCTAssertEqual(male.figureKind, .deity)

        let female = FromTextParser.parse("Sarpanit is a goddess, the consort of Marduk")
        XCTAssertEqual(female.gender, .female)
        XCTAssertEqual(female.figureKind, .deity)
    }

    func testFromTextKingWithDeityMentionIsHuman() {
        // A historical king's biography mentions gods (of predecessors, temples)
        // but must classify as human, not deity.
        let result = FromTextParser.parse("Hammurabi king of Babylon, reigned 1792 BC, son of Sin-Muballit")
        XCTAssertEqual(result.figureKind, .human)
    }

    func testFromTextRulerMentionOfGodIsHuman() {
        // "successor of the god X" in a reign line must not flip a king to deity.
        let result = FromTextParser.parse("Ur-Nammu ruler of Ur, the successor of the god Enlil, reigned 2112 BC")
        XCTAssertEqual(result.figureKind, .human)
    }

    func testFromTextDeityPredicationStillDetected() {
        // Subject predicated as a god keeps deity classification.
        let result = FromTextParser.parse("Marduk is a god of Babylon, the son of Enki")
        XCTAssertEqual(result.figureKind, .deity)
    }

    func testFromTextDomainAndTitle() {
        let result = FromTextParser.parse("Marduk, the god of creation and wisdom, lord of Babylon")
        XCTAssertEqual(result.domain?.lowercased().contains("creation"), true)
    }

    func testFromTextReturnsClipAsDescription() {
        let clip = "Marduk is the patron deity of Babylon and the son of Enki and Damkina."
        let result = FromTextParser.parse(clip)
        XCTAssertEqual(result.description, clip)
    }

}
