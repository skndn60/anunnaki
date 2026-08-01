import SwiftUI
import SwiftData

enum GroupMemberItem: Identifiable {
    case figure(Figure)
    case place(Place)
    case event(Event)
    case thing(Thing)

    var id: PersistentIdentifier {
        switch self {
        case .figure(let entity): return entity.persistentModelID
        case .place(let entity): return entity.persistentModelID
        case .event(let entity): return entity.persistentModelID
        case .thing(let entity): return entity.persistentModelID
        }
    }

    var entityType: GroupEntityType {
        switch self {
        case .figure: return .figure
        case .place: return .place
        case .event: return .event
        case .thing: return .thing
        }
    }

    var name: String {
        switch self {
        case .figure(let entity): return entity.name
        case .place(let entity): return entity.name
        case .event(let entity): return entity.name
        case .thing(let entity): return entity.name
        }
    }

    var icon: String {
        switch self {
        case .figure(let entity): return entity.figureType?.icon ?? "person.fill"
        case .place(let entity): return entity.placeType?.icon ?? "mappin.and.ellipse"
        case .event(let entity): return entity.eventType?.icon ?? "bolt.fill"
        case .thing(let entity): return entity.thingType?.icon ?? "cube.box"
        }
    }

    var color: Color {
        switch self {
        case .figure(let entity): return entity.figureType?.color ?? .gray
        case .place(let entity): return entity.placeType?.color ?? .teal
        case .event(let entity): return entity.eventType?.color ?? .orange
        case .thing(let entity): return entity.thingType?.color ?? .purple
        }
    }

    var subtitle: String {
        switch self {
        case .figure(let entity): return entity.figureType?.name ?? ""
        case .place(let entity): return entity.placeType?.name ?? ""
        case .event(let entity): return entity.eventType?.name ?? ""
        case .thing(let entity): return entity.thingType?.name ?? ""
        }
    }

    var figure: Figure? {
        if case .figure(let entity) = self { return entity }
        return nil
    }

    var place: Place? {
        if case .place(let entity) = self { return entity }
        return nil
    }

    var event: Event? {
        if case .event(let entity) = self { return entity }
        return nil
    }

    var thing: Thing? {
        if case .thing(let entity) = self { return entity }
        return nil
    }

    init?(association: FigureGroupAssociation) {
        if let figure = association.figure {
            self = .figure(figure)
        } else if let place = association.place {
            self = .place(place)
        } else if let event = association.event {
            self = .event(event)
        } else if let thing = association.thing {
            self = .thing(thing)
        } else {
            return nil
        }
    }

    func makeAssociation() -> FigureGroupAssociation {
        switch self {
        case .figure(let entity): return FigureGroupAssociation(figure: entity)
        case .place(let entity): return FigureGroupAssociation(place: entity)
        case .event(let entity): return FigureGroupAssociation(event: entity)
        case .thing(let entity): return FigureGroupAssociation(thing: entity)
        }
    }
}
