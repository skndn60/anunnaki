import XCTest
import SwiftData
@testable import MeCore

@MainActor
extension MeCoreTests {
    // MARK: - RelationshipManager

    func count<M: PersistentModel>(_ type: M.Type, in context: ModelContext) -> Int {
        (try? context.fetch(FetchDescriptor<M>()))?.count ?? 0
    }

    func testRelationshipManagerLinksRelationshipOnBothSides() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let anu = makeTreeFigure(context, "Anu")
        let enlil = makeTreeFigure(context, "Enlil")
        let fatherType = manager.relationshipType(named: "Father", category: "parent")

        let rel = manager.addRelationship(from: anu, to: enlil, relationshipType: fatherType, source: "test")

        XCTAssertTrue(rel.fromFigure === anu)
        XCTAssertTrue(rel.toFigure === enlil)
        XCTAssertTrue(rel.relationshipType === fatherType)
        XCTAssertEqual(rel.source, "test")
        XCTAssertTrue(anu.outgoingRelationships.contains { $0.persistentModelID == rel.persistentModelID })
        XCTAssertTrue(enlil.incomingRelationships.contains { $0.persistentModelID == rel.persistentModelID })
        XCTAssertTrue(fatherType.relationships.contains { $0.persistentModelID == rel.persistentModelID })
        XCTAssertEqual(count(Relationship.self, in: context), 1)
    }

    func testRelationshipManagerDedupesRelationship() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let a = makeTreeFigure(context, "A")
        let b = makeTreeFigure(context, "B")
        let fatherType = manager.relationshipType(named: "Father", category: "parent")

        let first = manager.addRelationship(from: a, to: b, relationshipType: fatherType)
        let second = manager.addRelationship(from: a, to: b, relationshipType: fatherType)

        XCTAssertEqual(first.persistentModelID, second.persistentModelID)
        XCTAssertEqual(count(Relationship.self, in: context), 1)

        _ = manager.addRelationship(from: a, to: b, relationshipType: fatherType, dedupe: false)
        XCTAssertEqual(count(Relationship.self, in: context), 2)
    }

    func testRelationshipManagerRelationshipLinksSource() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let a = makeTreeFigure(context, "A")
        let b = makeTreeFigure(context, "B")
        let motherType = manager.relationshipType(named: "Mother", category: "parent")
        let source = Source(name: "The Testament Divine")
        context.insert(source)

        let rel = manager.addRelationship(from: a, to: b, relationshipType: motherType, source: "display", sourceRef: source)

        XCTAssertTrue(rel.sourceRef === source)
        XCTAssertTrue(source.relationships.contains { $0.persistentModelID == rel.persistentModelID })
    }

    func testRelationshipManagerFigurePlaceAssociationLinksAllSidesAndDedupes() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let ninurta = makeTreeFigure(context, "Ninurta")
        let nigeru = Place(name: "Nigeru")
        context.insert(nigeru)
        let patron = manager.figurePlaceRoleType(named: "Patron Deity", colorHex: "#4A90D9")

        let assoc = manager.addFigurePlaceAssociation(figure: ninurta, place: nigeru, roleType: patron, source: "test", displayName: "Ninurta of Nigeru")

        XCTAssertTrue(assoc.figure === ninurta)
        XCTAssertTrue(assoc.place === nigeru)
        XCTAssertTrue(assoc.roleType === patron)
        XCTAssertEqual(assoc.source, "test")
        XCTAssertEqual(assoc.displayName, "Ninurta of Nigeru")
        XCTAssertTrue(ninurta.placeAssociations.contains { $0.persistentModelID == assoc.persistentModelID })
        XCTAssertTrue(nigeru.figureAssociations.contains { $0.persistentModelID == assoc.persistentModelID })
        XCTAssertTrue(patron.associations.contains { $0.persistentModelID == assoc.persistentModelID })
        XCTAssertEqual(count(FigurePlaceAssociation.self, in: context), 1)

        let again = manager.addFigurePlaceAssociation(figure: ninurta, place: nigeru, roleType: patron)
        XCTAssertEqual(again.persistentModelID, assoc.persistentModelID)
        XCTAssertEqual(count(FigurePlaceAssociation.self, in: context), 1)

        _ = manager.addFigurePlaceAssociation(figure: ninurta, place: nigeru, roleType: patron, dedupe: false)
        XCTAssertEqual(count(FigurePlaceAssociation.self, in: context), 2)
    }

    func testRelationshipManagerPlacePlaceAssociation() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let nigeru = Place(name: "Nigeru")
        let esagil = Place(name: "Esagil")
        context.insert(nigeru)
        context.insert(esagil)
        let locatedWithin = manager.placePlaceRoleType(named: "Located Within")

        let assoc = manager.addPlacePlaceAssociation(from: esagil, to: nigeru, roleType: locatedWithin, source: "test")

        XCTAssertTrue(assoc.fromPlace === esagil)
        XCTAssertTrue(assoc.toPlace === nigeru)
        XCTAssertTrue(assoc.roleType === locatedWithin)
        XCTAssertTrue(locatedWithin.associations.contains { $0.persistentModelID == assoc.persistentModelID })
        XCTAssertEqual(count(PlacePlaceAssociation.self, in: context), 1)

        let again = manager.addPlacePlaceAssociation(from: esagil, to: nigeru, roleType: locatedWithin)
        XCTAssertEqual(again.persistentModelID, assoc.persistentModelID)
        XCTAssertEqual(count(PlacePlaceAssociation.self, in: context), 1)
    }

    func testRelationshipManagerEventPlaceAssociation() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let event = Event(name: "Building of Esagil")
        let esagil = Place(name: "Esagil")
        context.insert(event)
        context.insert(esagil)
        let at = manager.eventPlaceRoleType(named: "At")

        let assoc = manager.addEventPlaceAssociation(event: event, place: esagil, roleType: at, source: "test")

        XCTAssertTrue(assoc.event === event)
        XCTAssertTrue(assoc.place === esagil)
        XCTAssertTrue(assoc.roleType === at)
        XCTAssertTrue(event.placeAssociations.contains { $0.persistentModelID == assoc.persistentModelID })
        XCTAssertTrue(esagil.eventAssociations.contains { $0.persistentModelID == assoc.persistentModelID })
        XCTAssertTrue(at.associations.contains { $0.persistentModelID == assoc.persistentModelID })
        XCTAssertEqual(count(EventPlaceAssociation.self, in: context), 1)

        let again = manager.addEventPlaceAssociation(event: event, place: esagil, roleType: at)
        XCTAssertEqual(again.persistentModelID, assoc.persistentModelID)
        XCTAssertEqual(count(EventPlaceAssociation.self, in: context), 1)
    }

    func testRelationshipManagerEventEventAssociation() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let first = Event(name: "First")
        let second = Event(name: "Second")
        context.insert(first)
        context.insert(second)
        let caused = manager.eventEventRoleType(named: "Caused")

        let assoc = manager.addEventEventAssociation(from: first, to: second, roleType: caused, source: "test")

        XCTAssertTrue(assoc.fromEvent === first)
        XCTAssertTrue(assoc.toEvent === second)
        XCTAssertTrue(assoc.roleType === caused)
        XCTAssertTrue(caused.associations.contains { $0.persistentModelID == assoc.persistentModelID })
        XCTAssertEqual(count(EventEventAssociation.self, in: context), 1)

        let again = manager.addEventEventAssociation(from: first, to: second, roleType: caused)
        XCTAssertEqual(again.persistentModelID, assoc.persistentModelID)
    }

    func testRelationshipManagerEventFigureAssociationLinksInvolvedFigures() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let event = Event(name: "The Flood")
        let utnapishtim = makeTreeFigure(context, "Utnapishtim")
        context.insert(event)
        let survived = manager.eventFigureRoleType(named: "Survived")

        let assoc = manager.addEventFigureAssociation(event: event, figure: utnapishtim, roleType: survived)

        XCTAssertTrue(assoc.event === event)
        XCTAssertTrue(assoc.figure === utnapishtim)
        XCTAssertTrue(assoc.roleType === survived)
        XCTAssertTrue((event.figureAssociations ?? []).contains { $0.persistentModelID == assoc.persistentModelID })
        XCTAssertTrue(utnapishtim.events.contains { $0.persistentModelID == event.persistentModelID })
        XCTAssertTrue(event.involvedFigures.contains { $0.persistentModelID == utnapishtim.persistentModelID })
        XCTAssertEqual(count(EventFigureAssociation.self, in: context), 1)

        let again = manager.addEventFigureAssociation(event: event, figure: utnapishtim, roleType: survived)
        XCTAssertEqual(again.persistentModelID, assoc.persistentModelID)
        XCTAssertEqual(count(EventFigureAssociation.self, in: context), 1)
    }

    func testRelationshipManagerEventFigureAssociationWithoutInvolvedFiguresKeepsAssociationEvenIfNotVisible() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let event = Event(name: "The Eclipse, pre-repair")
        let limmu = makeTreeFigure(context, "Bur-Sagale")
        context.insert(event)
        let witnessed = manager.eventFigureRoleType(named: "Witnessed")

        _ = manager.addEventFigureAssociation(
            event: event, figure: limmu, roleType: witnessed,
            alsoLinkInvolvedFigures: false, dedupe: false
        )

        XCTAssertTrue(event.involvedFigures.isEmpty, "with alsoLinkInvolvedFigures: false, involvedFigures stays empty")
        XCTAssertEqual((event.figureAssociations ?? []).count, 1, "but the association row still exists")
    }

    func testRepairInvolvedFiguresFromAssociations() {
        let container = makeContainer()
        let context = ModelContext(container)
        let event = Event(name: "The Eclipse of Bur-Sagale")
        let limmu = makeTreeFigure(context, "Bur-Sagale")
        context.insert(event)
        context.insert(limmu)

        // A user linked the figure as an actor but the association was created
        // with alsoLinkInvolvedFigures: false, so the two arrays diverged.
        let assoc = EventFigureAssociation(event: event, figure: limmu)
        context.insert(assoc)
        event.figureAssociations = [assoc]
        event.involvedFigures = []
        limmu.events = []
        try? context.save()

        Migration.repairInvolvedFiguresFromAssociations(context: context)

        XCTAssertTrue(event.involvedFigures.contains { $0.persistentModelID == limmu.persistentModelID },
                      "association must backfill involvedFigures")
        XCTAssertTrue(limmu.events.contains { $0.persistentModelID == event.persistentModelID },
                      "and backfill the figure's events")
        XCTAssertEqual(count(EventFigureAssociation.self, in: context), 1, "no new association created")

        Migration.repairInvolvedFiguresFromAssociations(context: context)
        XCTAssertEqual(event.involvedFigures.count, 1, "idempotent")
    }

    func testRelationshipManagerThingAssociations() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let thing = Thing(name: "Tablet of Destinies")
        let figure = makeTreeFigure(context, "Marduk")
        let place = Place(name: "Esagil")
        let event = Event(name: "Ritual")
        context.insert(thing)
        context.insert(place)
        context.insert(event)
        let tfr = manager.thingFigureRoleType(named: "Bearer")
        let tpr = manager.thingPlaceRoleType(named: "Kept At")
        let ter = manager.thingEventRoleType(named: "Used In")

        let fa = manager.addThingFigureAssociation(thing: thing, figure: figure, roleType: tfr, source: "test")
        let pa = manager.addThingPlaceAssociation(thing: thing, place: place, roleType: tpr, source: "test")
        let ea = manager.addThingEventAssociation(thing: thing, event: event, roleType: ter, source: "test")

        XCTAssertTrue(fa.figure === figure)
        XCTAssertTrue(thing.figureAssociations.contains { $0.persistentModelID == fa.persistentModelID })
        XCTAssertTrue(figure.thingAssociations.contains { $0.persistentModelID == fa.persistentModelID })
        XCTAssertTrue(tfr.associations.contains { $0.persistentModelID == fa.persistentModelID })

        XCTAssertTrue(pa.place === place)
        XCTAssertTrue(thing.placeAssociations.contains { $0.persistentModelID == pa.persistentModelID })
        XCTAssertTrue(place.thingAssociations.contains { $0.persistentModelID == pa.persistentModelID })
        XCTAssertTrue(tpr.associations.contains { $0.persistentModelID == pa.persistentModelID })

        XCTAssertTrue(ea.event === event)
        XCTAssertTrue(thing.eventAssociations.contains { $0.persistentModelID == ea.persistentModelID })
        XCTAssertTrue(event.thingAssociations.contains { $0.persistentModelID == ea.persistentModelID })
        XCTAssertTrue(ter.associations.contains { $0.persistentModelID == ea.persistentModelID })
    }

    func testRelationshipManagerGroupMembership() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let anunnaki = FigureGroup(name: "Anunnaki")
        let enlil = makeTreeFigure(context, "Enlil")
        let nigeru = Place(name: "Nigeru")
        context.insert(anunnaki)
        context.insert(nigeru)

        let member = manager.addGroupMember(group: anunnaki, figure: enlil, orderIndex: 1)
        let placeMember = manager.addGroupMember(group: anunnaki, place: nigeru, orderIndex: 2)

        XCTAssertTrue(member.figure === enlil)
        XCTAssertTrue(placeMember.place === nigeru)
        XCTAssertTrue(anunnaki.figureAssociations.contains { $0.persistentModelID == member.persistentModelID })
        XCTAssertTrue(enlil.groupAssociations.contains { $0.persistentModelID == member.persistentModelID })
        XCTAssertTrue(nigeru.groupAssociations.contains { $0.persistentModelID == placeMember.persistentModelID })
        XCTAssertEqual(count(FigureGroupAssociation.self, in: context), 2)

        let again = manager.addGroupMember(group: anunnaki, figure: enlil)
        XCTAssertEqual(again.persistentModelID, member.persistentModelID)
        XCTAssertEqual(count(FigureGroupAssociation.self, in: context), 2)
    }

    func testRelationshipManagerPantheonMembership() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let figure = makeTreeFigure(context, "Anu")
        let mesopotamian = Pantheon(name: "Mesopotamian")
        context.insert(mesopotamian)

        let assoc = manager.addPantheonMembership(figure: figure, pantheon: mesopotamian, displayName: "Anu")

        XCTAssertTrue(assoc.figure === figure)
        XCTAssertTrue(assoc.pantheon === mesopotamian)
        XCTAssertEqual(assoc.displayName, "Anu")
        XCTAssertTrue(mesopotamian.figureAssociations?.contains { $0.persistentModelID == assoc.persistentModelID } == true)
        XCTAssertTrue(mesopotamian.figures.contains { $0.persistentModelID == figure.persistentModelID })
        XCTAssertEqual(count(FigurePantheonAssociation.self, in: context), 1)

        let again = manager.addPantheonMembership(figure: figure, pantheon: mesopotamian)
        XCTAssertEqual(again.persistentModelID, assoc.persistentModelID)
        XCTAssertEqual(count(FigurePantheonAssociation.self, in: context), 1)
    }

    func testRelationshipManagerAlternateNamesStickiesTagsCitationsAttachments() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let inanna = makeTreeFigure(context, "Inanna")
        let uruk = Place(name: "Uruk")
        context.insert(uruk)
        let source = Source(name: "Inanna's Descent")
        context.insert(source)

        let figAlt = manager.addAlternateName(to: inanna, name: "Ishtar", tradition: .akkadian)
        let placeAlt = manager.addAlternateName(to: uruk, name: "Erech", tradition: .greek)
        let note = manager.addStickyNote(to: inanna, text: "check the huluppu tree episode")
        let tag = manager.addTag(Tag(name: "goddess"), to: inanna)
        let citation = manager.addCitation(to: source, location: "line 1", entityType: .figure, linkedEntityName: "Inanna")
        let attachment = manager.addAttachment(to: source, title: "Translation", url: "https://example.com")

        XCTAssertEqual(figAlt.name, "Ishtar")
        XCTAssertTrue(figAlt.figure === inanna)
        XCTAssertTrue(inanna.alternateNames.contains { $0.persistentModelID == figAlt.persistentModelID })
        XCTAssertTrue(uruk.alternateNames.contains { $0.persistentModelID == placeAlt.persistentModelID })
        XCTAssertTrue(inanna.stickies.contains { $0.persistentModelID == note.persistentModelID })
        XCTAssertTrue(inanna.tags.contains { $0.persistentModelID == tag.persistentModelID })
        XCTAssertTrue(source.citations.contains { $0.persistentModelID == citation.persistentModelID })
        XCTAssertEqual(citation.linkedEntityName, "Inanna")
        XCTAssertTrue(source.attachments.contains { $0.persistentModelID == attachment.persistentModelID })

        let dup = manager.addAlternateName(to: inanna, name: "Ishtar", tradition: .akkadian)
        XCTAssertEqual(dup.persistentModelID, figAlt.persistentModelID)
        XCTAssertEqual(count(AlternateName.self, in: context), 2)

        let dupTag = manager.addTag(tag, to: inanna)
        XCTAssertEqual(dupTag.persistentModelID, tag.persistentModelID)
        XCTAssertEqual(count(Tag.self, in: context), 1)

        let dupCitation = manager.addCitation(to: source, location: "line 1", entityType: .figure, linkedEntityName: "Inanna")
        XCTAssertEqual(dupCitation.persistentModelID, citation.persistentModelID)
        XCTAssertEqual(count(Citation.self, in: context), 1)
    }

    func testRelationshipManagerRoleTypeFetchOrCreate() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)

        let a = manager.relationshipType(named: "Sibling", category: "family")
        let b = manager.relationshipType(named: "Sibling", category: "family")
        XCTAssertEqual(a.persistentModelID, b.persistentModelID)
        XCTAssertEqual(count(RelationshipType.self, in: context), 1)
        let c = manager.relationshipType(named: "Father", category: "parent")
        XCTAssertNotEqual(a.persistentModelID, c.persistentModelID)

        let r1 = manager.figurePlaceRoleType(named: "Worshipped At")
        let r2 = manager.figurePlaceRoleType(named: "Worshipped At")
        XCTAssertEqual(r1.persistentModelID, r2.persistentModelID)
        XCTAssertEqual(count(FigurePlaceRoleType.self, in: context), 1)

        let p1 = manager.placePlaceRoleType(named: "Near To")
        let p2 = manager.placePlaceRoleType(named: "Near To")
        XCTAssertEqual(p1.persistentModelID, p2.persistentModelID)

        let e1 = manager.eventPlaceRoleType(named: "At")
        let e2 = manager.eventPlaceRoleType(named: "At")
        XCTAssertEqual(e1.persistentModelID, e2.persistentModelID)

        let ee1 = manager.eventEventRoleType(named: "Caused")
        let ee2 = manager.eventEventRoleType(named: "Caused")
        XCTAssertEqual(ee1.persistentModelID, ee2.persistentModelID)

        let ef1 = manager.eventFigureRoleType(named: "Attended")
        let ef2 = manager.eventFigureRoleType(named: "Attended")
        XCTAssertEqual(ef1.persistentModelID, ef2.persistentModelID)
    }

    func testRelationshipManagerSavePersistsRows() {
        let container = makeDiskContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let a = makeTreeFigure(context, "A")
        let b = makeTreeFigure(context, "B")
        let type = manager.relationshipType(named: "Spouse", category: "partner")
        manager.addRelationship(from: a, to: b, relationshipType: type)

        do {
            try manager.save()
        } catch {
            XCTFail("save() threw: \(error)")
        }
        XCTAssertEqual(count(Relationship.self, in: context), 1)
    }

    func testRelationshipManagerAssociationsLinkSource() {
        let container = makeContainer()
        let context = ModelContext(container)
        let manager = RelationshipManager(context: context)
        let source = Source(name: "Enuma Elish")
        context.insert(source)
        let fig = makeTreeFigure(context, "Marduk")
        let place = Place(name: "Babylon")
        context.insert(place)
        let event = Event(name: "Babylon Captivity")
        context.insert(event)
        let event2 = Event(name: "Marduk's Rise")
        context.insert(event2)
        let thing = Thing(name: "Tablet of Destinies")
        context.insert(thing)
        let fpRole = manager.figurePlaceRoleType(named: "Ruler")
        let ppRole = manager.placePlaceRoleType(named: "Near To")
        let epRole = manager.eventPlaceRoleType(named: "At")
        let eeRole = manager.eventEventRoleType(named: "Caused")
        let tfRole = manager.thingFigureRoleType(named: "Owned By")
        let tpRole = manager.thingPlaceRoleType(named: "Found In")
        let teRole = manager.thingEventRoleType(named: "Used In")

        let fp = manager.addFigurePlaceAssociation(figure: fig, place: place, roleType: fpRole, source: "Enuma Elish", sourceRef: source, dedupe: false)
        let pp = manager.addPlacePlaceAssociation(from: place, to: place, roleType: ppRole, source: "Enuma Elish", sourceRef: source, dedupe: false)
        let ep = manager.addEventPlaceAssociation(event: event, place: place, roleType: epRole, source: "Enuma Elish", sourceRef: source, dedupe: false)
        let ee = manager.addEventEventAssociation(from: event, to: event2, roleType: eeRole, source: "Enuma Elish", sourceRef: source, dedupe: false)
        let tf = manager.addThingFigureAssociation(thing: thing, figure: fig, roleType: tfRole, source: "Enuma Elish", sourceRef: source, dedupe: false)
        let tp = manager.addThingPlaceAssociation(thing: thing, place: place, roleType: tpRole, source: "Enuma Elish", sourceRef: source, dedupe: false)
        let te = manager.addThingEventAssociation(thing: thing, event: event, roleType: teRole, source: "Enuma Elish", sourceRef: source, dedupe: false)

        XCTAssertTrue(fp.sourceRef === source)
        XCTAssertTrue(pp.sourceRef === source)
        XCTAssertTrue(ep.sourceRef === source)
        XCTAssertTrue(ee.sourceRef === source)
        XCTAssertTrue(tf.sourceRef === source)
        XCTAssertTrue(tp.sourceRef === source)
        XCTAssertTrue(te.sourceRef === source)

        XCTAssertTrue(source.figurePlaceAssociations.contains { $0.persistentModelID == fp.persistentModelID })
        XCTAssertTrue(source.placePlaceAssociations.contains { $0.persistentModelID == pp.persistentModelID })
        XCTAssertTrue(source.eventPlaceAssociations.contains { $0.persistentModelID == ep.persistentModelID })
        XCTAssertTrue(source.eventEventAssociations.contains { $0.persistentModelID == ee.persistentModelID })
        XCTAssertTrue(source.thingFigureAssociations.contains { $0.persistentModelID == tf.persistentModelID })
        XCTAssertTrue(source.thingPlaceAssociations.contains { $0.persistentModelID == tp.persistentModelID })
        XCTAssertTrue(source.thingEventAssociations.contains { $0.persistentModelID == te.persistentModelID })

        XCTAssertEqual(count(Source.self, in: context), 1)
    }

    func testEnsureAssociationSourcesBackfillsEachTypeAndIsIdempotent() {
        let container = makeContainer()
        let context = container.mainContext
        let source = Source(name: "Enuma Elish")
        context.insert(source)
        let fig = Figure(name: "Marduk")
        context.insert(fig)
        let place = Place(name: "Babylon")
        context.insert(place)
        let event = Event(name: "Babylon Captivity")
        context.insert(event)
        let event2 = Event(name: "Marduk's Rise")
        context.insert(event2)
        let thing = Thing(name: "Tablet of Destinies")
        context.insert(thing)

        let fp = FigurePlaceAssociation(figure: fig, place: place, source: "ENUMA ELISH")
        context.insert(fp)
        let pp = PlacePlaceAssociation(fromPlace: place, source: "Enuma Elish")
        context.insert(pp)
        let ep = EventPlaceAssociation(event: event, place: place, source: "Enuma Elish")
        context.insert(ep)
        let ee = EventEventAssociation(fromEvent: event, toEvent: event2, source: "Enuma Elish")
        context.insert(ee)
        let tf = ThingFigureAssociation(thing: thing, figure: fig, source: "Enuma Elish")
        context.insert(tf)
        let tp = ThingPlaceAssociation(thing: thing, place: place, source: "Enuma Elish")
        context.insert(tp)
        let te = ThingEventAssociation(thing: thing, event: event, source: "Enuma Elish")
        context.insert(te)
        try? context.save()

        Migration.ensureAssociationSources(context: context)
        Migration.ensureAssociationSources(context: context)

        XCTAssertTrue(fp.sourceRef === source)
        XCTAssertTrue(pp.sourceRef === source)
        XCTAssertTrue(ep.sourceRef === source)
        XCTAssertTrue(ee.sourceRef === source)
        XCTAssertTrue(tf.sourceRef === source)
        XCTAssertTrue(tp.sourceRef === source)
        XCTAssertTrue(te.sourceRef === source)
        XCTAssertTrue(source.figurePlaceAssociations.contains { $0.persistentModelID == fp.persistentModelID })
        XCTAssertTrue(source.placePlaceAssociations.contains { $0.persistentModelID == pp.persistentModelID })
        XCTAssertTrue(source.eventPlaceAssociations.contains { $0.persistentModelID == ep.persistentModelID })
        XCTAssertTrue(source.eventEventAssociations.contains { $0.persistentModelID == ee.persistentModelID })
        XCTAssertTrue(source.thingFigureAssociations.contains { $0.persistentModelID == tf.persistentModelID })
        XCTAssertTrue(source.thingPlaceAssociations.contains { $0.persistentModelID == tp.persistentModelID })
        XCTAssertTrue(source.thingEventAssociations.contains { $0.persistentModelID == te.persistentModelID })
        XCTAssertEqual(count(Source.self, in: context), 1)
    }

    func testEnsureAssociationSourcesCreatesCoarseSourceForUnknownName() {
        let container = makeContainer()
        let context = container.mainContext
        let fig = Figure(name: "Marduk")
        context.insert(fig)
        let place = Place(name: "Babylon")
        context.insert(place)
        let assoc = FigurePlaceAssociation(figure: fig, place: place, source: "Sumerian hymns")
        context.insert(assoc)
        try? context.save()

        Migration.ensureAssociationSources(context: context)

        XCTAssertNotNil(assoc.sourceRef)
        XCTAssertEqual(assoc.sourceRef?.name, "Sumerian hymns")
        XCTAssertEqual(assoc.sourceRef?.sourceType, .ancientText)
        XCTAssertTrue(assoc.sourceRef?.figurePlaceAssociations.contains { $0.persistentModelID == assoc.persistentModelID } ?? false)
        XCTAssertEqual(count(Source.self, in: context), 1)
    }
}
