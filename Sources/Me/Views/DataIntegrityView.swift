import SwiftUI
import SwiftData

final class DataIntegrityScanStore: ObservableObject {
    @Published var rows: [FindingRow] = []
    @Published var dismissalCount = 0
    static let shared = DataIntegrityScanStore()

    var issueRows: [FindingRow] { rows.filter { $0.record.entityKind.isEmpty } }
    var contentRows: [FindingRow] { rows.filter { !$0.record.entityKind.isEmpty } }
}

struct FindingRow: Identifiable {
    let record: IntegrityFinding
    /// Present when the underlying problem still exists and can be repaired
    /// in one click; nil after relaunch until the problem is re-detected.
    let fixAction: ((ModelContext) -> Void)?

    var id: PersistentIdentifier { record.persistentModelID }
}

struct DataIntegrityView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var store = DataIntegrityScanStore.shared
    @State private var isScanning = false
    var coordinator: NavigationCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Integrity")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Structural checks (orphaned associations, broken propagation, duplicate memberships) plus content-consistency checks: gender vs wording, role genders, parent cycles, date logic, era references, ambiguous aliases. Results persist until fixed or dismissed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.dismissalCount > 0 {
                    Button("Clear Dismissals (\(store.dismissalCount))") { clearDismissals() }
                        .buttonStyle(.bordered)
                }
                Button("Scan") { scan() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning)
            }
            .padding()

            Divider()

            if isScanning {
                ProgressView("Scanning…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.rows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("No outstanding findings")
                        .font(.headline)
                    Text("Run Scan to check the database.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.issueRows) { row in
                        issueRow(row)
                    }

                    if !store.contentRows.isEmpty {
                        Section("Content Consistency (\(store.contentRows.count))") {
                            ForEach(store.contentRows) { row in
                                findingRow(row)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            refreshDismissalCount()
            if store.rows.isEmpty { restoreQueue() }
        }
    }

    private func issueRow(_ row: FindingRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: severityIcon(row))
                .foregroundStyle(severityColor(row))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.record.entityKey)
                    .font(.callout)
                Text(row.record.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let action = row.fixAction {
                Button("Fix") { fix(row, action: action) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Button("Dismiss") { dismiss(row) }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func findingRow(_ row: FindingRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: severityIcon(row))
                .foregroundStyle(severityColor(row))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(row.record.entityKind): \(row.record.entityKey)")
                    .font(.callout)
                Text(row.record.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if row.record.entityKind == "Figure",
               let figure = figure(named: row.record.entityKey) {
                Button("Open") {
                    coordinator?.navigateToFigure(figure.persistentModelID, name: figure.name)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            Button("Dismiss") { dismiss(row) }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func figure(named name: String) -> Figure? {
        let fetch = FetchDescriptor<Figure>(predicate: #Predicate { $0.name == name })
        return try? modelContext.fetch(fetch).first
    }

    private func severityIcon(_ row: FindingRow) -> String {
        if row.record.entityKind.isEmpty,
           let kind = IntegrityIssue.IssueKind(rawValue: row.record.kindRaw.droppingPrefix("issue.")) {
            return IntegrityIssue(kind: kind, title: "", description: "", isFixable: false, fixAction: nil).severityIcon
        }
        return ConsistencyFinding.Severity(rawValue: row.record.severityRaw)?.icon ?? "info.circle.fill"
    }

    private func severityColor(_ row: FindingRow) -> Color {
        if row.record.entityKind.isEmpty,
           let kind = IntegrityIssue.IssueKind(rawValue: row.record.kindRaw.droppingPrefix("issue.")) {
            return IntegrityIssue(kind: kind, title: "", description: "", isFixable: false, fixAction: nil).severityColor
        }
        return row.record.severityRaw == "warning" ? Color.orange : Color.blue
    }

    private func scan() {
        isScanning = true
        Task { @MainActor in
            let freshIssues = computeIssues()
            let freshFindings = computeFindings()
            let dismissed = dismissedSignatures()

            replaceRecords(with: freshIssues.map { issue in
                IntegrityFinding(
                    kindRaw: "issue.\(issue.kind.rawValue)", severityRaw: "",
                    entityKind: "", entityKey: issue.title, detail: issue.description
                )
            } + freshFindings.map { finding in
                IntegrityFinding(
                    kindRaw: finding.kind.rawValue, severityRaw: finding.severity.rawValue,
                    entityKind: finding.entityKind, entityKey: finding.entityName, detail: finding.message
                )
            }.filter { !dismissed.contains($0.signature) })

            var actions: [String: (ModelContext) -> Void] = [:]
            for issue in freshIssues {
                if let action = issue.fixAction {
                    actions["issue.\(issue.kind.rawValue)|\(issue.title)"] = action
                }
            }
            store.rows = fetchRecords().map { record in
                FindingRow(record: record, fixAction: actions[record.signature])
            }
            refreshDismissalCount()
            isScanning = false
        }
    }

    /// Rebuilds the visible queue from persisted records (launch or navigation).
    /// Fix actions are relinked where the problem still exists; rows whose data
    /// was already repaired keep their Dismiss-only state instead of vanishing.
    private func restoreQueue() {
        let records = fetchRecords()
        guard !records.isEmpty else { return }
        Task { @MainActor in
            var actions: [String: (ModelContext) -> Void] = [:]
            for issue in computeIssues() {
                if let action = issue.fixAction {
                    actions["issue.\(issue.kind.rawValue)|\(issue.title)"] = action
                }
            }
            store.rows = records.map { record in
                FindingRow(record: record, fixAction: actions[record.signature])
            }
        }
    }

    private func computeIssues() -> [IntegrityIssue] {
        var found: [IntegrityIssue] = []

        let allAssocs = (try? modelContext.fetch(FetchDescriptor<FigureGroupAssociation>())) ?? []

        let emptyEntities = allAssocs.filter { $0.figure == nil && $0.place == nil && $0.event == nil && $0.thing == nil }
        for assoc in emptyEntities {
            let groupName = assoc.group?.name ?? "(orphaned)"
            found.append(IntegrityIssue(
                kind: .emptyEntity,
                title: "Empty association in \"\(groupName)\"",
                description: "This association has no linked entity.",
                isFixable: true,
                fixAction: { context in
                    assoc.figure?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                    assoc.place?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                    assoc.event?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                    assoc.thing?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                    context.delete(assoc)
                }
            ))
        }

        let orphans = allAssocs.filter { $0.group == nil }
        for assoc in orphans {
            let entityName = assoc.figure?.name ?? assoc.place?.name ?? assoc.event?.name ?? assoc.thing?.name ?? "(unknown)"
            found.append(IntegrityIssue(
                kind: .orphaned,
                title: "Orphaned association: \(entityName)",
                description: "This association has no group.",
                isFixable: true,
                fixAction: { context in
                    assoc.figure?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                    assoc.place?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                    assoc.event?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                    assoc.thing?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                    context.delete(assoc)
                }
            ))
        }

        let propageted = allAssocs.filter { $0.propagatedFromEventName != nil }
        for assoc in propageted {
            guard let sourceName = assoc.propagatedFromEventName else { continue }
            let sourceExists = (try? modelContext.fetch(FetchDescriptor<Event>(predicate: #Predicate { $0.name == sourceName })))?.first != nil
            if !sourceExists {
                let entityName = assoc.figure?.name ?? assoc.place?.name ?? assoc.thing?.name ?? "?"
                found.append(IntegrityIssue(
                    kind: .brokenPropagation,
                    title: "Broken propagation link: \(entityName)",
                    description: "The source event \"\(sourceName)\" no longer exists.",
                    isFixable: true,
                    fixAction: { context in
                        assoc.propagatedFromEventName = nil
                    }
                ))
            }
        }

        let allRelationships = (try? modelContext.fetch(FetchDescriptor<Relationship>())) ?? []
        let parentKeywords = ["father", "mother", "parent"]
        for rel in allRelationships {
            guard let from = rel.fromFigure, rel.toFigure === from,
                  let typeName = rel.relationshipType?.name,
                  parentKeywords.contains(where: { typeName.lowercased() == $0 }) else { continue }
            found.append(IntegrityIssue(
                kind: .selfParentEdge,
                title: "Self-referential parent edge: \(from.name)",
                description: "\(from.name) is listed as their own \(typeName.lowercased()). Deleting this relationship resolves the contradiction.",
                isFixable: true,
                fixAction: { context in
                    from.outgoingRelationships.removeAll { $0.persistentModelID == rel.persistentModelID }
                    from.incomingRelationships.removeAll { $0.persistentModelID == rel.persistentModelID }
                    context.delete(rel)
                }
            ))
        }

        var seen = Set<String>()
        for assoc in allAssocs {
            guard let groupID = assoc.group?.persistentModelID else { continue }
            let entityKey: String
            if let fig = assoc.figure { entityKey = "fig:\(fig.persistentModelID):\(groupID)" }
            else if let place = assoc.place { entityKey = "place:\(place.persistentModelID):\(groupID)" }
            else if let event = assoc.event { entityKey = "event:\(event.persistentModelID):\(groupID)" }
            else if let thing = assoc.thing { entityKey = "thing:\(thing.persistentModelID):\(groupID)" }
            else { continue }

            if !seen.insert(entityKey).inserted {
                let entityName = assoc.figure?.name ?? assoc.place?.name ?? assoc.event?.name ?? assoc.thing?.name ?? "?"
                let groupName = assoc.group?.name ?? "?"
                found.append(IntegrityIssue(
                    kind: .duplicate,
                    title: "Duplicate membership: \(entityName) in \"\(groupName)\"",
                    description: "This entity appears more than once in the same group.",
                    isFixable: false,
                    fixAction: nil
                ))
            }
        }

        return found
    }

    private func computeFindings() -> [ConsistencyFinding] {
        let allFigures = (try? modelContext.fetch(FetchDescriptor<Figure>())) ?? []
        let allRelationships = (try? modelContext.fetch(FetchDescriptor<Relationship>())) ?? []
        let allAlternateNames = (try? modelContext.fetch(FetchDescriptor<AlternateName>())) ?? []
        let allEvents = (try? modelContext.fetch(FetchDescriptor<Event>())) ?? []
        let allEras = (try? modelContext.fetch(FetchDescriptor<Era>())) ?? []
        return ConsistencyEngine.runAll(
            figures: allFigures,
            relationships: allRelationships,
            alternateNames: allAlternateNames,
            events: allEvents,
            eras: allEras
        ).filter { finding in
            !(finding.kind == .parentCycle && !finding.entityName.contains("↔"))
        }
    }

    private func fetchRecords() -> [IntegrityFinding] {
        (try? modelContext.fetch(FetchDescriptor<IntegrityFinding>())) ?? []
    }

    private func replaceRecords(with newRecords: [IntegrityFinding]) {
        for existing in fetchRecords() { modelContext.delete(existing) }
        for record in newRecords { modelContext.insert(record) }
        try? modelContext.save()
    }

    private func fix(_ row: FindingRow, action: @escaping (ModelContext) -> Void) {
        action(modelContext)
        modelContext.delete(row.record)
        try? modelContext.save()
        store.rows.removeAll { $0.id == row.id }
    }

    private func dismiss(_ row: FindingRow) {
        modelContext.insert(FindingDismissal(kindRaw: row.record.kindRaw, entityKey: row.record.entityKey))
        modelContext.delete(row.record)
        try? modelContext.save()
        store.rows.removeAll { $0.id == row.id }
        refreshDismissalCount()
    }

    private func clearDismissals() {
        let all = (try? modelContext.fetch(FetchDescriptor<FindingDismissal>())) ?? []
        for dismissal in all { modelContext.delete(dismissal) }
        try? modelContext.save()
        store.dismissalCount = 0
    }

    private func dismissedSignatures() -> Set<String> {
        Set(((try? modelContext.fetch(FetchDescriptor<FindingDismissal>())) ?? []).map(\.signature))
    }

    private func refreshDismissalCount() {
        store.dismissalCount = (try? modelContext.fetchCount(FetchDescriptor<FindingDismissal>())) ?? 0
    }
}

struct IntegrityIssue: Identifiable {
    let id = UUID()
    let kind: IssueKind
    let title: String
    let description: String
    let isFixable: Bool
    let fixAction: ((ModelContext) -> Void)?

    enum IssueKind: String {
        case emptyEntity
        case orphaned
        case brokenPropagation
        case duplicate
        case selfParentEdge
    }

    var severityIcon: String {
        switch kind {
        case .emptyEntity, .orphaned, .selfParentEdge: return "exclamationmark.triangle.fill"
        case .brokenPropagation: return "link.badge.xmark"
        case .duplicate: return "doc.on.doc.fill"
        }
    }

    var severityColor: Color {
        switch kind {
        case .emptyEntity, .orphaned, .selfParentEdge: return .orange
        case .brokenPropagation: return .red
        case .duplicate: return .blue
        }
    }
}

private extension String {
    func droppingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
