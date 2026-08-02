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

package enum GroupSortMode: String, Codable, CaseIterable, Hashable {
    case alphabetical = "alphabetical"
    case ordered = "ordered"

    package var displayName: String {
        switch self {
        case .alphabetical: return "Name"
        case .ordered: return "Manual Order"
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
    package var sortModeRawValue: String?

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

    package var sortMode: GroupSortMode {
        get { GroupSortMode(rawValue: sortModeRawValue ?? "") ?? .alphabetical }
        set { sortModeRawValue = newValue.rawValue }
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

    private static func memberName(_ a: FigureGroupAssociation) -> String {
        a.figure?.name ?? a.place?.name ?? a.event?.name ?? a.thing?.name ?? ""
    }

    /// This group's member associations in the order they should be displayed:
    /// alphabetical by name, or by explicit `orderIndex` (with name tie-break) when `sortMode == .ordered`.
    package var sortedAssociations: [FigureGroupAssociation] {
        switch sortMode {
        case .alphabetical:
            return figureAssociations.sorted {
                Self.memberName($0).localizedCaseInsensitiveCompare(Self.memberName($1)) == .orderedAscending
            }
        case .ordered:
            return figureAssociations.sorted {
                let a = $0.orderIndex ?? Int.max
                let b = $1.orderIndex ?? Int.max
                if a != b { return a < b }
                return Self.memberName($0).localizedCaseInsensitiveCompare(Self.memberName($1)) == .orderedAscending
            }
        }
    }

    /// Switch the group's sort mode. Switching to `.ordered` seeds every association with a
    /// sequential `orderIndex` so the current order becomes a stable, fine-tunable baseline.
    package func setSortMode(_ mode: GroupSortMode) {
        sortMode = mode
        if mode == .ordered {
            for (i, assoc) in figureAssociations.enumerated() {
                assoc.orderIndex = i
            }
        }
    }

    /// Move an association up/down one position when the group is in manual order.
    package func moveAssociation(_ assoc: FigureGroupAssociation, direction: Int) {
        var sorted = sortedAssociations
        guard let idx = sorted.firstIndex(where: { $0 === assoc }) else { return }
        let newIdx = idx + direction
        guard sorted.indices.contains(newIdx) else { return }
        sorted.swapAt(idx, newIdx)
        for (i, a) in sorted.enumerated() { a.orderIndex = i }
    }

    /// A stable chronological key for a member association. For figures this is
    /// (era order * scale + position within era); `figure.orderIndex` is the seed's
    /// sequence counter within its era, i.e. the SKL reign order.
    package static func regnalKey(_ assoc: FigureGroupAssociation) -> Int64 {
        if let figure = assoc.figure {
            let era = min(figure.era?.orderIndex ?? 100_000, 100_000)
            return Int64(era) * 1_000_000 + Int64(figure.orderIndex)
        }
        if let event = assoc.event {
            let year = min(max(event.date.sortValue, -99_999_999), 99_999_999)
            return Int64(year) * 10_000_000
        }
        return Int64.max
    }

    /// Order every figure member association by its chronicles key and write sequential
    /// `orderIndex` values. Used by SKL/migration to auto-assign reign order.
    package func applyRegnalOrder() {
        let sorted = figureAssociations.sorted { Self.regnalKey($0) < Self.regnalKey($1) }
        for (i, assoc) in sorted.enumerated() { assoc.orderIndex = i }
    }

    package func displayName(for id: PersistentIdentifier) -> String? {
        figureAssociations.first { assoc in
            assoc.figure?.persistentModelID == id
                || assoc.place?.persistentModelID == id
                || assoc.event?.persistentModelID == id
                || assoc.thing?.persistentModelID == id
        }?.displayName
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
        entityType: GroupEntityType = .figure,
        sortMode: GroupSortMode = .alphabetical
    ) {
        self.name = name
        self.groupDescription = groupDescription
        self.icon = icon
        self.colorHex = colorHex
        self.orderIndex = orderIndex
        self.memberFilter = memberFilter
        self.kindRawValue = kind.rawValue
        self.entityTypeRawValue = entityType.rawValue
        self.sortModeRawValue = sortMode.rawValue
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