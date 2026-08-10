import SwiftUI
import SwiftData

/// Smart-group helpers. "Effective" members are what the group displays:
/// for smart groups the live filter matches (sorted by name); for manual groups
/// the stored associations in display order. Everything that shows group members
/// or counts should read through here so smart groups stay current automatically.
extension FigureGroup {
    func effectiveMemberItems(in context: ModelContext) -> [GroupMemberItem] {
        guard isSmart else {
            return sortedAssociations.compactMap(GroupMemberItem.init(association:))
        }
        let liveIDs = Set(liveMatchIDs(in: context))
        switch entityType {
        case .figure:
            return ((try? context.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? [])
                .filter { liveIDs.contains($0.persistentModelID) }
                .map { GroupMemberItem.figure($0, nil) }
        case .place:
            return ((try? context.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? [])
                .filter { liveIDs.contains($0.persistentModelID) }
                .map { GroupMemberItem.place($0, nil) }
        case .event:
            return ((try? context.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.name)]))) ?? [])
                .filter { liveIDs.contains($0.persistentModelID) }
                .map { GroupMemberItem.event($0, nil) }
        case .thing:
            return ((try? context.fetch(FetchDescriptor<Thing>(sortBy: [SortDescriptor(\.name)]))) ?? [])
                .filter { liveIDs.contains($0.persistentModelID) }
                .map { GroupMemberItem.thing($0, nil) }
        }
    }

    func effectiveMemberCount(in context: ModelContext) -> Int {
        guard isSmart else { return figureAssociations.count }
        return liveMatchIDs(in: context).count
    }
}

extension GroupAggregation {
    /// Compute the aggregation over an arbitrary list of member items (used by smart
    /// groups, where membership is evaluated live instead of from association rows).
    func compute(items: [GroupMemberItem]) -> GroupAggregationResult? {
        let values = items.compactMap { target.value(for: $0) }
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return GroupAggregationResult(
            count: values.count,
            sum: sum,
            average: operation == .average ? Double(sum) / Double(values.count) : nil
        )
    }
}

extension GroupAggregationTarget {
    /// Value extraction for a member item — mirrors `value(for: FigureGroupAssociation)`
    /// but works on the transient items smart groups produce.
    func value(for item: GroupMemberItem) -> Int? {
        switch self {
        case .reignYears:
            guard let figure = item.figure else { return nil }
            return figure.reignYears ?? ReignLength.parse(from: figure.figureDescription)?.years
        case .reignSpan:
            guard let figure = item.figure, let start = figure.reignStartYear, let end = figure.reignEndYear else { return nil }
            return end - start
        case .lifespan:
            guard let figure = item.figure,
                  let birth = figure.birthDate.startYear ?? figure.birthDate.endYear,
                  let death = figure.deathDate.endYear ?? figure.deathDate.startYear else { return nil }
            return death - birth
        case .birthYear:
            return item.figure?.birthDate.startYear ?? item.figure?.birthDate.endYear
        case .deathYear:
            return item.figure?.deathDate.endYear ?? item.figure?.deathDate.startYear
        case .eventYear:
            return item.event?.date.startYear ?? item.event?.date.endYear
        }
    }
}