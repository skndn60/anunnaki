import SwiftUI
import SwiftData

enum GroupMemberItem: Identifiable {
    case figure(Figure, String?)
    case place(Place, String?)
    case event(Event, String?)
    case thing(Thing, String?)

    var id: PersistentIdentifier {
        switch self {
        case .figure(let entity, _): return entity.persistentModelID
        case .place(let entity, _): return entity.persistentModelID
        case .event(let entity, _): return entity.persistentModelID
        case .thing(let entity, _): return entity.persistentModelID
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
        case .figure(let entity, _): return entity.name
        case .place(let entity, _): return entity.name
        case .event(let entity, _): return entity.name
        case .thing(let entity, _): return entity.name
        }
    }

    var displayName: String {
        if case .figure(let entity, let alias) = self, let alias, !alias.isEmpty {
            return "\(entity.name) as \(alias)"
        }
        if case .place(let entity, let alias) = self, let alias, !alias.isEmpty {
            return "\(entity.name) as \(alias)"
        }
        return name
    }

    var icon: String {
        switch self {
        case .figure(let entity, _): return entity.figureType?.icon ?? "person.fill"
        case .place(let entity, _): return entity.placeType?.icon ?? "mappin.and.ellipse"
        case .event(let entity, _): return entity.eventType?.icon ?? "bolt.fill"
        case .thing(let entity, _): return entity.thingType?.icon ?? "cube.box"
        }
    }

    var color: Color {
        switch self {
        case .figure(let entity, _): return entity.figureType?.color ?? .gray
        case .place(let entity, _): return entity.placeType?.color ?? .teal
        case .event(let entity, _): return entity.eventType?.color ?? .orange
        case .thing(let entity, _): return entity.thingType?.color ?? .purple
        }
    }

    var subtitle: String {
        switch self {
        case .figure(let entity, _): return entity.figureType?.name ?? ""
        case .place(let entity, _): return entity.placeType?.name ?? ""
        case .event(let entity, _): return entity.eventType?.name ?? ""
        case .thing(let entity, _): return entity.thingType?.name ?? ""
        }
    }

    var figure: Figure? {
        if case .figure(let entity, _) = self { return entity }
        return nil
    }

    var place: Place? {
        if case .place(let entity, _) = self { return entity }
        return nil
    }

    var event: Event? {
        if case .event(let entity, _) = self { return entity }
        return nil
    }

    var thing: Thing? {
        if case .thing(let entity, _) = self { return entity }
        return nil
    }

    init?(association: FigureGroupAssociation) {
        if let figure = association.figure {
            self = .figure(figure, association.displayName)
        } else if let place = association.place {
            self = .place(place, association.displayName)
        } else if let event = association.event {
            self = .event(event, association.displayName)
        } else if let thing = association.thing {
            self = .thing(thing, association.displayName)
        } else {
            return nil
        }
    }

    func makeAssociation() -> FigureGroupAssociation {
        switch self {
        case .figure(let entity, let alias): return FigureGroupAssociation(figure: entity, displayName: alias)
        case .place(let entity, let alias): return FigureGroupAssociation(place: entity, displayName: alias)
        case .event(let entity, let alias): return FigureGroupAssociation(event: entity, displayName: alias)
        case .thing(let entity, let alias): return FigureGroupAssociation(thing: entity, displayName: alias)
        }
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        if name.localizedCaseInsensitiveContains(query) { return true }
        return matchedAlternateName(for: query) != nil
    }

    func displayName(matching query: String) -> String {
        if let alt = matchedAlternateName(for: query) {
            return "\(name) as \(alt)"
        }
        return name
    }

    func matchedAlternateName(for query: String) -> String? {
        guard !query.isEmpty else { return nil }
        switch self {
        case .figure(let entity, _):
            return entity.alternateNames.first { $0.name.localizedCaseInsensitiveContains(query) }?.name
        case .place(let entity, _):
            return entity.alternateNames.first { $0.name.localizedCaseInsensitiveContains(query) }?.name
        case .event, .thing:
            return nil
        }
    }
}
