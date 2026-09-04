import Foundation
import SwiftData

package struct RelationshipManager {
    package let context: ModelContext

    package init(context: ModelContext) {
        self.context = context
    }

    package func save() throws {
        try context.save()
    }

    // MARK: - Figure ↔ Figure

    @discardableResult
    package func addRelationship(
        from: Figure,
        to: Figure,
        relationshipType: RelationshipType,
        source: String = "",
        sourceRef: Source? = nil,
        isPreferred: Bool = false,
        groupID: String = "",
        dedupe: Bool = true
    ) -> Relationship {
        if dedupe, let existing = from.outgoingRelationships.first(where: {
            $0.toFigure?.persistentModelID == to.persistentModelID &&
            $0.relationshipType?.persistentModelID == relationshipType.persistentModelID
        }) {
            return existing
        }
        let rel = Relationship(
            fromFigure: from,
            toFigure: to,
            relationshipType: relationshipType,
            source: source,
            sourceRef: sourceRef,
            isPreferred: isPreferred,
            groupID: groupID
        )
        context.insert(rel)
        push(rel, into: &from.outgoingRelationships)
        push(rel, into: &relationshipType.relationships)
        if let sourceRef {
            push(rel, into: &sourceRef.relationships)
        }
        return rel
    }

    // MARK: - Figure ↔ Place

    @discardableResult
    package func addFigurePlaceAssociation(
        figure: Figure,
        place: Place,
        roleType: FigurePlaceRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil,
        comments: String? = nil,
        displayName: String? = nil,
        confidence: FigurePlaceAssociation.Confidence? = nil,
        dedupe: Bool = true
    ) -> FigurePlaceAssociation {
        if dedupe, let existing = figure.placeAssociations.first(where: {
            $0.place?.persistentModelID == place.persistentModelID &&
            $0.roleType?.persistentModelID == roleType?.persistentModelID
        }) {
            return existing
        }
        let association = FigurePlaceAssociation(
            figure: figure,
            place: place,
            roleType: roleType,
            source: source,
            sourceRef: sourceRef,
            comments: comments,
            displayName: displayName,
            confidence: confidence
        )
        context.insert(association)
        push(association, into: &figure.placeAssociations)
        push(association, into: &place.figureAssociations)
        if let roleType { push(association, into: &roleType.associations) }
        if let sourceRef { push(association, into: &sourceRef.figurePlaceAssociations) }
        return association
    }

    // MARK: - Place ↔ Place

    @discardableResult
    package func addPlacePlaceAssociation(
        from: Place,
        to: Place,
        roleType: PlacePlaceRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil,
        dedupe: Bool = true
    ) -> PlacePlaceAssociation {
        if dedupe, let existing = roleType?.associations.first(where: {
            $0.fromPlace?.persistentModelID == from.persistentModelID &&
            $0.toPlace?.persistentModelID == to.persistentModelID
        }) ?? first(where: {
            $0.fromPlace?.persistentModelID == from.persistentModelID &&
            $0.toPlace?.persistentModelID == to.persistentModelID &&
            $0.roleType == nil
        }) {
            return existing
        }
        let association = PlacePlaceAssociation(fromPlace: from, toPlace: to, roleType: roleType, source: source, sourceRef: sourceRef)
        context.insert(association)
        if let roleType { push(association, into: &roleType.associations) }
        if let sourceRef { push(association, into: &sourceRef.placePlaceAssociations) }
        return association
    }

    // MARK: - Event ↔ Place

    @discardableResult
    package func addEventPlaceAssociation(
        event: Event,
        place: Place,
        roleType: EventPlaceRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil,
        dedupe: Bool = true
    ) -> EventPlaceAssociation {
        if dedupe, let existing = event.placeAssociations.first(where: {
            $0.place?.persistentModelID == place.persistentModelID &&
            $0.roleType?.persistentModelID == roleType?.persistentModelID
        }) {
            return existing
        }
        let association = EventPlaceAssociation(event: event, place: place, roleType: roleType, source: source, sourceRef: sourceRef)
        context.insert(association)
        push(association, into: &event.placeAssociations)
        push(association, into: &place.eventAssociations)
        if let roleType { push(association, into: &roleType.associations) }
        if let sourceRef { push(association, into: &sourceRef.eventPlaceAssociations) }
        return association
    }

    // MARK: - Event ↔ Event

    @discardableResult
    package func addEventEventAssociation(
        from: Event,
        to: Event,
        roleType: EventEventRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil,
        dedupe: Bool = true
    ) -> EventEventAssociation {
        if dedupe, let existing = roleType?.associations.first(where: {
            $0.fromEvent?.persistentModelID == from.persistentModelID &&
            $0.toEvent?.persistentModelID == to.persistentModelID
        }) ?? first(where: {
            $0.fromEvent?.persistentModelID == from.persistentModelID &&
            $0.toEvent?.persistentModelID == to.persistentModelID &&
            $0.roleType == nil
        }) {
            return existing
        }
        let association = EventEventAssociation(fromEvent: from, toEvent: to, roleType: roleType, source: source, sourceRef: sourceRef)
        context.insert(association)
        if let roleType { push(association, into: &roleType.associations) }
        if let sourceRef { push(association, into: &sourceRef.eventEventAssociations) }
        return association
    }

    // MARK: - Event ↔ Figure

    @discardableResult
    package func addEventFigureAssociation(
        event: Event,
        figure: Figure,
        roleType: EventFigureRoleType? = nil,
        displayName: String? = nil,
        alsoLinkInvolvedFigures: Bool = true,
        dedupe: Bool = true
    ) -> EventFigureAssociation {
        if dedupe, let existing = (event.figureAssociations ?? []).first(where: {
            $0.figure?.persistentModelID == figure.persistentModelID &&
            $0.roleType?.persistentModelID == roleType?.persistentModelID
        }) {
            return existing
        }
        let association = EventFigureAssociation(event: event, figure: figure, roleType: roleType, displayName: displayName)
        context.insert(association)
        push(association, into: &event.figureAssociations)
        if alsoLinkInvolvedFigures && !figure.events.contains(where: { $0.persistentModelID == event.persistentModelID }) {
            push(event, into: &figure.events)
        }
        return association
    }

    // MARK: - Thing ↔ Figure / Place / Event

    @discardableResult
    package func addThingFigureAssociation(
        thing: Thing,
        figure: Figure,
        roleType: ThingFigureRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil,
        displayName: String? = nil,
        dedupe: Bool = true
    ) -> ThingFigureAssociation {
        if dedupe, let existing = thing.figureAssociations.first(where: {
            $0.figure?.persistentModelID == figure.persistentModelID &&
            $0.roleType?.persistentModelID == roleType?.persistentModelID
        }) {
            return existing
        }
        let association = ThingFigureAssociation(thing: thing, figure: figure, roleType: roleType, source: source, sourceRef: sourceRef, displayName: displayName)
        context.insert(association)
        push(association, into: &thing.figureAssociations)
        push(association, into: &figure.thingAssociations)
        if let roleType { push(association, into: &roleType.associations) }
        if let sourceRef { push(association, into: &sourceRef.thingFigureAssociations) }
        return association
    }

    @discardableResult
    package func addThingPlaceAssociation(
        thing: Thing,
        place: Place,
        roleType: ThingPlaceRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil,
        dedupe: Bool = true
    ) -> ThingPlaceAssociation {
        if dedupe, let existing = thing.placeAssociations.first(where: {
            $0.place?.persistentModelID == place.persistentModelID &&
            $0.roleType?.persistentModelID == roleType?.persistentModelID
        }) {
            return existing
        }
        let association = ThingPlaceAssociation(thing: thing, place: place, roleType: roleType, source: source, sourceRef: sourceRef)
        context.insert(association)
        push(association, into: &thing.placeAssociations)
        push(association, into: &place.thingAssociations)
        if let roleType { push(association, into: &roleType.associations) }
        if let sourceRef { push(association, into: &sourceRef.thingPlaceAssociations) }
        return association
    }

    @discardableResult
    package func addThingEventAssociation(
        thing: Thing,
        event: Event,
        roleType: ThingEventRoleType? = nil,
        source: String = "",
        sourceRef: Source? = nil,
        dedupe: Bool = true
    ) -> ThingEventAssociation {
        if dedupe, let existing = thing.eventAssociations.first(where: {
            $0.event?.persistentModelID == event.persistentModelID &&
            $0.roleType?.persistentModelID == roleType?.persistentModelID
        }) {
            return existing
        }
        let association = ThingEventAssociation(thing: thing, event: event, roleType: roleType, source: source, sourceRef: sourceRef)
        context.insert(association)
        push(association, into: &thing.eventAssociations)
        push(association, into: &event.thingAssociations)
        if let roleType { push(association, into: &roleType.associations) }
        if let sourceRef { push(association, into: &sourceRef.thingEventAssociations) }
        return association
    }

    // MARK: - Entity ↔ Group

    @discardableResult
    package func addGroupMember(
        group: FigureGroup,
        figure: Figure? = nil,
        place: Place? = nil,
        event: Event? = nil,
        thing: Thing? = nil,
        note: String = "",
        displayName: String? = nil,
        orderIndex: Int? = nil,
        dedupe: Bool = true
    ) -> FigureGroupAssociation {
        if dedupe, let existing = group.figureAssociations.first(where: { candidate in
            let candidateID = candidate.figure?.persistentModelID
                ?? candidate.place?.persistentModelID
                ?? candidate.event?.persistentModelID
                ?? candidate.thing?.persistentModelID
            let requestedID = figure?.persistentModelID
                ?? place?.persistentModelID
                ?? event?.persistentModelID
                ?? thing?.persistentModelID
            guard let candidateID, let requestedID else { return false }
            return candidateID == requestedID
        }) {
            return existing
        }
        let association = FigureGroupAssociation(
            figure: figure,
            place: place,
            event: event,
            thing: thing,
            group: group,
            note: note,
            displayName: displayName,
            orderIndex: orderIndex
        )
        context.insert(association)
        push(association, into: &group.figureAssociations)
        if let figure {
            push(association, into: &figure.groupAssociations)
        }
        if let place {
            push(association, into: &place.groupAssociations)
        }
        if let event {
            push(association, into: &event.groupAssociations)
        }
        if let thing {
            push(association, into: &thing.groupAssociations)
        }
        return association
    }

    // MARK: - Figure ↔ Pantheon

    @discardableResult
    package func addPantheonMembership(
        figure: Figure,
        pantheon: Pantheon,
        displayName: String? = nil,
        dedupe: Bool = true
    ) -> FigurePantheonAssociation {
        if dedupe, let existing = pantheon.figureAssociations?.first(where: {
            $0.figure?.persistentModelID == figure.persistentModelID
        }) {
            return existing
        }
        let association = FigurePantheonAssociation(figure: figure, pantheon: pantheon, displayName: displayName)
        context.insert(association)
        push(association, into: &figure.pantheonAssociations)
        push(association, into: &pantheon.figureAssociations)
        if !figure.pantheons.contains(where: { $0.persistentModelID == pantheon.persistentModelID }) {
            push(pantheon, into: &figure.pantheons)
        }
        return association
    }

    // MARK: - Alternate names

    @discardableResult
    package func addAlternateName(
        to figure: Figure,
        name: String,
        tradition: AlternateName.Tradition = .sumerian,
        nameType: AlternateName.NameType = .spelling,
        note: String = "",
        dedupe: Bool = true
    ) -> AlternateName {
        if dedupe, let existing = figure.alternateNames.first(where: {
            $0.name == name && $0.tradition == tradition
        }) {
            return existing
        }
        let alternateName = AlternateName(figure: figure, name: name, tradition: tradition, nameType: nameType, note: note)
        context.insert(alternateName)
        push(alternateName, into: &figure.alternateNames)
        return alternateName
    }

    @discardableResult
    package func addAlternateName(
        to place: Place,
        name: String,
        tradition: AlternateName.Tradition = .sumerian,
        nameType: AlternateName.NameType = .spelling,
        note: String = "",
        dedupe: Bool = true
    ) -> AlternateName {
        if dedupe, let existing = place.alternateNames.first(where: {
            $0.name == name && $0.tradition == tradition
        }) {
            return existing
        }
        let alternateName = AlternateName(place: place, name: name, tradition: tradition, nameType: nameType, note: note)
        context.insert(alternateName)
        push(alternateName, into: &place.alternateNames)
        return alternateName
    }

    // MARK: - Sticky notes

    @discardableResult
    package func addStickyNote(to figure: Figure, text: String, createdAt: Date = .now, isResolved: Bool = false) -> StickyNote {
        let note = StickyNote(text: text, createdAt: createdAt, isResolved: isResolved, figure: figure)
        context.insert(note)
        push(note, into: &figure.stickies)
        return note
    }

    @discardableResult
    package func addStickyNote(to place: Place, text: String, createdAt: Date = .now, isResolved: Bool = false) -> StickyNote {
        let note = StickyNote(text: text, createdAt: createdAt, isResolved: isResolved, place: place)
        context.insert(note)
        push(note, into: &place.stickies)
        return note
    }

    @discardableResult
    package func addStickyNote(to event: Event, text: String, createdAt: Date = .now, isResolved: Bool = false) -> StickyNote {
        let note = StickyNote(text: text, createdAt: createdAt, isResolved: isResolved, event: event)
        context.insert(note)
        push(note, into: &event.stickies)
        return note
    }

    @discardableResult
    package func addStickyNote(to thing: Thing, text: String, createdAt: Date = .now, isResolved: Bool = false) -> StickyNote {
        let note = StickyNote(text: text, createdAt: createdAt, isResolved: isResolved, thing: thing)
        context.insert(note)
        push(note, into: &thing.stickies)
        return note
    }

    // MARK: - Tags

    @discardableResult
    package func addTag(_ tag: Tag, to figure: Figure) -> Tag {
        context.insert(tag)
        if !figure.tags.contains(where: { $0.persistentModelID == tag.persistentModelID }) {
            push(tag, into: &figure.tags)
        }
        return tag
    }

    @discardableResult
    package func addTag(_ tag: Tag, to place: Place) -> Tag {
        context.insert(tag)
        if !place.tags.contains(where: { $0.persistentModelID == tag.persistentModelID }) {
            push(tag, into: &place.tags)
        }
        return tag
    }

    @discardableResult
    package func addTag(_ tag: Tag, to event: Event) -> Tag {
        context.insert(tag)
        if !event.tags.contains(where: { $0.persistentModelID == tag.persistentModelID }) {
            push(tag, into: &event.tags)
        }
        return tag
    }

    @discardableResult
    package func addTag(_ tag: Tag, to thing: Thing) -> Tag {
        context.insert(tag)
        if !thing.tags.contains(where: { $0.persistentModelID == tag.persistentModelID }) {
            push(tag, into: &thing.tags)
        }
        return tag
    }

    // MARK: - Source attachments & citations

    @discardableResult
    package func addAttachment(
        to source: Source,
        title: String = "",
        url: String = "",
        attachmentType: Attachment.AttachmentType = .onlineText,
        note: String? = nil,
        dedupe: Bool = true
    ) -> Attachment {
        if dedupe, let existing = source.attachments.first(where: {
            $0.title == title && $0.url == url
        }) {
            return existing
        }
        let attachment = Attachment(source: source, title: title, url: url, attachmentType: attachmentType, note: note)
        context.insert(attachment)
        push(attachment, into: &source.attachments)
        return attachment
    }

    @discardableResult
    package func addCitation(
        to source: Source,
        location: String = "",
        note: String = "",
        entityType: Citation.EntityType = .figure,
        linkedEntityName: String = "",
        dedupe: Bool = true
    ) -> Citation {
        if dedupe, let existing = source.citations.first(where: {
            $0.location == location && $0.entityType == entityType && $0.linkedEntityName == linkedEntityName
        }) {
            return existing
        }
        let citation = Citation(source: source, location: location, note: note, entityType: entityType, linkedEntityName: linkedEntityName)
        context.insert(citation)
        push(citation, into: &source.citations)
        return citation
    }

    // MARK: - Type & role fetch-or-create

    @discardableResult
    package func relationshipType(named name: String, icon: String = "", colorHex: String = "#8E9EAF", category: String = "other", reverseName: String? = nil) -> RelationshipType {
        if let existing = first(where: { ($0 as RelationshipType).name == name }) {
            return existing
        }
        let type = RelationshipType(name: name, icon: icon, colorHex: colorHex, category: category, reverseName: reverseName)
        context.insert(type)
        return type
    }

    @discardableResult
    package func figurePlaceRoleType(named name: String, icon: String = "", colorHex: String = "#8E9EAF", reverseName: String? = nil) -> FigurePlaceRoleType {
        if let existing = first(where: { ($0 as FigurePlaceRoleType).name == name }) {
            return existing
        }
        let type = FigurePlaceRoleType(name: name, icon: icon, colorHex: colorHex, reverseName: reverseName)
        context.insert(type)
        return type
    }

    @discardableResult
    package func placePlaceRoleType(named name: String, icon: String = "", colorHex: String = "#8E9EAF", reverseName: String? = nil) -> PlacePlaceRoleType {
        if let existing = first(where: { ($0 as PlacePlaceRoleType).name == name }) {
            return existing
        }
        let type = PlacePlaceRoleType(name: name, icon: icon, colorHex: colorHex, reverseName: reverseName)
        context.insert(type)
        return type
    }

    @discardableResult
    package func eventPlaceRoleType(named name: String, icon: String = "", colorHex: String = "#8E9EAF", reverseName: String? = nil) -> EventPlaceRoleType {
        if let existing = first(where: { ($0 as EventPlaceRoleType).name == name }) {
            return existing
        }
        let type = EventPlaceRoleType(name: name, icon: icon, colorHex: colorHex, reverseName: reverseName)
        context.insert(type)
        return type
    }

    @discardableResult
    package func eventEventRoleType(named name: String, icon: String = "", colorHex: String = "#8E9EAF", reverseName: String? = nil) -> EventEventRoleType {
        if let existing = first(where: { ($0 as EventEventRoleType).name == name }) {
            return existing
        }
        let type = EventEventRoleType(name: name, icon: icon, colorHex: colorHex, reverseName: reverseName)
        context.insert(type)
        return type
    }

    @discardableResult
    package func eventFigureRoleType(named name: String, icon: String = "", colorHex: String = "#8E9EAF", reverseName: String? = nil) -> EventFigureRoleType {
        if let existing = first(where: { ($0 as EventFigureRoleType).name == name }) {
            return existing
        }
        let type = EventFigureRoleType(name: name, icon: icon, colorHex: colorHex, reverseName: reverseName)
        context.insert(type)
        return type
    }

    @discardableResult
    package func thingFigureRoleType(named name: String, icon: String = "", colorHex: String = "#8E9EAF", reverseName: String? = nil) -> ThingFigureRoleType {
        if let existing = first(where: { ($0 as ThingFigureRoleType).name == name }) {
            return existing
        }
        let type = ThingFigureRoleType(name: name, icon: icon, colorHex: colorHex, reverseName: reverseName)
        context.insert(type)
        return type
    }

    @discardableResult
    package func thingPlaceRoleType(named name: String, icon: String = "", colorHex: String = "#8E9EAF", reverseName: String? = nil) -> ThingPlaceRoleType {
        if let existing = first(where: { ($0 as ThingPlaceRoleType).name == name }) {
            return existing
        }
        let type = ThingPlaceRoleType(name: name, icon: icon, colorHex: colorHex, reverseName: reverseName)
        context.insert(type)
        return type
    }

    @discardableResult
    package func thingEventRoleType(named name: String, icon: String = "", colorHex: String = "#8E9EAF", reverseName: String? = nil) -> ThingEventRoleType {
        if let existing = first(where: { ($0 as ThingEventRoleType).name == name }) {
            return existing
        }
        let type = ThingEventRoleType(name: name, icon: icon, colorHex: colorHex, reverseName: reverseName)
        context.insert(type)
        return type
    }

    // MARK: - Internals

    private func first<M: PersistentModel>(where matching: (M) -> Bool) -> M? {
        let all = (try? context.fetch(FetchDescriptor<M>())) ?? []
        return all.first(where: matching)
    }

    private func push<M: PersistentModel>(_ row: M, into array: inout [M]) {
        array.append(row)
    }

    private func push<M: PersistentModel>(_ row: M, into array: inout [M]?) {
        array = (array ?? []) + [row]
    }
}