import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Detail panel showing all properties of a selected figure.
struct FigureDetailView: View {
    let figure: Figure
    var onSelectFigure: ((Figure) -> Void)?
    var onSelectPlace: ((Place) -> Void)?
    var onSelectEvent: ((Event) -> Void)?
    var onSelectImage: ((ImageAsset) -> Void)?
    var backLabel: String?
    var onBack: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Query private var matchingRelationships: [Relationship]
    @State private var droppedFigureName: String?
    @State private var showDropConfirmation = false
    @State private var selectedRelationTypeName: String = "Father"
    @State private var allRelationTypes: [RelationshipType] = []
    @State private var dropSource = ""
    @State private var isDropTargeted = false
    @State private var showDeleteAltConfirm = false
    @State private var altToDelete: AlternateName?
    @State private var showAddAltSheet = false
    @State private var showParentSearch = false
    @State private var parentSearchTypeName = ""
    @State private var parentSearchText = ""
    @State private var showPlaceLinkPopover = false
    @State private var placeSearchText = ""
    @State private var selectedPlaceForLink: Place?
    @State private var selectedPlaceRole: FigurePlaceRoleType?

    init(figure: Figure, onSelectFigure: ((Figure) -> Void)? = nil, onSelectPlace: ((Place) -> Void)? = nil, onSelectEvent: ((Event) -> Void)? = nil, onSelectImage: ((ImageAsset) -> Void)? = nil, backLabel: String? = nil, onBack: (() -> Void)? = nil) {
        self.figure = figure
        self.onSelectFigure = onSelectFigure
        self.onSelectPlace = onSelectPlace
        self.onSelectEvent = onSelectEvent
        self.onSelectImage = onSelectImage
        self.backLabel = backLabel
        self.onBack = onBack
        let name = figure.name
        _matchingRelationships = Query(filter: #Predicate<Relationship> { rel in
            rel.fromFigure?.name == name || rel.toFigure?.name == name
        })
    }

    private var figureCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == figure.name && $0.safeEntityType == .figure }
    }

    private var groupedRelationships: [(type: String, preferred: Relationship, alternatives: [Relationship])] {
        let dict = Dictionary(grouping: matchingRelationships) { $0.relationshipType?.name ?? "?" }
        return dict.compactMap { type, rels in
            guard let preferred = rels.first(where: { $0.isPreferred == true }) ?? rels.first else { return nil }
            let alts = rels.filter { $0.persistentModelID != preferred.persistentModelID }
            return (type, preferred, alts)
        }.sorted { $0.type < $1.type }
    }

    @ViewBuilder
    private var headerView: some View {
        if let backLabel, let onBack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption2.weight(.semibold))
                    Text("Back to \(backLabel)")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .pointingHand()
        }

        HStack(spacing: 12) {
            Circle()
                .fill(figure.figureType?.color.opacity(0.2) ?? .gray.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: figure.figureType?.icon ?? "questionmark")
                        .foregroundStyle(figure.figureType?.color ?? .gray)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(figure.name)
                        .font(.title2.bold())
                    Text(figure.gender.symbol)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                if let disambiguation = figure.disambiguation, !disambiguation.isEmpty {
                    Text(disambiguation)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                if !figure.title.isEmpty {
                    Text(figure.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(figure.figureType?.name ?? "Unknown")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(figure.figureType?.color.opacity(0.12) ?? .gray.opacity(0.12))
                )
            if figure.isConcept {
                Text("Concept")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.orange.opacity(0.12))
                    )
            }
        }
    }

    @ViewBuilder
    private var alternateNamesView: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Also Known As")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    showAddAltSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Add alternate name")
            }

            if figure.alternateNames.isEmpty {
                Text("No alternate names")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
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
                        Button(action: {
                            altToDelete = altName
                            showDeleteAltConfirm = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Delete alternate name")
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
    }

    @ViewBuilder
    private var relationshipsView: some View {
        if !matchingRelationships.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Relationships")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(groupedRelationships, id: \.type) { group in
                    RelationshipGroupRow(
                        relationship: group.preferred,
                        alternatives: group.alternatives,
                        perspective: figure,
                        onSelectFigure: onSelectFigure
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var eventsView: some View {
        let figureEvents: [Event] = modelContext.fetchAll().filter {
            $0.involvedFigures.contains(where: { $0.persistentModelID == figure.persistentModelID })
        }
        if !figureEvents.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(figureEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: event.eventType?.icon ?? "bolt")
                                .font(.caption)
                                .foregroundStyle(event.eventType?.color ?? .gray)
                                .frame(width: 14)
                            Button(action: { onSelectEvent?(event) }) {
                                Text(event.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.accentColor)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            .pointingHand()
                            Text(event.eventType?.name ?? "Other")
                                .font(.caption2)
                                .foregroundStyle(event.eventType?.color ?? .gray)
                Spacer()
                            Text(event.date.displayLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !event.placeAssociations.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.caption2)
                                    .foregroundStyle(.teal)
                                ForEach(Array(event.placeAssociations.enumerated()), id: \.element.id) { idx, assoc in
                                    Button(action: {
                                        if let p = assoc.place { onSelectPlace?(p) }
                                    }) {
                                        Text(assoc.place?.name ?? "?")
                                            .font(.caption)
                                            .foregroundStyle(Color.accentColor)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                    .pointingHand()
                                    if idx < event.placeAssociations.count - 1 {
                                        Text("·")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.leading, 22)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var citationsView: some View {
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
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView

                // Stickies
                StickyNoteSection(stickies: figure.stickies) { text in
                    let note = StickyNote(text: text, figure: figure)
                    modelContext.insert(note)
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
                MiniLineageView(figure: figure, relationships: matchingRelationships, onSelectFigure: onSelectFigure, onTapUnknownParent: { typeName in
                    parentSearchTypeName = typeName
                    parentSearchText = ""
                    showParentSearch = true
                })

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
                alternateNamesView

                Divider()

                // Relationships
                relationshipsView

                // Place Associations
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Associated Places")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Button(action: { showPlaceLinkPopover = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .help("Link a place")
                        .popover(isPresented: $showPlaceLinkPopover) {
                            PlaceLinkPopover(
                                figure: figure,
                                searchText: $placeSearchText,
                                selectedPlace: $selectedPlaceForLink,
                                selectedRole: $selectedPlaceRole,
                                isPresented: $showPlaceLinkPopover
                            )
                            .frame(width: 340, height: 400)
                        }
                    }

                    if figure.placeAssociations.isEmpty {
                        Text("No places linked")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(figure.placeAssociations) { assoc in
                            HStack(spacing: 8) {
                                Image(systemName: assoc.place?.placeType?.icon ?? "mappin")
                                    .font(.caption)
                                    .foregroundStyle(.teal)
                                    .frame(width: 14)
                                Text(assoc.roleType?.name ?? "—")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button(action: {
                                    if let place = assoc.place { onSelectPlace?(place) }
                                }) {
                                    Text(assoc.place?.name ?? "?")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.accentColor)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                                .pointingHand()
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

                // Associated Events
                eventsView

                // Images
                Divider()
                ImageGallery(
                    title: "Images",
                    images: figure.images,
                    onLinkImage: { asset in
                        asset.figures.append(figure)
                    },
                    onSelectImage: onSelectImage
                )

                // Tags
                if !figure.tags.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        FlowLayout(spacing: 4) {
                            ForEach(figure.tags) { tag in
                                TagTokenView(tag: tag)
                            }
                        }
                    }
                }

                // Citations
                citationsView

                Spacer()
            }
            .padding(20)
            .textSelection(.enabled)
        }
        .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { string, _ in
                if let name = string as? String {
                    DispatchQueue.main.async {
                        let allFigures: [Figure] = modelContext.fetchAll()
                        guard let sourceFigure = allFigures.first(where: { $0.name == name }) else { return }
                        droppedFigureName = name
                        selectedRelationTypeName = inferredType(from: sourceFigure, to: figure)
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
            let sourceName = droppedFigureName ?? ""
            VStack(spacing: 20) {
                Text("Create Relationship")
                    .font(.title3.bold())

                Text("Do you want **\(sourceName)** to be registered as the **\(selectedRelationTypeName.lowercased())** of **\(figure.name)**?")
                    .multilineTextAlignment(.center)

                Picker("Type", selection: $selectedRelationTypeName) {
                    ForEach(allRelationTypes, id: \.name) { type in
                        Text(type.name).tag(type.name)
                    }
                }
                .onAppear {
                    allRelationTypes = (modelContext.fetchAll() as [RelationshipType])
                }

                TextField("Source", text: $dropSource, prompt: Text("e.g. Enuma Elish, Tablet I"))

                HStack(spacing: 16) {
                    Button("Cancel") { showDropConfirmation = false }
                        .buttonStyle(.bordered)
                    Button("OK") {
                        let allFigures: [Figure] = modelContext.fetchAll()
                        if let sourceFigure = allFigures.first(where: { $0.name == sourceName }) {
                    let rel = Relationship(
                        fromFigure: sourceFigure,
                        toFigure: figure,
                        relationshipType: allRelationTypes.first(where: { $0.name == selectedRelationTypeName }),
                        source: dropSource
                    )
                            modelContext.insert(rel)
                        }
                        showDropConfirmation = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 400)
        }
        .alert("Delete Alternate Name?", isPresented: $showDeleteAltConfirm, presenting: altToDelete) { altName in
            Button("Delete", role: .destructive) {
                modelContext.delete(altName)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { altName in
            Text("Delete \"\(altName.name)\" (\(altName.tradition.rawValue)) from \(altName.figure?.name ?? "?")?")
        }
        .sheet(isPresented: $showAddAltSheet) {
            AlternateNameFormView(alternateName: nil, preSelectedFigure: figure)
        }
        .sheet(isPresented: $showParentSearch) {
            ParentSearchSheet(
                typeName: parentSearchTypeName,
                childFigure: figure,
                isPresented: $showParentSearch,
                searchText: $parentSearchText
            )
        }
    }

    private func inferredType(from source: Figure, to target: Figure) -> String {
        if source.gender == .female { return "Mother" }
        return "Father"
    }
}

/// A row showing a relationship group (preferred + alternatives), described from the perspective of the selected figure.
struct RelationshipGroupRow: View {
    let relationship: Relationship
    let alternatives: [Relationship]
    let perspective: Figure
    var onSelectFigure: ((Figure) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false
    @State private var showAlternativesPopover = false

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

            if !alternatives.isEmpty {
                Button {
                    showAlternativesPopover.toggle()
                } label: {
                    Text("+\(alternatives.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAlternativesPopover) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Alternative \(relationship.relationshipType?.name ?? "traditions")")
                            .font(.caption.bold())
                            .padding(.bottom, 2)
                        ForEach(alternatives) { alt in
                            AlternativeRelationRow(relationship: alt, perspective: perspective, onSelectFigure: onSelectFigure)
                        }
                    }
                    .padding(10)
                    .frame(minWidth: 200)
                }
            }

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
                showDeleteConfirm = true
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
            .pointingHand()
        }
    }

    private func labelPrefix(isFrom: Bool) -> String {
        let name = relationship.relationshipType?.name ?? ""
        switch name {
        case "Father":
            return isFrom ? "Father of" : "\(perspective.gender == .female ? "Daughter" : perspective.gender == .male ? "Son" : "Child") of"
        case "Mother":
            return isFrom ? "Mother of" : "\(perspective.gender == .female ? "Daughter" : perspective.gender == .male ? "Son" : "Child") of"
        case "Spouse":
            if perspective.gender == .male { return "Husband of" }
            else if perspective.gender == .female { return "Wife of" }
            else { return "Spouse of" }
        case "Consort":
            return "Consort of"
        case "Sibling":
            if perspective.gender == .male { return "Brother of" }
            else if perspective.gender == .female { return "Sister of" }
            else { return "Sibling of" }
        case "Uncle":
            return isFrom ? "Uncle of" : "Nephew/Niece of"
        case "Aunt":
            return isFrom ? "Aunt of" : "Nephew/Niece of"
        case "Creator":
            return isFrom ? "Creator of" : "Created by"
        case "Commander":
            return isFrom ? "Commander of" : "Commanded by"
        case "Servant":
            return isFrom ? "Servant of" : "Served by"
        case "Ally":
            return "Ally of"
        case "Enemy":
            return "Enemy of"
        case "Worshipper":
            return isFrom ? "Worshipper of" : "Worshipped by"
        default:
            return "Related to"
        }
    }

    private var relationshipIcon: String { relationship.relationshipType?.icon ?? "questionmark" }

    private var relationshipColor: Color { relationship.relationshipType?.color ?? .gray }
}

/// A compact row for an alternative relationship shown inside the popover.
struct AlternativeRelationRow: View {
    let relationship: Relationship
    let perspective: Figure
    var onSelectFigure: ((Figure) -> Void)?

    private var otherFigure: Figure? {
        let isFrom = relationship.fromFigure?.persistentModelID == perspective.persistentModelID
        return isFrom ? relationship.toFigure : relationship.fromFigure
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: relationship.relationshipType?.icon ?? "questionmark")
                .font(.caption2)
                .foregroundStyle(relationship.relationshipType?.color ?? .gray)
            Text(otherFigure?.name ?? "?")
                .font(.callout)
                .foregroundStyle(.secondary)
            if !relationship.source.isEmpty {
                Text("(\(relationship.source))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
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

// MARK: - Parent Search Sheet

private struct ParentSearchSheet: View {
    let typeName: String
    let childFigure: Figure
    @Binding var isPresented: Bool
    @Binding var searchText: String

    @Environment(\.modelContext) private var modelContext

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filtered: [Figure] {
        searchText.isEmpty ? allFigures : allFigures.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search for a \(typeName.lowercased())...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)

                Divider()

                if filtered.isEmpty {
                    Spacer()
                    Text("No figures found")
                        .foregroundStyle(.tertiary)
                    Spacer()
                } else {
                    List(filtered, id: \.persistentModelID) { fig in
                        Button {
                            selectParent(fig)
                        } label: {
                            HStack(spacing: 10) {
                                Text(fig.gender.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                Text(fig.name)
                                    .font(.body)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select \(typeName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .frame(width: 340, height: 420)
        }
    }

    private func selectParent(_ parent: Figure) {
        let type = fetchOrCreateType(name: typeName)
        if let type {
            let rel = Relationship(fromFigure: parent, toFigure: childFigure)
            modelContext.insert(rel)
            type.relationships.append(rel)
            try? modelContext.save()
        }
        isPresented = false
    }

    private func fetchOrCreateType(name: String) -> RelationshipType? {
        let types: [RelationshipType] = (try? modelContext.fetch(FetchDescriptor<RelationshipType>())) ?? []
        if let existing = types.first(where: { $0.name == name }) {
            return existing
        }
        let newType = RelationshipType(name: name, icon: "person.fill", colorHex: "808080", category: name == "Father" || name == "Mother" ? "parent" : "other")
        modelContext.insert(newType)
        return newType
    }
}

private struct PlaceLinkPopover: View {
    let figure: Figure
    @Binding var searchText: String
    @Binding var selectedPlace: Place?
    @Binding var selectedRole: FigurePlaceRoleType?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var allRoles: [FigurePlaceRoleType] = []

    private var allPlaces: [Place] {
        (try? modelContext.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredPlaces: [Place] {
        let linked = Set(figure.placeAssociations.compactMap { $0.place?.persistentModelID })
        let available = allPlaces.filter { !linked.contains($0.persistentModelID) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search places…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(.textBackgroundColor))
            .cornerRadius(6)

            if filteredPlaces.isEmpty {
                Text("No matching places")
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(filteredPlaces, id: \.persistentModelID) { place in
                    Button(action: { selectedPlace = place }) {
                        HStack(spacing: 10) {
                            Image(systemName: place.placeType?.icon ?? "mappin")
                                .font(.caption)
                                .foregroundStyle(.teal)
                                .frame(width: 16)
                            Text(place.name)
                                .font(.body)
                            if !place.modernLocation.isEmpty {
                                Text(place.modernLocation)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            if selectedPlace?.persistentModelID == place.persistentModelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Text("Role:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Role", selection: $selectedRole) {
                        Text("Select…").tag(nil as FigurePlaceRoleType?)
                        ForEach(allRoles, id: \.persistentModelID) { role in
                            HStack(spacing: 6) {
                                Image(systemName: role.icon)
                                Text(role.name)
                            }
                            .tag(role as FigurePlaceRoleType?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.bordered)
                    Button("Link") {
                        createAssociation()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedPlace == nil || selectedRole == nil)
                }
            }
        }
        .padding()
        .onAppear {
            allRoles = (try? modelContext.fetch(FetchDescriptor<FigurePlaceRoleType>(sortBy: [SortDescriptor(\.name)]))) ?? []
        }
    }

    private func createAssociation() {
        guard let place = selectedPlace, let role = selectedRole else { return }
        let assoc = FigurePlaceAssociation()
        modelContext.insert(assoc)
        figure.placeAssociations.append(assoc)
        place.figureAssociations.append(assoc)
        role.associations.append(assoc)
        try? modelContext.save()
    }
}

