import Foundation
import SwiftData

package enum GroupKind: String, Codable, CaseIterable, Hashable {
    case standard = "standard"
    case enoch = "enoch"
    case skl = "skl"
    case flood = "flood"

    package var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .enoch: return "Book of Enoch"
        case .skl: return "Sumerian King List"
        case .flood: return "The Flood"
        }
    }
}

package enum GroupEntityType: String, Codable, CaseIterable, Hashable {
    case figure = "figure"
    case place = "place"
    case event = "event"
    case thing = "thing"

    package var displayName: String {
        switch self {
        case .figure: return "Figure"
        case .place: return "Place"
        case .event: return "Event"
        case .thing: return "Thing"
        }
    }

    package var pluralName: String {
        switch self {
        case .figure: return "Figures"
        case .place: return "Places"
        case .event: return "Events"
        case .thing: return "Things"
        }
    }

    package var sidebarHeader: String {
        pluralName + " Groups"
    }

    package var icon: String {
        switch self {
        case .figure: return "person.3"
        case .place: return "mappin.and.ellipse"
        case .event: return "bolt.fill"
        case .thing: return "cube.box"
        }
    }
}

@Model
package final class FigureGroup {
    package var name: String
    package var groupDescription: String
    package var richDescription: Data?
    package var icon: String
    package var colorHex: String
    package var orderIndex: Int
    package var memberFilter: String?
    package var kindRawValue: String?
    package var entityTypeRawValue: String?
    package var publishedRawValue: Bool?

    package var isPublished: Bool {
        get { publishedRawValue ?? true }
        set { publishedRawValue = newValue ? nil : false }
    }

    package var kind: GroupKind {
        get { GroupKind(rawValue: kindRawValue ?? "") ?? .standard }
        set { kindRawValue = newValue.rawValue }
    }

    package var entityType: GroupEntityType {
        get { GroupEntityType(rawValue: entityTypeRawValue ?? "") ?? .figure }
        set { entityTypeRawValue = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \FigureGroupAssociation.group)
    package var figureAssociations: [FigureGroupAssociation] = []

    @Relationship(deleteRule: .nullify, inverse: \FigureGroup.parentGroup)
    package var subgroups: [FigureGroup]? = nil

    package var parentGroup: FigureGroup?

    package var directFigures: [Figure] {
        figureAssociations.compactMap { $0.figure }
    }

    package var directPlaces: [Place] {
        figureAssociations.compactMap { $0.place }
    }

    package var directEvents: [Event] {
        figureAssociations.compactMap { $0.event }
    }

    package var directThings: [Thing] {
        figureAssociations.compactMap { $0.thing }
    }

    package var decodedFilter: GroupMemberFilter? {
        get {
            guard let data = memberFilter?.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(GroupMemberFilter.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                memberFilter = nil
                return
            }
            memberFilter = String(data: data, encoding: .utf8)
        }
    }

    package init(
        name: String = "",
        groupDescription: String = "",
        icon: String = "rectangle.3.group",
        colorHex: String = "8E8E93",
        orderIndex: Int = 0,
        memberFilter: String? = nil,
        kind: GroupKind = .standard,
        entityType: GroupEntityType = .figure
    ) {
        self.name = name
        self.groupDescription = groupDescription
        self.icon = icon
        self.colorHex = colorHex
        self.orderIndex = orderIndex
        self.memberFilter = memberFilter
        self.kindRawValue = kind.rawValue
        self.entityTypeRawValue = entityType.rawValue
    }
}

package struct GroupMemberFilter: Codable, Equatable {
    package var figureTypeNames: [String]?
    package var domainKeywords: [String]?
    package var nameMatch: String?
    package var placeTypeNames: [String]?
    package var eventTypeNames: [String]?
    package var thingTypeNames: [String]?

    package init(
        figureTypeNames: [String]? = nil,
        domainKeywords: [String]? = nil,
        placeTypeNames: [String]? = nil,
        eventTypeNames: [String]? = nil,
        thingTypeNames: [String]? = nil,
        nameMatch: String? = nil
    ) {
        self.figureTypeNames = figureTypeNames
        self.domainKeywords = domainKeywords
        self.placeTypeNames = placeTypeNames
        self.eventTypeNames = eventTypeNames
        self.thingTypeNames = thingTypeNames
        self.nameMatch = nameMatch
    }

    package func matches(_ figure: Figure) -> Bool {
        if let typeNames = figureTypeNames, !typeNames.isEmpty {
            if let figureTypeName = figure.figureType?.name,
               typeNames.contains(where: { $0.localizedCaseInsensitiveCompare(figureTypeName) == .orderedSame }) {
                return true
            }
        }
        if let keywords = domainKeywords, !keywords.isEmpty {
            if keywords.contains(where: { figure.domain.localizedCaseInsensitiveContains($0) }) {
                return true
            }
        }
        if let match = nameMatch, !match.isEmpty {
            if figure.name.localizedCaseInsensitiveContains(match) {
                return true
            }
        }
        return false
    }

    package func matchesPlace(_ place: Place) -> Bool {
        if let typeNames = placeTypeNames, !typeNames.isEmpty {
            if let name = place.placeType?.name,
               typeNames.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                return true
            }
        }
        if let match = nameMatch, !match.isEmpty {
            if place.name.localizedCaseInsensitiveContains(match) {
                return true
            }
        }
        return false
    }

    package func matchesEvent(_ event: Event) -> Bool {
        if let typeNames = eventTypeNames, !typeNames.isEmpty {
            if let name = event.eventType?.name,
               typeNames.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                return true
            }
        }
        if let match = nameMatch, !match.isEmpty {
            if event.name.localizedCaseInsensitiveContains(match) {
                return true
            }
        }
        return false
    }

    package func matchesThing(_ thing: Thing) -> Bool {
        if let typeNames = thingTypeNames, !typeNames.isEmpty {
            if let name = thing.thingType?.name,
               typeNames.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                return true
            }
        }
        if let match = nameMatch, !match.isEmpty {
            if thing.name.localizedCaseInsensitiveContains(match) {
                return true
            }
        }
        return false
    }

    package var summary: String {
        var parts: [String] = []
        if let typeNames = figureTypeNames, !typeNames.isEmpty {
            parts.append("Type: \(typeNames.joined(separator: ", "))")
        }
        if let typeNames = placeTypeNames, !typeNames.isEmpty {
            parts.append("Place type: \(typeNames.joined(separator: ", "))")
        }
        if let typeNames = eventTypeNames, !typeNames.isEmpty {
            parts.append("Event type: \(typeNames.joined(separator: ", "))")
        }
        if let typeNames = thingTypeNames, !typeNames.isEmpty {
            parts.append("Thing type: \(typeNames.joined(separator: ", "))")
        }
        if let keywords = domainKeywords, !keywords.isEmpty {
            parts.append("Domain: \(keywords.joined(separator: ", "))")
        }
        if let match = nameMatch, !match.isEmpty {
            parts.append("Name: \"\(match)\"")
        }
        return parts.isEmpty ? "No filter" : parts.joined(separator: " · ")
    }
}