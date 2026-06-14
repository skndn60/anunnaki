import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Detail panel showing all properties of a selected figure.
struct FigureDetailView: View {
    let figure: Figure
    var onSelectFigure: ((Figure) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var citationCount = -1
    @State private var droppedFigureName: String?
    @State private var showDropConfirmation = false
    @State private var selectedRelationType: Relationship.RelationshipType = .father
    @State private var isDropTargeted = false
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

                // Citations
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sources & Citations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    if figureCitations.isEmpty {
                        Text("No matching citations found.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(figureCitations) { citation in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundStyle(.brown)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(citation.source?.name ?? "Unknown"), \(citation.safeLocation)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(citation.safeNote)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { string, _ in
                if let name = string as? String {
                    DispatchQueue.main.async {
                        let allFigures: [Figure] = modelContext.fetchAll()
                        guard let sourceFigure = allFigures.first(where: { $0.name == name }) else { return }
                        droppedFigureName = name
                        selectedRelationType = inferredType(from: sourceFigure, to: figure)
                        showDropConfirmation = true
                    }
                }
            }
            return true
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.05))
                    .overlay(
                        Text("Drop to create relationship")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                    )
                    .allowsHitTesting(false)
                    .padding(4)
            }
        }
        .sheet(isPresented: $showDropConfirmation) {
            if let sourceName = droppedFigureName {
                VStack(spacing: 20) {
                    Text("Create Relationship")
                        .font(.title3.bold())

                    Text("Do you want **\(sourceName)** to be registered as the **\(selectedRelationType.rawValue.lowercased())** of **\(figure.name)**?")
                        .multilineTextAlignment(.center)

                    Picker("Type", selection: $selectedRelationType) {
                        ForEach(Relationship.RelationshipType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    HStack(spacing: 16) {
                        Button("Cancel") { showDropConfirmation = false }
                            .buttonStyle(.bordered)
                        Button("OK") {
                            let allFigures: [Figure] = modelContext.fetchAll()
                            if let sourceFigure = allFigures.first(where: { $0.name == sourceName }) {
                                let rel = Relationship(
                                    fromFigure: sourceFigure,
                                    toFigure: figure,
                                    relationshipType: selectedRelationType
                                )
                                modelContext.insert(rel)
                            }
                            showDropConfirmation = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: 420)
                .presentationCompactAdaptation(.sheet)
            }
        }
    }

    private var relatedRelationships: [Relationship] {
        relationships.filter {
            $0.fromFigure?.persistentModelID == figure.persistentModelID ||
            $0.toFigure?.persistentModelID == figure.persistentModelID
        }
    }

    private var figureCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == figure.name && $0.safeEntityType == .figure }
    }

    private var typeColor: Color { figure.figureType.color }

    private var typeIcon: String { figure.figureType.icon }

    private func inferredType(from source: Figure, to target: Figure) -> Relationship.RelationshipType {
        if source.gender == .female { return .mother }
        if source.gender == .male { return .father }
        return .father
    }
}

/// A single row in the relationship list, described from the perspective of the selected figure.
struct RelationshipRow: View {
    let relationship: Relationship
    let perspective: Figure
    var onSelectFigure: ((Figure) -> Void)?
    @Environment(\.modelContext) private var modelContext

    @State private var showDeleteConfirm = false

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

            Button(action: { showDeleteConfirm = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete relationship")
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button("Delete Relationship", role: .destructive) {
                modelContext.delete(relationship)
                try? modelContext.save()
            }
        }
        .alert("Delete Relationship?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(relationship)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the relationship between \(relationship.fromFigure?.name ?? "?") and \(relationship.toFigure?.name ?? "?").")
        }
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
                    .foregroundStyle(Color.accentColor)
                    .underline()
            }
            .buttonStyle(.plain)
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
