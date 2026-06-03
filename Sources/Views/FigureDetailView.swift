import SwiftUI
import SwiftData

/// Detail panel showing all properties of a selected figure.
struct FigureDetailView: View {
    let figure: Figure
    var onSelectFigure: ((Figure) -> Void)?
    @Query private var relationships: [Relationship]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(typeColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: typeIcon)
                                .foregroundStyle(typeColor)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(figure.name)
                                .font(.title2.bold())
                            Text(figure.gender.symbol)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        if !figure.title.isEmpty {
                            Text(figure.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text(figure.figureType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(typeColor.opacity(0.12))
                        )
                }

                Divider()

                // Properties grid
                LazyVGrid(columns: [GridItem(.fixed(100), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                    PropertyRow(label: "Domain", value: figure.domain)
                    PropertyRow(label: "Birth", value: figure.birthDate.displayLabel)
                    PropertyRow(label: "Death", value: figure.deathDate.displayLabel)
                    PropertyRow(label: "Source", value: figure.source)
                }

                // Mini Lineage Tree
                MiniLineageView(figure: figure, relationships: relatedRelationships, onSelectFigure: onSelectFigure)

                // Description
                if !figure.figureDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(figure.figureDescription)
                            .font(.body)
                    }
                }

                // Alternate Names
                if !figure.alternateNames.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Also Known As")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(figure.alternateNames) { altName in
                            HStack(spacing: 8) {
                                Text(altName.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text(altName.tradition.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                                Text(altName.nameType.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                            }
                            if !altName.note.isEmpty {
                                Text(altName.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                }

                Divider()

                // Relationships
                let figureRels = relatedRelationships
                if !figureRels.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Relationships")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(figureRels) { rel in
                            RelationshipRow(relationship: rel, perspective: figure, onSelectFigure: onSelectFigure)
                        }
                    }
                }

                // Place Associations
                if !figure.placeAssociations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Associated Places")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(figure.placeAssociations) { assoc in
                            HStack(spacing: 8) {
                                Image(systemName: assoc.place?.placeType.icon ?? "mappin")
                                    .font(.caption)
                                    .foregroundStyle(.teal)
                                    .frame(width: 14)
                                Text(assoc.role.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(assoc.place?.name ?? "?")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Spacer()
                                if !assoc.source.isEmpty {
                                    Text(assoc.source)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }

                // Images
                Divider()
                FigureImageGallery(figure: figure)

                Spacer()
            }
            .padding(20)
        }
    }

    private var relatedRelationships: [Relationship] {
        relationships.filter {
            $0.fromFigure?.persistentModelID == figure.persistentModelID ||
            $0.toFigure?.persistentModelID == figure.persistentModelID
        }
    }

    private var typeColor: Color { figure.figureType.color }

    private var typeIcon: String { figure.figureType.icon }
}

/// A single row in the relationship list, described from the perspective of the selected figure.
struct RelationshipRow: View {
    let relationship: Relationship
    let perspective: Figure
    var onSelectFigure: ((Figure) -> Void)?

    @State private var isHovered = false

    private var otherFigure: Figure? {
        let isFrom = relationship.fromFigure?.persistentModelID == perspective.persistentModelID
        return isFrom ? relationship.toFigure : relationship.fromFigure
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: relationshipIcon)
                .font(.caption)
                .foregroundStyle(relationshipColor)
                .frame(width: 16)

            descriptionView

            Spacer()

            if !relationship.source.isEmpty {
                Text(relationship.source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var descriptionView: some View {
        let isFrom = relationship.fromFigure?.persistentModelID == perspective.persistentModelID
        let otherName = otherFigure?.name ?? "?"

        HStack(spacing: 4) {
            Text(labelPrefix(isFrom: isFrom))
                .font(.callout)
            Button(action: {
                if let fig = otherFigure { onSelectFigure?(fig) }
            }) {
                Text(otherName)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(isHovered ? Color.accentColor : .primary)
                    .underline(isHovered)
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }
    }

    private func labelPrefix(isFrom: Bool) -> String {
        switch relationship.relationshipType {
        case .father:
            return isFrom ? "Father of" : "\(perspective.gender == .female ? "Daughter" : perspective.gender == .male ? "Son" : "Child") of"
        case .mother:
            return isFrom ? "Mother of" : "\(perspective.gender == .female ? "Daughter" : perspective.gender == .male ? "Son" : "Child") of"
        case .spouse:
            if perspective.gender == .male { return "Husband of" }
            else if perspective.gender == .female { return "Wife of" }
            else { return "Spouse of" }
        case .consort:
            return "Consort of"
        case .sibling:
            if perspective.gender == .male { return "Brother of" }
            else if perspective.gender == .female { return "Sister of" }
            else { return "Sibling of" }
        case .uncle:
            return isFrom ? "Uncle of" : "Nephew/Niece of"
        case .aunt:
            return isFrom ? "Aunt of" : "Nephew/Niece of"
        case .creator:
            return isFrom ? "Creator of" : "Created by"
        }
    }

    private var relationshipIcon: String { relationship.relationshipType.icon }

    private var relationshipColor: Color { relationship.relationshipType.color }
}

/// A label-value pair for the properties grid.
struct PropertyRow: View {
    let label: String
    let value: String

    var body: some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
        Text(value.isEmpty ? "—" : value)
            .font(.callout)
    }
}
