import SwiftUI
import SwiftData

final class DataIntegrityScanStore: ObservableObject {
    @Published var rows: [FindingRow] = []
    @Published var dismissalCount = 0
    static let shared = DataIntegrityScanStore()
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
    @State private var scanDate: Date?
    @State private var descriptionEditFigure: Figure?
    @State private var wizardFigure: Figure?
    @State private var editPlace: Place?
    @State private var editEvent: Event?
    @State private var editThing: Thing?
    @State private var showDuplicateMergeSheet = false
    @State private var collapsedSections: Set<String> = []
    @State private var selectedRowID: PersistentIdentifier?
    var coordinator: NavigationCoordinator?

    private static let collapsedKey = "dataIntegrityCollapsedCategories"

    private var groupedRows: [(category: String, rows: [FindingRow])] {
        let all = store.rows
        guard !all.isEmpty else { return [] }
        var buckets: [String: [FindingRow]] = [:]
        for row in all {
            let cat = Self.category(for: row)
            buckets[cat, default: []].append(row)
        }
        return Self.categoryOrder.compactMap { cat in
            guard let rows = buckets[cat], !rows.isEmpty else { return nil }
            return (cat, rows)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 540, minHeight: 440)
        .onAppear {
            refreshDismissalCount()
            collapsedSections = Set(UserDefaults.standard.stringArray(forKey: Self.collapsedKey) ?? [])
            if store.rows.isEmpty { restoreQueue() }
        }
        .sheet(item: $descriptionEditFigure) { figure in
            QueueDescriptionEditor(figure: figure)
        }
        .sheet(item: $wizardFigure) { figure in
            FigureFormView(figure: figure)
        }
        .sheet(item: $editPlace) { place in
            PlaceFormView(place: place)
        }
        .sheet(item: $editEvent) { event in
            EventFormView(event: event)
        }
        .sheet(item: $editThing) { thing in
            ThingFormView(thing: thing)
        }
        .sheet(isPresented: $showDuplicateMergeSheet) {
            DuplicateMergeView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if let date = scanDate {
                    Text("Data Integrity on \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.title2)
                        .fontWeight(.semibold)
                } else {
                    Text("Data Integrity")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                if !store.rows.isEmpty {
                    Text("\(store.rows.count) issue\(store.rows.count == 1 ? "" : "s") detected. See details below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !isScanning {
                    Text("Run Scan to check the database.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !groupedRows.isEmpty {
                let allCollapsed = groupedRows.allSatisfy { collapsedSections.contains($0.category) }
                Button(allCollapsed ? "Expand All" : "Collapse All") { toggleAllSections() }
                    .buttonStyle(.bordered)
            }
            if store.dismissalCount > 0 {
                Button("Clear Dismissals (\(store.dismissalCount))") { clearDismissals() }
                    .buttonStyle(.bordered)
            }
            Button("Scan") { scan() }
                .buttonStyle(.borderedProminent)
                .disabled(isScanning)
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isScanning {
            ProgressView("Scanning\u{2026}")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.rows.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("No issues detected")
                    .font(.headline)
                Text("All checks passed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groupedRows, id: \.category) { section in
                        collapsibleSection(section.category, rows: section.rows)
                    }
                }
            }
        }
    }

    // MARK: - Collapsible section

    private func collapsibleSection(_ category: String, rows: [FindingRow]) -> some View {
        let isCollapsed = collapsedSections.contains(category)
        let count = rows.count
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isCollapsed { collapsedSections.remove(category) }
                    else { collapsedSections.insert(category) }
                    persistCollapsed()
                }
            } label: {
                HStack {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Text(category)
                        .font(.headline)
                    Text("(\(count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                Divider().padding(.leading, 40)
                ForEach(rows) { row in
                    findingRow(row)
                    if row.id != rows.last?.id {
                        Divider().padding(.leading, 40)
                    }
                }
            }

            Divider()
        }
    }

    // MARK: - Row rendering

    private func findingRow(_ row: FindingRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: severityIcon(row))
                .foregroundStyle(severityColor(row))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                if row.record.entityKind.isEmpty {
                    Text(row.record.entityKey)
                        .font(.callout)
                } else {
                    Text("\(row.record.entityKind): \(row.record.entityKey)")
                        .font(.callout)
                }
                Text(row.record.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if row.record.kindRaw == "issue.duplicateName" {
                Button("Merge\u{2026}") { showDuplicateMergeSheet = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            if let action = row.fixAction {
                Button("Fix") { fix(row, action: action) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Menu {
                entityMenuItems(for: row)
                Divider()
                Button("Copy Finding Text") { copyFinding(row.record.detail) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .fixedSize()
            Button("Dismiss") { dismiss(row) }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedRowID == row.id ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { selectedRowID = row.id }
        }
    }

    // MARK: - Category mapping

    private static let categoryOrder = [
        "Structural",
        "Relationship Consistency",
        "Content Consistency",
        "Data Completeness",
        "Temporal Logic",
        "Data Integrity",
    ]

    private static func category(for row: FindingRow) -> String {
        let raw = row.record.kindRaw
        if raw.hasPrefix("issue.") {
            let issueKind = raw.droppingPrefix("issue.")
            switch issueKind {
            case "emptyEntity", "orphaned", "brokenPropagation", "duplicate", "selfParentEdge", "duplicateName":
                return "Structural"
            default:
                return "Structural"
            }
        }
        guard let kind = ConsistencyFinding.Kind(rawValue: raw) else { return "Structural" }
        switch kind {
        case .pronounGender, .genderedNoun, .roleGender, .parentCycle,
             .invertedDates, .unknownEra, .ambiguousAlias, .stubFigure,
             .nameVariant, .aiDraftTable, .missingSpouseLink:
            return "Content Consistency"
        case .bidirectionalMismatch, .selfReferentialEdge, .duplicateEdge:
            return "Relationship Consistency"
        case .figureWithoutType, .figureWithoutDescription, .eventWithNoLinks, .placeWithoutCoordinates:
            return "Data Completeness"
        case .deathBeforeBirth, .reignOutsideLifespan, .childBornBeforeParent:
            return "Temporal Logic"
        case .orphanedAlternateName, .orphanedImageAsset, .sourceWithoutURL:
            return "Data Integrity"
        }
    }

    // MARK: - Helpers

    private func beginDescriptionEdit(_ row: FindingRow) {
        descriptionEditFigure = figure(named: row.record.entityKey)
    }

    private func copyFinding(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func figure(named name: String) -> Figure? {
        let fetch = FetchDescriptor<Figure>(predicate: #Predicate { $0.name == name })
        return try? modelContext.fetch(fetch).first
    }

    private func place(named name: String) -> Place? {
        let fetch = FetchDescriptor<Place>(predicate: #Predicate { $0.name == name })
        return try? modelContext.fetch(fetch).first
    }

    private func event(named name: String) -> Event? {
        let fetch = FetchDescriptor<Event>(predicate: #Predicate { $0.name == name })
        return try? modelContext.fetch(fetch).first
    }

    private func thing(named name: String) -> Thing? {
        let fetch = FetchDescriptor<Thing>(predicate: #Predicate { $0.name == name })
        return try? modelContext.fetch(fetch).first
    }

    @ViewBuilder
    private func entityMenuItems(for row: FindingRow) -> some View {
        let kind = row.record.entityKind
        let name = row.record.entityKey
        if kind == "Figure", let figure = figure(named: name) {
            Button("Edit Description\u{2026}") { beginDescriptionEdit(row) }
            Button("Open Edit Wizard\u{2026}") { wizardFigure = figure }
            Divider()
            Button("Open in Figures") {
                coordinator?.navigateToFigure(figure.persistentModelID, name: figure.name)
            }
        } else if kind == "Place", let place = place(named: name) {
            Button("Edit\u{2026}") { editPlace = place }
            Divider()
            Button("Open in Places") {
                coordinator?.navigateToPlace(place.persistentModelID, name: place.name)
            }
        } else if kind == "Event", let event = event(named: name) {
            Button("Edit\u{2026}") { editEvent = event }
            Divider()
            Button("Open in Events") {
                coordinator?.navigateToEvent(event.persistentModelID, name: event.name)
            }
        } else if kind == "Thing", let thing = thing(named: name) {
            Button("Edit\u{2026}") { editThing = thing }
            Divider()
            Button("Open in Things") {
                coordinator?.navigateToThing(thing.persistentModelID, name: thing.name)
            }
        }
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

    // MARK: - Scan

    private func persistCollapsed() {
        UserDefaults.standard.set(Array(collapsedSections), forKey: Self.collapsedKey)
    }

    private func toggleAllSections() {
        let visible = Set(groupedRows.map(\.category))
        let allCollapsed = groupedRows.allSatisfy { collapsedSections.contains($0.category) }
        withAnimation(.easeInOut(duration: 0.2)) {
            if allCollapsed {
                collapsedSections.subtract(visible)
            } else {
                collapsedSections.formUnion(visible)
            }
            persistCollapsed()
        }
    }

    private func scan() {
        isScanning = true
        scanDate = Date()
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

        if let duplicateGroups = try? DuplicateMerger.findGroups(in: modelContext) {
            for group in duplicateGroups {
                let kindLabel = group.kind.rawValue
                let count = group.ids.count
                found.append(IntegrityIssue(
                    kind: .duplicateName,
                    title: "Duplicate \(kindLabel.lowercased()) name: \"\(group.name)\" (\(count) copies)",
                    description: "Click Merge to combine \(count) \(kindLabel.lowercased())s named \"\(group.name)\" into one.",
                    isFixable: false,
                    fixAction: nil
                ))
            }
        }

        return found.filter { ConsistencyCheckSettings.isEnabled($0.kind) }
    }

    private func computeFindings() -> [ConsistencyFinding] {
        let allFigures = (try? modelContext.fetch(FetchDescriptor<Figure>())) ?? []
        let allRelationships = (try? modelContext.fetch(FetchDescriptor<Relationship>())) ?? []
        let allAlternateNames = (try? modelContext.fetch(FetchDescriptor<AlternateName>())) ?? []
        let allEvents = (try? modelContext.fetch(FetchDescriptor<Event>())) ?? []
        let allEras = (try? modelContext.fetch(FetchDescriptor<Era>())) ?? []
        let allPlaces = (try? modelContext.fetch(FetchDescriptor<Place>())) ?? []
        let allImageAssets = (try? modelContext.fetch(FetchDescriptor<ImageAsset>())) ?? []
        let allSources = (try? modelContext.fetch(FetchDescriptor<Source>())) ?? []
        let allPopupTables = (try? modelContext.fetch(FetchDescriptor<PopupTable>())) ?? []
        return ConsistencyEngine.runAll(
            figures: allFigures,
            relationships: allRelationships,
            alternateNames: allAlternateNames,
            events: allEvents,
            eras: allEras,
            places: allPlaces,
            imageAssets: allImageAssets,
            sources: allSources,
            popupTables: allPopupTables
        ).filter { finding in
            !(finding.kind == .parentCycle && !finding.entityName.contains("↔"))
        }.filter { finding in
            ConsistencyCheckSettings.isEnabled(finding.kind)
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

    enum IssueKind: String, CaseIterable {
        case emptyEntity
        case orphaned
        case brokenPropagation
        case duplicate
        case selfParentEdge
        case duplicateName

        var displayLabel: String {
            switch self {
            case .emptyEntity: return "Empty association"
            case .orphaned: return "Orphaned association"
            case .brokenPropagation: return "Broken propagation link"
            case .duplicate: return "Duplicate group membership"
            case .selfParentEdge: return "Self-referential parent"
            case .duplicateName: return "Duplicate name"
            }
        }

        var userDefaultsKey: String { "integrityIssue_\(rawValue)" }
    }

    var severityIcon: String {
        switch kind {
        case .emptyEntity, .orphaned, .selfParentEdge: return "exclamationmark.triangle.fill"
        case .brokenPropagation: return "link.badge.xmark"
        case .duplicate, .duplicateName: return "doc.on.doc.fill"
        }
    }

    var severityColor: Color {
        switch kind {
        case .emptyEntity, .orphaned, .selfParentEdge: return .orange
        case .brokenPropagation: return .red
        case .duplicate, .duplicateName: return .blue
        }
    }
}

private extension String {
    func droppingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}

private struct QueueDescriptionEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let figure: Figure
    @State private var richDescription: Data?
    @State private var plainDescription = ""
    @State private var loaded = false

    var body: some View {
        DescriptionEditorSheet(
            entityName: figure.name,
            richDescription: $richDescription,
            plainDescription: $plainDescription,
            onSave: {
                figure.richDescription = richDescription
                figure.figureDescription = plainDescription
                try? modelContext.save()
            }
        )
        .onAppear {
            guard !loaded else { return }
            loaded = true
            richDescription = figure.richDescription
            plainDescription = figure.figureDescription
        }
    }
}

// MARK: - Consistency Check Settings

struct ConsistencyCheckSetting: Identifiable {
    let id = UUID()
    let key: String
    let displayLabel: String
    let category: String
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum ConsistencyCheckSettings {
    static let masterKey = "consistencyChecksAllEnabled"

    static var masterEnabled: Bool {
        get { UserDefaults.standard.object(forKey: masterKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: masterKey) }
    }

    static func isEnabled(_ kind: ConsistencyFinding.Kind) -> Bool {
        guard masterEnabled else { return false }
        return UserDefaults.standard.object(forKey: kind.userDefaultsKey) as? Bool ?? true
    }

    static func isEnabled(_ kind: IntegrityIssue.IssueKind) -> Bool {
        guard masterEnabled else { return false }
        return UserDefaults.standard.object(forKey: kind.userDefaultsKey) as? Bool ?? true
    }

    static let findingCategories: [(category: String, checks: [ConsistencyCheckSetting])] = [
        ("Content Consistency", ConsistencyFinding.Kind.allCases.filter { kind in
            switch kind {
            case .pronounGender, .genderedNoun, .roleGender, .parentCycle,
                 .invertedDates, .unknownEra, .ambiguousAlias, .stubFigure,
                 .nameVariant, .aiDraftTable, .missingSpouseLink:
                return true
            default: return false
            }
        }.map { ConsistencyCheckSetting(key: $0.userDefaultsKey, displayLabel: $0.displayLabel, category: "Content Consistency") }),
        ("Relationship Consistency", [
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.bidirectionalMismatch.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.bidirectionalMismatch.displayLabel, category: "Relationship Consistency"),
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.selfReferentialEdge.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.selfReferentialEdge.displayLabel, category: "Relationship Consistency"),
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.duplicateEdge.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.duplicateEdge.displayLabel, category: "Relationship Consistency"),
        ]),
        ("Data Completeness", [
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.figureWithoutType.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.figureWithoutType.displayLabel, category: "Data Completeness"),
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.figureWithoutDescription.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.figureWithoutDescription.displayLabel, category: "Data Completeness"),
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.eventWithNoLinks.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.eventWithNoLinks.displayLabel, category: "Data Completeness"),
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.placeWithoutCoordinates.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.placeWithoutCoordinates.displayLabel, category: "Data Completeness"),
        ]),
        ("Temporal Logic", [
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.deathBeforeBirth.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.deathBeforeBirth.displayLabel, category: "Temporal Logic"),
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.reignOutsideLifespan.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.reignOutsideLifespan.displayLabel, category: "Temporal Logic"),
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.childBornBeforeParent.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.childBornBeforeParent.displayLabel, category: "Temporal Logic"),
        ]),
        ("Data Integrity", [
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.orphanedAlternateName.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.orphanedAlternateName.displayLabel, category: "Data Integrity"),
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.orphanedImageAsset.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.orphanedImageAsset.displayLabel, category: "Data Integrity"),
            ConsistencyCheckSetting(key: ConsistencyFinding.Kind.sourceWithoutURL.userDefaultsKey, displayLabel: ConsistencyFinding.Kind.sourceWithoutURL.displayLabel, category: "Data Integrity"),
        ]),
        ("Structural", IntegrityIssue.IssueKind.allCases.map {
            ConsistencyCheckSetting(key: $0.userDefaultsKey, displayLabel: $0.displayLabel, category: "Structural")
        }),
    ]
}
