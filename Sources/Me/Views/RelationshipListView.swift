import SwiftUI
import SwiftData

/// Input screen for managing relationships between figures.
struct RelationshipListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var relationships: [Relationship]
    @Query private var figures: [Figure]
    @State private var showingAddSheet = false
    @State private var editingRelationship: Relationship?
    @State private var searchText = ""
    @State private var sortOrder: RelationshipSortOrder = .fromFigure
    @State private var showDeleteConfirm = false
    @State private var relToDelete: Relationship?

    enum RelationshipSortOrder: String, CaseIterable {
        case fromFigure = "From Figure"
        case toFigure = "To Figure"
        case type = "Type"
        case source = "Source"
    }

    private var filteredRelationships: [Relationship] {
        var result = relationships
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                ($0.fromFigure?.name ?? "").lowercased().contains(query) ||
                ($0.toFigure?.name ?? "").lowercased().contains(query) ||
                ($0.relationshipType?.name ?? "").lowercased().contains(query) ||
                $0.source.lowercased().contains(query)
            }
        }
        switch sortOrder {
        case .fromFigure:
            result.sort { ($0.fromFigure?.name ?? "") < ($1.fromFigure?.name ?? "") }
        case .toFigure:
            result.sort { ($0.toFigure?.name ?? "") < ($1.toFigure?.name ?? "") }
        case .type:
            result.sort { ($0.relationshipType?.name ?? "") < ($1.relationshipType?.name ?? "") }
        case .source:
            result.sort { $0.source < $1.source }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Relationships")
                    .font(.title2.bold())
                Spacer()
                Picker("Sort", selection: $sortOrder) {
                    ForEach(RelationshipSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .frame(width: 150)
                TextField("🔍 Filter", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .overlay(alignment: .trailing) {
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 6)
                            .help("Clear filter")
                        }
                    }
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
            } else if filteredRelationships.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(searchText)\"")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filteredRelationships.enumerated()), id: \.element.id) { index, rel in
                            RelationshipRowView(
                                relationship: rel,
                                onEdit: { editingRelationship = rel },
                                onDelete: {
                                    relToDelete = rel
                                    showDeleteConfirm = true
                                }
                            )
                            .alternatingRowBackground(index: index)
                            Divider()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            RelationshipFormView()
        }
        .sheet(item: $editingRelationship) { rel in
            EditRelationshipForm(relationship: rel)
        }
        .alert("Delete Relationship?", isPresented: $showDeleteConfirm, presenting: relToDelete) { rel in
            Button("Delete", role: .destructive) {
                modelContext.delete(rel)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { rel in
            Text("Delete relationship between \(rel.fromFigure?.name ?? "?") and \(rel.toFigure?.name ?? "?")?")
        }
    }
}

struct RelationshipRowView: View {
    @Environment(\.modelContext) private var modelContext
    let relationship: Relationship
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isPreferred: Bool { relationship.isPreferred == true }

    var body: some View {
        HStack(spacing: 10) {
            if isPreferred {
                Button(action: {
                    Task { @MainActor in
                        relationship.isPreferred = false
                        try? modelContext.save()
                    }
                }) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
                .help("Click to unset as default")
            }
            Text(relationship.fromFigure?.name ?? "?")
                .fontWeight(isPreferred ? .bold : .medium)
                .foregroundStyle(isPreferred ? .primary : .secondary)
            Image(systemName: relationship.relationshipType?.icon ?? "questionmark")
                .font(.caption)
                .foregroundStyle(relationship.relationshipType?.color ?? .gray)
            Text(relationship.relationshipType?.name ?? "")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill((relationship.relationshipType?.color ?? .gray).opacity(0.12)))
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(relationship.toFigure?.name ?? "?")
                .fontWeight(isPreferred ? .bold : .medium)
                .foregroundStyle(isPreferred ? .primary : .secondary)
            if !relationship.source.isEmpty {
                Text(relationship.source)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            IconActionButton(icon: "pencil", color: .accentColor, help: "Edit", action: onEdit)
            IconActionButton(icon: "trash", color: .red, help: "Delete", action: onDelete)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)

    }
}

// MARK: - Relationship Form

