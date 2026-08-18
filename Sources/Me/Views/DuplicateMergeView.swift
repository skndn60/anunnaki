import SwiftUI
import SwiftData

private struct DuplicateMemberDisplay: Identifiable {
    let id: PersistentIdentifier
    let title: String
    let subtitle: String
}

private struct DuplicateGroupDisplay: Identifiable {
    let kind: DuplicateGroup.EntityKind
    let name: String
    let ids: [PersistentIdentifier]
    let members: [DuplicateMemberDisplay]

    var id: String { "\(kind.rawValue):\(name.lowercased())" }
    var duplicateCount: Int { ids.count - 1 }
}

struct DuplicateMergeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var groups: [DuplicateGroupDisplay] = []
    @State private var keeperIDs: [String: PersistentIdentifier] = [:]
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Merge Duplicates").font(.headline)
                Spacer()
                Button("Refresh") { load() }
                Button("Done") { dismiss() }
            }

            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }

            if groups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No duplicate names found.")
                        .font(.callout)
                    Text("Entities are matched case-insensitively by name.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groups) { group in
                            duplicateCard(group)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 640, height: 560)
        .task { load() }
    }

    private func duplicateCard(_ group: DuplicateGroupDisplay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: kindIcon(group.kind))
                Text(group.name).font(.headline)
                Text(group.kind.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                Spacer()
                Button("Merge \(group.duplicateCount) into keeper") {
                    merge(group)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(group.duplicateCount == 0)
            }
            ForEach(group.members) { member in
                memberRow(group: group, member: member)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private func memberRow(group: DuplicateGroupDisplay, member: DuplicateMemberDisplay) -> some View {
        let isKeeper = keeperIDs[group.id] == member.id
        return HStack(spacing: 8) {
            Button {
                keeperIDs[group.id] = member.id
            } label: {
                Image(systemName: isKeeper ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isKeeper ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(isKeeper ? "This is the keeper" : "Keep this one")

            VStack(alignment: .leading, spacing: 1) {
                Text(member.title)
                    .font(.callout)
                    .fontWeight(isKeeper ? .semibold : .regular)
                Text(member.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isKeeper {
                Text("Keeper")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }

    private func merge(_ group: DuplicateGroupDisplay) {
        guard let keeperID = keeperIDs[group.id] else { return }
        let duplicates = group.ids.filter { $0 != keeperID }
        var merged = 0
        for id in duplicates {
            switch group.kind {
            case .figure:
                guard let keeper = modelContext.model(for: keeperID) as? Figure,
                      let duplicate = modelContext.model(for: id) as? Figure else { continue }
                try? DuplicateMerger.mergeFigures(keeper, duplicate, in: modelContext)
                merged += 1
            case .place:
                guard let keeper = modelContext.model(for: keeperID) as? Place,
                      let duplicate = modelContext.model(for: id) as? Place else { continue }
                try? DuplicateMerger.mergePlaces(keeper, duplicate, in: modelContext)
                merged += 1
            case .event:
                guard let keeper = modelContext.model(for: keeperID) as? Event,
                      let duplicate = modelContext.model(for: id) as? Event else { continue }
                try? DuplicateMerger.mergeEvents(keeper, duplicate, in: modelContext)
                merged += 1
            case .thing:
                guard let keeper = modelContext.model(for: keeperID) as? Thing,
                      let duplicate = modelContext.model(for: id) as? Thing else { continue }
                try? DuplicateMerger.mergeThings(keeper, duplicate, in: modelContext)
                merged += 1
            }
        }
        statusMessage = "Merged \(merged) duplicate\(merged == 1 ? "" : "s")"
        load()
    }

    private func load() {
        let found = (try? DuplicateMerger.findGroups(in: modelContext)) ?? []
        groups = found.map { display(for: $0) }
        for group in groups where keeperIDs[group.id] == nil {
            keeperIDs[group.id] = group.ids.first
        }
    }

    private func display(for group: DuplicateGroup) -> DuplicateGroupDisplay {
        let members = group.ids.compactMap { id -> DuplicateMemberDisplay? in
            guard let detail = detail(for: group.kind, id: id) else { return nil }
            return DuplicateMemberDisplay(id: id, title: detail.title, subtitle: detail.subtitle)
        }
        return DuplicateGroupDisplay(kind: group.kind, name: group.name, ids: group.ids, members: members)
    }

    private func detail(for kind: DuplicateGroup.EntityKind, id: PersistentIdentifier) -> (title: String, subtitle: String)? {
        switch kind {
        case .figure:
            guard let figure = modelContext.model(for: id) as? Figure else { return nil }
            return (figure.name, "\(figure.figureType?.name ?? "Figure") · \(summary(for: figure))")
        case .place:
            guard let place = modelContext.model(for: id) as? Place else { return nil }
            return (place.name, "\(place.placeType?.name ?? "Place") · \(summary(for: place))")
        case .event:
            guard let event = modelContext.model(for: id) as? Event else { return nil }
            return (event.name, "\(event.eventType?.name ?? "Event") · \(summary(for: event))")
        case .thing:
            guard let thing = modelContext.model(for: id) as? Thing else { return nil }
            return (thing.name, "\(thing.thingType?.name ?? "Thing") · \(summary(for: thing))")
        }
    }

    private func summary(for figure: Figure) -> String {
        var parts: [String] = []
        if !figure.outgoingRelationships.isEmpty { parts.append("\(figure.outgoingRelationships.count) relationships") }
        if !figure.incomingRelationships.isEmpty { parts.append("\(figure.incomingRelationships.count) incoming") }
        if !figure.alternateNames.isEmpty { parts.append("\(figure.alternateNames.count) names") }
        if !figure.placeAssociations.isEmpty { parts.append("\(figure.placeAssociations.count) places") }
        if !figure.events.isEmpty { parts.append("\(figure.events.count) events") }
        if !figure.groupAssociations.isEmpty { parts.append("\(figure.groupAssociations.count) groups") }
        if figure.mugshotImage != nil { parts.append("mugshot") }
        return parts.isEmpty ? "No linked data" : parts.joined(separator: " · ")
    }

    private func summary(for place: Place) -> String {
        var parts: [String] = []
        if !place.figureAssociations.isEmpty { parts.append("\(place.figureAssociations.count) figures") }
        if !place.eventAssociations.isEmpty { parts.append("\(place.eventAssociations.count) events") }
        if !place.alternateNames.isEmpty { parts.append("\(place.alternateNames.count) names") }
        if !place.groupAssociations.isEmpty { parts.append("\(place.groupAssociations.count) groups") }
        return parts.isEmpty ? "No linked data" : parts.joined(separator: " · ")
    }

    private func summary(for event: Event) -> String {
        var parts: [String] = []
        if !(event.figureAssociations ?? []).isEmpty || !event.involvedFigures.isEmpty {
            parts.append("\(event.involvedFigures.count + (event.figureAssociations ?? []).count) figures")
        }
        if !event.placeAssociations.isEmpty { parts.append("\(event.placeAssociations.count) places") }
        if !event.groupAssociations.isEmpty { parts.append("\(event.groupAssociations.count) groups") }
        return parts.isEmpty ? "No linked data" : parts.joined(separator: " · ")
    }

    private func summary(for thing: Thing) -> String {
        var parts: [String] = []
        if !thing.figureAssociations.isEmpty { parts.append("\(thing.figureAssociations.count) figures") }
        if !thing.placeAssociations.isEmpty { parts.append("\(thing.placeAssociations.count) places") }
        if !thing.eventAssociations.isEmpty { parts.append("\(thing.eventAssociations.count) events") }
        if !thing.groupAssociations.isEmpty { parts.append("\(thing.groupAssociations.count) groups") }
        return parts.isEmpty ? "No linked data" : parts.joined(separator: " · ")
    }

    private func kindIcon(_ kind: DuplicateGroup.EntityKind) -> String {
        switch kind {
        case .figure: return "person.3"
        case .place: return "building.columns"
        case .event: return "bolt.fill"
        case .thing: return "cube.box"
        }
    }
}
