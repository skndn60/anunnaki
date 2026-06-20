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
    @State private var fromSearchText = ""
    @State private var toSearchText = ""
    @State private var relationshipType: Relationship.RelationshipType = .father
    @State private var source = ""

    private var filteredFromFigures: [Figure] {
        guard !fromSearchText.isEmpty else { return [] }
        return figures.filter { fig in
            (fromFigure == nil || fig.persistentModelID != fromFigure!.persistentModelID) &&
            fig.name.localizedCaseInsensitiveContains(fromSearchText)
        }
    }

    private var filteredToFigures: [Figure] {
        guard !toSearchText.isEmpty else { return [] }
        return figures.filter { fig in
            (toFigure == nil || fig.persistentModelID != toFigure!.persistentModelID) &&
            fig.name.localizedCaseInsensitiveContains(toSearchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Relationship")
                .font(.title3.bold())
                .padding()

            Form {
                Section("From") {
                    FigureSearchSelector(
                        selection: $fromFigure,
                        searchText: $fromSearchText,
                        figures: figures,
                        filteredFigures: filteredFromFigures,
                        placeholder: "Search from figure\u{2026}"
                    )
                }

                Section("Type") {
                    Picker("Type", selection: $relationshipType) {
                        ForEach(Relationship.RelationshipType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("To") {
                    FigureSearchSelector(
                        selection: $toFigure,
                        searchText: $toSearchText,
                        figures: figures,
                        filteredFigures: filteredToFigures,
                        placeholder: "Search to figure\u{2026}"
                    )
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
        .frame(width: 450, height: 520)
        .onChange(of: fromFigure) { _, _ in inferType() }
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

    private func inferType() {
        switch fromFigure?.gender {
        case .female: relationshipType = .mother
        case .male: relationshipType = .father
        default: break
        }
    }
}

// MARK: - Figure Search Selector

struct FigureSearchSelector: View {
    @Binding var selection: Figure?
    @Binding var searchText: String
    let figures: [Figure]
    let filteredFigures: [Figure]
    let placeholder: String

    var body: some View {
        if let fig = selection {
            HStack(spacing: 6) {
                Text("\(fig.gender.symbol) \(fig.name)")
                    .fontWeight(.medium)
                Spacer()
                Button { selection = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.3))
            .cornerRadius(6)
        }
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.quaternary.opacity(0.15))
        .cornerRadius(6)
        if !searchText.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if filteredFigures.isEmpty {
                        Text("No figures match \"\(searchText)\"")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(filteredFigures) { fig in
                            Button {
                                selection = fig
                                searchText = ""
                            } label: {
                                Text("\(fig.gender.symbol) \(fig.name)")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }
}
