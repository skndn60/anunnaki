import SwiftUI
import SwiftData

struct FromTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var input = ""
    @State private var result: FromTextResult?
    @State private var lastRecord: FromTextApplyRecord?
    @State private var undoError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add from Text")
                .font(.title2.bold())

            Text("Paste a description of a figure. The structured fields below will be filled in; the full clip is kept as the description. Examples:")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("\u{2022} Marduk is the son of Enki and Damkina, consort of Sarpanit, patron of Babylon")
                Text("\u{2022} Sarpanit, also known as Zarpanitum, the chief goddess of Babylon")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            TextEditor(text: $input)
                .font(.body)
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator, lineWidth: 0.5)
                )

            if let lastRecord {
                addedBanner(lastRecord)
            } else if let result {
                preview(result)
            } else {
                Text("Type something above to see what will be created.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 120)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                if lastRecord != nil {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Add") {
                        apply(result)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(result == nil || result?.subject.isEmpty == true)
                }
            }
        }
        .padding(20)
        .frame(width: 560)
        .alert("Could not undo", isPresented: $undoError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The data this add created could not be found, so nothing was removed.")
        }
        .onChange(of: input) { _, _ in
            result = FromTextParser.parse(input)
        }
    }

    @ViewBuilder
    private func addedBanner(_ record: FromTextApplyRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Added \(record.subject)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text("If this looks wrong, you can undo it. The add is also listed under the history panel (clock icon in the toolbar) in case you want to revert it later.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Undo This Add") {
                undo(record)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func preview(_ result: FromTextResult) -> some View {
        let summary = summaryItems(result)
        if summary.isEmpty {
            Text("Nothing recognized yet.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 120)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Will be added: \(result.subject)", systemImage: "person.crop.circle.badge.plus")
                    .font(.headline)
                Divider()
                ForEach(summary, id: \.0) { section, lines in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        ForEach(lines, id: \.self) { line in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text(line)
                                    .font(.callout)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !result.description.isEmpty {
                    Divider()
                    Text("Description: full pasted text is stored on the figure.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func summaryItems(_ result: FromTextResult) -> [(String, [String])] {
        var sections: [(String, [String])] = []

        var figure: [String] = []
        switch result.gender {
        case .male: figure.append("Gender: Male")
        case .female: figure.append("Gender: Female")
        case .unknown: figure.append("Gender: Unknown")
        }
        if let kind = result.figureKind.figureTypeName { figure.append("Type: \(kind)") }
        if let title = result.title { figure.append("Title: \(title.capitalized)") }
        if let domain = result.domain { figure.append("Domain: \(domain)") }
        if let by = result.birthYear { figure.append("Birth: \(formatYear(by))") }
        if let dy = result.deathYear { figure.append("Death: \(formatYear(dy))") }
        if let rs = result.reignStart, let re = result.reignEnd {
            figure.append("Reign: \(formatYear(rs)) \u{2013} \(formatYear(re))")
        }
        if !figure.isEmpty { sections.append(("Figure", figure)) }

        var family: [String] = []
        for rel in result.parents {
            family.append("\(rel.relationshipType): \(rel.fromFigure)")
        }
        for rel in result.otherRelationships {
            let arrow = rel.isPreferred ? " (preferred)" : ""
            family.append("\(rel.relationshipType): \(rel.fromFigure) \u{2192} \(rel.toFigure)\(arrow)")
        }
        if !family.isEmpty { sections.append(("Family & Relationships", family)) }

        var places: [String] = []
        for link in result.placeLinks {
            places.append("\(link.roleName) of \(link.place)")
        }
        if !places.isEmpty { sections.append(("Place Links", places)) }

        if !result.alternateNames.isEmpty {
            sections.append(("Alternate Names", result.alternateNames))
        }
        if !result.newFigures.isEmpty {
            sections.append(("New Figures (created on add)", result.newFigures.sorted()))
        }
        if !result.newPlaces.isEmpty {
            sections.append(("New Places (created on add)", result.newPlaces.sorted()))
        }
        return sections
    }

    private func formatYear(_ year: Int) -> String {
        if year < 0 { return "\(abs(year)) BCE" }
        return "\(year) CE"
    }

    private func apply(_ result: FromTextResult?) {
        guard let result else { return }
        guard let record = FromTextRecognizer.apply(result, in: modelContext) else { return }
        FromTextLog.append(record)
        try? modelContext.save()
        input = ""
        self.result = nil
        lastRecord = record
    }

    private func undo(_ record: FromTextApplyRecord) {
        let report = FromTextRecognizer.revert(record, in: modelContext)
        try? modelContext.save()
        if report.deletedFigures.isEmpty, report.deletedPlaces.isEmpty,
           report.deletedRelationships == 0, report.deletedPlaceLinks == 0,
           report.deletedAlternateNames == 0, report.restoredMutations.isEmpty {
            undoError = true
        } else {
            FromTextLog.markReverted(id: record.id)
            lastRecord = nil
        }
    }
}

