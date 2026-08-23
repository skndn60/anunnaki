import SwiftUI
import SwiftData

struct DataIntegrityView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var issues: [IntegrityIssue] = []
    @State private var findings: [ConsistencyFinding] = []
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Integrity")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Structural checks (orphaned associations, broken propagation, duplicate memberships) plus content-consistency checks: gender vs wording, role genders, parent cycles, date logic, era references, ambiguous aliases.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Scan") { scan() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning)
            }
            .padding()

            Divider()

            if isScanning {
                ProgressView("Scanning…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if issues.isEmpty && findings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("All clear")
                        .font(.headline)
                    Text("No issues found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(issues) { issue in
                        HStack(spacing: 12) {
                            Image(systemName: issue.severityIcon)
                                .foregroundStyle(issue.severityColor)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.title)
                                    .font(.callout)
                                Text(issue.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if issue.isFixable {
                                Button("Fix") { fix(issue) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if !findings.isEmpty {
                        Section("Content Consistency (\(findings.count))") {
                            ForEach(findings) { finding in
                                HStack(spacing: 12) {
                                    Image(systemName: finding.severity.icon)
                                        .foregroundStyle(finding.severity == .warning ? Color.orange : Color.blue)
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(finding.entityKind): \(finding.entityName)")
                                            .font(.callout)
                                        Text(finding.message)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func scan() {
        isScanning = true
        issues = []
        findings = []

        Task { @MainActor in
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

            let allFigures = (try? modelContext.fetch(FetchDescriptor<Figure>())) ?? []
            let allAlternateNames = (try? modelContext.fetch(FetchDescriptor<AlternateName>())) ?? []
            let allEvents = (try? modelContext.fetch(FetchDescriptor<Event>())) ?? []
            let allEras = (try? modelContext.fetch(FetchDescriptor<Era>())) ?? []
            findings = ConsistencyEngine.runAll(
                figures: allFigures,
                relationships: allRelationships,
                alternateNames: allAlternateNames,
                events: allEvents,
                eras: allEras
            ).filter { finding in
                !(finding.kind == .parentCycle && !finding.entityName.contains("↔"))
            }

            issues = found
            isScanning = false
        }
    }

    private func fix(_ issue: IntegrityIssue) {
        guard let action = issue.fixAction else { return }
        action(modelContext)
        try? modelContext.save()
        issues.removeAll { $0.id == issue.id }
    }
}

private struct IntegrityIssue: Identifiable {
    let id = UUID()
    let kind: IssueKind
    let title: String
    let description: String
    let isFixable: Bool
    let fixAction: ((ModelContext) -> Void)?

    enum IssueKind {
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
