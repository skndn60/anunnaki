import SwiftUI
import SwiftData

/// History of every "Add from Text" operation, with per-entry revert.
struct FromTextHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var records: [FromTextApplyRecord] = FromTextLog.load()
    @State private var pendingRevert: FromTextApplyRecord?
    @State private var lastReport: FromTextRevertReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add from Text History")
                .font(.title2.bold())

            Text("Every add made from pasted text is listed here. If an add produced wrong data, select it and revert \u{2014} only the figures, places, and links that add created are removed.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if records.isEmpty {
                Text("No adds yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(records) { record in
                            row(record)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let lastReport {
                Label(lastReport.summary, systemImage: "arrow.uturn.backward.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 620, height: 460)
        .confirmationDialog(
            "Revert this add?",
            isPresented: Binding(
                get: { pendingRevert != nil },
                set: { if !$0 { pendingRevert = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Revert", role: .destructive) {
                if let record = pendingRevert {
                    performRevert(record)
                }
                pendingRevert = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(revertMessage)
        }
    }

    @ViewBuilder
    private func row(_ record: FromTextApplyRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(record.subject, systemImage: "person.crop.circle.badge.plus")
                    .font(.headline)
                Spacer()
                if record.revertedAt != nil {
                    Label("Reverted", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Revert") {
                        pendingRevert = record
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(contents(of: record))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func contents(of record: FromTextApplyRecord) -> String {
        var parts: [String] = []
        if !record.createdFigureNames.isEmpty { parts.append("\(record.createdFigureNames.count) figure(s)") }
        if !record.createdPlaceNames.isEmpty { parts.append("\(record.createdPlaceNames.count) place(s)") }
        if !record.relationships.isEmpty { parts.append("\(record.relationships.count) relationship(s)") }
        if !record.placeLinks.isEmpty { parts.append("\(record.placeLinks.count) place link(s)") }
        if !record.alternateNames.isEmpty { parts.append("\(record.alternateNames.count) alternate name(s)") }
        if !record.figureMutations.isEmpty { parts.append("updated \(record.figureMutations.count) existing figure(s)") }
        return parts.isEmpty ? "No data recorded." : parts.joined(separator: ", ")
    }

    private var revertMessage: String {
        guard let record = pendingRevert else { return "" }
        return "This will remove what the add created: \(contents(of: record)). Figures or places that have since been given other data will be kept."
    }

    private func performRevert(_ record: FromTextApplyRecord) {
        let report = FromTextRecognizer.revert(record, in: modelContext)
        try? modelContext.save()
        FromTextLog.markReverted(id: record.id)
        records = FromTextLog.load()
        lastReport = report
    }
}
