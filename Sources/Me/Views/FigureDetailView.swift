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
    @Query private var figureBlindSpots: [BlindSpot]
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
    @State private var showPlaceLinkPopover = false
    @State private var placeSearchText = ""
    @State private var selectedPlaceForLink: Place?
    @State private var selectedPlaceRole: FigurePlaceRoleType?
    @State private var showAddCitation = false
    @State private var editingCommentsID: PersistentIdentifier?
    @State private var editingCommentsText: String = ""
    @State private var filterText = ""
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
        _figureBlindSpots = Query(filter: #Predicate<BlindSpot> { $0.figureName == name })
    }

    private func isParentGap(typeName: String) -> Bool {
        figureBlindSpots.contains {
            $0.blindSpotType == BlindSpotType.missingParent.rawValue &&
            $0.isResolved &&
            $0.categoryEnum == .knownGap &&
            ($0.parentType == nil || $0.parentType == typeName)
        }
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

    private func matchesFilter(_ text: String) -> Bool {
        guard !filterText.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(filterText)
    }

    private var filteredGroupedRelationships: [(type: String, preferred: Relationship, alternatives: [Relationship])] {
        groupedRelationships.compactMap { group in
            let matchingAlts = group.alternatives.filter {
                matchesFilter($0.fromFigure?.name ?? "") || matchesFilter($0.relationshipType?.name ?? "")
            }
            let preferredMatches = matchesFilter(group.preferred.fromFigure?.name ?? "") || matchesFilter(group.type)
            if preferredMatches || !matchingAlts.isEmpty {
                return (group.type, group.preferred, matchingAlts.isEmpty ? group.alternatives : matchingAlts)
            }
            return nil
        }
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

    private var filteredAlternateNames: [AlternateName] {
        filterText.isEmpty ? figure.alternateNames : figure.alternateNames.filter {
            matchesFilter($0.name) || matchesFilter($0.tradition.rawValue) || matchesFilter($0.nameType.rawValue) || matchesFilter($0.note)
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
                ForEach(filteredAlternateNames) { altName in
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
        if !filteredGroupedRelationships.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Relationships")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(filteredGroupedRelationships, id: \.type) { group in
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
        let allFigureEvents: [Event] = modelContext.fetchAll().filter {
            $0.involvedFigures.contains(where: { $0.persistentModelID == figure.persistentModelID })
        }
        let figureEvents = filterText.isEmpty ? allFigureEvents : allFigureEvents.filter {
            matchesFilter($0.name) || matchesFilter($0.eventType?.name ?? "") || matchesFilter($0.date.displayLabel)
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

    private var filteredCitations: [Citation] {
        filterText.isEmpty ? figureCitations : figureCitations.filter {
            matchesFilter($0.source?.name ?? "") || matchesFilter($0.safeLocation) || matchesFilter($0.safeNote)
        }
    }

    @ViewBuilder
    private var citationsView: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sources & Citations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { showAddCitation = true }) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Add citation")
            }

            if filteredCitations.isEmpty {
                    Text("No matching citations found.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(filteredCitations) { citation in
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

                // Filter
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    TextField("Filter relationships, places, events, names\u{2026}", text: $filterText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                    if !filterText.isEmpty {
                        Button(action: { filterText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)

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
                MiniLineageView(figure: figure, relationships: matchingRelationships, isParentGap: { [weak figure] typeName in
                    guard figure != nil else { return false }
                    return isParentGap(typeName: typeName)
                }, onSelectFigure: onSelectFigure, onTapUnknownParent: { typeName in
                    parentSearchTypeName = typeName
                    showParentSearch = true
                }, onMarkKnownUnavailable: { typeName in
                    let hasExistingSpot = figureBlindSpots.contains {
                        $0.figureName == figure.name &&
                        $0.blindSpotType == BlindSpotType.missingParent.rawValue &&
                        ($0.parentType == nil || $0.parentType == typeName)
                    }
                    if !hasExistingSpot {
                        let spot = BlindSpot(
                            figureName: figure.name,
                            blindSpotType: .missingParent,
                            category: .knownGap,
                            spotDescription: "No recorded \(typeName.lowercased()) for \(figure.name)",
                            suggestedQuery: "Who are the parents of \(figure.name)?",
                            isResolved: true,
                            parentType: typeName
                        )
                        modelContext.insert(spot)
                    }
                    if let sticky = figure.stickies.first(where: {
                        $0.text.hasPrefix("Missing \(typeName.lowercased())")
                    }) {
                        modelContext.delete(sticky)
                    }
                    try? modelContext.save()
                }, onRevertKnownUnavailable: { typeName in
                    if let spot = figureBlindSpots.first(where: {
                        $0.figureName == figure.name &&
                        $0.blindSpotType == BlindSpotType.missingParent.rawValue &&
                        $0.isResolved &&
                        $0.categoryEnum == .knownGap &&
                        ($0.parentType == nil || $0.parentType == typeName)
                    }) {
                        modelContext.delete(spot)
                    }
                    try? modelContext.save()
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
                        let filteredPlaces = filterText.isEmpty ? figure.placeAssociations : figure.placeAssociations.filter {
                            matchesFilter($0.place?.name ?? "") || matchesFilter($0.roleType?.name ?? "") || matchesFilter($0.source)
                        }
                        ForEach(filteredPlaces) { assoc in
                            VStack(alignment: .leading, spacing: 2) {
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
                                if editingCommentsID == assoc.persistentModelID {
                                    HStack(spacing: 4) {
                                        TextField("Comments", text: $editingCommentsText)
                                            .textFieldStyle(.plain)
                                            .font(.caption)
                                            .onSubmit {
                                                assoc.comments = editingCommentsText.isEmpty ? nil : editingCommentsText
                                                editingCommentsID = nil
                                                try? modelContext.save()
                                            }
                                        Button(action: {
                                            assoc.comments = editingCommentsText.isEmpty ? nil : editingCommentsText
                                            editingCommentsID = nil
                                            try? modelContext.save()
                                        }) {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                        }
                                        .buttonStyle(.plain)
                                        Button(action: {
                                            editingCommentsID = nil
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.leading, 22)
                                } else if let comments = assoc.comments, !comments.isEmpty {
                                    Button(action: {
                                        editingCommentsText = comments
                                        editingCommentsID = assoc.persistentModelID
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(comments)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Image(systemName: "pencil")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 22)
                                } else {
                                    Button(action: {
                                        editingCommentsText = ""
                                        editingCommentsID = assoc.persistentModelID
                                    }) {
                                        HStack(spacing: 4) {
                                            Text("Add comment…")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                            Image(systemName: "plus")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 22)
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

                Text("Do you want **\(sourceName)** to be registered as the **\(selectedRelationTypeName.lowercased())** of **\(self.figure.name)**?")
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
                        toFigure: self.figure,
                        source: dropSource
                    )
                            modelContext.insert(rel)
                            if let type = allRelationTypes.first(where: { $0.name == selectedRelationTypeName }) {
                                type.relationships.append(rel)
                            }
                            try? modelContext.save()
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
            AlternateNameFormView(alternateName: nil, preSelectedFigure: self.figure)
        }
        .sheet(isPresented: $showParentSearch) {
            ParentCoupleSheet(
                childFigure: self.figure,
                preferredTypeName: self.parentSearchTypeName,
                isPresented: self.$showParentSearch
            )
        }
        .sheet(isPresented: $showAddCitation) {
            AddCitationSheet(figure: self.figure)
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
            return isFrom ? "\(name) of" : "Has \(name)"
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

// MARK: - Parent Couple Sheet

private struct ParentCoupleSheet: View {
    let childFigure: Figure
    let preferredTypeName: String
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext

    @State private var fatherSearchText = ""
    @State private var motherSearchText = ""
    @State private var selectedFather: Figure?
    @State private var selectedMother: Figure?

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredFathers: [Figure] {
        let figs = allFigures.filter { $0.persistentModelID != selectedMother?.persistentModelID }
        return fatherSearchText.isEmpty ? figs : figs.filter { $0.name.localizedCaseInsensitiveContains(fatherSearchText) }
    }

    private var filteredMothers: [Figure] {
        let figs = allFigures.filter { $0.persistentModelID != selectedFather?.persistentModelID }
        return motherSearchText.isEmpty ? figs : figs.filter { $0.name.localizedCaseInsensitiveContains(motherSearchText) }
    }

    private var canAdd: Bool { selectedFather != nil || selectedMother != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    searchColumn(
                        label: "Father",
                        searchText: $fatherSearchText,
                        selected: $selectedFather,
                        filtered: filteredFathers
                    )
                    Divider()
                    searchColumn(
                        label: "Mother",
                        searchText: $motherSearchText,
                        selected: $selectedMother,
                        filtered: filteredMothers
                    )
                }
                .frame(maxHeight: .infinity)

                Divider()

                HStack {
                    Text("Both parents are optional. Added parents form a couple.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.bordered)
                    Button("Add") { addCouple() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAdd)
                }
                .padding(12)
            }
            .navigationTitle("Select Parent Couple")
            .frame(width: 580, height: 460)
        }
        .onAppear {
            if preferredTypeName == "Father" {
                fatherSearchText = ""
            } else {
                motherSearchText = ""
            }
        }
    }

    private func searchColumn(label: String, searchText: Binding<String>, selected: Binding<Figure?>, filtered: [Figure]) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.top, 10)
                .padding(.bottom, 4)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search \(label.lowercased())…", text: searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 8)

            if let fig = selected.wrappedValue {
                HStack(spacing: 4) {
                    Text(fig.gender.symbol)
                        .font(.caption)
                    Text(fig.name)
                        .font(.callout)
                    Button { selected.wrappedValue = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(fig.figureType?.color.opacity(0.12) ?? Color.gray.opacity(0.12))
                .cornerRadius(6)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            } else {
                List(filtered, id: \.persistentModelID) { fig in
                    Button {
                        selected.wrappedValue = fig
                        searchText.wrappedValue = ""
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
    }

    private func addCouple() {
        let existingParentRels = childFigure.incomingRelationships.filter {
            ($0.relationshipType?.name == "Father" || $0.relationshipType?.name == "Mother") &&
            !$0.groupID.isEmpty
        }
        let groupID: String
        if let existingGID = existingParentRels.first(where: { gid in
            let rels = existingParentRels.filter { $0.groupID == gid.groupID }
            let hasFather = rels.contains { $0.relationshipType?.name == "Father" }
            let hasMother = rels.contains { $0.relationshipType?.name == "Mother" }
            return !(hasFather && hasMother)
        }).map(\.groupID) {
            groupID = existingGID
        } else {
            groupID = UUID().uuidString
        }

        if let father = selectedFather {
            upsertParent(parent: father, typeName: "Father", groupID: groupID)
        }
        if let mother = selectedMother {
            upsertParent(parent: mother, typeName: "Mother", groupID: groupID)
        }
        try? modelContext.save()
        isPresented = false
    }

    private func upsertParent(parent: Figure, typeName: String, groupID: String) {
        let type = fetchOrCreateType(name: typeName)
        guard let type else { return }

        let existingRels = childFigure.incomingRelationships.filter {
            $0.relationshipType?.name == typeName
        }

        if let existingRel = existingRels.first {
            existingRel.groupID = groupID
            existingRel.fromFigure = parent
        } else {
            let rel = Relationship(fromFigure: parent, toFigure: childFigure, groupID: groupID)
            modelContext.insert(rel)
            type.relationships.append(rel)
        }
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
    @State private var comments: String = ""

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

                VStack(alignment: .leading, spacing: 4) {
                    Text("Comments:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. first antediluvian king", text: $comments)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
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
        let assoc = FigurePlaceAssociation(comments: comments.isEmpty ? nil : comments)
        modelContext.insert(assoc)
        figure.placeAssociations.append(assoc)
        place.figureAssociations.append(assoc)
        role.associations.append(assoc)
        try? modelContext.save()
    }
}

private struct AddCitationSheet: View {
    let figure: Figure
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var sources: [Source]

    @State private var selectedSource: Source?
    @State private var location = ""
    @State private var note = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Citation")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Source") {
                    Picker("Source", selection: $selectedSource) {
                        Text("Select a source").tag(nil as Source?)
                        ForEach(sources, id: \.persistentModelID) { source in
                            Text(source.name).tag(source as Source?)
                        }
                    }
                }

                TextField("Location", text: $location, prompt: Text("e.g. Tablet I, line 15"))

                TextField("Note", text: $note, prompt: Text("Optional note"))
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    let citation = Citation(
                        source: selectedSource,
                        location: location,
                        note: note,
                        entityType: .figure,
                        linkedEntityName: figure.name
                    )
                    modelContext.insert(citation)
                    try? modelContext.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedSource == nil)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
    }
}

