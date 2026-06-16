import SwiftUI
import SwiftData

/// Input screen for managing relationships between figures.
struct RelationshipListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var relationships: [Relationship]
    @Query private var figures: [Figure]
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Relationships")
                    .font(.title2.bold())
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Label("Add Relationship", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(figures.count < 2)
            }
            .padding()

            Divider()

            if relationships.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "link")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No relationships yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Define parent-child, spouse, and other connections between figures.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(relationships) { rel in
                    RelationshipRowView(relationship: rel, onDelete: { modelContext.delete(rel) })
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            RelationshipFormView()
        }
    }
}

struct RelationshipRowView: View {
    let relationship: Relationship
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(relationship.fromFigure?.name ?? "?")
                .fontWeight(.medium)
            Image(systemName: relationship.relationshipType.icon)
                .font(.caption)
                .foregroundStyle(relationship.relationshipType.color)
            Text(relationship.relationshipType.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(relationship.relationshipType.color.opacity(0.12)))
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(relationship.toFigure?.name ?? "?")
                .fontWeight(.medium)
            if !relationship.source.isEmpty {
                Text(relationship.source)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

// MARK: - Relationship Form

struct RelationshipFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]

    @State private var fromFigure: Figure?
    @State private var toFigure: Figure?
    @State private var relationshipType: Relationship.RelationshipType = .father
    @State private var source = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Relationship")
                .font(.title3.bold())
                .padding()

            Form {
                Picker("From", selection: $fromFigure) {
                    Text("Select a figure").tag(nil as Figure?)
                    ForEach(figures) { figure in
                        Text("\(figure.gender.symbol) \(figure.name)").tag(figure as Figure?)
                    }
                }

                Picker("Type", selection: $relationshipType) {
                    ForEach(Relationship.RelationshipType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                Picker("To", selection: $toFigure) {
                    Text("Select a figure").tag(nil as Figure?)
                    ForEach(figures) { figure in
                        Text("\(figure.gender.symbol) \(figure.name)").tag(figure as Figure?)
                    }
                }

                TextField("Source Text", text: $source, prompt: Text("e.g. Enuma Elish, Tablet I"))
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 450, height: 320)
    }

    private var isValid: Bool {
        guard let from = fromFigure, let to = toFigure else { return false }
        return from.persistentModelID != to.persistentModelID
    }

    private func save() {
        guard let from = fromFigure, let to = toFigure else { return }
        let relationship = Relationship(
            fromFigure: from, toFigure: to,
            relationshipType: relationshipType, source: source
        )
        modelContext.insert(relationship)
        dismiss()
    }
}
