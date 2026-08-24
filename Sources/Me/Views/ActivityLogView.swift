import SwiftUI
import SwiftData
import MeCore

struct ActivityLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityLogEntry.timestamp, order: .reverse) private var entries: [ActivityLogEntry]
    @State private var actionFilter: ActionFilter = .all
    @State private var userFilter: String = ""
    @State private var searchText = ""

    enum ActionFilter: String, CaseIterable {
        case all = "All"
        case created = "Created"
        case updated = "Updated"
        case deleted = "Deleted"

        var matches: ActivityAction? {
            switch self {
            case .all: return nil
            case .created: return .created
            case .updated: return .updated
            case .deleted: return .deleted
            }
        }
    }

    private var distinctUserNames: [String] {
        Array(Set(entries.map(\.displayUserName))).sorted()
    }

    private var filteredEntries: [ActivityLogEntry] {
        entries.filter { entry in
            if let action = actionFilter.matches, entry.actionType != action { return false }
            if !userFilter.isEmpty && entry.displayUserName != userFilter { return false }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                if !entry.linkedEntityName.lowercased().contains(query) &&
                    !entry.entityType.lowercased().contains(query) &&
                    !entry.displayUserName.lowercased().contains(query) &&
                    !entry.details.lowercased().contains(query) {
                    return false
                }
            }
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("Activity Log")
                    .font(.title2.bold())
                Spacer()
                TextField("Search\u{2026}", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Picker("Action", selection: $actionFilter) {
                    ForEach(ActionFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .frame(width: 130)
                Picker("User", selection: $userFilter) {
                    Text("All Users").tag("")
                    ForEach(distinctUserNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .frame(width: 150)
                Button(action: clearLog) {
                    Image(systemName: "trash")
                }
                .help("Clear the activity log")
            }
            .padding()

            Divider()

            if filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(entries.isEmpty ? "No activity recorded yet." : "No entries match the filters.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(filteredEntries, id: \.persistentModelID) { entry in
                    ActivityLogRow(entry: entry)
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds()
            }
        }
    }

    private func clearLog() {
        for entry in entries {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

private struct ActivityLogRow: View {
    let entry: ActivityLogEntry

    private var actionIcon: String {
        switch entry.actionType {
        case .created: return "plus.circle.fill"
        case .updated: return "pencil.circle.fill"
        case .deleted: return "trash.circle.fill"
        case nil: return "circle.dotted"
        }
    }

    private var actionColor: Color {
        switch entry.actionType {
        case .created: return .green
        case .updated: return .orange
        case .deleted: return .red
        case nil: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: actionIcon)
                .foregroundStyle(actionColor)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.displayUserName).fontWeight(.medium)
                    Text(entry.actionType?.displayLabel ?? entry.action).foregroundStyle(.secondary)
                    Text(entry.linkedEntityName).fontWeight(.medium)
                    Text("(\(entry.entityType))").foregroundStyle(.secondary)
                }
                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.timestamp, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
