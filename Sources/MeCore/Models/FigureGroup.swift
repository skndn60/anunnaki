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

/// Where a top-level group appears in the sidebar. Overrides the type-derived
/// placement (`entityType` → "History" for figures, "X Groups" for others).
package enum GroupSidebarTarget: Equatable, Hashable {
    case auto
    case history
    case data
    case custom(String)

    /// "history" / "data" / "custom:<name>" / nil for `.auto`.
    package var rawValue: String? {
        switch self {
        case .auto: return nil
        case .history: return "history"
        case .data: return "data"
        case .custom(let name): return "custom:\(name)"
        }
    }

    package init(rawValue: String?) {
        switch rawValue ?? "" {
        case "history": self = .history
        case "data": self = .data
        case let value where value.hasPrefix("custom:"):
            self = .custom(String(value.dropFirst("custom:".count)))
        default: self = .auto
        }
    }

    package var displayName: String {
        switch self {
        case .auto: return "Automatic (by type)"
        case .history: return "History"
        case .data: return "Data"
        case .custom(let name): return "Custom: \(name)"
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
    /// When true, the group's members are the live result of `decodedFilter` evaluated
    /// at display time — never stored association rows. Manual member picking and
    /// per-member ordering are disabled; pinned associations are ignored for display
    /// while smart is on (kept in the DB and restored if smart is turned back off).
    package var isSmartRawValue: Bool?
    package var kindRawValue: String?
    package var entityTypeRawValue: String?
    package var publishedRawValue: Bool?
    package var sortModeRawValue: String?
    package var aggregationRawValue: String?
    package var memberSingular: String?
    package var memberPlural: String?
    package var sidebarTargetRawValue: String?

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

    /// Where this group's sidebar entry appears. Defaults to `.auto` (type-derived),
    /// preserving pre-existing behavior for all existing groups.
    package var sidebarTarget: GroupSidebarTarget {
        get { GroupSidebarTarget(rawValue: sidebarTargetRawValue) }
        set { sidebarTargetRawValue = newValue.rawValue }
    }

    /// True when this group should render inside the sidebar's "History" section:
    /// explicitly targeted, or auto-derived for figure groups.
    package var rendersInHistory: Bool {
        switch sidebarTarget {
        case .history: return true
        case .auto: return entityType == .figure
        case .data, .custom: return false
        }
    }

    /// True when this group should render inside the sidebar's "Data" section.
    package var rendersInData: Bool {
        switch sidebarTarget {
        case .data: return true
        case .auto, .history, .custom: return false
        }
    }

    /// The custom section title when explicitly targeted at one, nil otherwise.
    package var customSectionTitle: String? {
        if case .custom(let title) = sidebarTarget {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    package var isSmart: Bool {
        get { isSmartRawValue == true }
        set { isSmartRawValue = newValue ? true : nil }
    }

    package var sortMode: GroupSortMode {
        get { GroupSortMode(rawValue: sortModeRawValue ?? "") ?? .alphabetical }
        set { sortModeRawValue = newValue.rawValue }
    }

    /// Custom label for a single member (e.g. "ruler"), falling back to "member".
    package var memberSingularLabel: String {
        guard let memberSingular, !memberSingular.isEmpty else { return "member" }
        return memberSingular
    }

    /// Custom label for multiple members (e.g. "rulers"), falling back to "members".
    package var memberPluralLabel: String {
        guard let memberPlural, !memberPlural.isEmpty else { return "members" }
        return memberPlural
    }

    /// "7 rulers" / "1 ruler", using the custom labels when set.
    package func memberCountText(count: Int) -> String {
        "\(count) \(count == 1 ? memberSingularLabel : memberPluralLabel)"
    }

    @Relationship(deleteRule: .cascade, inverse: \FigureGroupAssociation.group)
    package var figureAssociations: [FigureGroupAssociation] = []

    /// Free-form prose blocks that interleave with members when the group is in manual order.
    @Relationship(deleteRule: .cascade, inverse: \GroupTextBlock.group)
    package var textBlocks: [GroupTextBlock]? = nil

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

    /// This group's subgroups in the order they should be displayed:
    /// by explicit `orderIndex`, with name tie-break for subgroups that have no position.
    package var sortedSubgroups: [FigureGroup] {
        (subgroups ?? []).sorted { ($0.orderIndex, $0.name) < ($1.orderIndex, $1.name) }
    }

    /// The text blocks in display order (by `orderIndex`, then title).
    package var sortedTextBlocks: [GroupTextBlock] {
        (textBlocks ?? []).sorted {
            let a = $0.orderIndex ?? Int.max
            let b = $1.orderIndex ?? Int.max
            if a != b { return a < b }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    /// A single ordered spine over this group's members AND text blocks (both share one
    /// `orderIndex` domain). Members and prose are interleaved by their position; subgroups
    /// are NOT part of this spine.
    package var memberTextSpine: [GroupContentItem] {
        let members = sortedAssociations.map(GroupContentItem.member)
        let texts = sortedTextBlocks.map(GroupContentItem.text)
        var items = members + texts
        items.sort {
            let a = $0.orderIndex ?? Int.max
            let b = $1.orderIndex ?? Int.max
            if a != b { return a < b }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return items
    }

    /// Move a unified spine item up/down one position and renumber the whole member+text spine.
    package func moveMemberTextItem(_ item: GroupContentItem, direction: Int) {
        var spine = memberTextSpine
        guard let idx = spine.firstIndex(where: { $0 == item }) else { return }
        let newIdx = idx + direction
        guard spine.indices.contains(newIdx) else { return }
        spine.swapAt(idx, newIdx)
        for (i, content) in spine.enumerated() {
            switch content {
            case .member(let assoc): assoc.orderIndex = i
            case .text(let block): block.orderIndex = i
            }
        }
    }

    /// Whether the given spine item can move one position in `direction` (relative to the
    /// unified member+text spine, not just its own type's list).
    package func canMoveMemberTextItem(_ item: GroupContentItem, direction: Int) -> Bool {
        let spine = memberTextSpine
        guard let idx = spine.firstIndex(where: { $0 == item }) else { return false }
        return spine.indices.contains(idx + direction)
    }

    /// Move a spine item to an arbitrary insertion index (valid range 0...count),
    /// then renumber the whole member+text spine. Used by drag-and-drop reordering.
    package func moveMemberTextItem(_ item: GroupContentItem, toIndex: Int) {
        var spine = memberTextSpine
        guard let fromIdx = spine.firstIndex(where: { $0 == item }) else { return }
        let moved = spine.remove(at: fromIdx)
        let clamped = max(0, min(spine.count, toIndex))
        spine.insert(moved, at: clamped)
        for (i, content) in spine.enumerated() {
            switch content {
            case .member(let assoc): assoc.orderIndex = i
            case .text(let block): block.orderIndex = i
            }
        }
    }

    /// Append a text block at the END of the member+text spine so it starts at the bottom
    /// of the page (after all current members and prose), regardless of `sortMode`.
    package func appendTextBlock(_ block: GroupTextBlock) {
        if textBlocks == nil { textBlocks = [] }
        textBlocks?.append(block)
        let maxIndex = memberTextSpine.compactMap { $0.orderIndex }.max() ?? -1
        block.orderIndex = maxIndex + 1
    }

    /// Switch the group's sort mode. Switching to `.ordered` seeds every association and
    /// every subgroup with a sequential `orderIndex` so the current order becomes a stable,
    /// fine-tunable baseline.
    package func setSortMode(_ mode: GroupSortMode) {
        sortMode = mode
        if mode == .ordered {
            for (i, assoc) in figureAssociations.enumerated() {
                assoc.orderIndex = i
            }
            for (i, sub) in sortedSubgroups.enumerated() {
                sub.orderIndex = i
            }
            for (i, block) in sortedTextBlocks.enumerated() {
                block.orderIndex = i
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

    /// Move a subgroup up/down one position when the group is in manual order.
    package func moveSubgroup(_ subgroup: FigureGroup, direction: Int) {
        var sorted = sortedSubgroups
        guard let idx = sorted.firstIndex(where: { $0 === subgroup }) else { return }
        let newIdx = idx + direction
        guard sorted.indices.contains(newIdx) else { return }
        sorted.swapAt(idx, newIdx)
        for (i, sub) in sorted.enumerated() { sub.orderIndex = i }
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

    /// The aggregation config (if any) shown in this group's header.
    package var decodedAggregation: GroupAggregation? {
        get {
            guard let data = aggregationRawValue?.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(GroupAggregation.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                aggregationRawValue = nil
                return
            }
            aggregationRawValue = String(data: data, encoding: .utf8)
        }
    }

    /// Persistent IDs of every entity of this group's type that currently matches
    /// `decodedFilter`. Empty for manual groups. This is the "live membership" that
    /// smart groups display; it re-evaluates on every call so newly created figures
    /// appear immediately.
    package func liveMatchIDs(in context: ModelContext) -> [PersistentIdentifier] {
        guard isSmart, let filter = decodedFilter else { return [] }
        switch entityType {
        case .figure:
            let all = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
            return all.filter { filter.matches($0) }.map(\.persistentModelID)
        case .place:
            let all = (try? context.fetch(FetchDescriptor<Place>())) ?? []
            return all.filter { filter.matchesPlace($0) }.map(\.persistentModelID)
        case .event:
            let all = (try? context.fetch(FetchDescriptor<Event>())) ?? []
            return all.filter { filter.matchesEvent($0) }.map(\.persistentModelID)
        case .thing:
            let all = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
            return all.filter { filter.matchesThing($0) }.map(\.persistentModelID)
        }
    }

    package init(
        name: String = "",
        groupDescription: String = "",
        icon: String = "rectangle.3.group",
        colorHex: String = "8E8E93",
        orderIndex: Int = 0,
        memberFilter: String? = nil,
        isSmart: Bool = false,
        kind: GroupKind = .standard,
        entityType: GroupEntityType = .figure,
        sortMode: GroupSortMode = .alphabetical,
        memberSingular: String? = nil,
        memberPlural: String? = nil,
        sidebarTarget: GroupSidebarTarget = .auto
    ) {
        self.name = name
        self.groupDescription = groupDescription
        self.icon = icon
        self.colorHex = colorHex
        self.orderIndex = orderIndex
        self.memberFilter = memberFilter
        self.isSmartRawValue = isSmart ? true : nil
        self.kindRawValue = kind.rawValue
        self.entityTypeRawValue = entityType.rawValue
        self.sortModeRawValue = sortMode.rawValue
        self.memberSingular = memberSingular
        self.memberPlural = memberPlural
        self.sidebarTargetRawValue = sidebarTarget.rawValue
    }
}

/// A unified spine item in a group: either a member association or a text block.
/// Both share a single `orderIndex` domain so members and prose interleave.
package enum GroupContentItem: Equatable {
    case member(FigureGroupAssociation)
    case text(GroupTextBlock)

    /// The shared spine position. Nil = no explicit position.
    package var orderIndex: Int? {
        switch self {
        case .member(let assoc): return assoc.orderIndex
        case .text(let block): return block.orderIndex
        }
    }

    /// Display name: the member's entity name, or the text block's title.
    package var name: String {
        switch self {
        case .member(let assoc): return assoc.figure?.name ?? assoc.place?.name ?? assoc.event?.name ?? assoc.thing?.name ?? ""
        case .text(let block): return block.title
        }
    }
}

package struct GroupMemberFilter: Codable, Equatable {
    package var figureTypeNames: [String]?
    package var domainKeywords: [String]?
    package var pantheonNames: [String]?
    package var nameMatch: String?
    package var placeTypeNames: [String]?
    package var eventTypeNames: [String]?
    package var thingTypeNames: [String]?

    package init(
        figureTypeNames: [String]? = nil,
        domainKeywords: [String]? = nil,
        pantheonNames: [String]? = nil,
        placeTypeNames: [String]? = nil,
        eventTypeNames: [String]? = nil,
        thingTypeNames: [String]? = nil,
        nameMatch: String? = nil
    ) {
        self.figureTypeNames = figureTypeNames
        self.domainKeywords = domainKeywords
        self.pantheonNames = pantheonNames
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
        if let names = pantheonNames, !names.isEmpty {
            if names.contains(where: { name in
                figure.pantheons.contains { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
            }) {
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
        if let names = pantheonNames, !names.isEmpty {
            parts.append("Pantheon: \(names.joined(separator: ", "))")
        }
        if let match = nameMatch, !match.isEmpty {
            parts.append("Name: \"\(match)\"")
        }
        return parts.isEmpty ? "No filter" : parts.joined(separator: " · ")
    }
}

/// Aggregation operation applied over a group's member values.
package enum GroupAggregationOperation: String, Codable, CaseIterable, Hashable {
    case sum = "sum"
    case average = "average"

    package var displayName: String {
        switch self {
        case .sum: return "Sum"
        case .average: return "Average"
        }
    }

    /// Verb used to build the default title (e.g. "Total reign", "Average lifespan").
    package var verb: String {
        switch self {
        case .sum: return "Total"
        case .average: return "Average"
        }
    }
}

/// The field a group aggregation reads from each member.
package enum GroupAggregationTarget: String, Codable, CaseIterable, Hashable {
    case reignYears = "reignYears"
    case reignSpan = "reignSpan"
    case lifespan = "lifespan"
    case birthYear = "birthYear"
    case deathYear = "deathYear"
    case eventYear = "eventYear"

    package var displayName: String {
        switch self {
        case .reignYears: return "Listed reign (years)"
        case .reignSpan: return "Reign span (years)"
        case .lifespan: return "Lifespan (years)"
        case .birthYear: return "Birth year"
        case .deathYear: return "Death year"
        case .eventYear: return "Event date (year)"
        }
    }

    /// Short noun used to build the default title.
    package var shortName: String {
        switch self {
        case .reignYears: return "listed reign"
        case .reignSpan: return "reign span"
        case .lifespan: return "lifespan"
        case .birthYear: return "birth year"
        case .deathYear: return "death year"
        case .eventYear: return "event date"
        }
    }

    /// Whether the target's value is expressed in years (as opposed to a calendar year).
    package var isDuration: Bool {
        switch self {
        case .reignYears, .reignSpan, .lifespan: return true
        case .birthYear, .deathYear, .eventYear: return false
        }
    }

    /// The entity types that can supply values for this target.
    package var supportedEntityTypes: [GroupEntityType] {
        switch self {
        case .reignYears, .reignSpan, .lifespan, .birthYear, .deathYear: return [.figure]
        case .eventYear: return [.event]
        }
    }

    /// Extract the numeric value for a single member association, or nil when the
    /// member has no data for this field.
    package func value(for assoc: FigureGroupAssociation) -> Int? {
        switch self {
        case .reignYears:
            guard let figure = assoc.figure else { return nil }
            return figure.reignYears ?? ReignLength.parse(from: figure.figureDescription)?.years
        case .reignSpan:
            guard let figure = assoc.figure, let start = figure.reignStartYear, let end = figure.reignEndYear else { return nil }
            return end - start
        case .lifespan:
            guard let figure = assoc.figure,
                  let birth = figure.birthDate.startYear ?? figure.birthDate.endYear,
                  let death = figure.deathDate.endYear ?? figure.deathDate.startYear else { return nil }
            return death - birth
        case .birthYear:
            return assoc.figure?.birthDate.startYear ?? assoc.figure?.birthDate.endYear
        case .deathYear:
            return assoc.figure?.deathDate.endYear ?? assoc.figure?.deathDate.startYear
        case .eventYear:
            return assoc.event?.date.startYear ?? assoc.event?.date.endYear
        }
    }
}

/// A user-defined summary shown in a group's header, computed over its direct members.
package struct GroupAggregation: Codable, Equatable, Hashable {
    package var operation: GroupAggregationOperation
    package var target: GroupAggregationTarget
    package var label: String?

    package init(operation: GroupAggregationOperation, target: GroupAggregationTarget, label: String? = nil) {
        self.operation = operation
        self.target = target
        self.label = label
    }

    /// Title shown next to the computed value (custom label, or e.g. "Total reign").
    package var title: String {
        if let label, !label.isEmpty { return label }
        return "\(operation.verb) \(target.shortName)"
    }

    /// Sum and average over the group's direct member associations.
    package func compute(in group: FigureGroup) -> GroupAggregationResult? {
        let values = group.figureAssociations.compactMap { target.value(for: $0) }
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return GroupAggregationResult(
            count: values.count,
            sum: sum,
            average: operation == .average ? Double(sum) / Double(values.count) : nil
        )
    }

    /// Human-readable value for the computed result.
    package func formattedValue(for result: GroupAggregationResult) -> String {
        let number: Int = operation == .average ? Int((result.average ?? 0).rounded()) : result.sum
        if target.isDuration {
            return "\(Self.formatInt(number)) years"
        }
        return Self.formatYear(number)
    }

    private static func formatInt(_ value: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func formatYear(_ value: Int) -> String {
        let suffix = value < 0 ? " BCE" : " CE"
        return formatInt(abs(value)) + suffix
    }
}

package struct GroupAggregationResult: Equatable {
    package let count: Int
    package let sum: Int
    package let average: Double?

    package init(count: Int, sum: Int, average: Double?) {
        self.count = count
        self.sum = sum
        self.average = average
    }
}