struct RelationshipFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    @Query private var relationships: [Relationship]

    @State private var fromFigure: FigureSearchResult?
    @State private var toFigure: FigureSearchResult?
    @State private var fromSearchText = ""
    @State private var toSearchText = ""
    @Query private var allRelationTypes: [RelationshipType]
    @State private var selectedType: RelationshipType?
    @State private var source = ""

    private var filteredFromFigures: [FigureSearchResult] {
        guard !fromSearchText.isEmpty else { return [] }
        let figs = figures.filter { fromFigure == nil || $0.persistentModelID != fromFigure!.figure.persistentModelID }
        return searchFigures(figs, query: fromSearchText)
    }

    private var filteredToFigures: [FigureSearchResult] {
        guard !toSearchText.isEmpty else { return [] }
        let figs = figures.filter { toFigure == nil || $0.persistentModelID != toFigure!.figure.persistentModelID }
        return searchFigures(figs, query: toSearchText)
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
                    Picker("Type", selection: $selectedType) {
                        ForEach(allRelationTypes, id: \.self) { type in
                            Text(type.name).tag(type as RelationshipType?)
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
        .alert("Duplicate Relationship", isPresented: $showDuplicateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Add Anyway") { showPreferredPrompt = true }
        } message: {
            Text(duplicateMessage)
        }
        .alert("Preferred Relationship", isPresented: $showPreferredPrompt) {
            Button("Make Default") { commit(isPreferred: true) }
            Button("Keep Existing as Default") { commit(isPreferred: false) }
        } message: {
            Text("Should this be the default \(selectedType?.name ?? "relationship") for \(fromFigure?.figure.name ?? "?")?")
        }
    }

    private func commit(isPreferred: Bool) {
        guard let from = fromFigure?.figure, let to = toFigure?.figure, let type = selectedType else { return }
        if isPreferred {
            let existing = relationships.filter {
                $0.fromFigure?.persistentModelID == from.persistentModelID &&
                $0.relationshipType?.name == type.name
            }
            for rel in existing { rel.isPreferred = false }
        }
        let relationship = Relationship(
            fromFigure: from, toFigure: to,
            source: source,
            isPreferred: isPreferred
        )
        modelContext.insert(relationship)
        type.relationships.append(relationship)
        try? modelContext.save()
        dismiss()
    }

    private var isValid: Bool {
        guard let from = fromFigure?.figure, let to = toFigure?.figure else { return false }
        return from.persistentModelID != to.persistentModelID
    }

    @State private var duplicateMessage = ""

    private func save() {
        guard let from = fromFigure?.figure, let to = toFigure?.figure, let type = selectedType else { return }

        let existing = relationships.filter {
            $0.fromFigure?.persistentModelID == from.persistentModelID &&
            $0.relationshipType?.name == type.name
        }
        if existing.isEmpty {
            let relationship = Relationship(
                fromFigure: from, toFigure: to,
                source: source,
                isPreferred: false
            )
            modelContext.insert(relationship)
            type.relationships.append(relationship)
            try? modelContext.save()
            dismiss()
        } else if type.category == "parent" {
            duplicateMessage = "\(from.name) already has a \(type.name) relationship (\(existing.first?.toFigure?.name ?? "?")). Adding another will create conflicting lineages."
            showDuplicateAlert = true
        } else {
            showPreferredPrompt = true
        }
    }

    @State private var showDuplicateAlert = false
    @State private var showPreferredPrompt = false

    private func inferType() {
        switch fromFigure?.figure.gender {
        case .female: selectedType = allRelationTypes.first(where: { $0.name == "Mother" })
        case .male: selectedType = allRelationTypes.first(where: { $0.name == "Father" })
        default: break
        }
    }
}

// MARK: - Figure Search Selector

struct FigureSearchSelector: View {
    @Binding var selection: FigureSearchResult?
    @Binding var searchText: String
    let figures: [Figure]
    let filteredFigures: [FigureSearchResult]
    let placeholder: String

    var body: some View {
        if let selection {
            HStack(spacing: 6) {
                Text("\(selection.figure.gender.symbol) \(selection.displayName)")
                    .fontWeight(.medium)
                Spacer()
                Button { self.selection = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear selection")
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
                .textFieldStyle(.roundedBorder)
        }
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
                        ForEach(filteredFigures, id: \.id) { result in
                            Button {
                                selection = result
                                searchText = ""
                            } label: {
                                Text("\(result.figure.gender.symbol) \(result.displayName)")
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
