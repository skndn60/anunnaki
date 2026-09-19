import SwiftUI
import SwiftData

private struct FigureMergeDisplay: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let disambiguation: String
    let typeName: String
    let typeColor: Color
    let typeIcon: String
}

/// Merges the currently-viewed figure into a chosen keeper. The viewed figure
/// becomes the duplicate (deleted); every link and piece of content folds into
/// the keeper. All candidate rows are precomputed value snapshots so the sheet
/// never faults a live `Figure` during a layout pass.
struct FigureMergeSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.userSession) private var userSession

    let duplicate: Figure
    var onMergeComplete: ((PersistentIdentifier) -> Void)?

    @Query private var figures: [Figure]

    @State private var duplicateInfo: FigureMergeDisplay?
    @State private var candidates: [FigureMergeDisplay] = []
    @State private var searchText = ""
    @State private var selectedKeeperID: PersistentIdentifier?
    @State private var isMerging = false
    @State private var errorMessage: String?
    @State private var confirmMerge = false

    private var visibleCandidates: [FigureMergeDisplay] {
        guard !searchText.isEmpty else { return candidates }
        return candidates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectedKeeperName: String {
        guard let id = selectedKeeperID else { return "" }
        return candidates.first { $0.id == id }?.name ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Merge \u{201C}\(duplicateInfo?.name ?? "Figure")\u{201D} Into\u{2026}")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }

            Text("Links, alternate names, and content from this figure will fold into the chosen keeper, then it is deleted. This cannot be undone.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search figures\u{2026}", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if duplicateInfo == nil {
                Spacer()
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else if candidates.isEmpty {
                Spacer()
                Text("No other figures to merge into.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                List(selection: $selectedKeeperID) {
                    ForEach(visibleCandidates) { candidate in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(candidate.typeColor)
                                .frame(width: 8, height: 8)
                            Image(systemName: candidate.typeIcon)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            Text(candidate.name)
                                .lineLimit(1)
                            if !candidate.disambiguation.isEmpty {
                                Text(candidate.disambiguation)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if !candidate.typeName.isEmpty {
                                Text(candidate.typeName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(candidate.id)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            HStack {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Merge Into \(selectedKeeperName)") {
                    confirmMerge = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(selectedKeeperID == nil || isMerging)
            }
        }
        .padding()
        .frame(width: 460, height: 480)
        .task { load() }
        .alert("Merge Figures?", isPresented: $confirmMerge) {
            Button("Merge", role: .destructive) { performMerge() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\u{201C}\(duplicateInfo?.name ?? "This figure")\u{201D} will be merged into \u{201C}\(selectedKeeperName)\u{201D} and deleted.")
        }
    }

    private func load() {
        guard duplicateInfo == nil else { return }
        duplicateInfo = FigureMergeDisplay(
            id: duplicate.persistentModelID,
            name: duplicate.name,
            disambiguation: duplicate.disambiguation ?? "",
            typeName: duplicate.figureType?.name ?? "",
            typeColor: duplicate.figureType?.color ?? .gray,
            typeIcon: duplicate.figureType?.icon ?? "person.fill"
        )
        candidates = figures
            .filter { $0.persistentModelID != duplicate.persistentModelID }
            .map { figure in
                FigureMergeDisplay(
                    id: figure.persistentModelID,
                    name: figure.name,
                    disambiguation: figure.disambiguation ?? "",
                    typeName: figure.figureType?.name ?? "",
                    typeColor: figure.figureType?.color ?? .gray,
                    typeIcon: figure.figureType?.icon ?? "person.fill"
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if let first = candidates.first, selectedKeeperID == nil {
            selectedKeeperID = first.id
        }
    }

    private func performMerge() {
        guard let keeperID = selectedKeeperID else { return }
        isMerging = true
        defer { isMerging = false }
        guard let keeper = modelContext.model(for: keeperID) as? Figure,
              let duplicate = modelContext.model(for: duplicate.persistentModelID) as? Figure else {
            errorMessage = "A figure could not be resolved. Try again."
            return
        }
        do {
            let duplicateName = duplicate.name
            let keeperName = keeper.name
            try DuplicateMerger.mergeFigures(keeper, duplicate, in: modelContext)
            try modelContext.save()
            ActivityLogger.record(
                action: .updated,
                entityType: "Figure",
                entityName: keeperName,
                details: "Merged \u{201C}\(duplicateName)\u{201D} into this figure",
                context: modelContext,
                session: userSession
            )
            onMergeComplete?(keeperID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}