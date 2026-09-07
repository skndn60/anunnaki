import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
    // MARK: - ConsistencyEngine

    func runConsistency(_ context: ModelContext) -> [ConsistencyFinding] {
        ConsistencyEngine.runAll(
            figures: (try? context.fetch(FetchDescriptor<Figure>())) ?? [],
            relationships: (try? context.fetch(FetchDescriptor<Relationship>())) ?? [],
            alternateNames: (try? context.fetch(FetchDescriptor<AlternateName>())) ?? [],
            events: (try? context.fetch(FetchDescriptor<Event>())) ?? [],
            eras: (try? context.fetch(FetchDescriptor<Era>())) ?? []
        )
    }

    func makeRelationType(_ name: String, in context: ModelContext) -> RelationshipType {
        let type = RelationshipType(name: name, icon: "link", colorHex: "8E8E93", category: "family")
        context.insert(type)
        return type
    }

    func testPronounRuleFlagsOnlyOppositePronouns() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "MaleWithShe", gender: .male,
                              figureDescription: "She guards her city."))
        context.insert(Figure(name: "FemaleWithHe", gender: .female,
                              figureDescription: "He rules; his word is law."))
        context.insert(Figure(name: "MixedPronouns", gender: .male,
                              figureDescription: "He and his wife — she outlived him."))
        context.insert(Figure(name: "SubstringSafety", gender: .male,
                              figureDescription: "Lord of history here; heir to everything."))
        context.insert(Figure(name: "UnknownGender", gender: .unknown,
                              figureDescription: "She appears in her temple."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .pronounGender }
        XCTAssertEqual(Set(findings.map(\.entityName)), Set(["MaleWithShe", "FemaleWithHe"]))
    }

    func testPronounRuleIgnoresSingleBackwardReference() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Dumuzi", gender: .male, figureDescription:
            "Shepherd god and consort of Inanna. Sent to the underworld as her substitute."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .pronounGender }
        XCTAssertTrue(findings.isEmpty,
                      "a lone \"her\" pointing back at a named woman is coreference, not misgendering")
    }

    func testPronounRuleDefersToMentionedFigureOfSameGender() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Enki", gender: .male, figureDescription: "God of fresh water and crafts."))
        context.insert(Figure(name: "Ninkasi", gender: .female, figureDescription:
            "Goddess of beer. Enki blessed her brew; mortals praised him for the recipe he shared."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .pronounGender }
        XCTAssertTrue(findings.isEmpty,
                      "\"he/him\" after naming male Enki belongs to him, not female Ninkasi")
    }

    func testPronounRuleStillFlagsWhenHomonymKeysAreAmbiguous() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Nanna", gender: .male))
        context.insert(Figure(name: "Nanna", gender: .female, figureDescription:
            "Nanna brewed the ritual beer. He tasted it first; he approved the batch."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .pronounGender }
        XCTAssertEqual(findings.count, 1,
                       "a homonymous name claimed by both genders must never veto genuine findings")
    }

    func testGenderedNounRuleUsesWholeWords() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "MaleGoddessWording", title: "Patron of Dilbat", gender: .male,
                              figureDescription: "A goddess of farming boundaries."))
        context.insert(Figure(name: "FemaleGodWording", gender: .female,
                              figureDescription: "A goddess who advised the king of Kish."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .genderedNoun }
        XCTAssertEqual(findings.count, 1, "\"god\" inside 'goddess' must not leak into the masculine set")
        XCTAssertEqual(findings.first?.entityName, "MaleGoddessWording")

        let consistent = runConsistency(context).filter { $0.entityName == "FemaleGodWording" && $0.kind == .genderedNoun }
        XCTAssertTrue(consistent.isEmpty,
                      "goddess + king is mixed wording — skipped, and 'kingdom' never counts as 'king'")
    }

    func testGenderedNounIgnoresRelationalKinshipNouns() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Daughters of Men", gender: .female, figureDescription: "She mourned her husband and brother — an undefined number of females."))
        try? context.save()
        let findings = runConsistency(context).filter { $0.entityName == "Daughters of Men" && $0.kind == .genderedNoun }
        XCTAssertTrue(findings.isEmpty,
                      "kinship nouns (husband/brother) describe others, not the figure's own gender: \(findings.map { $0.message })")
    }

    func testGenderWordingExemptsKubaba() {
        let container = makeContainer()
        let context = container.mainContext
        // Kubaba is recorded on the SKL as the only female "king" of Kish — the
        // masculine wording is historically correct, so it must not flag.
        context.insert(Figure(name: "Kug-Bau", title: "King of Third dynasty of Kish", gender: .female,
                              figureDescription: "Kubaba became king of Kish, the only woman to do so."))
        try? context.save()

        let kubaba = runConsistency(context).filter {
            $0.entityName == "Kug-Bau" && ($0.kind == .genderedNoun || $0.kind == .pronounGender)
        }
        XCTAssertTrue(kubaba.isEmpty, "Kubaba's authentic 'king' wording must not flag: \(kubaba.map { $0.message })")

        // A different female figure described as a king is still caught.
        context.insert(Figure(name: "Unrelated", gender: .female,
                              figureDescription: "She was made king of the city."))
        try? context.save()
        let other = runConsistency(context).filter {
            $0.entityName == "Unrelated" && ($0.kind == .genderedNoun || $0.kind == .pronounGender)
        }
        XCTAssertEqual(other.count, 1, "a non-exempt female figure described as 'king' should still flag")
    }

    func testGenderWordingExemptsDaughtersOfMan() {
        let container = makeContainer()
        let context = container.mainContext
        // "The daughters of Man" is a female collective whose description analyzes
        // Genesis 6:1-4 ("the sons of God", "kings", "warriors"). That wording
        // describes the passage, not the figure, so it must not flag.
        context.insert(Figure(name: "The daughters of Man", gender: .female,
                              figureDescription: "The 'sons of God' saw that they were fair; These were the heroes that were of old."))
        try? context.save()

        let exempt = runConsistency(context).filter {
            $0.entityName == "The daughters of Man" && ($0.kind == .genderedNoun || $0.kind == .pronounGender)
        }
        XCTAssertTrue(exempt.isEmpty, "The daughters of Man must not flag for quoting 'sons of God': \(exempt.map { $0.message })")

        // A different female figure is still caught for the same wording.
        context.insert(Figure(name: "Unrelated", gender: .female,
                              figureDescription: "Some claimed she was a god, but the records show otherwise."))
        try? context.save()
        let other = runConsistency(context).filter {
            $0.entityName == "Unrelated" && ($0.kind == .genderedNoun || $0.kind == .pronounGender)
        }
        XCTAssertEqual(other.count, 1, "a non-exempt female figure described with 'god' should still flag")
    }

    func testCorrectAnomalousGenealogyResolvesChildBornBeforeParentFindings() {
        let container = makeContainer()
        let context = container.mainContext
        let fatherType = makeRelationType("Father", in: context)

        func fig(_ name: String, _ birth: Int?, _ death: Int? = nil, reignStart: Int? = nil, reignEnd: Int? = nil) -> Figure {
            var figure = Figure(
                name: name,
                birthDate: MythologicalDate(startYear: birth),
                deathDate: MythologicalDate(startYear: death)
            )
            figure.reignStartYear = reignStart
            figure.reignEndYear = reignEnd
            context.insert(figure)
            return figure
        }

        let manishtushu = fig("Manishtushu", -2205)
        let naramSin = fig("Naram-Sin of Akkad", -2280)
        let burSuen = fig("Bur-Suen", -1821)
        let lipitEnlil = fig("Lipit-Enlil", -1874, -1868, reignStart: -1874, reignEnd: -1868)
        let hablum = fig("Hablum", -2135)
        let puzurSuen = fig("Puzur-Suen", -2273)
        let mahalalel = fig("Mahalalel", -3386)
        let jared = fig("Jared", -3544, -2624, reignStart: -3544, reignEnd: -2624)
        let enoch = fig("Enoch", -3382, -3019, reignStart: -3382, reignEnd: -3019)
        let rachujal = fig("Rachujal", -3603)
        let rashujal = fig("Rashujal", -3749)

        context.insert(Relationship(fromFigure: manishtushu, toFigure: naramSin, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: burSuen, toFigure: lipitEnlil, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: hablum, toFigure: puzurSuen, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: mahalalel, toFigure: jared, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: jared, toFigure: enoch, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: rachujal, toFigure: rashujal, relationshipType: makeRelationType("Mother", in: context)))
        context.insert(IntegrityFinding(kindRaw: "childBornBeforeParent", severityRaw: "warning",
                                        entityKind: "Figure", entityKey: "Jared", detail: "stale"))
        try? context.save()

        let before = runConsistency(context).filter { $0.kind == .childBornBeforeParent }
        XCTAssertEqual(before.count, 5, "fixture should reproduce all five warnings, got \(before.map { $0.message })")

        Migration.correctAnomalousGenealogy(context: context)

        XCTAssertEqual(manishtushu.birthDate.startYear, -2305, "Manishtushu birth rebased before Naram-Sin")
        XCTAssertEqual(lipitEnlil.birthDate.startYear, -1800, "Lipit-Enlil reign moved after Bur-Suen's death")
        XCTAssertEqual(lipitEnlil.deathDate.startYear, -1790)
        XCTAssertEqual(lipitEnlil.reignStartYear, -1800)
        XCTAssertEqual(jared.birthDate.startYear, -3321, "Jared = Mahalalel + 65 per Genesis 5:15")
        XCTAssertEqual(enoch.birthDate.startYear, -3159, "Enoch = Jared + 162 per Genesis 5:21")
        XCTAssertEqual(jared.deathDate.startYear, -2359, "Jared lived 962 years")
        XCTAssertEqual(enoch.reignEndYear, -2794, "Enoch lived 365 years")

        let puzurRels = (try? context.fetch(FetchDescriptor<Relationship>()))?.filter {
            $0.fromFigure?.name == "Hablum" && $0.toFigure?.name == "Puzur-Suen"
        } ?? []
        XCTAssertTrue(puzurRels.isEmpty, "chronologically impossible Hablum→Puzur-Suen father edge removed")

        let dismissal = (try? context.fetch(FetchDescriptor<FindingDismissal>())) ?? []
        XCTAssertTrue(dismissal.contains { $0.signature == "childBornBeforeParent|Rashujal" },
                      "mythical Watcher pair dismissed in app")

        let staleFindings = ((try? context.fetch(FetchDescriptor<IntegrityFinding>())) ?? []).filter { $0.kindRaw == "childBornBeforeParent" }
        XCTAssertTrue(staleFindings.isEmpty, "stale persisted findings cleared")

        let after = runConsistency(context).filter { $0.kind == .childBornBeforeParent }
        XCTAssertEqual(after.map { $0.entityName }, ["Rashujal"],
                       "only the dismissed mythical pair still computes a finding")

        Migration.correctAnomalousGenealogy(context: context)
        let afterSecond = runConsistency(context).filter { $0.kind == .childBornBeforeParent }
        XCTAssertEqual(afterSecond.map { $0.entityName }, ["Rashujal"],
                       "migration idempotent — rerun changes nothing")
        XCTAssertEqual(manishtushu.birthDate.startYear, -2305)
    }

    func testRoleGenderRuleFlagsContradictingEndpoints() {
        let container = makeContainer()
        let context = container.mainContext
        let fatherType = makeRelationType("Father", in: context)
        let motherType = makeRelationType("Mother", in: context)
        let spouseType = makeRelationType("Spouse", in: context)
        let mom = Figure(name: "Mom", gender: .female)
        let dad = Figure(name: "Dad", gender: .male)
        let son = Figure(name: "Son", gender: .male)
        context.insert(mom); context.insert(dad); context.insert(son)
        context.insert(Relationship(fromFigure: dad, toFigure: son, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: mom, toFigure: son, relationshipType: motherType))
        context.insert(Relationship(fromFigure: mom, toFigure: dad, relationshipType: spouseType))
        try? context.save()
        XCTAssertEqual(runConsistency(context).filter { $0.kind == .roleGender }.count, 0)

        context.insert(Relationship(fromFigure: mom, toFigure: son, relationshipType: fatherType))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .roleGender }
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings[0].message.contains("listed in the \"Father\" role"))
    }

    func testParentCycleRuleFlagsMutualAndSelfParentage() {
        let container = makeContainer()
        let context = container.mainContext
        let fatherType = makeRelationType("Father", in: context)
        let motherType = makeRelationType("Mother", in: context)
        let creatorType = makeRelationType("Creator", in: context)
        let a = Figure(name: "A", gender: .male)
        let b = Figure(name: "B", gender: .male)
        let c = Figure(name: "C", gender: .male)
        let d = Figure(name: "D", gender: .male)
        context.insert(a); context.insert(b); context.insert(c); context.insert(d)
        context.insert(Relationship(fromFigure: a, toFigure: b, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: b, toFigure: a, relationshipType: motherType))
        context.insert(Relationship(fromFigure: c, toFigure: c, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: d, toFigure: d, relationshipType: creatorType, source: ""))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .parentCycle }
        XCTAssertEqual(findings.count, 2, "mutual pair reported once despite two edges; self-creation via Creator is legitimate")
        XCTAssertEqual(Set(findings.map(\.entityName)), Set(["A ↔ B", "C"]))
    }

    func testInvertedLifeDatesRule() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(
            name: "TimeTraveller",
            figureDescription: "Born late, died earlier.",
            birthDate: MythologicalDate(year: -100),
            deathDate: MythologicalDate(year: -500)
        ))
        context.insert(Figure(
            name: "NormalLife",
            figureDescription: "",
            birthDate: MythologicalDate(year: -500),
            deathDate: MythologicalDate(year: -450)
        ))
        context.insert(Figure(name: "Immortal", figureDescription: ""))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .invertedDates }
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.entityName, "TimeTraveller")
    }

    func testUnknownEraReferenceRule() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Era(name: "Old Babylonian Period"))
        context.insert(Figure(
            name: "TypoKing",
            figureDescription: "",
            birthDate: MythologicalDate(year: -1800, era: "Old Babylonain Peroid"),
            deathDate: MythologicalDate(year: -1750, era: "Old Babylonian Period")
        ))
        context.insert(Event(
            name: "Some Event",
            eventDescription: "",
            era: "Ur Iii Periode"
        ))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .unknownEra }.map(\.message)
        XCTAssertEqual(findings.count, 2)
        XCTAssertTrue(findings.contains { $0.contains("Birth date") && $0.contains("Old Babylonain Peroid") })
        XCTAssertTrue(findings.contains { $0.contains("Ur Iii Periode") },
                      "normalized matching means the valid death-era string passes while typos surface")
    }

    func testAmbiguousAliasRule() {
        let container = makeContainer()
        let context = container.mainContext
        let f1 = Figure(name: "First")
        let f2 = Figure(name: "Second")
        let f3 = Figure(name: "Third")
        context.insert(f1); context.insert(f2); context.insert(f3)
        context.insert(AlternateName(figure: f1, name: "Ninsianna"))
        context.insert(AlternateName(figure: f2, name: "Ninsi'anna"))
        context.insert(AlternateName(figure: f3, name: "Ninsianna"))
        context.insert(AlternateName(figure: f1, name: "Unique Alias"))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .ambiguousAlias }
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.entityName, "Ninsianna")
        XCTAssertEqual(findings.first?.message, "The name \"Ninsianna\" is attached to multiple figures: First, Second, Third.")
    }

    func testAmbiguousAliasRuleSkipsSyncretismNames() {
        let container = makeContainer()
        let context = container.mainContext
        let asalluhi = Figure(name: "Asalluhi")
        let marduk = Figure(name: "Marduk")
        context.insert(asalluhi); context.insert(marduk)
        context.insert(AlternateName(figure: asalluhi, name: "Asarluhi", nameType: .syncretism))
        context.insert(AlternateName(figure: marduk, name: "Asarluhi", nameType: .syncretism))

        let a = Figure(name: "A")
        let b = Figure(name: "B")
        context.insert(a); context.insert(b)
        context.insert(AlternateName(figure: a, name: "Dup"))
        context.insert(AlternateName(figure: b, name: "Dup"))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .ambiguousAlias }
        XCTAssertEqual(findings.count, 1, "syncretism-typed shared aliases are exempt; real duplicates still flag")
        XCTAssertEqual(findings.first?.entityName, "Dup")
    }

    func testVariantProseFoldingMapsNinNibruSpellingBackToFigureNinnibru() {
        let source = "Ninnibru, also romanized as Nin-Nibru, was a Mesopotamian goddess regarded as the wife of Ninurta."
        let folded = FoldedProse(source: source)
        XCTAssertEqual(folded.text, "ninnibru, also romanized as ninnibru, was a mesopotamian goddess regarded as the wife of ninurta")

        let key = DuplicateMerger.normalizationKey("Ninnibru")
        let regex = try! NSRegularExpression(pattern: "\\b(?:\(NSRegularExpression.escapedPattern(for: key)))\\b", options: [.caseInsensitive])
        let matches = regex.matches(in: folded.text, range: NSRange(folded.text.startIndex..., in: folded.text))
            .compactMap { folded.origRange(for: $0.range) }
            .map { (source as NSString).substring(with: $0) }

        XCTAssertEqual(matches, ["Ninnibru", "Nin-Nibru"],
            "the hyphen variant 'Nin-Nibru' must fold to the same key as the registered 'Ninnibru' and map back to its original span")
    }

    func testVariantProseFoldingPreservesWordBoundaries() {
        let source = "Ninnibru was the wife of Ninurta, not a Nin Nibru gate."
        let folded = FoldedProse(source: source)
        let key = DuplicateMerger.normalizationKey("Ninnibru")
        let regex = try! NSRegularExpression(pattern: "\\b(?:\(NSRegularExpression.escapedPattern(for: key)))\\b", options: [.caseInsensitive])
        let matches = regex.matches(in: folded.text, range: NSRange(folded.text.startIndex..., in: folded.text))
            .compactMap { folded.origRange(for: $0.range) }
            .map { (source as NSString).substring(with: $0) }
        XCTAssertEqual(matches, ["Ninnibru"],
            "the space-separated 'Nin Nibru' is a different name and must not fold into a match")
    }

    func testAutoLinkResolverMatchesNinNibruVariantInRealSeedData() {
        let container = makeContainer()
        let context = ModelContext(container)
        SeedData.ensureTypesExist(context: context)
        Migration.ensureMesopotamianDeitiesImportExist(context: context)
        Migration.ensureAlternateNamesImportExist(context: context)
        try? context.save()

        var matchTexts: [String] = []
        for figure in context.fetchAll() as [Figure] {
            matchTexts.append(figure.name)
            for alt in figure.alternateNames { matchTexts.append(alt.name) }
        }
        for place in context.fetchAll() as [Place] {
            matchTexts.append(place.name)
            for alt in place.alternateNames { matchTexts.append(alt.name) }
        }
        for event in context.fetchAll() as [Event] {
            matchTexts.append(event.name)
        }

        let resolver = LinkResolver(matchTexts: matchTexts)
        let description = "Ninnibru, also romanized as Nin-Nibru, was a Mesopotamian goddess regarded as the wife of Ninurta."
        let spans = resolver.resolve(in: description)

        let linked = spans.compactMap { span -> String? in
            guard let figure = (context.fetchAll() as [Figure]).first(where: {
                $0.name == span.matchText || DuplicateMerger.normalizationKey($0.name) == span.key
            }) else { return nil }
            let range = span.range
            let text = (description as NSString).substring(with: range)
            return "\(text)→\(figure.name)"
        }
        XCTAssertEqual(linked, ["Ninnibru→Ninnibru", "Nin-Nibru→Ninnibru"],
            "both the exact 'Ninnibru' and the hyphen-variant 'Nin-Nibru' must resolve to the Ninnibru figure")
    }

    func testAutoLinkResolverDoesNotMatchSpaceSeparatedVariants() {
        let resolver = LinkResolver(matchTexts: ["Ninnibru"])
        let description = "She was not a Nin Nibru goddess, yet she merged with Nin-Nibru regularly."
        let spans = resolver.resolve(in: description)
        let linked = spans.map { (description as NSString).substring(with: $0.range) }
        XCTAssertEqual(linked, ["Nin-Nibru"],
            "a space-separated 'Nin Nibru' is a different word pair and must not link, while the hyphen variant still does")
    }

    func testAmbiguousAliasRuleSkipsLogographicReadingNames() {
        let container = makeContainer()
        let context = container.mainContext
        let ishkur = Figure(name: "Ishkur")
        let wer = Figure(name: "Wer")
        context.insert(ishkur); context.insert(wer)
        context.insert(AlternateName(figure: ishkur, name: "Mer", nameType: .logographic))
        context.insert(AlternateName(figure: wer, name: "Mer", nameType: .spelling))

        let a = Figure(name: "A")
        let b = Figure(name: "B")
        context.insert(a); context.insert(b)
        context.insert(AlternateName(figure: a, name: "Dup"))
        context.insert(AlternateName(figure: b, name: "Dup"))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .ambiguousAlias }
        XCTAssertEqual(findings.count, 1, "a logographic reading like dIM='Mer' is shared across storm-god figures; real spelling duplicates still flag")
        XCTAssertEqual(findings.first?.entityName, "Dup")
    }

    func testAmbiguousAliasRuleSkipsEpithetAndTranslationNames() {
        let container = makeContainer()
        let context = container.mainContext
        let ashur = Figure(name: "Ashur")
        let marduk = Figure(name: "Marduk")
        context.insert(ashur); context.insert(marduk)
        context.insert(AlternateName(figure: ashur, name: "Bel", nameType: .epithet))
        context.insert(AlternateName(figure: marduk, name: "Bel", nameType: .epithet))
        context.insert(AlternateName(figure: ashur, name: "Malka", nameType: .translation))
        context.insert(AlternateName(figure: marduk, name: "Malka", nameType: .translation))

        let a = Figure(name: "A")
        let b = Figure(name: "B")
        context.insert(a); context.insert(b)
        context.insert(AlternateName(figure: a, name: "Dup"))
        context.insert(AlternateName(figure: b, name: "Dup"))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .ambiguousAlias }
        XCTAssertEqual(findings.count, 1, "a shared epithet/title like Bel is normal; real spelling duplicates still flag")
        XCTAssertEqual(findings.first?.entityName, "Dup")
    }

    func testStubFigureRule() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Bare Name"))
        context.insert(Figure(name: "Exempt Stub", figureDescription: ""))
        if let exempt = try? context.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.name == "Exempt Stub" })).first {
            exempt.coverageExempt = true
        }
        let rich = Figure(name: "Rich Figure", domain: "Wisdom", figureDescription: "Full record.")
        let linked = Figure(name: "Linked Stub")
        context.insert(rich)
        context.insert(linked)
        context.insert(Relationship(fromFigure: rich, toFigure: linked,
                                    relationshipType: makeRelationType("Father", in: context)))
        try? context.save()

        let stubs = runConsistency(context).filter { $0.kind == .stubFigure }.map(\.entityName)
        XCTAssertEqual(stubs, ["Bare Name"])
    }

    func testNameVariantRuleFlagsCollapsedSpelling() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Enbi-Ishtar", gender: .male, figureDescription:
            "King of Kish in the Early Dynastic period. The cult of Enbiishtar flourished at Kish."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .nameVariant }
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings[0].message.contains("Enbiishtar"))
        XCTAssertTrue(findings[0].message.contains("Enbi-Ishtar"))
    }

    func testNameVariantRuleAcceptsExactSpellingsAndWordBoundaries() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Anu", gender: .male))
        context.insert(Figure(name: "Inanna", gender: .female))
        context.insert(Figure(name: "Enbi-Ishtar", gender: .male, figureDescription:
            "King of Kish who honored Inanna and Anu. The Anunnaki judged mortals; Enbi-Ishtar reigned."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .nameVariant }
        XCTAssertTrue(findings.isEmpty,
                      "exact mentions stay silent and \"Anu\" inside \"Anunnaki\" must not fire")
    }

    func testNameVariantRuleSkipsAmbiguousKeys() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Ea-nasir", gender: .male))
        context.insert(Figure(name: "Ea Nasir", gender: .male))
        context.insert(Figure(name: "Scribe", figureDescription:
            "Complaints against Eanasir are the earliest customer reviews."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .nameVariant }
        XCTAssertTrue(findings.isEmpty, "a key shared by several spellings cannot recommend one")
    }

    func testNameVariantRuleDoesNotFuseAdjacentMentionsAcrossPunctuation() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Urur", gender: .male))
        context.insert(Figure(name: "Lu-Enlilla", gender: .male, figureDescription:
            "Merchant during the Third Dynasty of Ur (Ur III period). Acting on behalf of the Temple of Nanna at Ur."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .nameVariant }
        XCTAssertTrue(findings.isEmpty,
                      "\"…of Ur (Ur III…\" is two mentions of Ur, not a misspelling of the figure Urur")
    }

    func testNameVariantRuleDoesNotSplitHyphenatedNames() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Su'en", gender: .male))
        context.insert(Figure(name: "Yarlaganda", gender: .male, figureDescription:
            "Yarlaganda succeeded Puzur-Suen and his reign represents the twilight of the Gutian era."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .nameVariant }
        XCTAssertTrue(findings.isEmpty,
                      "the \"Suen\" inside \"Puzur-Suen\" is a name segment, not a variant of \"Su'en\"")
    }

    func testNameVariantRuleTreatsDeterminativeDotAsWordInterior() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Ninmar", gender: .female, figureDescription:
            "Nin-MAR.KI (reading uncertain) was the daughter of Nanshe."))
        try? context.save()

        let findings = runConsistency(context).filter { $0.kind == .nameVariant }
        XCTAssertTrue(findings.isEmpty,
                      "the \".KI\" determinative is word-interior, so \"Nin-MAR.KI\" must not fire as a variant of \"Ninmar\"")
    }

    // MARK: - Consistency repairs & historical period eras

    func makeGenderedPair(_ context: ModelContext) -> (male: Figure, female: Figure) {
        let male = Figure(name: "Uras", title: "patron god of Dilbat", gender: .male)
        let female = Figure(name: "Uras", gender: .female)
        context.insert(male)
        context.insert(female)
        return (male, female)
    }

    func testRepairMovesUrasMotherEdgesToTheGoddess() {
        let container = makeContainer()
        let context = container.mainContext
        let (male, goddess) = makeGenderedPair(context)
        let ninsun = Figure(name: "Ninsun", gender: .female)
        let ninisina = Figure(name: "Ninisina", gender: .female)
        let other = Figure(name: "Unrelated Child", gender: .female)
        context.insert(ninsun); context.insert(ninisina); context.insert(other)
        let motherType = makeRelationType("Mother", in: context)
        context.insert(Relationship(fromFigure: male, toFigure: ninsun, relationshipType: motherType))
        context.insert(Relationship(fromFigure: male, toFigure: ninisina, relationshipType: motherType))
        context.insert(Relationship(fromFigure: male, toFigure: other, relationshipType: motherType))
        try? context.save()

        Migration.ensureConsistentParentRoles(context: context)

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(edges.filter { $0.toFigure === ninsun || $0.toFigure === ninisina }
            .compactMap(\.fromFigure), [goddess, goddess])
        XCTAssertEqual(edges.filter { $0.toFigure === other }.first?.fromFigure, male,
                       "edges to other children are untouched — scoped strictly to Ninsun/Ninisina")

        Migration.ensureConsistentParentRoles(context: context)
        XCTAssertEqual(edges.filter { $0.fromFigure === goddess }.count, 2, "idempotent")
    }

    func testRepairNoOpsWhenNoFemaleNamesakeExists() {
        let container = makeContainer()
        let context = container.mainContext
        let loneMale = Figure(name: "Uras", title: "patron god of Dilbat", gender: .male)
        let ninsun = Figure(name: "Ninsun", gender: .female)
        context.insert(loneMale); context.insert(ninsun)
        context.insert(Relationship(fromFigure: loneMale, toFigure: ninsun,
                                    relationshipType: makeRelationType("Mother", in: context)))
        try? context.save()

        Migration.ensureConsistentParentRoles(context: context)

        let edge = (try? context.fetch(FetchDescriptor<Relationship>()))?.first
        XCTAssertEqual(edge?.fromFigure, loneMale,
                       "without a female namesake the edge must stay — no blind re-pointing")
    }

    func testRepairRetypesRachujalFatherEdgeAndLeavesSelfEdge() {
        let container = makeContainer()
        let context = container.mainContext
        let rachujal = Figure(name: "Rachujal", gender: .female)
        let rashujal = Figure(name: "Rashujal", gender: .male)
        context.insert(rachujal); context.insert(rashujal)
        let fatherType = makeRelationType("Father", in: context)
        let motherType = makeRelationType("Mother", in: context)
        context.insert(Relationship(fromFigure: rachujal, toFigure: rashujal, relationshipType: fatherType))
        let selfEdge = Relationship(fromFigure: rashujal, toFigure: rashujal, relationshipType: motherType)
        context.insert(selfEdge)
        try? context.save()

        Migration.ensureConsistentParentRoles(context: context)

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(edges.first { $0.fromFigure === rachujal }?.relationshipType?.name, "Mother")
        XCTAssertEqual(edges.first { $0.fromFigure === rashujal && $0.toFigure === rashujal }?.relationshipType?.name,
                       "Mother", "the self-edge is user data — it stays until removed by hand")
    }

    func testHistoricalPeriodErasCreatedOrderedAndDriftProof() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        Migration.ensureHistoricalPeriodEras(context: context)
        Migration.fixEraOrderIndices(context: context)
        Migration.fixEraOrderIndices(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        XCTAssertEqual(eras.count, 3)
        let byName = Dictionary(eras.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(byName["Old Assyrian Period"]?.orderIndex, 31)
        XCTAssertEqual(byName["Old Babylonian Period"]?.orderIndex, 32)
        XCTAssertEqual(byName["Neo-Assyrian Period"]?.orderIndex, 33)
        XCTAssertEqual(byName["Old Babylonian Period"]?.startDate.startYear, -1894)
        XCTAssertEqual(byName["Neo-Assyrian Period"]?.endDate.endYear, -609)

        Migration.ensureHistoricalPeriodEras(context: context)
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Era>())) ?? -1, 3, "check-by-name idempotency")
    }

    func testHistoricalPeriodErasSkipExistingUserEra() {
        let container = makeContainer()
        let context = container.mainContext
        let usersEra = Era(name: "Old Babylonian Period")
        usersEra.eraDescription = "User's own write-up"
        context.insert(usersEra)
        try? context.save()

        Migration.ensureHistoricalPeriodEras(context: context)

        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        XCTAssertEqual(eras.count, 3, "user's era suppresses creation; the other two still arrive")
        XCTAssertEqual(eras.first { $0.name == "Old Babylonian Period" }?.eraDescription, "User's own write-up")
    }

    // MARK: - FigurePlaceAssociation confidence qualifier

    func testFigurePlaceAssociationConfidenceRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let gula = Figure(name: "Gula", figureDescription: "Healing goddess")
        let nippur = Place(name: "Nippur", placeDescription: "City of Enlil")
        context.insert(gula)
        context.insert(nippur)
        let assoc = FigurePlaceAssociation(
            figure: gula,
            place: nippur,
            roleType: nil,
            source: "AMGG, s.v. Gula",
            confidence: .possible
        )
        context.insert(assoc)
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.confidence, .possible)
        XCTAssertEqual(fetched.first?.confidence?.label, "possible")
    }

    func testFigurePlaceAssociationConfidenceDefaultsToNilAndSupportsDisputed() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(FigurePlaceAssociation(source: "plain claim"))
        context.insert(FigurePlaceAssociation(source: "conflicting traditions", confidence: .disputed))
        try? context.save()

        let fetched = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched.first { $0.source == "plain claim" }?.confidence, nil)
        XCTAssertEqual(fetched.first { $0.source == "conflicting traditions" }?.confidence, .disputed)
        XCTAssertEqual(fetched.first { $0.source == "conflicting traditions" }?.confidence?.label, "disputed")

        XCTAssertEqual(Set(FigurePlaceAssociation.Confidence.allCases), [.possible, .disputed])
    }

    // MARK: - NameDuplicateCheck

    func testNameDuplicateCheckNormalizationCollidesSpellingVariants() {
        XCTAssertEqual(NameDuplicateCheck.normalizedKey("Ea-nasir"), "eanasir")
        XCTAssertEqual(NameDuplicateCheck.normalizedKey("Ea Nasir"), "eanasir")
        XCTAssertEqual(NameDuplicateCheck.normalizedKey("  UR-AS  "), "uras")
    }

    func testNameDuplicateCheckWarningFindsAndFormatsMatches() {
        let existing = ["Uras", "Ur-as", "Enlil", "Dagan"]
        XCTAssertEqual(NameDuplicateCheck.warning(candidate: "URAS!", existingNames: existing), "Ur-as, Uras")
        XCTAssertNil(NameDuplicateCheck.warning(candidate: "Nanna", existingNames: existing))
        XCTAssertNil(NameDuplicateCheck.warning(candidate: "", existingNames: existing))
        XCTAssertNil(NameDuplicateCheck.warning(candidate: "   ", existingNames: existing))
        XCTAssertNil(NameDuplicateCheck.warning(candidate: "Uras", existingNames: []))
    }

    // MARK: - Propagator: ignore non-reign prose dates

    func testPropagatorIgnoresMidTextTabletDate() {
        let container = makeContainer()
        let context = container.mainContext
        let alulim = Figure(
            name: "Alulim",
            figureDescription: "Alulim was a mythological ruler. The tablet of Old Babylonian period (c. 1900–1600 BC) from Ur describing the divine appointment of Alulim. (Listed reign: 28,800 years.)",
            birthDate: MythologicalDate(year: nil, era: "", isApproximate: true),
            deathDate: MythologicalDate(year: nil, era: "", isApproximate: true),
            orderIndex: 1
        )
        context.insert(alulim)
        try? context.save()

        Migration.enrichSKLData(context: context)

        XCTAssertNil(alulim.reignStartYear, "a mid-text tablet-date must not seed a reign start")
        XCTAssertNil(alulim.reignEndYear, "a mid-text tablet-date must not seed a reign end")
    }

    func testPropagatorIgnoresProseDateWithoutReignIntent() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(
            name: "Ili-Ishar",
            figureDescription: "Iii-Ishar was a ruler of the city of Mari after the fall of Akkad c. 2085-2072 BCE.",
            birthDate: MythologicalDate(year: nil, era: "", isApproximate: true),
            deathDate: MythologicalDate(year: nil, era: "", isApproximate: true)
        )
        context.insert(figure)
        try? context.save()

        Migration.enrichSKLData(context: context)

        XCTAssertNil(figure.reignStartYear, "'BCE' prose about an event must not seed a reign")
        XCTAssertNil(figure.reignEndYear)
    }

    func testPropagatorKeepsReignIntentDate() {
        let container = makeContainer()
        let context = container.mainContext
        let entemena = Figure(
            name: "Entemena",
            figureDescription: "Entemena, son of Eannatum, was a Sumerian king of Lagash who reigned c. 2440–2425 BC.",
            birthDate: MythologicalDate(year: nil, era: "Early Dynastic Period", isApproximate: true),
            deathDate: MythologicalDate(year: nil, era: "Early Dynastic Period", isApproximate: true)
        )
        context.insert(entemena)
        try? context.save()

        Migration.enrichSKLData(context: context)

        XCTAssertEqual(entemena.reignStartYear, -2440)
        XCTAssertEqual(entemena.reignEndYear, -2425)
    }

    func testPropagatorKeepsTailAnchoredAnchorDate() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(
            name: "Ur-Namma",
            figureDescription: "Ruler from the Third dynasty of Ur. Reigned 18 years. c. 2047–2030 BC (short)",
            birthDate: MythologicalDate(year: nil, era: "Third dynasty of Ur", isApproximate: true),
            deathDate: MythologicalDate(year: nil, era: "Third dynasty of Ur", isApproximate: true)
        )
        context.insert(figure)
        try? context.save()

        Migration.enrichSKLData(context: context)

        XCTAssertEqual(figure.reignStartYear, -2047)
        XCTAssertEqual(figure.reignEndYear, -2030)
    }

    // MARK: - Mugshots

    func testImageCropRectFullDefault() {
        XCTAssertEqual(ImageCropRect.full.cgRect, CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertNil(ImageCropRect(encoded: nil))
        XCTAssertNil(ImageCropRect(encoded: ""))
        XCTAssertNil(ImageCropRect(encoded: "0.1,0.2"))
        XCTAssertNil(ImageCropRect(encoded: "a,b,c,d"))
    }

    func testImageCropRectEncodeDecodeRoundTrip() {
        let crop = ImageCropRect(x: 0.25, y: 0.1, width: 0.4, height: 0.5)
        let decoded = ImageCropRect(encoded: crop.encoded())
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded, crop)
    }

    func testImageCropRectClampsOutOfBounds() {
        let crop = ImageCropRect(x: -0.2, y: 1.5, width: 3, height: -1)
        XCTAssertGreaterThanOrEqual(crop.x, 0)
        XCTAssertLessThanOrEqual(crop.x + crop.width, 1)
        XCTAssertLessThanOrEqual(crop.y + crop.height, 1)
        XCTAssertGreaterThanOrEqual(crop.height, 0)
    }

    func testMugshotFieldsRoundTrip() {
        let container = makeContainer()
        let context = container.mainContext
        let gudea = Figure(name: "Gudea", gender: .male)
        context.insert(gudea)
        let statue = ImageAsset(filename: "gudea_statue.jpg", caption: "Gudea statue from Girsu", source: "Louvre")
        context.insert(statue)
        gudea.mugshotImage = statue
        gudea.mugshotCropRect = ImageCropRect(x: 0.2, y: 0.1, width: 0.4, height: 0.5).encoded()
        gudea.mugshotIdentification = "inscribed"
        try? context.save()

        let fetched = try? context.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.name == "Gudea" })).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.mugshotImage?.filename, "gudea_statue.jpg")
        XCTAssertEqual(fetched?.mugshotIdentification, "inscribed")
        XCTAssertEqual(ImageCropRect(encoded: fetched?.mugshotCropRect), ImageCropRect(x: 0.2, y: 0.1, width: 0.4, height: 0.5))
        XCTAssertEqual(statue.mugshots.count, 1)
        XCTAssertEqual(statue.mugshots.first?.name, "Gudea")
    }

    func testMugshotRemovedWhenImageDeleted() {
        let container = makeContainer()
        let context = container.mainContext
        let gudea = Figure(name: "Gudea", gender: .male)
        context.insert(gudea)
        let statue = ImageAsset(filename: "statue.jpg")
        context.insert(statue)
        gudea.mugshotImage = statue
        try? context.save()

        context.delete(statue)
        try? context.save()

        XCTAssertNil(gudea.mugshotImage, "Deleting the mugshot image must nullify the figure's mugshot (delete rule .nullify)")
    }

    // MARK: - Duplicate Merger

    func testDuplicateMergerFindGroupsFiguresCaseInsensitive() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Ea"))
        context.insert(Figure(name: "ea"))
        context.insert(Figure(name: "EA"))
        context.insert(Figure(name: "Enki"))
        try? context.save()

        let groups = try! DuplicateMerger.findGroups(in: context)
        let figureGroups = groups.filter { $0.kind == .figure }
        XCTAssertEqual(figureGroups.count, 1)
        XCTAssertEqual(figureGroups.first?.name.lowercased(), "ea", "Group name keeps the first-seen spelling (fetch order not guaranteed)")
        XCTAssertEqual(figureGroups.first?.ids.count, 3)
    }

    func testDuplicateMergerFindGroupsDoesNotMixKinds() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Babylon"))
        context.insert(Place(name: "Babylon"))
        context.insert(Event(name: "Babylon"))
        try? context.save()

        let groups = try! DuplicateMerger.findGroups(in: context)
        XCTAssertTrue(groups.isEmpty, "A figure, place, and event sharing a name are distinct entities — never a merge group")
    }

    func testDuplicateMergerFindGroupsSkippedWhenSingle() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Enki"))
        context.insert(Place(name: "Nippur"))
        try? context.save()

        let groups = try! DuplicateMerger.findGroups(in: context)
        XCTAssertTrue(groups.isEmpty)
    }

    func testDuplicateMergerFindGroupsIncludesSources() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Source(name: "Atra-Hasis"))
        context.insert(Source(name: "Atrahasis"))
        context.insert(Figure(name: "Atrahasis"))
        try? context.save()

        let groups = try! DuplicateMerger.findGroups(in: context)
        let sourceGroups = groups.filter { $0.kind == .source }
        XCTAssertEqual(sourceGroups.count, 1)
        XCTAssertEqual(sourceGroups.first?.ids.count, 2, "hy-phenated and unhyphenated spellings group with the Figure kept distinct")
    }

    func testDuplicateMergerNormalizationGroupsHyphenVariants() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "Nippur"))
        context.insert(Place(name: "Nippur"))
        context.insert(Place(name: "Nin-lil"))
        context.insert(Place(name: "Ninlil"))
        try? context.save()

        let groups = try! DuplicateMerger.findGroups(in: context)
        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups.contains { $0.name == "Nippur" })
        XCTAssertTrue(groups.contains { $0.name == "Nin-lil" || $0.name == "Ninlil" })
    }

    func testDuplicateMergerMergeSourcesFoldsReferences() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Source(name: "Atra-Hasis", author: "W. Lambert")
        let duplicate = Source(name: "Atra-Hasis", url: "https://example.com/atra")
        context.insert(keeper)
        context.insert(duplicate)
        let cit = Citation(source: duplicate, location: "Tablet I", note: "flood", entityType: .event, linkedEntityName: "The Flood")
        context.insert(cit)
        let faction = Source(name: "Faction")
        context.insert(faction)
        let cell = PopupTableCell(value: "x")
        context.insert(cell)
        let cellSource = CellSource(source: "Atra-Hasis", location: "lines 1-5")
        context.insert(cellSource)
        cell.cellSources.append(cellSource)
        duplicate.cellListSources.append(cellSource)
        try? context.save()

        try! DuplicateMerger.mergeSources(keeper, duplicate, in: context)

        XCTAssertEqual(keeper.citations.count, 1)
        XCTAssertEqual(keeper.citations.first?.safeLocation, "Tablet I")
        XCTAssertEqual(keeper.url, "https://example.com/atra", "non-empty fields adopt")
        XCTAssertEqual(keeper.cellListSources.count, 1)
        XCTAssertEqual(cellSource.sourceRef?.persistentModelID, keeper.persistentModelID)
        let remaining: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(Set(remaining.map(\.persistentModelID)), Set([keeper.persistentModelID, faction.persistentModelID]), "duplicate deleted, others untouched")
    }

    func testDuplicateMergerMergeSourcesRePointsAssociationSourceRefs() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Source(name: "Atrahasis")
        let duplicate = Source(name: "Atra-Hasis")
        context.insert(keeper)
        context.insert(duplicate)

        let eventA = Event(name: "A", eventType: nil, eventDescription: "")
        let eventB = Event(name: "B", eventType: nil, eventDescription: "")
        context.insert(eventA)
        context.insert(eventB)
        let eventEvent = EventEventAssociation(fromEvent: eventA, toEvent: eventB, roleType: eventRoleType(context: context), source: "Atra-Hasis", sourceRef: duplicate)
        context.insert(eventEvent)

        let figure = Figure(name: "Enki")
        let place = Place(name: "Eridu")
        context.insert(figure)
        context.insert(place)
        let fpa = FigurePlaceAssociation(figure: figure, place: place, source: "Atra-Hasis", sourceRef: duplicate)
        context.insert(fpa)
        try? context.save()

        try! DuplicateMerger.mergeSources(keeper, duplicate, in: context)

        let eea: [EventEventAssociation] = (try? context.fetch(FetchDescriptor<EventEventAssociation>())) ?? []
        XCTAssertEqual(eea.count, 1)
        XCTAssertEqual(eea.first?.sourceRef?.persistentModelID, keeper.persistentModelID, "event-event association re-pointed to keeper")

        let fpas: [FigurePlaceAssociation] = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []
        XCTAssertEqual(fpas.count, 1)
        XCTAssertEqual(fpas.first?.sourceRef?.persistentModelID, keeper.persistentModelID, "figure-place association re-pointed to keeper")

        let remainingSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        XCTAssertEqual(remainingSources.count, 1, "duplicate deleted, no stub survives")
    }

    func eventRoleType(context: ModelContext) -> EventEventRoleType {
        if let existing = try? context.fetch(FetchDescriptor<EventEventRoleType>()).first {
            return existing
        }
        let created = EventEventRoleType(name: "Caused", icon: "arrow.right", colorHex: "007AFF")
        context.insert(created)
        return created
    }

    func testDuplicateMergerMergeFiguresRePointsRelationships() {
        let container = makeContainer()
        let context = container.mainContext
        let fatherType = RelationshipType(name: "Father", icon: "link", colorHex: "007AFF", category: "family")
        context.insert(fatherType)
        let keeper = Figure(name: "Enki")
        let duplicate = Figure(name: "enki")
        let child = Figure(name: "Marduk")
        let parent = Figure(name: "Anu")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(child)
        context.insert(parent)
        context.insert(Relationship(fromFigure: duplicate, toFigure: child, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: parent, toFigure: duplicate, relationshipType: fatherType))
        context.insert(Relationship(fromFigure: duplicate, toFigure: duplicate, relationshipType: fatherType))
        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        let rels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        XCTAssertEqual(rels.count, 2, "the duplicate→duplicate self-relationship is deleted")
        XCTAssertTrue(rels.contains { $0.fromFigure === keeper && $0.toFigure === child }, "outgoing re-pointed to keeper")
        XCTAssertTrue(rels.contains { $0.fromFigure === parent && $0.toFigure === keeper }, "incoming re-pointed to keeper")
        XCTAssertFalse(rels.contains { $0.fromFigure === duplicate || $0.toFigure === duplicate })
    }

    func testDuplicateMergerMergeFiguresFoldsOwnedContent() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Figure(name: "Ninhursag")
        let duplicate = Figure(name: "nin-hursag")
        context.insert(keeper)
        context.insert(duplicate)

        let alt = AlternateName(figure: duplicate, name: "Mami", tradition: .akkadian, nameType: .syncretism)
        context.insert(alt)
        duplicate.alternateNames.append(alt)

        let place = Place(name: "Nippur")
        context.insert(place)
        let role = FigurePlaceRoleType(name: "Patron", icon: "star", colorHex: "FF0000")
        context.insert(role)
        let pa = FigurePlaceAssociation(figure: duplicate, place: place, roleType: role)
        context.insert(pa)
        duplicate.placeAssociations.append(pa)
        place.figureAssociations.append(pa)

        let tag = Tag(name: "goddess")
        context.insert(tag)
        duplicate.tags.append(tag)

        let sticky = StickyNote(text: "check cult", figure: duplicate)
        context.insert(sticky)
        duplicate.stickies.append(sticky)

        let group = FigureGroup(name: "Pantheon")
        context.insert(group)
        let ga = FigureGroupAssociation(figure: duplicate, group: group)
        context.insert(ga)
        duplicate.groupAssociations.append(ga)

        let pantheon = Pantheon(name: "Mesopotamian")
        context.insert(pantheon)
        duplicate.pantheons.append(pantheon)

        let image = ImageAsset(filename: "ninhursag.jpg")
        context.insert(image)
        duplicate.images.append(image)

        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        XCTAssertEqual(keeper.alternateNames.map(\.name), ["Mami"])
        XCTAssertEqual(keeper.placeAssociations.count, 1)
        XCTAssertEqual(keeper.placeAssociations.first?.place, place)
        XCTAssertEqual(keeper.tags.count, 1)
        XCTAssertEqual(keeper.stickies.count, 1)
        XCTAssertEqual(keeper.groupAssociations.count, 1)
        XCTAssertEqual(keeper.pantheons.count, 1)
        XCTAssertEqual(keeper.images.count, 1)
        XCTAssertTrue(place.figureAssociations.contains { $0.figure === keeper })
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<Figure>())) ?? []).count, 1, "duplicate is deleted")
    }

    func testDuplicateMergerMergeFiguresAdoptsEmptyFields() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Figure(name: "Enki")
        let duplicate = Figure(name: "enki", gender: .male)
        duplicate.title = "Lord of the Abzu"
        duplicate.domain = "Water, Wisdom"
        duplicate.figureDescription = "God of fresh water"
        duplicate.epithet = "Nudimmud"
        context.insert(keeper)
        context.insert(duplicate)
        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        XCTAssertEqual(keeper.title, "Lord of the Abzu")
        XCTAssertEqual(keeper.domain, "Water, Wisdom")
        XCTAssertEqual(keeper.figureDescription, "God of fresh water")
        XCTAssertEqual(keeper.epithet, "Nudimmud")
        XCTAssertEqual(keeper.gender, .male)
    }

    func testDuplicateMergerMergeFiguresKeepsKeeperFields() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Figure(name: "Enki", gender: .male)
        keeper.title = "Keeper Title"
        keeper.domain = "Keeper Domain"
        let duplicate = Figure(name: "enki")
        duplicate.title = "Duplicate Title"
        duplicate.domain = "Duplicate Domain"
        context.insert(keeper)
        context.insert(duplicate)
        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        XCTAssertEqual(keeper.title, "Keeper Title", "keeper values always win")
        XCTAssertEqual(keeper.domain, "Keeper Domain")
    }

    func testDuplicateMergerMergePlacesRePointsAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Place(name: "Nippur")
        let duplicate = Place(name: "nippur")
        let figure = Figure(name: "Enlil")
        let other = Place(name: "Ekur")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(figure)
        context.insert(other)
        let role = FigurePlaceRoleType(name: "Worshipped", icon: "star", colorHex: "00FF00")
        context.insert(role)
        let fa = FigurePlaceAssociation(figure: figure, place: duplicate, roleType: role)
        context.insert(fa)
        figure.placeAssociations.append(fa)
        duplicate.figureAssociations.append(fa)
        let ppr = PlacePlaceRoleType(name: "Located Within", icon: "link", colorHex: "0000FF")
        context.insert(ppr)
        context.insert(PlacePlaceAssociation(fromPlace: duplicate, toPlace: other, roleType: ppr))
        try? context.save()

        try! DuplicateMerger.mergePlaces(keeper, duplicate, in: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.count, 2, "duplicate deleted, keeper + other remain")
        XCTAssertTrue(figure.placeAssociations.contains { $0.place === keeper })
        let ppas = (try? context.fetch(FetchDescriptor<PlacePlaceAssociation>())) ?? []
        XCTAssertEqual(ppas.count, 1)
        XCTAssertTrue(ppas.contains { $0.fromPlace === keeper && $0.toPlace === other })
    }

    func testDuplicateMergerMergeEventsRePointsAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Event(name: "The Flood")
        let duplicate = Event(name: "the flood")
        let figure = Figure(name: "Utnapishtim")
        let other = Event(name: "Ark Lands")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(figure)
        context.insert(other)
        let role = EventFigureRoleType(name: "Protagonist", icon: "person", colorHex: "FF00FF")
        context.insert(role)
        let efa = EventFigureAssociation(event: duplicate, figure: figure, roleType: role)
        context.insert(efa)
        duplicate.figureAssociations = [efa]
        let er = EventEventRoleType(name: "Precedes", icon: "arrow.right", colorHex: "00FFFF")
        context.insert(er)
        context.insert(EventEventAssociation(fromEvent: duplicate, toEvent: other, roleType: er))
        try? context.save()

        try! DuplicateMerger.mergeEvents(keeper, duplicate, in: context)

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertEqual(events.count, 2, "duplicate deleted, keeper + other remain")
        XCTAssertTrue((keeper.figureAssociations ?? []).contains { $0.figure === figure })
        let eeas = (try? context.fetch(FetchDescriptor<EventEventAssociation>())) ?? []
        XCTAssertEqual(eeas.count, 1)
        XCTAssertTrue(eeas.contains { $0.fromEvent === keeper && $0.toEvent === other })
    }

    func testDuplicateMergerMergeThingsFoldsAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Thing(name: "Tablet of Destinies")
        let duplicate = Thing(name: "tablet of destinies")
        let figure = Figure(name: "Marduk")
        let place = Place(name: "Esagila")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(figure)
        context.insert(place)
        let role = ThingFigureRoleType(name: "Holder", icon: "hand.raised", colorHex: "888888")
        context.insert(role)
        let tfa = ThingFigureAssociation(thing: duplicate, figure: figure, roleType: role)
        context.insert(tfa)
        duplicate.figureAssociations.append(tfa)
        figure.thingAssociations.append(tfa)
        let tpr = ThingPlaceRoleType(name: "Kept At", icon: "building.columns", colorHex: "999999")
        context.insert(tpr)
        let tpa = ThingPlaceAssociation(thing: duplicate, place: place, roleType: tpr)
        context.insert(tpa)
        duplicate.placeAssociations.append(tpa)
        place.thingAssociations.append(tpa)
        try? context.save()

        try! DuplicateMerger.mergeThings(keeper, duplicate, in: context)

        let things = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        XCTAssertEqual(things.count, 1)
        XCTAssertEqual(keeper.figureAssociations.count, 1)
        XCTAssertEqual(keeper.figureAssociations.first?.figure, figure)
        XCTAssertEqual(keeper.placeAssociations.count, 1)
        XCTAssertEqual(keeper.placeAssociations.first?.place, place)
    }

    func testDuplicateMergerMergeFiguresMovesEventFigureAssociations() {
        let container = makeContainer()
        let context = container.mainContext
        let keeper = Figure(name: "Enkidu")
        let duplicate = Figure(name: "enkidu")
        let event = Event(name: "Hunting the Bull of Heaven")
        context.insert(keeper)
        context.insert(duplicate)
        context.insert(event)
        let role = EventFigureRoleType(name: "Participant", icon: "person", colorHex: "ABCDEF")
        context.insert(role)
        let efa = EventFigureAssociation(event: event, figure: duplicate, roleType: role)
        context.insert(efa)
        event.figureAssociations = [efa]
        try? context.save()

        try! DuplicateMerger.mergeFigures(keeper, duplicate, in: context)

        XCTAssertEqual(event.figureAssociations?.first?.figure?.persistentModelID, keeper.persistentModelID)
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<Figure>())) ?? []).count, 1)
    }

    // MARK: - Seed reconciliation guards (case-insensitive)

    func testEnsureMissingCitiesAndAssociationsSkipsCaseVariantPlace() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Place(name: "Bad-Tibira", placeType: nil, modernLocation: "Tell al-Madineh", placeDescription: "", source: "Sumerian King List", latitude: 31.382778, longitude: 46.004444))
        try? context.save()

        Migration.ensureMissingCitiesAndAssociations(context: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.count, 46, "all other seed places still created; the case-variant must not be re-seeded")
        let badTibiras = places.filter { $0.name.lowercased() == "bad-tibira" }
        XCTAssertEqual(badTibiras.count, 1, "a case-variant existing place must not be re-seeded")
        XCTAssertEqual(badTibiras.first?.name, "Bad-Tibira")
    }

    func testEnsureMissingCitiesAndAssociationsCreatesMissingPlace() {
        let container = makeContainer()
        let context = container.mainContext
        try? context.save()

        Migration.ensureMissingCitiesAndAssociations(context: context)

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(places.count, 46, "seed has 46 places")
        XCTAssertTrue(places.contains { $0.name == "Bad-tibira" })
    }

    func testEnsureSKLEventsAndFiguresSkipsCaseVariantFigureAndPlace() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Figure(name: "Eannatum"))
        context.insert(Place(name: "Girsu", placeType: nil, modernLocation: "", placeDescription: "", source: "", latitude: 0, longitude: 0))
        try? context.save()

        Migration.ensureSKLEventsAndFigures(context: context)

        let eannatums = (try? context.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.name == "Eannatum" }))) ?? []
        XCTAssertEqual(eannatums.count, 1, "existing exact-name figure must not be duplicated")

        let girsu = (try? context.fetch(FetchDescriptor<Place>(predicate: #Predicate { $0.name == "Girsu" }))) ?? []
        XCTAssertEqual(girsu.count, 1, "existing exact-name place must not be duplicated")
    }

    // MARK: - Tag engine (rule-based auto-tags)

    func testTagEngineDeityTags() {
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        let figure = Figure(
            name: "Enki",
            figureType: deityType,
            gender: .male,
            domain: "Water, Wisdom, Magic, Crafts",
            figureDescription: "",
            birthDate: MythologicalDate(year: nil, era: "Age of the First Gods", isApproximate: true),
            deathDate: .unknown,
            source: "Atra-Hasis, Enki and Ninhursag"
        )
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("deity"))
        XCTAssertTrue(tags.contains("god"))
        XCTAssertFalse(tags.contains("goddess"))
        XCTAssertTrue(tags.contains("water"))
        XCTAssertTrue(tags.contains("wisdom"))
        XCTAssertTrue(tags.contains("magic"))
        XCTAssertTrue(tags.contains("crafts"))
        XCTAssertTrue(tags.contains("atrahasis"))
        XCTAssertTrue(tags.contains("age of the first gods"))
    }

    func testTagEngineGoddessTag() {
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        let figure = Figure(name: "Inanna", figureType: deityType, gender: .female, domain: "Love, War, Fertility, Venus", figureDescription: "", source: "Inanna's Descent")
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("goddess"))
        XCTAssertFalse(tags.contains("god"))
        XCTAssertTrue(tags.contains("inanna's descent"))
        XCTAssertTrue(tags.contains("love"))
        XCTAssertTrue(tags.contains("venus"))
    }

    func testTagEngineKingTags() {
        let humanType = FigureType(name: "Human", icon: "person", colorHex: "007AFF")
        let figure = Figure(name: "Aga of Kish", figureType: humanType, gender: .male, domain: "Kingship of Kish", figureDescription: "", source: "Sumerian King List")
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("human"))
        XCTAssertTrue(tags.contains("king"))
        XCTAssertTrue(tags.contains("kingship"))
        XCTAssertTrue(tags.contains("kish"))
        XCTAssertTrue(tags.contains("sumerian king list"))
    }

    func testTagEngineNonRulingHumanIsNotKing() {
        let humanType = FigureType(name: "Human", icon: "person", colorHex: "007AFF")
        let figure = Figure(name: "Hammurabi", figureType: humanType, gender: .male, domain: "", figureDescription: "", source: "")
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("human"))
        XCTAssertFalse(tags.contains("king"))
    }

    func testTagEngineWatcherTagForCommander() {
        let commanderType = FigureType(name: "Commander", icon: "shield", colorHex: "EF4444")
        let figure = Figure(name: "Samyaza", figureType: commanderType, gender: .male, domain: "Divine Council", figureDescription: "", source: "Book of Enoch (1 Enoch)")
        let tags = TagEngine.tags(for: figure)
        XCTAssertTrue(tags.contains("watcher"))
        XCTAssertTrue(tags.contains("book of enoch"))
        XCTAssertTrue(tags.contains("divine"))
        XCTAssertTrue(tags.contains("council"))
    }

    func testTagEnginePlaceTags() {
        let cityType = PlaceType(name: "City", icon: "building", colorHex: "007AFF")
        let place = Place(name: "Eridu", placeType: cityType, modernLocation: "Abu Shahrain, Southern Iraq", placeDescription: "", source: "Sumerian King List", latitude: 30.816, longitude: 45.996)
        let tags = TagEngine.tags(for: place)
        XCTAssertTrue(tags.contains("city"))
        XCTAssertTrue(tags.contains("iraq"))
        XCTAssertTrue(tags.contains("sumerian king list"))
        XCTAssertEqual(TagEngine.historicalRegionTag("Upper Mesopotamia"), "mesopotamia")
        XCTAssertNil(TagEngine.historicalRegionTag("Eridu"))
    }

    func testTagEngineEventTags() {
        let battleType = EventType(name: "Battle", icon: "flame", colorHex: "FF3B30")
        let event = Event(name: "Sargon Conquers Sumer", eventType: battleType, eventDescription: "", date: .unknown, era: "Dynasty of Akkad", source: "Sumerian King List")
        let tags = TagEngine.tags(for: event)
        XCTAssertTrue(tags.contains("battle"))
        XCTAssertTrue(tags.contains("dynasty of akkad"))
        XCTAssertTrue(tags.contains("sumerian king list"))
    }

    func testTagEngineThingCategories() {
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "The Gold Dagger of Ur", description: "").contains("artifact"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Kingship", description: "").contains("office"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Truth", description: "").contains("concept"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Atra-Hasis", description: "").contains("literary work"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Craft of the smith", description: "").contains("craft"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Me", description: "").contains("divine powers"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "The flood", description: "").contains("flood"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Holy purification", description: "").contains("concept"))
        XCTAssertTrue(TagEngine.thingCategoryTags(name: "Kurgarra (cultic entertainer)", description: "").contains("office"))
    }

    func testTagEngineDomainSplitsPhrases() {
        XCTAssertEqual(TagEngine.domainTags("Sky, Kingship, Authority"), ["sky", "kingship", "authority"])
        XCTAssertEqual(TagEngine.domainTags("Kingship of Kish"), ["kingship", "kish"])
        XCTAssertEqual(TagEngine.domainTags("Salt Water, Chaos"), ["salt", "water", "chaos"])
        XCTAssertEqual(TagEngine.domainTags(""), [])
    }

    func testTagEngineDomainStripsConnectorsAndFragments() {
        XCTAssertEqual(TagEngine.domainTags("and the underworld"), ["underworld"])
        XCTAssertEqual(TagEngine.domainTags("associated with farming and fertility"), ["farming", "fertility"])
        XCTAssertEqual(TagEngine.domainTags("steward and scribe"), ["steward", "scribe"])
        XCTAssertEqual(TagEngine.domainTags("and boundary stones"), ["boundary", "stones"])
        XCTAssertEqual(TagEngine.domainTags("localized military defense"), ["localized", "military", "defense"])
        XCTAssertEqual(TagEngine.domainTags("and"), [])
        XCTAssertEqual(TagEngine.domainTags("Sky, Sky"), ["sky"])
    }

    func testTagEngineColorHexDeterministic() {
        XCTAssertEqual(TagEngine.colorHex(for: "wisdom"), TagEngine.colorHex(for: "wisdom"))
        XCTAssertNotEqual(TagEngine.colorHex(for: "wisdom"), TagEngine.colorHex(for: "battle"))
        XCTAssertEqual(TagEngine.colorHex(for: "water").count, 6)
    }

    func testEnsureAutoTagsTagsAllKinds() {
        let container = makeContainer()
        let context = container.mainContext
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        let figure = Figure(name: "Enki", figureType: deityType, gender: .male, domain: "Water, Wisdom", figureDescription: "", source: "Enuma Elish")
        context.insert(figure)
        let cityType = PlaceType(name: "City", icon: "building", colorHex: "007AFF")
        context.insert(Place(name: "Uruk", placeType: cityType, modernLocation: "Iraq", placeDescription: "", source: "", latitude: 31.322, longitude: 45.639))
        let battleType = EventType(name: "Battle", icon: "flame", colorHex: "FF3B30")
        context.insert(Event(name: "Slaying of Tiamat", eventType: battleType, eventDescription: "", date: .unknown, era: "Creation", source: "Enuma Elish"))
        context.insert(Thing(name: "The Gold Dagger of Ur", thingDescription: "", source: ""))
        try? context.save()

        Migration.ensureAutoTags(context: context)

        XCTAssertFalse(figure.tags.isEmpty)
        XCTAssertTrue(figure.tags.contains { $0.name == "deity" })
        XCTAssertTrue(figure.tags.contains { $0.name == "water" })
        let allPlaces: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        XCTAssertEqual(allPlaces.first?.tags.map(\.name).sorted(), ["city", "iraq"])
        let allEvents: [Event] = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        XCTAssertTrue(allEvents.first?.tags.contains { $0.name == "battle" } ?? false)
        XCTAssertTrue(allEvents.first?.tags.contains { $0.name == "creation" } ?? false)
        let allThings: [Thing] = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        XCTAssertTrue(allThings.first?.tags.contains { $0.name == "artifact" } ?? false)
    }

    func testEnsureAutoTagsSkipsEntitiesWithExistingTags() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Marduk", figureType: FigureType(name: "Deity", icon: "star", colorHex: "FF9500"), gender: .male, domain: "Storm, Creation, Kingship", figureDescription: "", source: "Enuma Elish")
        context.insert(figure)
        let userTag = Tag(name: "user-curated", colorHex: "FF9500")
        context.insert(userTag)
        figure.tags.append(userTag)
        try? context.save()

        Migration.ensureAutoTags(context: context)

        XCTAssertEqual(figure.tags.map(\.name), ["user-curated"], "an entity with any tag must be left untouched")
    }

    func testEnsureAutoTagsIsIdempotentAndReusesTags() {
        let container = makeContainer()
        let context = container.mainContext
        let deityType = FigureType(name: "Deity", icon: "star", colorHex: "FF9500")
        context.insert(Figure(name: "Enki", figureType: deityType, gender: .male, domain: "Water", figureDescription: "", source: "Enuma Elish"))
        context.insert(Figure(name: "Ea", figureType: deityType, gender: .male, domain: "Water", figureDescription: "", source: "Enuma Elish"))
        try? context.save()

        Migration.ensureAutoTags(context: context)
        Migration.ensureAutoTags(context: context)

        let allTags: [Tag] = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        XCTAssertEqual(allTags.filter { $0.name == "water" }.count, 1, "the same tag name must resolve to one Tag row")
        XCTAssertEqual(allTags.filter { $0.name == "deity" }.count, 1)
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in figures {
            XCTAssertEqual(figure.tags.count, Set(figure.tags.map(\.name)).count, "no duplicate tag rows per figure")
        }
    }

    func testEnsureAutoTagsLeavesUntaggableEntitiesUntagged() {
        let container = makeContainer()
        let context = container.mainContext
        context.insert(Thing(name: "Unremarkable", thingDescription: "", source: ""))
        try? context.save()

        Migration.ensureAutoTags(context: context)

        let allTags: [Tag] = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        XCTAssertTrue(allTags.isEmpty, "a thing that matches no category must not force a tag")
        let allThings: [Thing] = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        XCTAssertTrue(allThings.first?.tags.isEmpty ?? true)
    }

    func testEnsureRefinedDomainTagsSplitsLegacyFragments() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Ninurta", figureType: FigureType(name: "Deity", icon: "star", colorHex: "FF9500"), gender: .male, domain: "steward and scribe; associated with farming and fertility; and the underworld", figureDescription: "", source: "Sumerian King List")
        context.insert(figure)
        let legacyNames = ["steward and scribe", "associated with farming and fertility", "and the underworld", "sumerian king list"]
        for name in legacyNames {
            let tag = Tag(name: name, colorHex: "FF9500")
            context.insert(tag)
            figure.tags.append(tag)
        }
        try? context.save()

        Migration.ensureRefinedDomainTags(context: context)

        let names = Set(figure.tags.map(\.name))
        for obsolete in ["steward and scribe", "associated with farming and fertility", "and the underworld"] {
            XCTAssertFalse(names.contains(obsolete), "legacy fragment \(obsolete) must be removed")
        }
        for refined in ["steward", "scribe", "farming", "fertility", "underworld"] {
            XCTAssertTrue(names.contains(refined), "refined single-word tag \(refined) missing")
        }
        XCTAssertTrue(names.contains("sumerian king list"), "tradition tag must survive the pass")
    }

    func testEnsureRefinedDomainTagsIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let figure = Figure(name: "Ninurta", figureType: FigureType(name: "Deity", icon: "star", colorHex: "FF9500"), gender: .male, domain: "steward and scribe", figureDescription: "", source: "")
        context.insert(figure)
        let legacy = Tag(name: "steward and scribe", colorHex: "FF9500")
        context.insert(legacy)
        figure.tags.append(legacy)
        try? context.save()

        Migration.ensureRefinedDomainTags(context: context)
        Migration.ensureRefinedDomainTags(context: context)

        XCTAssertEqual(Set(figure.tags.map(\.name)), ["steward", "scribe"])
        let allTags: [Tag] = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        XCTAssertEqual(allTags.filter { $0.name == "steward" }.count, 1, "one Tag row per refined name")
        XCTAssertEqual(allTags.filter { $0.name == "scribe" }.count, 1)
    }

    func testEnsureDynastyGroupsCreatesSubgroupsWithFiguresAndEvents() {
        let container = makeContainer()
        let context = container.mainContext
        let kishEra = Era(name: "First dynasty of Kish", orderIndex: 0)
        let akkadEra = Era(name: "Dynasty of Akkad", orderIndex: 1)
        context.insert(kishEra)
        context.insert(akkadEra)

        func king(_ name: String, era: Era, order: Int) -> Figure {
            let figure = Figure(name: name, domain: "Kingship", figureDescription: "", orderIndex: order)
            figure.era = era
            context.insert(figure)
            return figure
        }
        king("En-me-barage-si", era: kishEra, order: 0)
        king("Agga", era: kishEra, order: 1)
        king("Sargon", era: akkadEra, order: 0)
        king("Naram-Sin", era: akkadEra, order: 1)
        context.insert(Figure(name: "Enki", domain: "Wisdom", figureDescription: "", orderIndex: 0))

        let kishEvent = Event(name: "Siege of Uruk", date: .unknown, era: "First dynasty of Kish", source: "")
        let akkadEvent = Event(name: "Fall of Akkad", date: .unknown, era: "Dynasty of Akkad", source: "")
        let floodEvent = Event(name: "The Great Flood", date: .unknown, era: "The Great Flood", source: "")
        context.insert(kishEvent)
        context.insert(akkadEvent)
        context.insert(floodEvent)
        try? context.save()

        Migration.ensureDynastyGroups(context: context)
        Migration.ensureDynastyGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let top = groups.first(where: { $0.name == "Dynasties" }) else {
            return XCTFail("Dynasties top group missing")
        }
        XCTAssertEqual(top.kind, .skl)
        let subs = top.sortedSubgroups
        XCTAssertEqual(subs.map(\.name), ["First dynasty of Kish", "Dynasty of Akkad"])

        guard let kish = subs.first(where: { $0.name == "First dynasty of Kish" }),
              let akkad = subs.first(where: { $0.name == "Dynasty of Akkad" }) else {
            return XCTFail("dynasty subgroups missing")
        }

        XCTAssertEqual(kish.sortedAssociations.compactMap { $0.figure?.name }, ["En-me-barage-si", "Agga"], "kings in reign order")
        XCTAssertEqual(akkad.sortedAssociations.compactMap { $0.figure?.name }, ["Sargon", "Naram-Sin"])
        XCTAssertFalse(kish.sortedAssociations.contains { $0.figure?.name == "Enki" }, "non-dynastic figure excluded")

        XCTAssertEqual(kish.era?.persistentModelID, kishEra.persistentModelID, "subgroup linked to its era")
        XCTAssertEqual(akkad.era?.persistentModelID, akkadEra.persistentModelID, "subgroup linked to its era")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<Era>())) ?? 0, 2)
        XCTAssertEqual(kishEra.groups?.map(\.name), ["First dynasty of Kish"], "inverse era.groups populated")

        XCTAssertEqual(kish.sortedAssociations.compactMap { $0.event?.name }, ["Siege of Uruk"], "era-matched event attached")
        XCTAssertEqual(akkad.sortedAssociations.compactMap { $0.event?.name }, ["Fall of Akkad"])
        XCTAssertFalse(akkad.sortedAssociations.contains { $0.event?.name == "The Great Flood" }, "non-dynastic event excluded")
        XCTAssertEqual(kish.sortMode, .ordered)

        let totalAssocs = (try? context.fetchCount(FetchDescriptor<FigureGroupAssociation>())) ?? 0
        XCTAssertEqual(totalAssocs, 6, "no duplicate members across two runs")
    }

    func testEnsureDynastyGroupsPreservesManualSubgroup() {
        let container = makeContainer()
        let context = container.mainContext
        let akkadEra = Era(name: "Dynasty of Akkad", orderIndex: 1)
        context.insert(akkadEra)
        let sargon = Figure(name: "Sargon", domain: "Kingship", figureDescription: "", orderIndex: 0)
        sargon.era = akkadEra
        context.insert(sargon)

        let top = FigureGroup(name: "Dynasties", icon: "building.columns", colorHex: "007AFF", kind: .skl)
        context.insert(top)
        let manualSub = FigureGroup(name: "Dynasty of Akkad", icon: "crown", colorHex: "007AFF", orderIndex: 0, kind: .skl, sortMode: .ordered)
        context.insert(manualSub)
        top.subgroups = [manualSub]
        let manualAssoc = FigureGroupAssociation(figure: sargon)
        context.insert(manualAssoc)
        manualSub.figureAssociations = [manualAssoc]
        sargon.groupAssociations.append(manualAssoc)
        manualAssoc.orderIndex = 7
        try? context.save()

        Migration.ensureDynastyGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        let subs = groups.filter { $0.name == "Dynasty of Akkad" }
        XCTAssertEqual(subs.count, 1, "existing subgroup reused, not duplicated")
        XCTAssertEqual(subs.first?.figureAssociations.count, 1, "manual member kept, no duplicate")
        XCTAssertEqual(subs.first?.figureAssociations.first?.orderIndex, 7, "manual order index untouched")
        XCTAssertEqual(subs.first?.era?.persistentModelID, akkadEra.persistentModelID, "existing subgroup linked to its era")
    }

    func testEnsureDynastyGroupsIncludesFullSKLRulingBlock() {
        let container = makeContainer()
        let context = container.mainContext
        let eras: [(String, Int)] = [
            ("First dynasty of Kish", 11),
            ("First rulers of Uruk", 12),
            ("First dynasty of Ur", 13),
            ("Dynasty of Awan", 14),
            ("Second dynasty of Kish", 15),
            ("Dynasty of Hamazi", 16),
            ("Second dynasty of Uruk", 17),
            ("Second dynasty of Ur", 18),
            ("Dynasty of Adab", 19),
            ("Dynasty of Mari", 20),
            ("Third dynasty of Kish", 21),
            ("Dynasty of Akshak", 22),
            ("Fourth dynasty of Kish", 23),
            ("Third dynasty of Uruk", 24),
            ("Dynasty of Akkad", 25),
            ("Fourth dynasty of Uruk", 26),
            ("Gutian rule", 27),
            ("Fifth dynasty of Uruk", 28),
            ("Third dynasty of Ur", 29),
            ("Dynasty of Isin", 30),
        ]
        for (name, order) in eras {
            context.insert(Era(name: name, orderIndex: order))
        }
        try? context.save()

        Migration.ensureDynastyGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let top = groups.first(where: { $0.name == "Dynasties" }) else {
            return XCTFail("Dynasties top group missing")
        }
        XCTAssertEqual(top.sortedSubgroups.map(\.name), eras.map(\.0), "dynasties follow SKL ruling order, not alphabetical")
        XCTAssertEqual(top.sortedSubgroups.map(\.orderIndex), eras.map(\.1), "subgroup orderIndex matches era ruling order")
        XCTAssertEqual(top.sortMode, .ordered, "Dynasties group page shows dynasties in ruling order")
    }

    func testEnsureDynastyGroupsLinksErasAcrossOtherTrees() {
        let container = makeContainer()
        let context = container.mainContext
        let kishEra = Era(name: "First dynasty of Kish", orderIndex: 0)
        let akkadEra = Era(name: "Dynasty of Akkad", orderIndex: 1)
        context.insert(kishEra)
        context.insert(akkadEra)

        let legacyTop = FigureGroup(name: "Sumerian King List", icon: "building.columns", colorHex: "8E8E93", kind: .skl)
        context.insert(legacyTop)
        let kishSub = FigureGroup(name: "First dynasty of Kish", icon: "crown", colorHex: "8E8E93", orderIndex: 0, kind: .skl)
        let akkadSub = FigureGroup(name: "The dynasty of Akkad", icon: "crown", colorHex: "8E8E93", orderIndex: 1, kind: .skl)
        let typoSub = FigureGroup(name: "Fouth dynasty of Uruk", icon: "crown", colorHex: "8E8E93", orderIndex: 2, kind: .skl)
        context.insert(kishSub)
        context.insert(akkadSub)
        context.insert(typoSub)
        legacyTop.subgroups = [kishSub, akkadSub, typoSub]
        try? context.save()

        Migration.ensureDynastyGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        let kish = groups.first { $0.name == "First dynasty of Kish" && $0.parentGroup === legacyTop }
        let akkad = groups.first { $0.name == "Dynasty of Akkad" && $0.parentGroup === legacyTop }
        let typo = groups.first { $0.name == "Fouth dynasty of Uruk" }
        XCTAssertEqual(kish?.era?.persistentModelID, kishEra.persistentModelID, "legacy subgroup linked by exact normalized name")
        XCTAssertEqual(akkad?.era?.persistentModelID, akkadEra.persistentModelID, "legacy subgroup renamed to canonical name and linked")
        XCTAssertNil(typo?.era, "typo'd name with no matching era left untouched")
        XCTAssertEqual(kishEra.groups?.contains { $0 === kish }, true, "inverse era.groups includes legacy subgroup")
        XCTAssertEqual(kish?.figureAssociations.isEmpty, true, "no members auto-added to legacy tree")
    }

    func testEnsureDynastyGroupsRepairsLegacyTreeToRulingOrder() {
        let container = makeContainer()
        let context = container.mainContext
        let eras: [(String, Int)] = [
            ("First dynasty of Kish", 11),
            ("First rulers of Uruk", 12),
            ("First dynasty of Ur", 13),
            ("Dynasty of Awan", 14),
            ("Second dynasty of Kish", 15),
            ("Dynasty of Hamazi", 16),
            ("Second dynasty of Uruk", 17),
            ("Second dynasty of Ur", 18),
            ("Dynasty of Adab", 19),
            ("Dynasty of Mari", 20),
            ("Third dynasty of Kish", 21),
            ("Dynasty of Akshak", 22),
            ("Fourth dynasty of Kish", 23),
            ("Third dynasty of Uruk", 24),
            ("Dynasty of Akkad", 25),
            ("Fourth dynasty of Uruk", 26),
            ("Gutian rule", 27),
            ("Fifth dynasty of Uruk", 28),
            ("Third dynasty of Ur", 29),
            ("Dynasty of Isin", 30),
        ]
        for (name, order) in eras {
            context.insert(Era(name: name, orderIndex: order))
        }

        let legacyTop = FigureGroup(name: "Sumerian King List", icon: "building.columns", colorHex: "8E8E93", kind: .skl)
        context.insert(legacyTop)
        let typoSub = FigureGroup(name: "Fouth dynasty of Uruk", icon: "crown", colorHex: "8E8E93", orderIndex: 2, kind: .skl)
        context.insert(typoSub)
        legacyTop.subgroups = [typoSub]
        try? context.save()

        Migration.ensureDynastyGroups(context: context)

        let groups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        let legacy = groups.first { $0.name == "Sumerian King List" }
        XCTAssertEqual(legacy?.sortedSubgroups.map(\.name), eras.map(\.0), "legacy tree matches timeline ruling order")
        XCTAssertEqual(legacy?.sortedSubgroups.map(\.orderIndex), eras.map(\.1), "legacy subgroup order synced to era order")
        XCTAssertEqual(legacy?.sortedSubgroups.count, 20, "missing dynasties added")
        XCTAssertNotNil(legacy?.sortedSubgroups.first { $0.name == "Fourth dynasty of Uruk" }?.era, "typo renamed and era linked")
        XCTAssertEqual(legacy?.sortedSubgroups.first { $0.name == "Fourth dynasty of Uruk" }?.era?.orderIndex, 26)
    }

}
