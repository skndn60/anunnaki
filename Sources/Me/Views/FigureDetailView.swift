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
    @Query(sort: \Source.name) private var dropSources: [Source]
    @State private var dropSource: Source?
    @State private var isDropTargeted = false

    @State private var showParentSearch = false
    @State private var parentSearchTypeName = ""



    @State private var filterText = ""
    @State private var showAddCitation = false
    @State private var showAddAttribution = false
    @State private var editingAttribution: ContentAttribution?
    @State private var showMugshotSheet = false
    @State private var showingPopupTableGrid: PopupTable?
    @State private var showDescriptionEditor = false
    @State private var editRichDescription: Data? = nil
    @State private var editPlainDescription = ""
    @State private var copiedName = false
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

    private func markParentKnownUnavailable(_ typeName: String) {
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
    }

    private func revertParentKnownUnavailable(_ typeName: String) {
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
    }

    private var figureAttributions: [ContentAttribution] {
        let all: [ContentAttribution] = modelContext.fetchAll()
        return all.filter { $0.figure == figure }
    }

    private var isDivineFigure: Bool {
        guard let name = figure.figureType?.name else { return false }
        return ["Deity", "Primordial", "Semi-Divine", "Igigi", "Archangel", "Commander"].contains(name)
    }

    private var figureCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == figure.name && $0.safeEntityType == .figure }
    }

    private var filteredRelationships: [Relationship] {
        let filtered = matchingRelationships.filter {
            matchesFilter($0.fromFigure?.name ?? "") ||
            matchesFilter($0.toFigure?.name ?? "") ||
            matchesFilter($0.relationshipType?.name ?? "")
        }
        return filtered.sorted {
            let l0 = displayedLabelPrefix(of: $0)
            let l1 = displayedLabelPrefix(of: $1)
            if l0 != l1 { return l0 < l1 }
            let n0 = otherFigureName(in: $0)
            let n1 = otherFigureName(in: $1)
            return n0 < n1
        }
    }

    private func displayedLabelPrefix(of relationship: Relationship) -> String {
        let isFrom = relationship.fromFigure?.persistentModelID == figure.persistentModelID
        return relationshipDirectionPrefix(relationship, perspective: figure, isFrom: isFrom)
    }

    private func otherFigureName(in relationship: Relationship) -> String {
        let isFrom = relationship.fromFigure?.persistentModelID == figure.persistentModelID
        return (isFrom ? relationship.toFigure?.name : relationship.fromFigure?.name) ?? ""
    }

    private func matchesFilter(_ text: String) -> Bool {
        guard !filterText.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(filterText)
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
            Button {
                showMugshotSheet = true
            } label: {
                MugshotView(
                    image: figure.mugshotImage,
                    cropRect: ImageCropRect(encoded: figure.mugshotCropRect),
                    size: 44,
                    figureType: figure.figureType,
                    identification: figure.mugshotIdentification
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .background(Circle().fill(Color(.textBackgroundColor)))
                }
            }
            .buttonStyle(.plain)
            .help("Set mugshot")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(figure.name)
                        .font(.title2.bold())
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(figure.name, forType: .string)
                        copiedName = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if copiedName { copiedName = false }
                        }
                    } label: {
                        Image(systemName: copiedName ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(copiedName ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .baselineOffset(9)
                    .help("Copy name to clipboard")
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
                    AttributedPropertyView(attributions: figureAttributions, propertyName: "title") {
                        Text(figure.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                FigureEpithetRow(epithet: figure.epithet)
            }

            Spacer()

            FigureTypeBadge(figureType: figure.figureType)
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

            Button {
                editRichDescription = figure.richDescription
                editPlainDescription = figure.figureDescription
                showDescriptionEditor = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit description")
        }
        .sheet(isPresented: $showDescriptionEditor) {
            DescriptionEditorSheet(
                entityName: figure.name,
                richDescription: $editRichDescription,
                plainDescription: $editPlainDescription
            )
            .onDisappear {
                figure.richDescription = editRichDescription
                figure.figureDescription = editPlainDescription
                try? modelContext.save()
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
                        .textFieldStyle(.roundedBorder)
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
                    PropertyRow(label: "Cause of Death", value: figure.causeOfDeath ?? "Unknown")
                    PropertyRow(label: "Source", value: figure.source)
                    if figure.reignStartYear != nil || figure.reignEndYear != nil {
                        let reignStr: String = {
                            switch (figure.reignStartYear, figure.reignEndYear) {
                            case let (s?, e?): return "\(abs(s))\u{2013}\(abs(e)) BC"
                            case let (s?, nil): return "From \(abs(s)) BC"
                            case let (nil, e?): return "To \(abs(e)) BC"
                            default: return ""
                            }
                        }()
                        PropertyRow(label: "Reign", value: reignStr)
                    }
                }

                // Mini Lineage Tree
                MiniLineageView(figure: figure, relationships: matchingRelationships, isParentGap: { [weak figure] typeName in
                    guard figure != nil else { return false }
                    return isParentGap(typeName: typeName)
                }, onSelectFigure: onSelectFigure, onTapUnknownParent: { typeName in
                    parentSearchTypeName = typeName
                    showParentSearch = true
                }, onMarkKnownUnavailable: { typeName in
                    markParentKnownUnavailable(typeName)
                }, onRevertKnownUnavailable: { typeName in
                    revertParentKnownUnavailable(typeName)
                })

                // Description
                if !figure.figureDescription.isEmpty || figure.richDescription != nil {
                    AttributedPropertyView(attributions: figureAttributions, propertyName: "figureDescription") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            LinkedDescription(text: figure.figureDescription, richData: figure.richDescription)
                                .font(.body)
                        }
                    }
                }

                // Attributions
                ContentAttributionSection(
                    attributions: figureAttributions,
                    onAdd: { showAddAttribution = true },
                    onEdit: { editingAttribution = $0 },
                    onDelete: { attribution in
                        modelContext.delete(attribution)
                        try? modelContext.save()
                    }
                )

                // Alternate Names
                AlternateNamesSection(figure: figure, filterText: filterText)

                // Relationships
                if !filteredRelationships.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Relationships")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(filteredRelationships, id: \.persistentModelID) { rel in
                            RelationshipGroupRow(
                                relationship: rel,
                                alternatives: [],
                                perspective: figure,
                                onSelectFigure: onSelectFigure
                            )
                        }
                    }
                }

                // Place Associations
                PlacesSection(figure: figure, filterText: filterText, onSelectPlace: onSelectPlace)

                // Associated Things
                ThingsSection(figure: figure)

                // Figure Groups
                GroupsSection(figure: figure)

                // Pantheons
                if isDivineFigure {
                    PantheonsSection(figure: figure)
                }

                // Comparison Tables
                ComparisonTablesSection(figure: figure, showingPopupTableGrid: $showingPopupTableGrid)

                // Associated Events
                EventsSection(figure: figure, filterText: filterText, onSelectEvent: onSelectEvent, onSelectPlace: onSelectPlace)

                // Images
                Divider()
                ImageGallery(
                    title: "Images",
                    images: figure.images,
                    onLinkImage: { asset in
                        figure.images.append(asset)
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
                CitationsSection(figure: figure, filterText: filterText, showAddCitation: $showAddCitation)

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

                SourcePickerView(selection: $dropSource, sources: dropSources)

                HStack(spacing: 16) {
                    Button("Cancel") { showDropConfirmation = false }
                        .buttonStyle(.bordered)
                    Button("OK") {
                        let allFigures: [Figure] = modelContext.fetchAll()
                        if let sourceFigure = allFigures.first(where: { $0.name == sourceName }) {
                    let rel = Relationship(
                        fromFigure: sourceFigure,
                        toFigure: self.figure,
                        source: dropSource?.name ?? ""
                    )
                            modelContext.insert(rel)
                            if let type = allRelationTypes.first(where: { $0.name == selectedRelationTypeName }) {
                                type.relationships.append(rel)
                            }
                            if let source = dropSource {
                                source.relationships.append(rel)
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
        .sheet(isPresented: $showAddAttribution) {
            ContentAttributionFormView(attribution: nil)
        }
        .sheet(item: $editingAttribution) { attribution in
            ContentAttributionFormView(attribution: attribution)
        }
        .sheet(isPresented: $showMugshotSheet) {
            MugshotSheet(figure: figure) { showMugshotSheet = false }
        }
        .sheet(item: $showingPopupTableGrid) { table in
            PopupTableView(table: table)
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
        VStack(alignment: .leading, spacing: 2) {
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

                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete relationship")
            }

            if !relationship.sourceDisplayName.isEmpty {
                SourceBadgeView(name: relationship.sourceDisplayName, url: relationship.sourceURL)
                    .padding(.leading, 16)
            }
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
        relationshipDirectionPrefix(relationship, perspective: perspective, isFrom: isFrom)
    }

    private var relationshipIcon: String { relationship.relationshipType?.icon ?? "questionmark" }

    private var relationshipColor: Color { relationship.relationshipType?.color ?? .gray }
}

/// Direction-aware label prefix for a relationship as seen from `perspective`.
/// Outgoing ("Father of") and incoming ("Son of" / reverseName) directions are
/// phrased from the viewer's standpoint so a child always reads as a child.
private func relationshipDirectionPrefix(_ relationship: Relationship, perspective: Figure, isFrom: Bool) -> String {
    let name = relationship.relationshipType?.name ?? ""
    if let reverseName = relationship.relationshipType?.reverseName, !reverseName.isEmpty {
        return isFrom ? "\(name) of" : "\(reverseName) of"
    }
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
            Text(directionLabel + (otherFigure?.name ?? "?"))
                .font(.callout)
                .foregroundStyle(.secondary)
            if !relationship.sourceDisplayName.isEmpty {
                SourceBadgeView(name: relationship.sourceDisplayName, url: relationship.sourceURL)
            }
        }
    }

    private var directionLabel: String {
        let isFrom = relationship.fromFigure?.persistentModelID == perspective.persistentModelID
        return relationshipDirectionPrefix(relationship, perspective: perspective, isFrom: isFrom) + " "
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
    @State private var selectedFather: FigureSearchResult?
    @State private var selectedMother: FigureSearchResult?

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredFathers: [FigureSearchResult] {
        let figs = allFigures.filter { $0.persistentModelID != selectedMother?.figure.persistentModelID }
        return searchFigures(figs, query: fatherSearchText)
    }

    private var filteredMothers: [FigureSearchResult] {
        let figs = allFigures.filter { $0.persistentModelID != selectedFather?.figure.persistentModelID }
        return searchFigures(figs, query: motherSearchText)
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

    private func searchColumn(label: String, searchText: Binding<String>, selected: Binding<FigureSearchResult?>, filtered: [FigureSearchResult]) -> some View {
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
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 8)

            if let result = selected.wrappedValue {
                HStack(spacing: 4) {
                    Text(result.figure.gender.symbol)
                        .font(.caption)
                    Text(result.displayName)
                        .font(.callout)
                    Button { selected.wrappedValue = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(result.figure.figureType?.color.opacity(0.12) ?? Color.gray.opacity(0.12))
                .cornerRadius(6)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            } else {
                List(filtered) { result in
                    Button {
                        selected.wrappedValue = result
                        searchText.wrappedValue = ""
                    } label: {
                        HStack(spacing: 10) {
                            Text(result.figure.gender.symbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                            Text(result.displayName)
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
            upsertParent(parent: father.figure, typeName: "Father", groupID: groupID)
        }
        if let mother = selectedMother {
            upsertParent(parent: mother.figure, typeName: "Mother", groupID: groupID)
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


