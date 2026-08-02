import SwiftUI
import SwiftData

struct FromTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var input = ""
    @State private var result: FromTextResult?

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

            if let result {
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
                Button("Add") {
                    apply(result)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(result == nil || result?.subject.isEmpty == true)
            }
        }
        .padding(20)
        .frame(width: 560)
        .onChange(of: input) { _, _ in
            result = FromTextParser.parse(input)
        }
    }

    @ViewBuilder
    private func preview(_ result: FromTextResult) -> some View {
        let rows = fieldRows(result)
        if rows.isEmpty && result.alternateNames.isEmpty {
            Text("Nothing recognized yet.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 120)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("\(result.subject)", systemImage: "person.crop.circle")
                    .font(.headline)
                ForEach(rows, id: \.0) { label, value in
                    HStack(alignment: .top, spacing: 8) {
                        Text(label + ":")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Text(value)
                            .font(.callout)
                    }
                }
                if !result.alternateNames.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("AKA:")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Text(result.alternateNames.joined(separator: ", "))
                            .font(.callout)
                    }
                }
                if !result.newFigures.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("New figures:")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Text(result.newFigures.joined(separator: ", "))
                            .font(.callout)
                    }
                }
                if !result.newPlaces.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("New places:")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Text(result.newPlaces.joined(separator: ", "))
                            .font(.callout)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func fieldRows(_ result: FromTextResult) -> [(String, String)] {
        var rows: [(String, String)] = []
        rows.append(("Name", result.subject.isEmpty ? "—" : result.subject))
        var gender = "Unknown"
        switch result.gender {
        case .male: gender = "Male"
        case .female: gender = "Female"
        case .unknown: gender = "Unknown"
        }
        rows.append(("Gender", gender))
        if let kind = result.figureKind.figureTypeName { rows.append(("Type", kind)) }
        if let title = result.title { rows.append(("Title", title.capitalized)) }
        if let domain = result.domain { rows.append(("Domain", domain)) }
        var birth = "—"
        if let by = result.birthYear { birth = formatYear(by) }
        rows.append(("Birth", birth))
        var death = "—"
        if let dy = result.deathYear, result.birthYear != result.deathYear { death = formatYear(dy) }
        rows.append(("Death", death))
        if let rs = result.reignStart, let re = result.reignEnd {
            rows.append(("Reign", "\(formatYear(rs)) \u{2013} \(formatYear(re))"))
        }
        var parents = "—"
        if !result.parents.isEmpty {
            parents = result.parents.map { "\($0.relationshipType): \($0.fromFigure)" }.joined(separator: ", ")
        }
        rows.append(("Parents", parents))
        if !result.otherRelationships.isEmpty {
            let others = result.otherRelationships.map { "\($0.relationshipType): \($0.toFigure)" }.joined(separator: ", ")
            rows.append(("Relations", others))
        }
        if !result.placeLinks.isEmpty {
            let places = result.placeLinks.map { "\($0.roleName) of \($0.place)" }.joined(separator: ", ")
            rows.append(("Places", places))
        }
        return rows
    }

    private func formatYear(_ year: Int) -> String {
        if year < 0 { return "\(abs(year)) BCE" }
        return "\(year) CE"
    }

    private func apply(_ result: FromTextResult?) {
        guard let result else { return }
        FromTextRecognizer.apply(result, in: modelContext)
        try? modelContext.save()
    }
}

private enum FromTextRecognizer {
    static func apply(_ result: FromTextResult, in context: ModelContext) {
        guard !result.subject.isEmpty else { return }
        let subjectFigure = figure(named: result.subject, in: context)
        if let subjectFigure {
            populate(subjectFigure, result, in: context)
        }

        for link in result.placeLinks {
            let place = place(named: link.place, in: context)
            let role = roleType(named: link.roleName, in: context)
            let assoc = FigurePlaceAssociation(figure: subjectFigure, place: place, roleType: role, source: "From text")
            context.insert(assoc)
            subjectFigure?.placeAssociations.append(assoc)
            place.figureAssociations.append(assoc)
        }

        for rel in result.otherRelationships {
            guard let from = figure(named: rel.fromFigure, in: context),
                  let to = figure(named: rel.toFigure, in: context) else { continue }
            let type = relationType(named: rel.relationshipType, in: context)
            let relationship = Relationship(fromFigure: from, toFigure: to, relationshipType: type, source: "From text", isPreferred: rel.isPreferred)
            context.insert(relationship)
            from.outgoingRelationships.append(relationship)
        }

        for name in result.alternateNames {
            guard let subjectFigure, !name.isEmpty else { continue }
            let alt = AlternateName(figure: subjectFigure, name: name, tradition: .other, nameType: .spelling, note: "")
            context.insert(alt)
            subjectFigure.alternateNames.append(alt)
        }
    }

    private static func populate(_ figure: Figure, _ result: FromTextResult, in context: ModelContext) {
        if result.figureKind != .unknown, let name = result.figureKind.figureTypeName {
            figure.figureType = figureType(named: name, in: context)
        }
        switch result.gender {
        case .male: figure.gender = .male
        case .female: figure.gender = .female
        case .unknown: break
        }
        if let title = result.title { figure.title = title.capitalized }
        if let domain = result.domain { figure.domain = domain }
        if !result.description.isEmpty, figure.figureDescription.isEmpty {
            figure.figureDescription = result.description
        }
        if let by = result.birthYear {
            figure.birthDate = MythologicalDate(year: by, isApproximate: true)
        }
        if let dy = result.deathYear {
            figure.deathDate = MythologicalDate(year: dy, isApproximate: true)
        }
        if let rs = result.reignStart { figure.reignStartYear = rs }
        if let re = result.reignEnd { figure.reignEndYear = re }
    }

    private static func figure(named name: String, in context: ModelContext) -> Figure? {
        guard !name.isEmpty else { return nil }
        let all: [Figure] = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        if let existing = all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return existing }
        let figure = Figure(name: name)
        context.insert(figure)
        return figure
    }

    private static func place(named name: String, in context: ModelContext) -> Place {
        let all: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        if let existing = all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return existing }
        let place = Place(name: name)
        context.insert(place)
        return place
    }

    private static func figureType(named name: String, in context: ModelContext) -> FigureType? {
        let all: [FigureType] = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        if let existing = all.first(where: { $0.name == name }) { return existing }
        let type = FigureType(name: name, icon: "person.fill", colorHex: "007AFF")
        context.insert(type)
        return type
    }

    private static func relationType(named name: String, in context: ModelContext) -> RelationshipType? {
        let all: [RelationshipType] = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        if let existing = all.first(where: { $0.name == name }) { return existing }
        let type = RelationshipType(name: name, icon: "link", colorHex: "007AFF", category: "family")
        context.insert(type)
        return type
    }

    private static func roleType(named name: String, in context: ModelContext) -> FigurePlaceRoleType? {
        let all: [FigurePlaceRoleType] = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
        if let existing = all.first(where: { $0.name == name }) { return existing }
        let type = FigurePlaceRoleType(name: name, icon: "star.fill", colorHex: "FF9500")
        context.insert(type)
        return type
    }
}