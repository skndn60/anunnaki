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

            Text("Describe a figure and its connections in plain language. Separate clauses with a semicolon. Examples:")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("\u{2022} Marduk is the son of Enki and Damkina")
                Text("\u{2022} Sarpanit; consort of Marduk")
                Text("\u{2022} Marduk patron of Babylon")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            TextEditor(text: $input)
                .font(.body)
                .frame(height: 90)
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
                    .frame(height: 90)
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
                .disabled(result == nil)
            }
        }
        .padding(20)
        .frame(width: 500)
        .onChange(of: input) { _, _ in
            result = FromTextParser.parse(input)
        }
    }

    @ViewBuilder
    private func preview(_ result: FromTextResult) -> some View {
        let hasPreview = result.subject != nil || !result.relationships.isEmpty || !result.placeLinks.isEmpty
        if !hasPreview {
            Text("Nothing recognized yet.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 90)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if let subject = result.subject {
                    Label("Subject: \(subject)", systemImage: "person.crop.circle")
                        .font(.callout)
                }
                if !result.relationships.isEmpty {
                    Text("Relationships").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(result.relationships, id: \.self) { rel in
                        let type = rel.relationshipType ?? "Relationship"
                        Text("\(rel.fromFigure) \u{2192} \(rel.toFigure) (\(type))")
                            .font(.callout)
                    }
                }
                if !result.placeLinks.isEmpty {
                    Text("Place links").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(result.placeLinks, id: \.self) { link in
                        Text("\(link.figure) \u{2013} \(link.role.displayName) of \(link.place)")
                            .font(.callout)
                    }
                }
                if !result.newFigures.isEmpty {
                    Label("New figures: \(result.newFigures.joined(separator: ", "))", systemImage: "person.badge.plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !result.newPlaces.isEmpty {
                    Label("New places: \(result.newPlaces.joined(separator: ", "))", systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func apply(_ result: FromTextResult?) {
        guard let result else { return }
        FromTextRecognizer.apply(result, in: modelContext)
        try? modelContext.save()
    }
}

private enum FromTextRecognizer {
    static func apply(_ result: FromTextResult, in context: ModelContext) {
        let subject = figure(named: result.subject, in: context)

        for link in result.placeLinks {
            let place = place(named: link.place, in: context)
            let role = roleType(named: link.role.displayName, in: context)
            let assoc = FigurePlaceAssociation(figure: subject, place: place, roleType: role, source: "From text")
            context.insert(assoc)
            subject?.placeAssociations.append(assoc)
            place.figureAssociations.append(assoc)
        }

        for rel in result.relationships {
            guard let from = figure(named: rel.fromFigure, in: context),
                  let to = figure(named: rel.toFigure, in: context),
                  let typeName = rel.relationshipType else { continue }
            let type = relationType(named: typeName, in: context)
            let relationship = Relationship(fromFigure: from, toFigure: to, relationshipType: type, source: "From text", isPreferred: rel.isPreferred)
            context.insert(relationship)
            from.outgoingRelationships.append(relationship)
        }
    }

    private static func figure(named name: String?, in context: ModelContext) -> Figure? {
        guard let name, !name.isEmpty else { return nil }
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