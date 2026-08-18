import SwiftUI
import SwiftData

/// Section showing comparison tables a figure belongs to.
struct ComparisonTablesSection: View {
    let figure: Figure
    @Binding var showingPopupTableGrid: PopupTable?

    var body: some View {
        let tables = figure.popupTableCells.compactMap(\.table)
        let uniqueTables = Array(Set(tables.map(\.persistentModelID))).compactMap { id in
            tables.first { $0.persistentModelID == id }
        }.sorted { $0.name < $1.name }

        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Comparison Tables")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }

            if uniqueTables.isEmpty {
                Text("Not in any comparison table")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(uniqueTables) { table in
                    Button(action: { showingPopupTableGrid = table }) {
                        HStack(spacing: 8) {
                            Image(systemName: "tablecells")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 16)
                            Text(table.name)
                                .font(.callout)
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}